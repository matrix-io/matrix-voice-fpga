/*
* Copyright 2016 <Admobilize>
* MATRIX Labs  [http://creator.matrix.one]
* This file is part of MATRIX Creator HDL for Spartan 6
*
* MATRIX Creator HDL is like free software: you can redistribute
* it and/or modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.

* This program is distributed in the hope that it will be useful, but
* WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.

* You should have received a copy of the GNU General Public License along
* with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

module system #(
  parameter                  BOOTRAM_FILE      = "rtl/wb_bram/image               .ram",
  parameter                  EVERLOOP_FILE     = "rtl/wb_everloop/image           .ram",
  parameter                  ADDR_WIDTH        = 15                              ,
  parameter                  DATA_WIDTH        = 16                              ,
  parameter                  GPIO_WIDTH        = 13                              ,
  //General Configuration
  parameter                  SYS_FREQ_HZ       = 150_000_000                     ,
  parameter                  CLKFX_DIVIDE      = 1                               ,
  parameter                  CLKFX_MULTIPLY    = 3                               ,
  parameter [          63:0] VERSION           = 64'hBAD2_6032_000A_0001         ,
  //Microphone Configuration
  parameter                  OUT_FREQ_HZ       = 16_000                          ,
  parameter                  PDM_FREQ_HZ       = 3_000_000                       , /* this frequency must be multiple of 16000, 22000, 44000, 48000 Hz */
  parameter [DATA_WIDTH-1:0] PDM_RATIO   = $floor(SYS_FREQ_HZ/PDM_FREQ_HZ)-1,
  parameter [DATA_WIDTH-1:0] PDM_READING_TIME = $floor(7*PDM_RATIO/12),
  parameter [DATA_WIDTH-1:0] DECIMATION_RATIO = $floor((SYS_FREQ_HZ ) / (OUT_FREQ_HZ * (PDM_RATIO+1)))-1,
  parameter [DATA_WIDTH-1:0] DATA_GAIN_DEFAULT = 3                               ,
  //DAC Volumen Initial Configuration
  parameter                  VOLUMEN_PWM_FREQ  = 5_000_000                       ,
  parameter                  VOLUMEN_INIT      = SYS_FREQ_HZ/(2*VOLUMEN_PWM_FREQ),
  parameter                  BIT_FRAME_N       = 177                             , // 44_100 Constant
  // Everloop
  parameter [DATA_WIDTH-1:0] N_LEDS            = 18
) (
  input                   clk_50      ,
  input                   resetn      ,
  output                  led_debug   ,
  /* RASPBERRY's SPI interface */
  input                   rpi_mosi    ,
  input                   rpi_ss      ,
  input                   rpi_sck     ,
  output                  rpi_miso    ,
  input                   rpi_ss1     ,
  /* Component SPI interface */
  output                  component_mosi,
  output                  component_cs ,
  output                  component_clk,
  /* ESP SPI interface */
  input                   esp_mosi    ,
  input                   esp_ss      ,
  input                   esp_sck     ,
  output                  esp_miso    ,
  /* PDM MIC Array */
  input  [           7:0] pdm_data    ,
  output                  pdm_clk     ,
  output [           1:0] mic_irq     ,
  /* Everloop */
  output                  everloop_ctl,
  /* ESP_INTERFACE */
  inout                   EN_ESP      ,
  inout                   EN_PROG_ESP ,
  input                   ESP_TX      ,
  output                  ESP_RX      ,
  input                   PI_TX       ,
  output                  PI_RX       ,
  input                   GPIO_25     ,
  input                   GPIO_24     ,
  /* DAC */
  inout  [           1:0] dac_output  ,
  output                  dac_volumen ,
  output                  dac_mute    ,
  output                  dac_hp_nspk ,
  /* GPIO */
  inout  [GPIO_WIDTH-1:0] gpio_io
  /* Debug */
);

  // Set up component SPI
  assign component_cs = rpi_ss1;
  assign component_clk = rpi_sck;
  assign component_mosi = rpi_mosi;

  assign ESP_RX      = PI_TX;
  assign PI_RX       = ESP_TX;
  assign EN_ESP      = count[1]&GPIO_25?1'bZ:1'b0;
  assign EN_PROG_ESP = count[1]&GPIO_24?1'bZ:1'b0;

  reg[1:0] count;

  always @(posedge clk) begin
    if(!count[1])
      count <= count + 1;
  end

  wire mic_array_irq;

  assign mic_irq[0] = mic_array_irq;
  assign mic_irq[1] = mic_array_irq;

  assign led_debug = 1'b0;

//------------------------------------------------------------------
// DCM Logic
//------------------------------------------------------------------
  wire clk ;
  wire nclk;
  creator_dcm #(
    .CLKFX_DIVIDE  (CLKFX_DIVIDE  ),
    .CLKFX_MULTIPLY(CLKFX_MULTIPLY)
  ) dcm (
    .clkin       (clk_50),
    .clk_out_200 (clk   ),
    .nclk_out_200(nclk  ),
    .clk_out_25  (      )
  );

//------------------------------------------------------------------
// Whishbone Wires
//------------------------------------------------------------------
  wire                  gnd   = 1'b0              ;
  wire [           1:0] gnd2  = 4'h0              ;
  wire [DATA_WIDTH-1:0] gnd16 = {DATA_WIDTH{1'b0}};
  wire [ADDR_WIDTH-1:0] gnd15 = {ADDR_WIDTH{1'b0}};

  wire [ADDR_WIDTH-1:0]   spi0_adr,
                          spi1_adr,
                          bram0_adr,
                          mic_array_adr,
                          everloop_adr,
                          dac_adr,
                          gpio0_adr;

  wire [DATA_WIDTH-1:0]   spi0_dat_i,
                          spi0_dat_o,
                          spi1_dat_i,
                          spi1_dat_o,
                          bram0_dat_r,
                          bram0_dat_w,
                          mic_array_dat_r,
                          mic_array_dat_w,
                          everloop_dat_r,
                          everloop_dat_w,
                          dac_dat_r,
                          dac_dat_w,
                          gpio0_dat_r,
                          gpio0_dat_w;

  wire [1:0]    bram0_sel,
                mic_array_sel,
                everloop_sel,
                dac_sel,
                gpio0_sel;

  wire          spi0_we,
                spi1_we,
                bram0_we,
                mic_array_we,
                everloop_we,
                dac_we,
                gpio0_we;


  wire          spi0_cyc,
                spi1_cyc,
                bram0_cyc,
                mic_array_cyc,
                everloop_cyc,
                dac_cyc,
                gpio0_cyc;


  wire          spi0_stb,
                spi1_stb,
                bram0_stb,
                mic_array_stb,
                everloop_stb,
                dac_stb,
                gpio0_stb;

  wire          spi0_ack,
                spi1_ack,
                bram0_ack,
                mic_array_ack,
                everloop_ack,
                dac_ack,
                gpio0_ack;

//---------------------------------------------------------------------------
// Wishbone Interconnect
//---------------------------------------------------------------------------

  conbus #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .s_addr_w  (3         ),
    .s0_addr   (3'b000    ), // bram          000 0000 0000 0000 0x0000
    .s1_addr   (3'b010    ), // mic_array     010 0000 0000 0000 0x2000
    .s2_addr   (3'b011    ), // everloop0     011 0000 0000 0000 0x3000
    .s3_addr   (3'b110    ), // dac0          110 0000 0000 0000 0x6000
    .s4_addr   (3'b100    )  // gpio0         100 0000 0000 0000 0x4000
  ) conbus0 (
    .sys_clk (clk            ),
    .sys_rst (resetn         ),
    // Master0 to the RPi
    .m0_dat_i(spi0_dat_i     ),
    .m0_dat_o(spi0_dat_o     ),
    .m0_adr_i(spi0_adr       ),
    .m0_we_i (spi0_we        ),
    .m0_sel_i(gnd2           ),
    .m0_cyc_i(spi0_cyc       ),
    .m0_stb_i(spi0_stb       ),
    .m0_cti_i(3'b000         ),
    .m0_ack_o(spi0_ack       ),
    // Master1 to the ESP32
    .m1_dat_i(spi1_dat_i     ),
    .m1_dat_o(spi1_dat_o     ),
    .m1_adr_i(spi1_adr       ),
    .m1_we_i (spi1_we        ),
    .m1_sel_i(gnd2           ),
    .m1_cyc_i(spi1_cyc       ),
    .m1_stb_i(spi1_stb       ),
    .m1_cti_i(3'b000         ),
    .m1_ack_o(spi1_ack       ),
    
    // Slave0  bram
    .s0_dat_i(bram0_dat_r    ),
    .s0_dat_o(bram0_dat_w    ),
    .s0_adr_o(bram0_adr      ),
    .s0_sel_o(bram0_sel      ),
    .s0_we_o (bram0_we       ),
    .s0_cyc_o(bram0_cyc      ),
    .s0_stb_o(bram0_stb      ),
    .s0_ack_i(bram0_ack      ),
    
    // Slave1  mic_array
    .s1_dat_i(mic_array_dat_r),
    .s1_dat_o(mic_array_dat_w),
    .s1_adr_o(mic_array_adr  ),
    .s1_sel_o(mic_array_sel  ),
    .s1_we_o (mic_array_we   ),
    .s1_cyc_o(mic_array_cyc  ),
    .s1_stb_o(mic_array_stb  ),
    .s1_ack_i(mic_array_ack  ),
    
    // Slave2  mic_array
    .s2_dat_i(everloop_dat_r ),
    .s2_dat_o(everloop_dat_w ),
    .s2_adr_o(everloop_adr   ),
    .s2_sel_o(everloop_sel   ),
    .s2_we_o (everloop_we    ),
    .s2_cyc_o(everloop_cyc   ),
    .s2_stb_o(everloop_stb   ),
    .s2_ack_i(everloop_ack   ),
    
    // Slave3  mic_array
    .s3_dat_i(dac_dat_r      ),
    .s3_dat_o(dac_dat_w      ),
    .s3_adr_o(dac_adr        ),
    .s3_sel_o(dac_sel        ),
    .s3_we_o (dac_we         ),
    .s3_cyc_o(dac_cyc        ),
    .s3_stb_o(dac_stb        ),
    .s3_ack_i(dac_ack        ),

    // Slave3  mic_array
    .s4_dat_i(gpio0_dat_r    ),
    .s4_dat_o(gpio0_dat_w    ),
    .s4_adr_o(gpio0_adr      ),
    .s4_sel_o(gpio0_sel      ),
    .s4_we_o (gpio0_we       ),
    .s4_cyc_o(gpio0_cyc      ),
    .s4_stb_o(gpio0_stb      ),
    .s4_ack_i(gpio0_ack      )
  );

//---------------------------------------------------------------------------
// RASPBERRY's SPI INTERFACE
//---------------------------------------------------------------------------
  wb_spi_slave #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) spi0 (
    .clk       (clk       ),
    .resetn    (resetn    ),
    
    .mosi      (rpi_mosi  ),
    .ss        (rpi_ss    ),
    .sck       (rpi_sck   ),
    .miso      (rpi_miso  ),
    
    .data_bus_r(spi0_dat_i),
    .data_bus_w(spi0_dat_o),
    .addr_bus  (spi0_adr  ),
    .strobe    (spi0_stb  ),
    .cycle     (spi0_cyc  ),
    .wr        (spi0_we   ),
    .ack       (spi0_ack  )
  );


//---------------------------------------------------------------------------
// ESP32 INTERFACE
//---------------------------------------------------------------------------
  wb_spi_slave #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) spi1 (
    .clk       (clk       ),
    .resetn    (resetn    ),
    
    .mosi      (esp_mosi  ),
    .ss        (esp_ss    ),
    .sck       (esp_sck   ),
    .miso      (esp_miso  ),
    
    .data_bus_r(spi1_dat_i),
    .data_bus_w(spi1_dat_o),
    .addr_bus  (spi1_adr  ),
    .strobe    (spi1_stb  ),
    .cycle     (spi1_cyc  ),
    .wr        (spi1_we   ),
    .ack       (spi1_ack  )
  );


//---------------------------------------------------------------------------
// Block RAM
//---------------------------------------------------------------------------
  wire [DATA_WIDTH-1:0] mic_sample_rate     ;
  wire [DATA_WIDTH-1:0] mic_data_gain       ;
  wire [DATA_WIDTH-1:0] dac_volumen_control ;
  wire [DATA_WIDTH-1:0] dac_bit_frame_number;

  wire dac_mute,dac_hp_nspk,dac_fifo_flush;


  wb_bram #(
    .ADDR_WIDTH       (ADDR_WIDTH       ),
    .DATA_WIDTH       (DATA_WIDTH       ),
    .VERSION          (VERSION          ),
    .CLKFX_DIVIDE     (CLKFX_DIVIDE     ),
    .CLKFX_MULTIPLY   (CLKFX_MULTIPLY   ),
    .DECIMATION_RATIO (DECIMATION_RATIO ),
    .DATA_GAIN_DEFAULT(DATA_GAIN_DEFAULT),
    .VOLUMEN_PWM_FREQ (VOLUMEN_PWM_FREQ ),
    .VOLUMEN_INIT     (VOLUMEN_INIT     ),
    .BIT_FRAME_N      (BIT_FRAME_N      )
  ) bram0 (
    .clk                 (clk                 ),
    .resetn              (resetn              ),
    .wb_adr_i            (bram0_adr           ),
    .wb_dat_o            (bram0_dat_r         ),
    .wb_dat_i            (bram0_dat_w         ),
    .wb_sel_i            (bram0_sel           ),
    .wb_stb_i            (bram0_stb           ),
    .wb_cyc_i            (bram0_cyc           ),
    .wb_we_i             (bram0_we            ),
    .wb_ack_o            (bram0_ack           ),
    // MIC Configuration
    .mic_sample_rate     (mic_sample_rate     ),
    .mic_data_gain       (mic_data_gain       ),
    // DAC Configuration
    .dac_volumen_control (dac_volumen_control ),
    .dac_bit_frame_number(dac_bit_frame_number),
    .dac_mute            (dac_mute            ),
    .dac_hp_nspk         (dac_hp_nspk         ),
    .dac_fifo_flush      (dac_fifo_flush      )
  );

//---------------------------------------------------------------------------
// Microphone Array
//---------------------------------------------------------------------------
  wb_mic_array #(
    .SYS_FREQ_HZ     (SYS_FREQ_HZ     ),
    .ADDR_WIDTH      (ADDR_WIDTH      ),
    .DATA_WIDTH      (DATA_WIDTH      ),
    .PDM_FREQ_HZ     (PDM_FREQ_HZ     ),
    .PDM_RATIO       (PDM_RATIO       ),
    .PDM_READING_TIME(PDM_READING_TIME)
  ) mic_array0 (
    .clk        (clk            ),
    .resetn     (resetn         ),
    // MIC_Interface
    .pdm_data   (pdm_data       ),
    .pdm_clk    (pdm_clk        ),
    .irq        (mic_array_irq  ),
    // Wishbone interface
    .wb_clk     (clk            ),
    .wb_stb_i   (mic_array_stb  ),
    .wb_cyc_i   (mic_array_cyc  ),
    .wb_we_i    (mic_array_we   ),
    .wb_adr_i   (mic_array_adr  ),
    .wb_sel_i   (mic_array_sel  ),
    .wb_dat_i   (mic_array_dat_w),
    .wb_dat_o   (mic_array_dat_r),
    .wb_ack_o   (mic_array_ack  ),
    //Configuration
    .sample_rate(mic_sample_rate),
    .data_gain  (mic_data_gain  )
  );

//---------------------------------------------------------------------------
// Everloop
//---------------------------------------------------------------------------
  wb_everloop #(
    .MEM_FILE_NAME(EVERLOOP_FILE),
    .SYS_FREQ_HZ  (SYS_FREQ_HZ  ),
    .ADDR_WIDTH   (ADDR_WIDTH   ),
    .DATA_WIDTH   (DATA_WIDTH   ),
    .N_LEDS       (N_LEDS)
  ) everloop0 (
    .clk         (clk           ),
    .resetn      (resetn        ),
    // Wishbone interface
    .wb_stb_i    (everloop_stb  ),
    .wb_cyc_i    (everloop_cyc  ),
    .wb_we_i     (everloop_we   ),
    .wb_adr_i    (everloop_adr  ),
    .wb_sel_i    (everloop_sel  ),
    .wb_dat_i    (everloop_dat_w),
    .wb_dat_o    (everloop_dat_r),
    .everloop_ctl(everloop_ctl  ),
    .wb_ack_o    (everloop_ack  )
  );

//---------------------------------------------------------------------------
// DAC
//---------------------------------------------------------------------------

  wb_dac #(
    .SYS_FREQ_HZ     (SYS_FREQ_HZ     ),
    .DATA_WIDTH      (DATA_WIDTH      ),
    .ADDR_WIDTH      (ADDR_WIDTH      ),
    .VOLUMEN_PWM_FREQ(VOLUMEN_PWM_FREQ)
  ) dac0 (
    .clk                 (clk                 ),
    .resetn              (resetn              ),
    //Wishbone interface
    .wb_stb_i            (dac_stb             ),
    .wb_cyc_i            (dac_cyc             ),
    .wb_we_i             (dac_we              ),
    .wb_adr_i            (dac_adr             ),
    .wb_sel_i            (dac_sel             ),
    .wb_dat_i            (dac_dat_w           ),
    .wb_dat_o            (dac_dat_r           ),
    .wb_ack_o            (dac_ack             ),
    //DAC
    .dac_output_l        (dac_output[0]       ),
    .dac_output_r        (dac_output[1]       ),
    .dac_volumen         (dac_volumen         ),
    //DAC Configuration
    .dac_volumen_control (dac_volumen_control ),
    .dac_bit_frame_number(dac_bit_frame_number),
    .dac_fifo_flush      (dac_fifo_flush      )
  );

//---------------------------------------------------------------------------
// GPIO
//---------------------------------------------------------------------------
  wb_gpio #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .GPIO_WIDTH(GPIO_WIDTH)
  ) gpio0 (
    .clk     (clk        ),
    .rst     (resetn     ),
    .wb_stb_i(gpio0_stb  ),
    .wb_cyc_i(gpio0_cyc  ),
    .wb_we_i (gpio0_we   ),
    .wb_adr_i(gpio0_adr  ),
    .wb_dat_i(gpio0_dat_w),
    .wb_dat_o(gpio0_dat_r),
    .gpio_io (gpio_io    ),
    .wb_ack_o(gpio0_ack  )
  );

endmodule 

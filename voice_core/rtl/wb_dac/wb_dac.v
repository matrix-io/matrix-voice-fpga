/*
* Copyright 2016-2020 MATRIX Labs
* MATRIX Labs  [http://creator.matrix.one]
*
* Authors: Kevin Patiño    <kevin.patino@admobilize.com>        
*
* This file is part of MATRIX Voice HDL for Spartan 6
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


/* DAC Sampling Frequency Table

Based in OUT_DATA_FREQ    = 4_000_000

FS (KHz)  ----    BIT_FRAME_N
8       ----        975
16      ----        487
32      ----        243
44.1    ----        176
48      ----        162
88.2    ----        88
96      ----        81
*/

module wb_dac #(
  parameter SYS_FREQ_HZ = "mandatory",
  parameter DATA_WIDTH = "mandatory",
  parameter ADDR_WIDTH = "mandatory",
  //DAC Initial Configuration
  parameter VOLUMEN_PWM_FREQ = "mandatory",
  parameter FIFO_ADDR_SIZE = ADDR_WIDTH-4                   ,
  parameter OUT_DATA_FREQ  = 4_000_000                      ,
  parameter SAMP_FREQ      = 44_100                         ,
  parameter SAMP_DAC       = (SYS_FREQ_HZ/(OUT_DATA_FREQ*2))
) (
  input                       clk                 ,
  input                       resetn              ,
  // Wishbone
  input                       wb_stb_i            ,
  input                       wb_cyc_i            ,
  input                       wb_we_i             ,
  input      [           1:0] wb_sel_i            ,
  input      [ADDR_WIDTH-1:0] wb_adr_i            ,
  input      [DATA_WIDTH-1:0] wb_dat_i            ,
  output reg [DATA_WIDTH-1:0] wb_dat_o            ,
  output                      wb_ack_o            ,
  //DAC
  inout                      dac_output_l        ,
  inout                      dac_output_r        ,
  output                      dac_volumen         ,
  //DAC Control
  input      [DATA_WIDTH-1:0] dac_volumen_control ,
  input      [DATA_WIDTH-1:0] dac_bit_frame_number,
  input                       dac_fifo_flush
);

  wire wb_rd = wb_stb_i & wb_cyc_i & ~wb_we_i & ~wb_ack_o;
  wire wb_wr = wb_stb_i & wb_cyc_i & wb_we_i & ~wb_ack_o ;

  wire dac_data_en,load_sigma,reset_sigma,channel_sel;

  assign dac_data_en = (wb_adr_i[FIFO_ADDR_SIZE] == 0) & wb_wr;

  wire [DATA_WIDTH-1:0] dac_data_r;
  wire [DATA_WIDTH-1:0] dac_data_l;

  dac #(.DATA_WIDTH(DATA_WIDTH)) dac0_left (
    .clk        (clk         ),
    .resetn     (resetn      ),
    .dac_data   (dac_data_l  ),
    .load_sigma (load_sigma  ),
    .dac_output (dac_output_l),
    .reset_sigma(reset_sigma )
  );

  dac #(.DATA_WIDTH(DATA_WIDTH)) dac1_rigth (
    .clk        (clk         ),
    .resetn     (resetn      ),
    .dac_data   (dac_data_r  ),
    .load_sigma (load_sigma  ),
    .dac_output (dac_output_r),
    .reset_sigma(reset_sigma )
  );

  wire empty,load_data,ack_fifo,fifo_ready;

  wire [FIFO_ADDR_SIZE:0] read_pointer,write_pointer;

  dac_fifo #(
    .ADDR_WIDTH(FIFO_ADDR_SIZE+1),
    .DATA_WIDTH(DATA_WIDTH      )
  ) dac_fifo0 (
    .clk          (clk           ),
    .resetn       (resetn        ),
    .write_enable (dac_data_en   ),
    .data_a       (wb_dat_i      ),
    .write_ack    (ack_fifo      ),
    
    .read_enable  (load_data     ),
    .data_b       (dac_data_r    ),
    .data_c       (dac_data_l    ),
    
    .empty        (empty         ),
    .fifo_ready   (fifo_ready    ),
    .read_pointer (read_pointer  ),
    .write_pointer(write_pointer ),
    .channel_sel  (channel_sel   ),
    .fifo_flush   (dac_fifo_flush)
  );

  reg [DATA_WIDTH-1:0] bit_frame_number;

  dac_fsm #(
    .DATA_WIDTH(DATA_WIDTH),
    .SAMP_DAC  (SAMP_DAC  )
  ) dac_fsm0 (
    .clk             (clk                 ),
    .resetn          (resetn              ),
    .empty           (empty               ),
    .ready           (fifo_ready          ),
    .reset_sigma     (reset_sigma         ),
    .bit_frame_number(dac_bit_frame_number),
    .load_data       (load_data           ),
    .load_sigma      (load_sigma          ),
    .channel_sel     (channel_sel         )
  );

  dac_control #(
    .SYS_FREQ_HZ(SYS_FREQ_HZ     ),
    .DATA_WIDTH (DATA_WIDTH      ),
    .PWM_FREQ   (VOLUMEN_PWM_FREQ)
  ) dac_control0 (
    .clk            (clk                ),
    .resetn         (resetn             ),
    .volumen_control(dac_volumen_control),
    .dac_volumen    (dac_volumen        )
  );

  reg wb_ack;
  assign wb_ack_o = wb_ack | ack_fifo;

  always @(posedge clk or posedge resetn) begin
    if (resetn) begin
      wb_ack   <= 0;
      wb_dat_o <= {DATA_WIDTH{1'b0}};
    end else begin
      wb_ack <= 0;
      if (wb_rd & wb_adr_i[FIFO_ADDR_SIZE]) begin
        wb_ack <= 1;
        case (wb_adr_i[3:0])
          3'b010  : wb_dat_o <= read_pointer;
          3'b011  : wb_dat_o <= write_pointer;
          default : wb_dat_o <= {DATA_WIDTH{1'b0}};
        endcase
      end
    end
  end

endmodule

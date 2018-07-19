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

module wb_bram #(
  parameter DATA_WIDTH = "mandatory",
  parameter ADDR_WIDTH = "mandatory",
  //General configuration
  parameter        CLKFX_DIVIDE   = "mandatory",
  parameter        CLKFX_MULTIPLY = "mandatory",
  parameter [63:0] VERSION        = "mandatory",
  //Microphone Configuration
  parameter [DATA_WIDTH-1:0] DECIMATION_RATIO  = "mandatory",
  parameter [DATA_WIDTH-1:0] DATA_GAIN_DEFAULT = "mandatory",
  //DAC Configuration
  parameter VOLUMEN_PWM_FREQ = "mandatory",
  parameter VOLUMEN_INIT     = "mandatory",
  parameter BIT_FRAME_N      = "mandatory",
  // Memory Configuration
  parameter MEM_ADDR_WIDTH = ADDR_WIDTH-7,
  parameter DEPTH          = (1            << MEM_ADDR_WIDTH)
) (
  input                       clk                 ,
  input                       resetn              ,
  //
  input                       wb_stb_i            ,
  input                       wb_cyc_i            ,
  input                       wb_we_i             ,
  input      [ADDR_WIDTH-1:0] wb_adr_i            ,
  output reg [DATA_WIDTH-1:0] wb_dat_o            ,
  input      [DATA_WIDTH-1:0] wb_dat_i            ,
  input      [           1:0] wb_sel_i            ,
  output reg                  wb_ack_o            ,
  // Register Configuration
  output reg [DATA_WIDTH-1:0] mic_sample_rate     ,
  output reg [DATA_WIDTH-1:0] mic_data_gain       ,
  output reg [DATA_WIDTH-1:0] dac_volumen_control ,
  output reg [DATA_WIDTH-1:0] dac_bit_frame_number,
  output reg                  dac_mute            ,
  output reg                  dac_hp_nspk         ,
  output reg                  dac_fifo_flush
);

  wire wb_wr,wb_rd;

  assign wb_wr = wb_cyc_i & wb_stb_i & wb_we_i & ~wb_ack_o;
  assign wb_rd = wb_cyc_i & wb_stb_i & ~wb_we_i & ~wb_ack_o;

  reg [DATA_WIDTH-1:0] ram[0:DEPTH-1];

//------------------------------------------------------------------
// read/write port A
//------------------------------------------------------------------
  always @(posedge clk) begin
    wb_ack_o <= 0;
    if(wb_wr | wb_rd) begin
      wb_ack_o <= 1;
      if (wb_wr)
        ram[wb_adr_i[MEM_ADDR_WIDTH-1:0]] <= wb_dat_i;

      wb_dat_o <= ram[wb_adr_i[MEM_ADDR_WIDTH-1:0]];
    end
  end

//------------------------------------------------------------------
// read port B
//------------------------------------------------------------------
  reg [DATA_WIDTH-1:0] data_ram      ;
  reg [           3:0] update_counter; //TODO: Parameter

  reg update_enable;

  localparam S_IDLE   = 1'd0;
  localparam S_UPDATE = 1'd1;

  reg state;

  always @(state) begin
    case(state)
      S_IDLE :
        update_enable = 1'b0;
      S_UPDATE :
        update_enable = 1'b1;
    endcase
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      state <= S_IDLE;
    else begin
      case(state)
        S_IDLE :
          if(wb_ack_o)
            state <= S_UPDATE;
        S_UPDATE :
          if(update_counter == 4'd12)
            state <= S_IDLE;
        else
          state <= S_UPDATE;
      endcase
    end
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn) begin
      update_counter <= 0;
    end else begin
      if(update_enable)
        update_counter <= update_counter + 1;
      else
        update_counter <= 0;
    end
  end

  always @(posedge clk) begin
    data_ram <= ram[update_counter];
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      mic_sample_rate <= DECIMATION_RATIO;
    else if (update_counter == 4'd6 + 1)
      mic_sample_rate <= data_ram;
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      mic_data_gain <= DATA_GAIN_DEFAULT;
    else if (update_counter == 4'd7 + 1)
      mic_data_gain <= data_ram;
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      dac_volumen_control <= VOLUMEN_INIT;
    else if (update_counter == 4'd8 + 1)
      dac_volumen_control <= data_ram;
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      dac_bit_frame_number <= BIT_FRAME_N;
    else if (update_counter == 4'd9 + 1)
      dac_bit_frame_number <= data_ram;
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      dac_mute <= 0;
    else if (update_counter == 4'd10 + 1)
      dac_mute <= data_ram[0];
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      dac_hp_nspk <= 0;
    else if (update_counter == 4'd11 + 1)
      dac_hp_nspk <= data_ram[0];
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      dac_fifo_flush <= 0;
    else if (update_counter == 4'd12 + 1)
      dac_fifo_flush <= data_ram[0];
  end

  integer i;
  initial
    begin
      ram[0] = VERSION[63-:16];
      ram[1] = VERSION[63-16-:16];
      ram[2] = VERSION[63-32-:16];
      ram[3] = VERSION[63-48-:16];
      ram[4] = CLKFX_DIVIDE;
      ram[5] = CLKFX_MULTIPLY;
      ram[6] = DECIMATION_RATIO;
      ram[7] = DATA_GAIN_DEFAULT;
      ram[8] = VOLUMEN_INIT;
      ram[9] = BIT_FRAME_N;
      ram[10] = 0;
      ram[11] = 16'd1;
      ram[12] = 0;
      for (i = 13; i < DEPTH ; i=i+1) begin
        ram[i] = 0;
      end
    end

endmodule


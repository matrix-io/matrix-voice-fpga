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

module dac_fsm #(
  parameter DATA_WIDTH = "mandatory",
  parameter SAMP_DAC = "mandatory"
)(
  input                  clk             ,
  input                  resetn          ,
  input                  empty           ,
  input                  ready           ,
  input [DATA_WIDTH-1:0] bit_frame_number,
  //Output Control Signals
  output reg             load_data       ,
  output reg             load_sigma      ,
  output reg             reset_sigma     ,
  output reg             channel_sel
);

  reg [DATA_WIDTH-1:0] dac_counter;
  reg [DATA_WIDTH-1:0] sigma_count;

  wire time_trigger,dac_complete;

  reg [2:0] state;

  localparam [2:0] S_IDLE        = 3'd0;
  localparam [2:0] S_CHARGE_DATA_L = 3'd1;
  localparam [2:0] S_CHARGE_DATA_R = 3'd2;
  localparam [2:0] S_WAIT        = 3'd3;
  localparam [2:0] S_LOAD_SIGMA  = 3'd4;


  always @(posedge clk or posedge resetn) begin
    if(resetn | time_trigger | load_data)
      dac_counter <= 0;
    else
      dac_counter <= dac_counter + 1;
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn | load_data) begin
      sigma_count <= 0;
    end else begin
      if(load_sigma) begin
        sigma_count <= sigma_count + 1;
      end else begin
        sigma_count <= sigma_count;
      end
    end
  end

  assign time_trigger = (dac_counter == SAMP_DAC);
  assign dac_complete = (sigma_count == bit_frame_number);

  always @(posedge clk or posedge resetn) begin
    if(resetn)
      state <= S_IDLE;
    else begin
      case(state)
        S_IDLE :
          if(empty)
            state <= S_IDLE;
        else if(ready)
          state <= S_CHARGE_DATA_L;

        S_CHARGE_DATA_L :
          state <= S_CHARGE_DATA_R;
        
        S_CHARGE_DATA_R :
          state <= S_WAIT;

        S_WAIT :
          if(time_trigger)
            state <= S_LOAD_SIGMA;
        else
          state <= S_WAIT;

        S_LOAD_SIGMA :
          if(dac_complete & ~empty)
            state <= S_CHARGE_DATA_L;
        else if(dac_complete & empty)
          state <= S_IDLE;
        else
          state <= S_WAIT;

        default :
          state <= S_IDLE;
      endcase
    end
  end

  always @(state) begin
    load_data   = 1'b0;
    load_sigma  = 1'b0;
    reset_sigma = 1'b0;
    channel_sel = 1'b0;
    case(state)
      S_IDLE : begin
        load_data   = 1'b0;
        load_sigma  = 1'b0;
        reset_sigma = 1'b1;
        channel_sel = 1'b0;
      end
      S_CHARGE_DATA_L : begin
        load_data   = 1'b1;
        load_sigma  = 1'b0;
        reset_sigma = 1'b0;
        channel_sel = 1'b0;
      end
      S_CHARGE_DATA_R : begin
        load_data   = 1'b1;
        load_sigma  = 1'b0;
        reset_sigma = 1'b0;
        channel_sel = 1'b1;
      end
      S_WAIT : begin
        load_data   = 1'b0;
        load_sigma  = 1'b0;
        reset_sigma = 1'b0;
        channel_sel = 1'b0;
      end
      S_LOAD_SIGMA : begin
        load_data   = 1'b0;
        load_sigma  = 1'b1;
        reset_sigma = 1'b0;
        channel_sel = 1'b0;
      end
      default : begin
        load_data   = 1'b0;
        load_sigma  = 1'b0;
        reset_sigma = 1'b0;
        channel_sel = 1'b0;
      end
    endcase
  end

endmodule
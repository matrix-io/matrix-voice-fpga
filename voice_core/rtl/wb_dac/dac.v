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

module dac #(parameter DATA_WIDTH = 16) (
  input                   clk        , // Clock
  input                   resetn     , // Asynchronous reset active low
  input                   reset_sigma,
  input  [DATA_WIDTH-1:0] dac_data   ,
  input                   load_sigma ,
  inout                  dac_output
);

  wire [DATA_WIDTH+1:0] delta_add;
  wire [DATA_WIDTH+1:0] sigma_add;

  reg [DATA_WIDTH+1:0] sigma_reg;
  reg [DATA_WIDTH+1:0] delta    ;

  initial begin
    sigma_reg = 0;
  end

  always @(*) begin
    if(dac_output)
      delta = 2'b11 << DATA_WIDTH;
    else
      delta = 0;
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn|reset_sigma) begin
      sigma_reg <= 0;
    end else begin
      if(load_sigma)
        sigma_reg <= sigma_add;
      else
        sigma_reg <= sigma_reg;
    end
  end

  assign dac_output = (reset_sigma) ? 1'bz : sigma_reg[DATA_WIDTH+1];
  assign delta_add  = dac_data + delta;
  assign sigma_add  = sigma_reg + delta_add;

endmodule

/*
* Copyright 2016-2020 MATRIX Labs
* MATRIX Labs  [http://creator.matrix.one]
*
* Authors: Andres Calderon <andres.calderon@admobilize.com>
*          Kevin Patiño    <kevin.patino@admobilize.com>        
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

  module dac_control #(
    parameter SYS_FREQ_HZ = "mandatory",
    parameter DATA_WIDTH = "mandatory",
    parameter PWM_FREQ = "mandatory",
    parameter PWM_COUNTER = SYS_FREQ_HZ/PWM_FREQ,
    parameter COUNT_WIDTH = $clog2(PWM_COUNTER)
) (
    input                   clk            ,
    input                   resetn         ,
    input  [DATA_WIDTH-1:0] volumen_control,
    output                  dac_volumen
  );
  
  reg [COUNT_WIDTH-1:0] counter; 

  wire reset_count;
  assign reset_count = (counter == PWM_COUNTER);

  always @(posedge clk or posedge resetn) begin
    if(resetn ) 
      counter <= 0;
    else  if (reset_count)
      counter <= 0;
    else   
      counter <= counter + 1;
  end

  assign dac_volumen = (counter < volumen_control); 
  
endmodule // dac_control

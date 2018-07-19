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

module dac_fifo #(
  parameter ADDR_WIDTH = "mandatory",
  parameter DATA_WIDTH = "mandatory",
  parameter EMPTY_CONSTANT = (2  ** ADDR_WIDTH)/4
) (
  input                       clk          ,
  input                       resetn       ,
  // write port a
  input                       write_enable ,
  output reg                  write_ack    ,
  input      [DATA_WIDTH-1:0] data_a       ,
  // read port b
  input                       read_enable  ,
  output reg                  read_ack     ,
  output reg [DATA_WIDTH-1:0] data_b       ,
  output reg [DATA_WIDTH-1:0] data_c       ,
  //status
  output                      empty        ,
  output                      fifo_ready   ,
  output reg [ADDR_WIDTH-1:0] read_pointer ,
  output reg [ADDR_WIDTH-1:0] write_pointer,
  input                       channel_sel  ,
  input                       fifo_flush
);

  initial begin
    write_ack = 0;
  end

  localparam DEPTH = (2 ** ADDR_WIDTH);

  reg [DATA_WIDTH-1:0] ram[0:DEPTH-1];

  assign empty = (write_pointer == read_pointer);

  always @(posedge clk or posedge resetn) begin
    if(resetn | fifo_flush) begin
      read_pointer <= 0;
    end else if(read_enable) begin
      read_pointer <= read_pointer + 1;
    end
  end

  always @(posedge clk or posedge resetn) begin
    if(resetn | fifo_flush) begin
      write_pointer <= 0;
    end else if(write_ack) begin
      write_pointer <= write_pointer + 1;
    end
  end

  reg [ADDR_WIDTH-1:0] diff_pointer;

  always @(*) begin
    if(write_pointer>read_pointer)
      diff_pointer <= write_pointer-read_pointer;
    else if(write_pointer)
      diff_pointer <= (DEPTH-read_pointer+write_pointer);
    else diff_pointer<=0;
  end

  assign fifo_ready = (diff_pointer > 1);

//------------------------------------------------------------------
// write port A
//------------------------------------------------------------------
  always @(posedge clk) begin
    write_ack <= 0;
    if (write_enable) begin
      ram[write_pointer] <= data_a;
      write_ack          <= 1;
    end
  end

//------------------------------------------------------------------
// read port B
//------------------------------------------------------------------
  always @(posedge clk) begin
    if(read_enable)
      data_b <= ram[read_pointer];
    else
      data_b <= data_b;
  end
//------------------------------------------------------------------
// port C Register
//------------------------------------------------------------------
  always @(posedge clk) begin
    if(resetn)
      data_c <= 0;
    else begin
      if(read_enable & channel_sel)
        data_c <= data_b;
      else
        data_c <= data_c;
    end
  end

endmodule // uart_fifo
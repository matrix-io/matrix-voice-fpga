`timescale 1ns / 1ps

  module system_TB;
       // Inputs
       reg clk;
       reg clk_esp;
       reg resetn;
       reg rpi_mosi;
       reg rpi_ss;
       reg rpi_sck;
       reg esp_mosi;
       reg esp_ss;
       reg esp_sck;
       reg uart0_rx;
       reg uart1_rx;
       reg [7:0]pdm_data;
       reg CS_SELECT;
       // Outputs
       wire miso;
       wire led;
       wire [15:0] gpio_io;
       
       wire nfc_sck;
       reg nfc_miso;

  system uut(
       .clk_50(clk), .resetn(resetn), .rpi_mosi(rpi_mosi), .rpi_ss(rpi_ss), .rpi_sck(rpi_sck), 
       .rpi_miso(rpi_miso), .esp_mosi(esp_mosi), .esp_ss(esp_ss), .esp_sck(esp_sck), 
       .esp_miso(esp_miso), .pdm_data(pdm_data)
       
  );

  initial begin
    // Initialize Inputs
    resetn = 0; clk = 0; clk_esp = 0; rpi_mosi = 0; rpi_ss = 1; rpi_sck = 1; esp_mosi = 0; esp_ss = 1; esp_sck = 1; uart0_rx = 0; nfc_miso = 0;
  end
  
//------------------------------------------
//          TRI-STATE GENERATION
//------------------------------------------
parameter PERIOD_INPUT = 8000;
parameter real DUTY_CYCLE_INPUT = 0.8;

reg [15:0] data;
reg [15:0] gpio_dir;

genvar k;
generate 
  for (k=0;k<16;k=k+1)  begin: gpio_tris
    assign gpio_io[k] = ~(gpio_dir[k]) ? data[k] : 1'bz;
  end
endgenerate

initial    // Clock process for clk
    begin
        #OFFSET;
        forever
        begin
            data = 16'h0000;
            #(PERIOD_INPUT-(PERIOD_INPUT*DUTY_CYCLE_INPUT)) data = 16'hFFFF;
            #(PERIOD_INPUT*DUTY_CYCLE_INPUT);
        end
    end


//------------------------------------------
//          RESET GENERATION
//------------------------------------------

event reset_trigger;
event reset_done_trigger;

initial begin 
  forever begin 
   @ (reset_trigger);
   @ (negedge clk);
   resetn = 1;
   @ (negedge clk);
   resetn = 0;
   -> reset_done_trigger;
  end
end


//------------------------------------------
//          CLOCK GENERATION
//------------------------------------------

    parameter TBIT   = 2;
    parameter PERIOD = 20;
    parameter real DUTY_CYCLE = 0.5;
    parameter OFFSET = 0;

//------------------------------------------
//          MEMORY MAP
//------------------------------------------
    
    parameter bram_addr = 0;
    parameter uart_addr = 14'h0800;
    parameter mica_addr = 14'h1000;
    parameter pxxx_addr = 14'h1800;
    parameter pyyy_addr = 14'h2000;

    parameter read      = 1;
    parameter write     = 0;
    parameter single    = 0;
    parameter burst     = 1;

    initial    // Clock process for clk
    begin
        #OFFSET;
        forever
        begin
            clk = 1'b0;
            #(PERIOD-(PERIOD*DUTY_CYCLE)) clk = 1'b1;
            #(PERIOD*DUTY_CYCLE);
        end
    end

    initial    // Clock process for clk
    begin
        #OFFSET;
        forever
        begin
            clk_esp = 1'b0;
            #(PERIOD-(PERIOD*DUTY_CYCLE)) clk_esp = 1'b1;
            #(PERIOD*DUTY_CYCLE);
        end
    end


//------------------------------------------
//          SPI SINGLE TRANSFER TASK
//------------------------------------------
  reg [4:0] i;
  reg [15:0] data_tx_rpi;
  reg [15:0] data_tx_e_rpi;

  task automatic spi_transfer_pi;
    input [14:0] address;
    input [15:0] data;
    input RnW;
  begin
    data_tx_e_rpi = {address,RnW};
    data_tx_rpi = {data_tx_e_rpi[7:0],data_tx_e_rpi[15:8]};
    rpi_ss = 1;
    repeat(4*TBIT) begin
      @(negedge clk);
    end
    rpi_ss = 0; 
    repeat(2*TBIT) begin
      @(negedge clk);
    end
  ///////////////////
  // Send address 
  ///////////////////
    for(i=0; i<16; i=i+1) begin
      rpi_sck = 0;
      rpi_mosi <= data_tx_rpi[15-i];
      repeat(TBIT) begin
        @(negedge clk);
      end
      rpi_sck = 1;	
      repeat(TBIT) begin
        @(negedge clk);
      end
    end
  ///////////////////
  // Send data
  ///////////////////
    data_tx_rpi <= {data[7:0],data[15:8]};
    repeat(2*TBIT) begin
      @(negedge clk);
    end
    for(i=0; i<16; i=i+1) begin
      rpi_sck = 0;
      rpi_mosi <= data_tx_rpi[15-i];
      repeat(TBIT) begin
        @(negedge clk);
      end
      rpi_sck = 1;	
      repeat(TBIT) begin
        @(negedge clk);
      end
    end
    repeat(4*TBIT) begin
      @(negedge clk);
    end		
    rpi_ss = 1;
    repeat(4*TBIT) begin
      @(negedge clk);
    end
  end
  endtask

  reg [4:0] j;
  reg [15:0] data_tx_esp;
  reg [15:0] data_tx_e_esp;

  task automatic spi_transfer_esp;
    input [14:0] address_esp;
    input [15:0] data_esp;
    input RnW_esp;
  begin
    data_tx_e_esp = {address_esp,RnW_esp};
    data_tx_esp = {data_tx_e_esp[7:0],data_tx_e_esp[15:8]};
    esp_ss = 1;
    repeat(4*TBIT) begin
      @(negedge clk_esp);
    end
    esp_ss = 0; 
    repeat(2*TBIT) begin
      @(negedge clk_esp);
    end
  ///////////////////
  // Send address 
  ///////////////////
    for(j=0; j<16; j=j+1) begin
      esp_sck = 0;
      esp_mosi <= data_tx_esp[15-j];
      repeat(TBIT) begin
        @(negedge clk_esp);
      end
      esp_sck = 1;  
      repeat(TBIT) begin
        @(negedge clk_esp);
      end
    end
  ///////////////////
  // Send data
  ///////////////////
    data_tx_esp <= {data_esp[7:0],data_esp[15:8]};
    repeat(2*TBIT) begin
      @(negedge clk_esp);
    end
    for(j=0; j<16; j=j+1) begin
      esp_sck = 0;
      esp_mosi <= data_tx_esp[15-j];
      repeat(TBIT) begin
        @(negedge clk_esp);
      end
      esp_sck = 1;  
      repeat(TBIT) begin
        @(negedge clk_esp);
      end
    end
    repeat(4*TBIT) begin
      @(negedge clk_esp);
    end   
    esp_ss = 1;
    repeat(4*TBIT) begin
      @(negedge clk_esp);
    end
  end
  endtask

parameter depth = (1 << 8);
// actual ram cells
reg [15:0] ram [0:depth-1];
localparam MEM_FILE_NAME = "rtl/wb_dac/sine";

initial 
begin
  if (MEM_FILE_NAME != "none")
  begin
    $readmemh(MEM_FILE_NAME, ram);
  end
end

//------------------------------------------
//          SPI BURST TRANSFER TASK
//------------------------------------------
  reg [4:0] ib;
  reg [4:0] jb;
  reg [15:0] data_txb[16:0];
  reg [15:0] data_txb_e;
  
  task automatic spi_burst_transfer;
    input [15:0] address_b;
    input [4:0] count;
    input RnW_b;
  begin
    data_txb_e = {address_b,RnW_b};
    data_txb[0] = {data_txb_e[7:0],data_txb_e[15:8]};
    data_txb[1] = {8'b1,8'b0};
    data_txb[2] = 0;
    data_txb[3] = 0;
    data_txb[4] = 0;
    data_txb[5] = 0;
    data_txb[6] = 0;
    data_txb[7] = 0;
    data_txb[8] = 0;
    data_txb[9] = 0;
    data_txb[10] = 0;
    data_txb[11] = 0;
    data_txb[12] = 0;
    data_txb[13] = 0;
    data_txb[14] = 0;
    data_txb[15] = 0;
    data_txb[16] = 0;

    rpi_ss = 1;
    repeat(20*TBIT) begin
      @(negedge clk);
    end
    rpi_ss = 0; 
    repeat(2*TBIT) begin
      @(negedge clk);
    end
    for(jb = 0; jb < count; jb = jb + 1) begin 
      repeat(2*TBIT) begin
        @(negedge clk);
      end
      for(ib = 0; ib < 16; ib = ib + 1) begin
        rpi_sck = 0;
        rpi_mosi <= data_txb[jb][15-ib];
        repeat(TBIT) begin
          @(negedge clk);
        end
        rpi_sck = 1;	
        repeat(TBIT) begin
          @(negedge clk);
        end
      end
    end
    rpi_ss = 1;
    repeat(4*TBIT) begin
      @(negedge clk);
    end
  end
  endtask

initial begin: TEST_CASE 
  #250 -> reset_trigger;
  #0 CS_SELECT <= 1'b0;
  #0 pdm_data <= 8'hAA;
  @ (reset_done_trigger);
  #500
  spi_transfer_pi(15'h4000 + 12, 16'd1, write);
  spi_transfer_pi(15'h4000 + 12, 16'd0, write);
  spi_burst_transfer(15'h2000,5'd17,write);
  //spi_transfer_pi(15'h6804, 16'd60, write);

  gpio_dir <= 16'hFFF0;
  //spi_transfer_pi(15'd7, 16'd1, write);
  //spi_transfer_pi(15'd8, 16'd1, write);
  spi_transfer_pi(15'd7, 0, read);

  spi_burst_transfer(15'h2000, 5'h12, read);
  #10 spi_transfer_esp(15'h5000, 16'hABCF, write);
  spi_transfer_esp(15'h5001, 16'hABCF, write);
  spi_transfer_esp(15'h5002, 16'hABCF, write);
  spi_transfer_esp(15'h5003, 16'hABCF, write);

  spi_transfer_esp(15'h0000, 16'hCDFA, write);
  spi_transfer_esp(15'h0000, 0, read);

  //#10 spi_transfer_pi(14'h0003, 0, single, read);
  //join
end

   initial begin: TEST_DUMP
     $dumpfile("system_TB.vcd");
     $dumpvars(-1 );
     #((PERIOD*DUTY_CYCLE)*75000) $finish;
   end

endmodule

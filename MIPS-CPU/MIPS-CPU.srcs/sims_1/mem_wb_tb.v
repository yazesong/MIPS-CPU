`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

module mem_wb_tb;
  reg clk, rst, pause, flush;
  reg mem_wreg_e;
  reg[`RegRangeLog2] mem_wreg_addr;
  reg[`WordRange] mem_wreg_data;
  reg mem_hilo_we;
  reg[`WordRange] mem_hi_data, mem_lo_data;
  reg mem_cp0_we;
  reg[4:0] mem_cp0_waddr;
  reg[`WordRange] mem_cp0_wdata;

  wire wb_wreg_e;
  wire[`RegRangeLog2] wb_wreg_addr;
  wire[`WordRange] wb_wreg_data;
  wire wb_hilo_we;
  wire[`WordRange] wb_hi_data, wb_lo_data;
  wire wb_cp0_we;
  wire[4:0] wb_cp0_waddr;
  wire[`WordRange] wb_cp0_wdata;

  initial begin clk=0; forever #5 clk=~clk; end

  task check;
    input cond;
    input [256*8-1:0] msg;
    begin
      if(!cond) begin $display("FAIL %s", msg); $fatal; end
      else $display("PASS %s", msg);
    end
  endtask

  mem_wb dut(
    .clk(clk), .rst(rst), .pause(pause), .flush(flush),
    .mem_wreg_e(mem_wreg_e), .mem_wreg_addr(mem_wreg_addr), .mem_wreg_data(mem_wreg_data),
    .mem_hilo_we(mem_hilo_we), .mem_hi_data(mem_hi_data), .mem_lo_data(mem_lo_data),
    .f_mem_cp0_we(mem_cp0_we), .f_mem_cp0_waddr(mem_cp0_waddr), .f_mem_cp0_wdata(mem_cp0_wdata),
    .wb_wreg_e(wb_wreg_e), .wb_wreg_addr(wb_wreg_addr), .wb_wreg_data(wb_wreg_data),
    .wb_hilo_we(wb_hilo_we), .wb_hi_data(wb_hi_data), .wb_lo_data(wb_lo_data),
    .t_wb_cp0_we(wb_cp0_we), .t_wb_cp0_waddr(wb_cp0_waddr), .t_wb_cp0_wdata(wb_cp0_wdata)
  );

  initial begin
    rst = `Enable;
    pause = `Disable;
    flush = `Disable;
    mem_wreg_e = `Disable;
    mem_wreg_addr = 0;
    mem_wreg_data = 0;
    mem_hilo_we = `Disable;
    mem_hi_data = 0;
    mem_lo_data = 0;
    mem_cp0_we = `Disable;
    mem_cp0_waddr = 0;
    mem_cp0_wdata = 0;
    @(posedge clk);
    rst = `Disable;

    @(posedge clk);
    mem_wreg_e = `Enable;
    mem_wreg_addr = 5'd4;
    mem_wreg_data = 32'h1111_0000;
    mem_hilo_we = `Enable;
    mem_hi_data = 32'h2;
    mem_lo_data = 32'h3;
    mem_cp0_we = `Enable;
    mem_cp0_waddr = 5'd10;
    mem_cp0_wdata = 32'habcd_0000;
    @(posedge clk);
    check(wb_wreg_e && wb_wreg_addr==5'd4 && wb_wreg_data==32'h1111_0000, "wreg latch");
    check(wb_hilo_we && wb_hi_data==32'h2 && wb_lo_data==32'h3, "hilo latch");
    check(wb_cp0_we && wb_cp0_waddr==5'd10 && wb_cp0_wdata==32'habcd_0000, "cp0 latch");

    pause = `Enable;
    mem_wreg_data = 32'h9999_0000;
    @(posedge clk);
    check(wb_wreg_data==32'h1111_0000, "pause holds");
    pause = `Disable;

    flush = `Enable;
    @(posedge clk);
    check(wb_wreg_e==`Disable && wb_hilo_we==`Disable && wb_cp0_we==`Disable, "flush clears");
    flush = `Disable;

    $display("mem_wb TB PASS");
    $finish;
  end
endmodule

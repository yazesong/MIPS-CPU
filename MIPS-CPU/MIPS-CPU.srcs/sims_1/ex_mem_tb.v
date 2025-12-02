`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

module ex_mem_tb;
  reg clk, rst, pause, flush;
  reg ex_wreg_e;
  reg[`RegRangeLog2] ex_wreg_addr;
  reg[`WordRange] ex_wreg_data;
  reg ex_hilo_we;
  reg[`WordRange] ex_hi, ex_lo;
  reg[`ALUOpRange] ex_aluop;
  reg[`WordRange] ex_mem_addr, ex_mem_data;
  reg[`WordRange] ex_ins;
  reg ex_cp0_we;
  reg[4:0] ex_cp0_waddr;
  reg[`WordRange] ex_cp0_wdata;
  reg[`WordRange] ex_pc;
  reg[`WordRange] ex_abn;

  wire mem_wreg_e;
  wire[`RegRangeLog2] mem_wreg_addr;
  wire[`WordRange] mem_wreg_data;
  wire mem_hilo_we;
  wire[`WordRange] mem_hi, mem_lo;
  wire[`ALUOpRange] mem_aluop;
  wire[`WordRange] mem_addr, mem_data, mem_ins;
  wire mem_cp0_we;
  wire[4:0] mem_cp0_waddr;
  wire[`WordRange] mem_cp0_wdata;
  wire[`WordRange] mem_pc, mem_abn;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task check;
    input cond;
    input [256*8-1:0] msg;
    begin
      if(!cond) begin $display("FAIL %s", msg); $fatal; end
      else $display("PASS %s", msg);
    end
  endtask

  ex_mem dut(
    .clk(clk), .rst(rst), .pause(pause), .flush(flush),
    .ex_wreg_e(ex_wreg_e), .ex_wreg_addr(ex_wreg_addr), .ex_wreg_data(ex_wreg_data),
    .ex_hilo_we(ex_hilo_we), .ex_hi_data(ex_hi), .ex_lo_data(ex_lo),
    .f_ex_aluop(ex_aluop), .f_ex_mem_addr(ex_mem_addr), .f_ex_mem_data(ex_mem_data),
    .f_ex_ins(ex_ins),
    .f_ex_cp0_we(ex_cp0_we), .f_ex_cp0_waddr(ex_cp0_waddr), .f_ex_cp0_wdata(ex_cp0_wdata),
    .f_ex_pc_addr_in(ex_pc), .f_ex_abnormal_type(ex_abn),
    .mem_wreg_e(mem_wreg_e), .mem_wreg_addr(mem_wreg_addr), .mem_wreg_data(mem_wreg_data),
    .mem_hilo_we(mem_hilo_we), .mem_hi_data(mem_hi), .mem_lo_data(mem_lo),
    .t_mem_aluop(mem_aluop), .t_mem_addr(mem_addr), .t_mem_data(mem_data), .t_mem_ins(mem_ins),
    .t_mem_cp0_we(mem_cp0_we), .t_mem_cp0_waddr(mem_cp0_waddr), .t_mem_cp0_wdata(mem_cp0_wdata),
    .t_mem_pc_addr_out(mem_pc), .t_mem_abnormal_type(mem_abn)
  );

  initial begin
    rst = `Enable;
    pause = `Disable;
    flush = `Disable;
    ex_wreg_e = `Disable;
    ex_wreg_addr = 0;
    ex_wreg_data = 0;
    ex_hilo_we = `Disable;
    ex_hi = 0;
    ex_lo = 0;
    ex_aluop = `ALUOP_NOP;
    ex_mem_addr = 0;
    ex_mem_data = 0;
    ex_ins = 0;
    ex_cp0_we = `Disable;
    ex_cp0_waddr = 0;
    ex_cp0_wdata = 0;
    ex_pc = 0;
    ex_abn = 0;
    @(posedge clk);
    rst = `Disable;

    // 正常传递
    @(posedge clk);
    ex_wreg_e = `Enable;
    ex_wreg_addr = 5'd3;
    ex_wreg_data = 32'h1234_0000;
    ex_hilo_we = `Enable;
    ex_hi = 32'h1111_1111;
    ex_lo = 32'h2222_2222;
    ex_aluop = `EXOP_SW;
    ex_mem_addr = 32'h8000_0004;
    ex_mem_data = 32'h5555_0000;
    ex_cp0_we = `Enable;
    ex_cp0_waddr = 5'd12;
    ex_cp0_wdata = 32'habcd_0000;
    ex_pc = 32'h1000_0000;
    ex_abn = 32'h8;
    @(posedge clk);
    check(mem_wreg_e && mem_wreg_addr==5'd3 && mem_wreg_data==32'h1234_0000, "wreg latch");
    check(mem_hilo_we && mem_hi==32'h1111_1111 && mem_lo==32'h2222_2222, "hilo latch");
    check(mem_aluop==`EXOP_SW && mem_addr==32'h8000_0004 && mem_data==32'h5555_0000, "mem ctrl latch");
    check(mem_cp0_we && mem_cp0_waddr==5'd12 && mem_cp0_wdata==32'habcd_0000, "cp0 latch");
    check(mem_pc==32'h1000_0000 && mem_abn==32'h8, "pc/abn latch");

    // pause 保持
    pause = `Enable;
    ex_wreg_data = 32'h9999_0000;
    @(posedge clk);
    check(mem_wreg_data==32'h1234_0000, "pause holds");
    pause = `Disable;

    // flush 清空
    flush = `Enable;
    @(posedge clk);
    check(mem_wreg_e==`Disable && mem_hilo_we==`Disable && mem_aluop==`ALUOP_NOP, "flush clears");
    flush = `Disable;

    $display("ex_mem TB PASS");
    $finish;
  end
endmodule

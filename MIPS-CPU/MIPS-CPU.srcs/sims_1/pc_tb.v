`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// PC 模块 tb：验证优先级 rst > flush > pause > branch > pc+4
module pc_tb;
  reg clk;
  reg rst;
  reg pause;
  reg branch_en_in;
  reg [`WordRange] branch_addr_in;
  reg flush;
  reg [`WordRange] interrupt_pc;
  wire[`WordRange] pc;

  pc dut(
    .clk(clk), .rst(rst),
    .pause(pause),
    .branch_en_in(branch_en_in), .branch_addr_in(branch_addr_in),
    .flush(flush), .interrupt_pc(interrupt_pc),
    .pc(pc)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst = `Enable; pause = `Disable; branch_en_in = `Disable;
    branch_addr_in = 0; flush = `Disable; interrupt_pc = 32'h8000_0000;

    @(posedge clk);
    if (pc !== `ZeroWord) begin
      $display("FAIL reset pc");
      $fatal;
    end

    rst = `Disable;
    @(posedge clk);
    if (pc !== 32'd4) begin
      $display("FAIL pc+4");
      $fatal;
    end

    // branch
    branch_en_in  = `Enable;
    branch_addr_in= 32'h1234_5678;
    @(posedge clk);
    if (pc !== branch_addr_in) begin
      $display("FAIL branch");
      $fatal;
    end
    branch_en_in = `Disable;

    // pause 保持
    pause = `Enable;
    branch_addr_in = 32'hAAAA_BBBB;
    @(posedge clk);
    if (pc !== 32'h1234_5678) begin
      $display("FAIL pause hold");
      $fatal;
    end
    pause = `Disable;

    // flush 高优先级
    flush = `Enable;
    interrupt_pc = 32'hFFFF_0000;
    @(posedge clk);
    if (pc !== 32'hFFFF_0000) begin
      $display("FAIL flush");
      $fatal;
    end
    flush = `Disable;

    $display("pc TB PASS");
    $finish;
  end
endmodule

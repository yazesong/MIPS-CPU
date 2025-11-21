`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// HI/LO 寄存器 tb
module hilo_tb;
  reg rst;
  reg clk;
  reg we_in;
  reg [`WordRange] hi_in, lo_in;
  wire[`WordRange] hi_out, lo_out;

  hilo dut(
    .rst(rst), .clk(clk),
    .we_in(we_in), .hi_in(hi_in), .lo_in(lo_in),
    .hi_out(hi_out), .lo_out(lo_out)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst   = `Enable;
    we_in = `Disable;
    hi_in = 0; lo_in = 0;
    @(posedge clk);
    if (hi_out !== `ZeroWord || lo_out !== `ZeroWord) begin
      $display("FAIL reset not zero");
      $fatal;
    end

    rst = `Disable;
    // 写一次
    we_in = `Enable; hi_in = 32'h1111_2222; lo_in = 32'h3333_4444;
    @(posedge clk);
    if (hi_out !== hi_in || lo_out !== lo_in) begin
      $display("FAIL write");
      $fatal;
    end

    // 写使能关，保持
    we_in = `Disable; hi_in = 32'hAAAA_BBBB; lo_in = 32'hCCCC_DDDD;
    @(posedge clk);
    if (hi_out !== 32'h1111_2222 || lo_out !== 32'h3333_4444) begin
      $display("FAIL hold");
      $fatal;
    end

    $display("hilo TB PASS");
    $finish;
  end
endmodule

`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

module mul_tb;
  reg clk;
  reg[`WordRange] a, b;
  reg start, if_signed;
  wire[`DivMulResultRange] result;
  wire valid;

  initial begin clk=0; forever #5 clk=~clk; end

  task check;
    input cond;
    input [256*8-1:0] msg;
    begin
      if(!cond) begin $display("FAIL %s", msg); $fatal; end
      else $display("PASS %s", msg);
    end
  endtask

  mul dut(.clk(clk), .dataA(a), .dataB(b), .start(start), .if_signed(if_signed), .result(result), .valid(valid));

  initial begin
    start=0; if_signed=0; a=0; b=0;
    #10;
    // 无符号
    a = 32'h0000_0010;
    b = 32'h0000_0003;
    start = 1'b1;
    if_signed = 1'b0;
    @(posedge clk);
    start = 1'b0;
    repeat(7) @(posedge clk);
    check(valid && result==64'h0000_0000_0000_0030, "unsigned mul");

    // 有符号乘负数
    a = -5;
    b = 3;
    start = 1'b1;
    if_signed = 1'b1;
    @(posedge clk);
    start = 1'b0;
    repeat(7) @(posedge clk);
    check(valid && result==$signed(-5)*$signed(3), "signed mul");

    // 有符号负*负
    a = -4;
    b = -2;
    start = 1'b1;
    if_signed = 1'b1;
    @(posedge clk);
    start = 1'b0;
    repeat(7) @(posedge clk);
    check(valid && result==64'd8, "signed mul neg*neg");

    $display("mul TB PASS");
    $finish;
  end
endmodule

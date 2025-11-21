`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// ALU 自检 testbench：遍历常见 ALUOP，覆盖边界与溢出场景
module alu_tb;

  reg [`WordRange]    a;
  reg [`WordRange]    b;
  reg [`ALUOpRange]   op;
  wire[`WordRange]    y;
  wire zf, cf, sf, of;

  alu dut (
    .data1 (a),
    .data2 (b),
    .op    (op),
    .res   (y),
    .zf    (zf),
    .cf    (cf),
    .sf    (sf),
    .of    (of)
  );

  // 计算期望并比对
  task check;
    input [31:0] ta, tb;
    input [5:0]  top;
    input [32:0] expect32p1; // 33 位期望
    begin
      a  = ta;
      b  = tb;
      op = top;
      #1;
      if ({cf, y} !== expect32p1) begin
        $display("FAIL op=%0d a=0x%08x b=0x%08x res=0x%08x cf=%b expect={%b,0x%08x}", top, a, b, y, cf, expect32p1[32], expect32p1[31:0]);
        $fatal;
      end
    end
  endtask

  initial begin
    // 无操作
    check(32'h0, 32'h0, `ALUOP_NOP,   33'h0);

    // 加法（有/无符号），包含进位和溢出
    check(32'h0000_0001, 32'h0000_0001, `ALUOP_ADDU, 33'h0_0000_0002);
    check(32'hFFFF_FFFF, 32'h0000_0001, `ALUOP_ADDU, 33'h1_0000_0000); // 无符号进位
    check(32'h7FFF_FFFF, 32'h0000_0001, `ALUOP_ADD,  33'h0_8000_0000); // 有符号溢出
    check(32'h8000_0000, 32'hFFFF_FFFF, `ALUOP_ADD,  33'h1_7FFF_FFFF); // 负数相加

    // 减法（有/无符号）
    check(32'h0000_0002, 32'h0000_0001, `ALUOP_SUBU, 33'h0_0000_0001);
    check(32'h0000_0000, 32'h0000_0001, `ALUOP_SUBU, 33'h0_FFFF_FFFF); // 无符号借位，cf=0
    check(32'h8000_0000, 32'h0000_0001, `ALUOP_SUB,  33'h1_7FFF_FFFF); // 有符号溢出

    // 逻辑运算
    check(32'hAA55_FF00, 32'h0F0F_F0F0, `ALUOP_AND,  33'h0_0A05_F000);
    check(32'hAA55_FF00, 32'h0F0F_F0F0, `ALUOP_OR,   33'h0_AF5F_FFF0);
    check(32'hAA55_FF00, 32'h0F0F_F0F0, `ALUOP_XOR,  33'h0_A55A_0FF0);
    check(32'hAA55_FF00, 32'h0F0F_F0F0, `ALUOP_NOR,  33'h0_50A0_000F);

    // 移位：移位量来自 data1[4:0]
    check(32'h0000_0004, 32'h0000_0001, `ALUOP_SLL,  33'h0_0000_0010);
    check(32'h0000_0004, 32'hF000_0000, `ALUOP_SRL,  33'h0_0F00_0000);
    check(32'h0000_0004, 32'hF000_0000, `ALUOP_SRA,  33'h0_FF00_0000); // 保持符号

    // 比较
    check(32'h8000_0000, 32'h7FFF_FFFF, `ALUOP_SLT,  33'h0_0000_0001); // -2147483648 < 2147483647
    check(32'hFFFF_FFFF, 32'h0000_0001, `ALUOP_SLTU, 33'h0_0000_0001); // 无符号比较

    $display("ALU TB PASS");
    $finish;
  end

endmodule

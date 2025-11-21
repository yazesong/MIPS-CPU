`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/14 18:11:18
// Design Name: 
// Module Name: alu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "public.v"

// 实现除乘/除法外的所有算术与逻辑指令
module alu (
  input  wire[`WordRange] data1, // 操作数1（也用于移位位数）
  input  wire[`WordRange] data2, // 操作数2
  input  wire[`ALUOpRange] op, // 操作类型

  output wire[`WordRange] res, // 32位计算结果
  output wire zf, // zero-flag，结果为0置1
  output wire cf, // carry-flag，无符号加/减产生进位/借位
  output wire sf, // sign-flag，结果为负时置1
  output wire of  // overflow-flag，与最高位保持一致
);

  // 复用的信号
  wire [4:0] shamt = data1[4:0]; // 移位位数
  wire signed[`WordRange] signed_a = data1; // data1 有符号视图
  wire signed[`WordRange] signed_b = data2; // data2 有符号视图

  // 32位结果和1位进位
  reg  [32:0] alu_result;

  // 组合逻辑生成结果
  always @(*) begin
    alu_result = {1'b0, `ZeroWord};
    case (op)
      `ALUOP_NOP:  alu_result = {1'b0, `ZeroWord};
      `ALUOP_ADDU: alu_result = {1'b0, data1} + {1'b0, data2};      // 无符号加
      `ALUOP_ADD:  alu_result = {signed_a[31], signed_a} + {signed_b[31], signed_b}; // 有符号加
      `ALUOP_SUBU: alu_result = {1'b0, data1} - {1'b0, data2};      // 无符号减
      `ALUOP_SUB:  alu_result = {signed_a[31], signed_a} - {signed_b[31], signed_b}; // 有符号减
      `ALUOP_AND:  alu_result = {1'b0, (data1 & data2)};            // 按位与
      `ALUOP_OR:   alu_result = {1'b0, (data1 | data2)};            // 按位或
      `ALUOP_XOR:  alu_result = {1'b0, (data1 ^ data2)};            // 按位异或
      `ALUOP_NOR:  alu_result = {1'b0, ~(data1 | data2)};           // 按位或非
      `ALUOP_SLL:  alu_result = {1'b0, (data2 << shamt)};           // 逻辑左移
      `ALUOP_SRL:  alu_result = {1'b0, (data2 >> shamt)};           // 逻辑右移
      `ALUOP_SRA:  alu_result = {1'b0, (signed_b >>> shamt)};       // 算术右移
      `ALUOP_SLT:  alu_result = signed_a < signed_b ? 33'd1 : 33'd0; // 有符号比较
      `ALUOP_SLTU: alu_result = data1   < data2   ? 33'd1 : 33'd0;   // 无符号比较
      default:     alu_result = {1'b0, `ZeroWord};
    endcase
  end

  // 输出
  assign res = alu_result[`WordRange];
  assign cf  = alu_result[32];
  assign zf  = (alu_result[`WordRange] == `ZeroWord) ? 1'b1 : 1'b0;
  assign sf  = alu_result[31];
  assign of  = alu_result[32];

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/15 10:09:11
// Design Name: 
// Module Name: pc
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

// 指令计数器PC
module pc (

  input clk, // 时钟
  input rst, // 同步复位信号

  input wire pause, // 流水暂停信号

  input wire branch_en_in, // 是否转移
  input wire[`WordRange] branch_addr_in, // 转移的地址

  //异常相关
  input wire flush,
  input wire[`WordRange] interrupt_pc,
  output reg[`WordRange] pc // 当前PC
  
);

  // 如果rst，则复位到0x0，否则+4
  always @(posedge clk) begin
    if (rst == `Enable) begin
      pc <= `ZeroWord;
    end else if (flush == `Enable) begin
      pc <= interrupt_pc;        // 异常/中断入口
    end else if (pause == `Enable) begin
      pc <= pc;                 
    end else if (branch_en_in == `Enable) begin
      pc <= branch_addr_in;      // 跳转
    end else begin
      pc <= pc + 32'd4;          // 顺序执行
    end
  end

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/14 17:06:48
// Design Name: 
// Module Name: hilo
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
module hilo (
  input  rst,     // 复位信号，高电平有效
  input  clk,     // 时钟信号

  input  wire we_in,   // 写使能
  input  wire[`WordRange] hi_in, // 要写入 HI 的数据
  input  wire[`WordRange] lo_in, // 要写入 LO 的数据

  output reg [`WordRange] hi_out, // HI 当前值
  output reg [`WordRange] lo_out  // LO 当前值
);

  // 在时钟上升沿更新 HI/LO
  always @(posedge clk) begin
    // 复位时，HI/LO 清零
    if (rst == `Enable) begin
      hi_out <= `ZeroWord;
      lo_out <= `ZeroWord;
    end else if (we_in == `Enable) begin
      hi_out <= hi_in;
      lo_out <= lo_in;
    end
  end

endmodule

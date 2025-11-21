`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/12 16:39:56
// Design Name: 
// Module Name: gpr
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
/////////////////////////////////////////////////////////////////////////////////
`include "public.v"
// 通用寄存器组gpr,32×32位，一个写端口两个读端口
// 同步写，在时钟上升沿写入，禁止写$0
// 异步读，组合逻辑实时输出寄存器值
// 当同周期写回与读同一寄存器时，优先输出写回数据
module gpr(
    input rst, // 复位信号
    input clk, // 时钟

    input we, // 写使能
    input wire[`RegRangeLog2] waddr, // 写地址
    input wire[`WordRange] wdata, // 写数据

    input re1, // 读使能rs
    input wire[`RegRangeLog2] raddr1, // 读地址rs
    output reg[`WordRange] rdata1, // 读数据rs

    input re2, // 读使能rt
    input wire[`RegRangeLog2] raddr2, // 读地址rt
    output reg[`WordRange] rdata2 // 读数据rt

    );

    reg [31:0] regs [0:`RegCount-1]; // 32个32位寄存器

    // 写操作，在时钟上升沿写入
    always @(posedge clk) begin
        if (rst == `Disable) begin
            if (we == `Enable && waddr != `RegCountLog2'b0) begin
                regs[waddr] <= wdata;
            end
        end
    end

    // 组合读出逻辑
  always @(*) begin
    // 读端口1
    // 复位或读取$0时，固定输出0
    if (rst == `Enable || raddr1 == `RegCountLog2'b0) begin
      rdata1 = `ZeroWord;
    // 同周期写回与读同一寄存器，优先输出写回数据，用于防止读后写数据冒险
    end else if (re1 == `Enable && we == `Enable && raddr1 == waddr) begin
      rdata1 = wdata;
    // 读为不使能状态时时输出0
    end else if (re1 == `Disable) begin
      rdata1 = `ZeroWord;
    // 直接从寄存器数组中读取
    end else begin
      rdata1 = regs[raddr1];
    end

    // 读端口2
    if (rst == `Enable || raddr2 == `RegCountLog2'b0) begin
      rdata2 = `ZeroWord;
    end else if (re2 == `Enable && we == `Enable && raddr2 == waddr) begin
      rdata2 = wdata;
    end else if (re2 == `Disable) begin
      rdata2 = `ZeroWord;
    end else begin
      rdata2 = regs[raddr2];
    end
  end

endmodule
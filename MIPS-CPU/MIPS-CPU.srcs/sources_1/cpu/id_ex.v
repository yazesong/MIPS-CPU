`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 11:20:28
// Design Name: 
// Module Name: id_ex
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

// ID/EX 流水寄存器
// 把译码阶段已经确定好的控制信号/操作数打拍交给执行阶段
module id_ex(
  input  wire                 clk,
  input  wire                 rst,
  // 来自 ID
  input  wire[`ALUOpRange]    id_aluop,
  input  wire[`WordRange]     id_data1,
  input  wire[`WordRange]     id_data2,
  input  wire                 id_wreg_e,
  input  wire[`RegRangeLog2]  id_wreg_addr,
  input  wire[`WordRange]     id_link_addr,
  input  wire                 id_in_delayslot,
  input  wire                 id_next_in_delayslot,
  input  wire[`WordRange]     id_ins,
  input  wire[`WordRange]     f_id_current_pc_addr_in,
  input  wire[`WordRange]     f_id_abnormal_type_in,
  // 来自调度
  input  wire                 pause,
  input  wire                 flush,
  // 输出给 EX
  output reg [`ALUOpRange]    ex_aluop,
  output reg [`WordRange]     ex_data1,
  output reg [`WordRange]     ex_data2,
  output reg                  ex_wreg_e,
  output reg [`RegRangeLog2]  ex_wreg_addr,
  output reg [`WordRange]     ex_link_addr,
  output reg                  ex_in_delayslot,
  output reg                  ex_next_in_delayslot,
  output reg [`WordRange]     ex_ins,
  output reg [`WordRange]     t_ex_current_pc_addr_out,
  output reg [`WordRange]     t_ex_abnormal_type_out
);

  // 复用一个 always 块，按优先级：rst > flush > pause > 正常更新
  always @(posedge clk) begin
    if (rst == `Enable) begin
      ex_aluop                <= `ALUOP_NOP;
      ex_data1                <= `ZeroWord;
      ex_data2                <= `ZeroWord;
      ex_wreg_e               <= `Disable;
      ex_wreg_addr            <= {`RegCountLog2{1'b0}};
      ex_link_addr            <= `ZeroWord;
      ex_in_delayslot         <= `Disable;
      ex_next_in_delayslot    <= `Disable;
      ex_ins                  <= `ZeroWord;
      t_ex_current_pc_addr_out<= `ZeroWord;
      t_ex_abnormal_type_out  <= `ZeroWord;
    end else if (flush == `Enable) begin
      // 异常/flush 直接清泡
      ex_aluop                <= `ALUOP_NOP;
      ex_data1                <= `ZeroWord;
      ex_data2                <= `ZeroWord;
      ex_wreg_e               <= `Disable;
      ex_wreg_addr            <= {`RegCountLog2{1'b0}};
      ex_link_addr            <= `ZeroWord;
      ex_in_delayslot         <= `Disable;
      ex_next_in_delayslot    <= `Disable;
      ex_ins                  <= `ZeroWord;
      t_ex_current_pc_addr_out<= `ZeroWord;
      t_ex_abnormal_type_out  <= `ZeroWord;
    end else if (pause == `Enable) begin
      // 暂停时保持寄存器原值
      ex_aluop                <= ex_aluop;
      ex_data1                <= ex_data1;
      ex_data2                <= ex_data2;
      ex_wreg_e               <= ex_wreg_e;
      ex_wreg_addr            <= ex_wreg_addr;
      ex_link_addr            <= ex_link_addr;
      ex_in_delayslot         <= ex_in_delayslot;
      ex_next_in_delayslot    <= ex_next_in_delayslot;
      ex_ins                  <= ex_ins;
      t_ex_current_pc_addr_out<= t_ex_current_pc_addr_out;
      t_ex_abnormal_type_out  <= t_ex_abnormal_type_out;
    end else begin
      ex_aluop                <= id_aluop;
      ex_data1                <= id_data1;
      ex_data2                <= id_data2;
      ex_wreg_e               <= id_wreg_e;
      ex_wreg_addr            <= id_wreg_addr;
      ex_link_addr            <= id_link_addr;
      ex_in_delayslot         <= id_in_delayslot;
      ex_next_in_delayslot    <= id_next_in_delayslot;
      ex_ins                  <= id_ins;
      t_ex_current_pc_addr_out<= f_id_current_pc_addr_in;
      t_ex_abnormal_type_out  <= f_id_abnormal_type_in;
    end
  end

endmodule

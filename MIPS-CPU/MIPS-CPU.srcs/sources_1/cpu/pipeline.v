`timescale 1ns / 1ps
`include "public.v"

// 流水线调度器
module pipeline(
  input  wire         rst,
  // 阻塞请求
  input  wire         pause_req_id,
  input  wire         pause_req_ex,
  // 阻塞响应
  output reg          pause_res_pc,
  output reg          pause_res_if,
  output reg          pause_res_id,
  output reg          pause_res_ex,
  output reg          pause_res_mem,
  output reg          pause_res_wb,
  // 异常/中断
  input  wire[`WordRange] abnormal_type,
  input  wire[`WordRange] cp0_epc_in,
  output reg [`WordRange] interrupt_pc_out,
  output reg          flush
);

  always @(*) begin
    // 默认值
    pause_res_pc  = `Disable;
    pause_res_if  = `Disable;
    pause_res_id  = `Disable;
    pause_res_ex  = `Disable;
    pause_res_mem = `Disable;
    pause_res_wb  = `Disable;
    flush         = `Disable;
    interrupt_pc_out = `ZeroWord;

    if (rst == `Enable) begin
      pause_res_pc = `Disable;
      pause_res_if = `Disable;
      pause_res_id = `Disable;
      pause_res_ex = `Disable;
      pause_res_mem = `Disable;
      pause_res_wb = `Disable;
      flush = `Disable;
      // 复位全清
    end else if (abnormal_type != `ZeroWord) begin
      flush = `Enable;
      // 异常时让各级继续前进到 flush 清泡
      case (abnormal_type[6:2])
        `ABN_INTERRUPT,
        `ABN_BREAK,
        `ABN_OVERFLOW,
        `ABN_PRESERVE,
        `ABN_SYSTEMCALL,
        5'b00000: interrupt_pc_out = 32'h0000F000;
        `ABN_ERET: interrupt_pc_out = cp0_epc_in;
        default: ;
      endcase
    end else if (pause_req_id == `Enable || pause_req_ex == `Enable) begin
      // 数据相关/乘除法请求暂停：所有级锁存
      pause_res_pc  = `Enable;
      pause_res_if  = `Enable;
      pause_res_id  = `Enable;
      pause_res_ex  = `Enable;
      pause_res_mem = `Enable;
      pause_res_wb  = `Enable;
    end
  end

endmodule

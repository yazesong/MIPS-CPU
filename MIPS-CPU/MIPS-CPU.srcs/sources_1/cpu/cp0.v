`timescale 1ns / 1ps
`include "public.v"

// 协处理器 CP0（简化版，保持 cpu1 功能一致）
// 负责中断屏蔽、异常记录、EPC 保存和计时器中断
module cp0(
  input  wire         clk,
  input  wire         rst,
  input  wire         we_in,
  input  wire[4:0]    waddr_in,
  input  wire[`WordRange] data_in,
  input  wire[4:0]    raddr_in,
  input  wire[5:0]    int_in,
  output reg [`WordRange] data_out,
  output reg [`WordRange] count_out,
  output reg [`WordRange] compare_out,
  output reg [`WordRange] status_out,
  output reg [`WordRange] cause_out,
  output reg [`WordRange] epc_out,
  output reg [`WordRange] config_out,
  output reg          timer_int_o,
  // 异常相关
  input  wire[`WordRange] abnormal_type,
  input  wire[`WordRange] current_pc_addr_in
);

  // 时序寄存器：count/compare/status/cause/epc
  always @(posedge clk) begin
    if (rst == `Enable) begin
      data_out   <= `ZeroWord;
      count_out  <= `ZeroWord;
      compare_out<= `ZeroWord;
      status_out <= 32'd1;       // 默认关闭中断
      cause_out  <= `ZeroWord;
      epc_out    <= `ZeroWord;
      config_out <= `ZeroWord;
      timer_int_o<= `Disable;
    end else begin
      // 基本计数器
      count_out <= count_out + 32'd1;
      cause_out[13:8] <= int_in;
      // 定时器中断
      if (compare_out != `ZeroWord && count_out == compare_out)
        timer_int_o <= `Enable;

      // 异常写入
      if (abnormal_type != `ZeroWord) begin
        epc_out       <= current_pc_addr_in;
        status_out[0] <= `Disable;                 // 屏蔽中断
        cause_out[6:2]<= abnormal_type[6:2];
        if (abnormal_type[6:2] == `ABN_ERET) begin
          epc_out       <= `ZeroWord;
          status_out[0] <= `Enable;                // ERET 打开中断
        end
      end

      // 软件写寄存器
      if (we_in == `Enable) begin
        case (waddr_in)
          `CP0_REG_COUNT  : count_out   <= data_in;
          `CP0_REG_COMPARE: begin compare_out <= data_in; timer_int_o <= `Disable; end
          `CP0_REG_STATUE : status_out  <= data_in;
          `CP0_REG_EPC    : epc_out     <= data_in;
          `CP0_REG_CAUSE  : cause_out[6:2] <= data_in[6:2];
          default         : ;
        endcase
      end
    end
  end

  // 异步读
  always @(*) begin
    if (rst == `Enable) begin
      data_out = `ZeroWord;
    end else begin
      case (raddr_in)
        `CP0_REG_COUNT  : data_out = count_out;
        `CP0_REG_COMPARE: data_out = compare_out;
        `CP0_REG_STATUE : data_out = status_out;
        `CP0_REG_EPC    : data_out = epc_out;
        `CP0_REG_CAUSE  : data_out = cause_out;
        default         : data_out = `ZeroWord;
      endcase
    end
  end

endmodule

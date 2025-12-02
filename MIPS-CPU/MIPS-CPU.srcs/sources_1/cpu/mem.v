`timescale 1ns / 1ps
`include "public.v"

// 访存阶段：生成总线控制、处理加载/存储的字节/半字/符号扩展
module mem(
  input  wire                 rst,
  // 来自 EX/MEM
  input  wire                 wreg_e_in,
  input  wire[`WordRange]     wreg_data_in,
  input  wire[`RegRangeLog2]  wreg_addr_in,
  input  wire                 hilo_we_in,
  input  wire[`WordRange]     hi_data_in,
  input  wire[`WordRange]     lo_data_in,
  input  wire[`ALUOpRange]    aluop_in,
  input  wire[`WordRange]     mem_addr_in,
  input  wire[`WordRange]     mem_store_data_in,
  input  wire[`WordRange]     mem_read_data_in,
  // 输出到 WB
  output reg                  wreg_e_out,
  output reg[`WordRange]      wreg_data_out,
  output reg[`RegRangeLog2]   wreg_addr_out,
  output reg                  hilo_we_out,
  output reg[`WordRange]      hi_data_out,
  output reg[`WordRange]      lo_data_out,
  // 输出到总线
  output reg[`WordRange]      mem_addr_out,
  output reg                  mem_we_out,
  output reg[3:0]             mem_byte_sel_out,
  output wire[`WordRange]     mem_store_data_out,
  output reg                  mem_e_out,
  // CP0 旁路
  input  wire                 cp0_we_in,
  input  wire[4:0]            cp0_waddr_in,
  input  wire[`WordRange]     cp0_wdata_in,
  output reg                  cp0_we_out,
  output reg[4:0]             cp0_waddr_out,
  output reg[`WordRange]      cp0_wdata_out,
  // 异常信息传递
  input  wire[`WordRange]     current_mem_pc_addr_in,
  input  wire[`WordRange]     abnormal_type_in,
  input  wire[`WordRange]     cp0_status_in,
  input  wire[`WordRange]     cp0_cause_in,
  input  wire[`WordRange]     cp0_epc_in,
  output reg[`WordRange]      abnormal_type_out,
  output reg[`WordRange]      current_mem_pc_addr_out
);

  assign mem_store_data_out = mem_store_data_in;

  // 异常信息：尽量保持与 cpu1 行为一致
  always @(*) begin
    abnormal_type_out      = `ZeroWord;
    current_mem_pc_addr_out= `ZeroWord;
    if (rst == `Enable) begin
      // 复位清零
    end else if (current_mem_pc_addr_in != `ZeroWord) begin
      if (cp0_status_in[0] == `Enable) begin
        // 未屏蔽则传递异常
        abnormal_type_out       = {16'h0, cp0_cause_in[13:8], 1'b0, abnormal_type_in[6:2], 2'b00};
        current_mem_pc_addr_out = current_mem_pc_addr_in;
      end else if (abnormal_type_in[6:2] == `ABN_ERET) begin
        abnormal_type_out       = {16'h0, cp0_cause_in[13:8], 1'b0, abnormal_type_in[6:2], 2'b00};
        current_mem_pc_addr_out = current_mem_pc_addr_in;
      end
    end
  end

  // 主控制：写回/总线控制
  always @(*) begin
    if (rst == `Enable) begin
      wreg_e_out       = `Disable;
      wreg_data_out    = `ZeroWord;
      wreg_addr_out    = {`RegCountLog2{1'b0}};
      hilo_we_out      = `Disable;
      hi_data_out      = `ZeroWord;
      lo_data_out      = `ZeroWord;
      mem_addr_out     = `ZeroWord;
      mem_we_out       = `Disable;
      mem_byte_sel_out = 4'b0000;
      mem_e_out        = `Disable;
      cp0_we_out       = `Disable;
      cp0_waddr_out    = 5'd0;
      cp0_wdata_out    = `ZeroWord;
    end else begin
      // 默认透传
      wreg_e_out       = wreg_e_in;
      wreg_data_out    = wreg_data_in;
      wreg_addr_out    = wreg_addr_in;
      hilo_we_out      = hilo_we_in;
      hi_data_out      = hi_data_in;
      lo_data_out      = lo_data_in;
      mem_addr_out     = `ZeroWord;
      mem_we_out       = `Disable;
      mem_byte_sel_out = 4'b1111;
      mem_e_out        = `Disable;
      cp0_we_out       = cp0_we_in;
      cp0_waddr_out    = cp0_waddr_in;
      cp0_wdata_out    = cp0_wdata_in;

      case (aluop_in)
        // 载入
        `EXOP_LB: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Disable;
          mem_e_out    = `Enable;
          case (mem_addr_in[1:0])
            2'b00: begin wreg_data_out = {{24{mem_read_data_in[7]}},  mem_read_data_in[7:0]};  mem_byte_sel_out = 4'b0001; end
            2'b01: begin wreg_data_out = {{24{mem_read_data_in[15]}}, mem_read_data_in[15:8]}; mem_byte_sel_out = 4'b0010; end
            2'b10: begin wreg_data_out = {{24{mem_read_data_in[23]}}, mem_read_data_in[23:16]};mem_byte_sel_out = 4'b0100; end
            2'b11: begin wreg_data_out = {{24{mem_read_data_in[31]}}, mem_read_data_in[31:24]};mem_byte_sel_out = 4'b1000; end
          endcase
        end
        `EXOP_LBU: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Disable;
          mem_e_out    = `Enable;
          case (mem_addr_in[1:0])
            2'b00: begin wreg_data_out = {24'h0, mem_read_data_in[7:0]};   mem_byte_sel_out = 4'b0001; end
            2'b01: begin wreg_data_out = {24'h0, mem_read_data_in[15:8]};  mem_byte_sel_out = 4'b0010; end
            2'b10: begin wreg_data_out = {24'h0, mem_read_data_in[23:16]}; mem_byte_sel_out = 4'b0100; end
            2'b11: begin wreg_data_out = {24'h0, mem_read_data_in[31:24]}; mem_byte_sel_out = 4'b1000; end
          endcase
        end
        `EXOP_LH: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Disable;
          mem_e_out    = `Enable;
          if (mem_addr_in[1] == 1'b0) begin
            wreg_data_out    = {{16{mem_read_data_in[15]}}, mem_read_data_in[15:0]};
            mem_byte_sel_out = 4'b0011;
          end else begin
            wreg_data_out    = {{16{mem_read_data_in[31]}}, mem_read_data_in[31:16]};
            mem_byte_sel_out = 4'b1100;
          end
        end
        `EXOP_LHU: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Disable;
          mem_e_out    = `Enable;
          if (mem_addr_in[1] == 1'b0) begin
            wreg_data_out    = {16'h0, mem_read_data_in[15:0]};
            mem_byte_sel_out = 4'b0011;
          end else begin
            wreg_data_out    = {16'h0, mem_read_data_in[31:16]};
            mem_byte_sel_out = 4'b1100;
          end
        end
        // 存储
        `EXOP_SB: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Enable;
          mem_e_out    = `Enable;
          case (mem_addr_in[1:0])
            2'b00: mem_byte_sel_out = 4'b0001;
            2'b01: mem_byte_sel_out = 4'b0010;
            2'b10: mem_byte_sel_out = 4'b0100;
            2'b11: mem_byte_sel_out = 4'b1000;
          endcase
        end
        `EXOP_SH: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Enable;
          mem_e_out    = `Enable;
          mem_byte_sel_out = mem_addr_in[1] ? 4'b1100 : 4'b0011;
        end
        `EXOP_LW: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Disable;
          mem_e_out    = `Enable;
          wreg_data_out= mem_read_data_in;
          mem_byte_sel_out = 4'b1111;
        end
        `EXOP_SW: begin
          mem_addr_out = mem_addr_in;
          mem_we_out   = `Enable;
          mem_e_out    = `Enable;
          mem_byte_sel_out = 4'b1111;
        end
        default: begin
          // 其它保持默认透传
        end
      endcase
    end
  end

endmodule

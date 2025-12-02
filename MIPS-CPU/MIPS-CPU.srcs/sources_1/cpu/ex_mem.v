`timescale 1ns / 1ps
`include "public.v"

// EX/MEM 流水寄存器
module ex_mem(
  input  wire                clk,
  input  wire                rst,
  // 来自 EX
  input  wire                ex_wreg_e,
  input  wire[`RegRangeLog2] ex_wreg_addr,
  input  wire[`WordRange]    ex_wreg_data,
  input  wire                ex_hilo_we,
  input  wire[`WordRange]    ex_hi_data,
  input  wire[`WordRange]    ex_lo_data,
  input  wire[`ALUOpRange]   f_ex_aluop,
  input  wire[`WordRange]    f_ex_mem_addr,
  input  wire[`WordRange]    f_ex_mem_data,
  input  wire[`WordRange]    f_ex_ins,
  input  wire                f_ex_cp0_we,
  input  wire[4:0]           f_ex_cp0_waddr,
  input  wire[`WordRange]    f_ex_cp0_wdata,
  input  wire[`WordRange]    f_ex_pc_addr_in,
  input  wire[`WordRange]    f_ex_abnormal_type,
  // 调度
  input  wire                pause,
  input  wire                flush,
  // 输出给 MEM
  output reg                 mem_wreg_e,
  output reg[`RegRangeLog2]  mem_wreg_addr,
  output reg[`WordRange]     mem_wreg_data,
  output reg                 mem_hilo_we,
  output reg[`WordRange]     mem_hi_data,
  output reg[`WordRange]     mem_lo_data,
  output reg[`ALUOpRange]    t_mem_aluop,
  output reg[`WordRange]     t_mem_addr,
  output reg[`WordRange]     t_mem_data,
  output reg[`WordRange]     t_mem_ins,
  output reg                 t_mem_cp0_we,
  output reg[4:0]            t_mem_cp0_waddr,
  output reg[`WordRange]     t_mem_cp0_wdata,
  output reg[`WordRange]     t_mem_pc_addr_out,
  output reg[`WordRange]     t_mem_abnormal_type
);

  // 还是 rst > flush > pause > 正常更新
  always @(posedge clk) begin
    if (rst == `Enable) begin
      mem_wreg_e          <= `Disable;
      mem_wreg_addr       <= {`RegCountLog2{1'b0}};
      mem_wreg_data       <= `ZeroWord;
      mem_hilo_we         <= `Disable;
      mem_hi_data         <= `ZeroWord;
      mem_lo_data         <= `ZeroWord;
      t_mem_aluop         <= `ALUOP_NOP;
      t_mem_addr          <= `ZeroWord;
      t_mem_data          <= `ZeroWord;
      t_mem_ins           <= `ZeroWord;
      t_mem_cp0_we        <= `Disable;
      t_mem_cp0_waddr     <= 5'd0;
      t_mem_cp0_wdata     <= `ZeroWord;
      t_mem_pc_addr_out   <= `ZeroWord;
      t_mem_abnormal_type <= `ZeroWord;
    end else if (flush == `Enable) begin
      mem_wreg_e          <= `Disable;
      mem_wreg_addr       <= {`RegCountLog2{1'b0}};
      mem_wreg_data       <= `ZeroWord;
      mem_hilo_we         <= `Disable;
      mem_hi_data         <= `ZeroWord;
      mem_lo_data         <= `ZeroWord;
      t_mem_aluop         <= `ALUOP_NOP;
      t_mem_addr          <= `ZeroWord;
      t_mem_data          <= `ZeroWord;
      t_mem_ins           <= `ZeroWord;
      t_mem_cp0_we        <= `Disable;
      t_mem_cp0_waddr     <= 5'd0;
      t_mem_cp0_wdata     <= `ZeroWord;
      t_mem_pc_addr_out   <= `ZeroWord;
      t_mem_abnormal_type <= `ZeroWord;
    end else if (pause == `Enable) begin
      mem_wreg_e          <= mem_wreg_e;
      mem_wreg_addr       <= mem_wreg_addr;
      mem_wreg_data       <= mem_wreg_data;
      mem_hilo_we         <= mem_hilo_we;
      mem_hi_data         <= mem_hi_data;
      mem_lo_data         <= mem_lo_data;
      t_mem_aluop         <= t_mem_aluop;
      t_mem_addr          <= t_mem_addr;
      t_mem_data          <= t_mem_data;
      t_mem_ins           <= t_mem_ins;
      t_mem_cp0_we        <= t_mem_cp0_we;
      t_mem_cp0_waddr     <= t_mem_cp0_waddr;
      t_mem_cp0_wdata     <= t_mem_cp0_wdata;
      t_mem_pc_addr_out   <= t_mem_pc_addr_out;
      t_mem_abnormal_type <= t_mem_abnormal_type;
    end else begin
      mem_wreg_e          <= ex_wreg_e;
      mem_wreg_addr       <= ex_wreg_addr;
      mem_wreg_data       <= ex_wreg_data;
      mem_hilo_we         <= ex_hilo_we;
      mem_hi_data         <= ex_hi_data;
      mem_lo_data         <= ex_lo_data;
      t_mem_aluop         <= f_ex_aluop;
      t_mem_addr          <= f_ex_mem_addr;
      t_mem_data          <= f_ex_mem_data;
      t_mem_ins           <= f_ex_ins;
      t_mem_cp0_we        <= f_ex_cp0_we;
      t_mem_cp0_waddr     <= f_ex_cp0_waddr;
      t_mem_cp0_wdata     <= f_ex_cp0_wdata;
      t_mem_pc_addr_out   <= f_ex_pc_addr_in;
      t_mem_abnormal_type <= f_ex_abnormal_type;
    end
  end

endmodule

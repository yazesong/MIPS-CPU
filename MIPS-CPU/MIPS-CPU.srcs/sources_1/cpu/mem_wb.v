`timescale 1ns / 1ps
`include "public.v"

// MEM/WB 流水寄存器
module mem_wb(
  input  wire                clk,
  input  wire                rst,
  // 来自 MEM
  input  wire                mem_wreg_e,
  input  wire[`RegRangeLog2] mem_wreg_addr,
  input  wire[`WordRange]    mem_wreg_data,
  input  wire                mem_hilo_we,
  input  wire[`WordRange]    mem_hi_data,
  input  wire[`WordRange]    mem_lo_data,
  input  wire                f_mem_cp0_we,
  input  wire[4:0]           f_mem_cp0_waddr,
  input  wire[`WordRange]    f_mem_cp0_wdata,
  input  wire                pause,
  input  wire                flush,
  // 输出给 WB（寄存器组/HILO/CP0）
  output reg                 wb_wreg_e,
  output reg[`RegRangeLog2]  wb_wreg_addr,
  output reg[`WordRange]     wb_wreg_data,
  output reg                 wb_hilo_we,
  output reg[`WordRange]     wb_hi_data,
  output reg[`WordRange]     wb_lo_data,
  output reg                 t_wb_cp0_we,
  output reg[4:0]            t_wb_cp0_waddr,
  output reg[`WordRange]     t_wb_cp0_wdata
);

  always @(posedge clk) begin
    if (rst == `Enable) begin
      wb_wreg_e      <= `Disable;
      wb_wreg_addr   <= {`RegCountLog2{1'b0}};
      wb_wreg_data   <= `ZeroWord;
      wb_hilo_we     <= `Disable;
      wb_hi_data     <= `ZeroWord;
      wb_lo_data     <= `ZeroWord;
      t_wb_cp0_we    <= `Disable;
      t_wb_cp0_waddr <= 5'd0;
      t_wb_cp0_wdata <= `ZeroWord;
    end else if (flush == `Enable) begin
      wb_wreg_e      <= `Disable;
      wb_wreg_addr   <= {`RegCountLog2{1'b0}};
      wb_wreg_data   <= `ZeroWord;
      wb_hilo_we     <= `Disable;
      wb_hi_data     <= `ZeroWord;
      wb_lo_data     <= `ZeroWord;
      t_wb_cp0_we    <= `Disable;
      t_wb_cp0_waddr <= 5'd0;
      t_wb_cp0_wdata <= `ZeroWord;
    end else if (pause == `Enable) begin
      wb_wreg_e      <= wb_wreg_e;
      wb_wreg_addr   <= wb_wreg_addr;
      wb_wreg_data   <= wb_wreg_data;
      wb_hilo_we     <= wb_hilo_we;
      wb_hi_data     <= wb_hi_data;
      wb_lo_data     <= wb_lo_data;
      t_wb_cp0_we    <= t_wb_cp0_we;
      t_wb_cp0_waddr <= t_wb_cp0_waddr;
      t_wb_cp0_wdata <= t_wb_cp0_wdata;
    end else begin
      wb_wreg_e      <= mem_wreg_e;
      wb_wreg_addr   <= mem_wreg_addr;
      wb_wreg_data   <= mem_wreg_data;
      wb_hilo_we     <= mem_hilo_we;
      wb_hi_data     <= mem_hi_data;
      wb_lo_data     <= mem_lo_data;
      t_wb_cp0_we    <= f_mem_cp0_we;
      t_wb_cp0_waddr <= f_mem_cp0_waddr;
      t_wb_cp0_wdata <= f_mem_cp0_wdata;
    end
  end

endmodule

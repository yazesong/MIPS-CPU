`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 16:24:31
// Design Name: 
// Module Name: ex
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

// 执行阶段：算术/逻辑，乘除法握手，HI/LO 前递，CP0 访问等
module ex(
  input  wire                 rst,
  input  wire[`ALUOpRange]    aluop_in,
  input  wire[`WordRange]     data1_in,
  input  wire[`WordRange]     data2_in,
  input  wire[`RegRangeLog2]  wreg_addr_in,
  input  wire                 wreg_e_in,
  output reg [`RegRangeLog2]  wreg_addr_out,
  output reg                  wreg_e_out,
  output reg [`WordRange]     wreg_data_out,
  // HI/LO 旁路
  input  wire[`WordRange]     hi_data_in,
  input  wire[`WordRange]     lo_data_in,
  input  wire                 mem_hilo_we_in,
  input  wire[`WordRange]     mem_hi_data_in,
  input  wire[`WordRange]     mem_lo_data_in,
  input  wire                 wb_hilo_we_in,
  input  wire[`WordRange]     wb_hi_data_in,
  input  wire[`WordRange]     wb_lo_data_in,
  output reg                  hilo_we_out,
  output reg[`WordRange]      hi_data_out,
  output reg[`WordRange]      lo_data_out,
  // 暂停请求（给调度器）
  output reg                  pause_req,
  // link 地址
  input  wire[`WordRange]     link_addr_in,
  // DIV 接口
  output reg[`WordRange]      div_data1_signed,
  output reg[`WordRange]      div_data2_signed,
  output reg[`WordRange]      div_data1_unsigned,
  output reg[`WordRange]      div_data2_unsigned,
  output reg                  div_data_valid_signed,
  output reg                  div_data_valid_unsigned,
  input  wire[`DivMulResultRange] div_result_signed,
  input  wire                 div_result_valid_signed,
  input  wire[`DivMulResultRange] div_result_unsigned,
  input  wire                 div_result_valid_unsigned,
  // MUL 接口
  output reg[`WordRange]      mul_data1,
  output reg[`WordRange]      mul_data2,
  output reg                  mul_type,
  output reg                  mul_valid,
  input  wire[`DivMulResultRange] mul_result,
  input  wire                 mul_result_valid,
  // 其他
  input  wire                 is_in_delayslot,
  input  wire[`WordRange]     ins_in,
  output reg[`ALUOpRange]     aluop_out,
  output reg[`WordRange]      mem_addr_out,
  output reg[`WordRange]      mem_data_out,
  // CP0 前递
  input  wire[`WordRange]     cp0_data_in,
  output reg [4:0]            cp0_raddr_out,
  input  wire                 f_mem_cp0_we_in,
  input  wire[4:0]            f_mem_cp0_w_addr,
  input  wire[`WordRange]     f_mem_cp0_w_data,
  input  wire                 f_wb_cp0_we_in,
  input  wire[4:0]            f_wb_cp0_w_addr,
  input  wire[`WordRange]     f_wb_cp0_w_data,
  output reg                  cp0_we_out,
  output reg [4:0]            cp0_waddr_out,
  output reg[`WordRange]      cp0_w_data_out,
  // 向后传递
  output reg[`WordRange]      ins_out,
  // 异常
  input  wire[`WordRange]     current_ex_pc_addr_in,
  input  wire[`WordRange]     abnormal_type_in,
  output reg[`WordRange]      abnormal_type_out,
  output reg[`WordRange]      current_ex_pc_addr_out
);

  wire[`WordRange] alu_res;
  reg [`WordRange] mov_res;
  reg [`WordRange] hi_temp, lo_temp;

  // ALU 实例，算术逻辑由单独模块完成
  alu u_alu(
    .data1(data1_in),
    .data2(data2_in),
    .op   (aluop_in),
    .res  (alu_res)
  );

  // HI/LO 旁路选择
  always @(*) begin
    if (rst == `Enable) begin
      hi_temp = `ZeroWord;
      lo_temp = `ZeroWord;
    end else if (mem_hilo_we_in == `Enable) begin
      hi_temp = mem_hi_data_in;
      lo_temp = mem_lo_data_in;
    end else if (wb_hilo_we_in == `Enable) begin
      hi_temp = wb_hi_data_in;
      lo_temp = wb_lo_data_in;
    end else begin
      hi_temp = hi_data_in;
      lo_temp = lo_data_in;
    end
  end

  // MFC0/MFHI/MFLO 结果选择
  always @(*) begin
    mov_res      = `ZeroWord;
    cp0_raddr_out= 5'd0;
    if (rst != `Enable) begin
      case (aluop_in)
        `EXOP_MFHI: mov_res = hi_temp;
        `EXOP_MFLO: mov_res = lo_temp;
        `EXOP_MFC0: begin
          cp0_raddr_out = ins_in[15:11];
          mov_res       = cp0_data_in;
          if (f_mem_cp0_we_in && f_mem_cp0_w_addr == ins_in[15:11]) begin
            mov_res = f_mem_cp0_w_data;
          end else if (f_wb_cp0_we_in && f_wb_cp0_w_addr == ins_in[15:11]) begin
            mov_res = f_wb_cp0_w_data;
          end
        end
        default: ;
      endcase
    end
  end

  // CP0 写控制
  always @(*) begin
    if (rst == `Enable) begin
      cp0_we_out   = `Disable;
      cp0_waddr_out= 5'd0;
      cp0_w_data_out = `ZeroWord;
    end else if (aluop_in == `EXOP_MTC0) begin
      cp0_we_out   = `Enable;
      cp0_waddr_out= ins_in[15:11];
      cp0_w_data_out = data1_in;
    end else begin
      cp0_we_out   = `Disable;
      cp0_waddr_out= 5'd0;
      cp0_w_data_out = `ZeroWord;
    end
  end

  // 写回/访存/乘除法控制
  always @(*) begin
    // 默认透传
    wreg_e_out      = (rst == `Enable) ? `Disable : wreg_e_in;
    wreg_addr_out   = wreg_addr_in;
    wreg_data_out   = (rst == `Enable) ? `ZeroWord : alu_res;
    hilo_we_out     = `Disable;
    hi_data_out     = `ZeroWord;
    lo_data_out     = `ZeroWord;
    pause_req       = `Disable;
    div_data_valid_signed   = `Disable;
    div_data_valid_unsigned = `Disable;
    div_data1_signed        = `ZeroWord;
    div_data2_signed        = `ZeroWord;
    div_data1_unsigned      = `ZeroWord;
    div_data2_unsigned      = `ZeroWord;
    mul_data1               = `ZeroWord;
    mul_data2               = `ZeroWord;
    mul_valid               = `Disable;
    mul_type                = `Disable;
    mem_addr_out            = data1_in + {{16{ins_in[15]}}, ins_in[15:0]};
    mem_data_out            = data2_in;
    aluop_out               = aluop_in;
    ins_out                 = ins_in;
    abnormal_type_out       = (rst == `Enable) ? `ZeroWord : abnormal_type_in;
    current_ex_pc_addr_out  = (rst == `Enable) ? `ZeroWord : current_ex_pc_addr_in;

    if (rst == `Enable) begin
      // 已在默认分支处理
    end else begin
      case (aluop_in)
        `ALUOP_DIV: begin
          if (div_result_valid_signed == `Disable) begin
            div_data1_signed        = data1_in;
            div_data2_signed        = data2_in;
            div_data_valid_signed   = `Enable;
            pause_req               = `Enable;
          end
        end
        `ALUOP_DIVU: begin
          if (div_result_valid_unsigned == `Disable) begin
            div_data1_unsigned      = data1_in;
            div_data2_unsigned      = data2_in;
            div_data_valid_unsigned = `Enable;
            pause_req               = `Enable;
          end
        end
        `ALUOP_MULT: begin
          if (mul_result_valid == `Disable) begin
            mul_data1 = data1_in;
            mul_data2 = data2_in;
            mul_type  = `Enable;
            mul_valid = `Enable;
            pause_req = `Enable;
          end
        end
        `ALUOP_MULTU: begin
          if (mul_result_valid == `Disable) begin
            mul_data1 = data1_in;
            mul_data2 = data2_in;
            mul_type  = `Disable;
            mul_valid = `Enable;
            pause_req = `Enable;
          end
        end
        `EXOP_JR, `EXOP_JALR, `EXOP_J, `EXOP_JAL,
        `EXOP_BEQ, `EXOP_BGTZ, `EXOP_BLEZ, `EXOP_BNE,
        `EXOP_BGEZ, `EXOP_BGEZAL, `EXOP_BLTZ, `EXOP_BLTZAL: begin
          wreg_data_out = link_addr_in;
        end
        `EXOP_MFC0, `EXOP_MFLO, `EXOP_MFHI: begin
          wreg_data_out = mov_res;
        end
        default: ;
      endcase
    end
  end

  // HI/LO 写入控制
  always @(*) begin
    hilo_we_out = `Disable;
    hi_data_out = hi_temp;
    lo_data_out = lo_temp;
    if (rst != `Enable) begin
      case (aluop_in)
        `ALUOP_DIV:   begin hilo_we_out = `Enable; hi_data_out = div_result_signed[31:0];   lo_data_out = div_result_signed[63:32]; end
        `ALUOP_DIVU:  begin hilo_we_out = `Enable; hi_data_out = div_result_unsigned[31:0]; lo_data_out = div_result_unsigned[63:32]; end
        `ALUOP_MULT,
        `ALUOP_MULTU: begin hilo_we_out = `Enable; hi_data_out = mul_result[63:32];         lo_data_out = mul_result[31:0]; end
        `EXOP_MTHI:   begin hilo_we_out = `Enable; hi_data_out = data1_in;                  lo_data_out = lo_temp; end
        `EXOP_MTLO:   begin hilo_we_out = `Enable; hi_data_out = hi_temp;                  lo_data_out = data1_in; end
        default: ;
      endcase
    end
  end

endmodule

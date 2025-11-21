`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/17 11:32:53
// Design Name: 
// Module Name: id
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

// 指令译码模块
// 对指令进行译码，输出包括：
// 源操作数1、源操作数2、写入的目的寄存器的运算类型（逻辑、移位、算术）
module id (

  input rst, // 复位
  input wire[`WordRange] pc_in, // 输入的PC值，译码阶段指令地址
  input wire[`WordRange] ins_in, // 输入的指令，即取出的指令

  // 寄存器来向数据相关接口
  input wire[`WordRange] reg1_data_in, // 输入的寄存器数据1
  input wire[`WordRange] reg2_data_in, // 输入的寄存器数据2
  output reg reg1_ren_out, // 寄存器读使能1
  output reg reg2_ren_out, // 寄存器读使能2
  output reg[`RegRangeLog2] reg1_addr_out, // 寄存器读地址1
  output reg[`RegRangeLog2] reg2_addr_out, // 寄存器读地址2

  // 告诉执行单元应执行何种操作
  output reg[`ALUOpRange] exop_out, // 输出的ALUOp

  // 最终决定的数据
  output reg[`WordRange] data1_out, // 输出的数据1
  output reg[`WordRange] data2_out, // 输出的数据2
  
  // 寄存器去向相关接口
  output reg wreg_wen_out, // 写寄存器使能输出
  output reg[`RegRangeLog2] wreg_addr_out, // 写寄存器地址输出

  // 下面部分用于采用数据前推（转移）法解决相隔0条（ID-EX）和相隔1条（ID-MEM）阶段的RAW数据相关
  // EX阶段运算结果（即上条指令）
  input wire ex_wreg_en_in,
  input wire[`WordRange] ex_wreg_data_in,
  input wire[`RegRangeLog2] ex_wreg_addr_in,
  // MEM阶段运算结果（上两条指令）
  input wire mem_wreg_en_in,
  input wire[`WordRange] mem_wreg_data_in,
  input wire[`RegRangeLog2] mem_wreg_addr_in,

  output reg pause_req, // 要求进行流水暂停信号

  // 延迟槽相关
  input wire in_delayslot_in, // 当前要进入（译码阶段）指令是否是延迟槽内指令（必须执行）
  output reg in_delayslot_out,  // 当前要出（译码阶段）指令是否是延迟槽内指令（必须执行）
  output reg next_in_delayslot_out, // 下条指令是否处是延迟槽内指令（即当前指令是否要跳转）
  
  // 分支相关
  output reg branch_en_out,  // 分支生效信号
  output reg[`WordRange] branch_addr_out, // 分支跳转地址
  output reg[`WordRange] link_addr_out, // 转移指令需要保存的地址
  
  output reg[`WordRange] ins_out,   // 向流水线后续传递的指令 在添加存储指令时需要用到

  // 异常相关
  // abnormal_type_out
  // 31...12 预留
  // 11 eret
  // 10 systemcall
  // 9...8 abnormal info
  // 7...0 interrupt info
  output reg[`WordRange] abnormal_type_out,//指令的异常信息
  output reg[`WordRange] current_id_pc_addr_out //当前处在译码阶段指令的地址

);

  // controller 输出的控制信号
  wire               ctrl_reg1_ren;
  wire               ctrl_reg2_ren;
  wire[`RegRangeLog2] ctrl_reg1_addr;
  wire[`RegRangeLog2] ctrl_reg2_addr;
  wire               ctrl_wreg_wen;
  wire[`RegRangeLog2] ctrl_wreg_addr;
  wire[`ALUOpRange]  ctrl_exop;
  wire[`WordRange]   ctrl_immed;
  wire               ctrl_is_branch;
  wire[3:0]          ctrl_branch_type;
  wire[`WordRange]   ctrl_branch_imm_target;
  wire[`WordRange]   ctrl_branch_rel_offset;
  wire[`WordRange]   ctrl_link_addr;
  wire[`WordRange]   ctrl_abnormal_type;

  // 指令中的立即数的扩展结果
  reg[`WordRange] immed;

  // controller 例化
  controller u_controller (
    .rst               (rst),
    .pc_in             (pc_in),
    .ins_in            (ins_in),
    .reg1_ren_out      (ctrl_reg1_ren),
    .reg2_ren_out      (ctrl_reg2_ren),
    .reg1_addr_out     (ctrl_reg1_addr),
    .reg2_addr_out     (ctrl_reg2_addr),
    .wreg_wen_out      (ctrl_wreg_wen),
    .wreg_addr_out     (ctrl_wreg_addr),
    .exop_out          (ctrl_exop),
    .immed_out         (ctrl_immed),
    .is_branch_out     (ctrl_is_branch),
    .branch_type_out   (ctrl_branch_type),
    .branch_imm_target (ctrl_branch_imm_target),
    .branch_rel_offset (ctrl_branch_rel_offset),
    .link_addr_out     (ctrl_link_addr),
    .abnormal_type_out (ctrl_abnormal_type)
  );

  // 预先算好PC+4+offset，便于条件分支直接复用
  wire[`WordRange] ctrl_branch_pc4 = pc_in + 32'd4 + ctrl_branch_rel_offset;

  // 分支类型编码，需与controller内保持一致
  localparam BR_NONE   = 4'd0;
  localparam BR_J      = 4'd1;
  localparam BR_JAL    = 4'd2;
  localparam BR_JR     = 4'd3;
  localparam BR_JALR   = 4'd4;
  localparam BR_BEQ    = 4'd5;
  localparam BR_BNE    = 4'd6;
  localparam BR_BGTZ   = 4'd7;
  localparam BR_BLEZ   = 4'd8;
  localparam BR_BGEZ   = 4'd9;
  localparam BR_BLTZ   = 4'd10;
  localparam BR_BGEZAL = 4'd11;
  localparam BR_BLTZAL = 4'd12;
 

  // 控制信号分发controller负责译码，这里只做复位保护和透传
  always @(*) begin
    if (rst == `Enable) begin
      exop_out = `ALUOP_NOP;
      wreg_wen_out = `Disable;
      wreg_addr_out = `RegCountLog2'd0;
      reg1_ren_out = `Disable;
      reg1_addr_out = `RegCountLog2'd0;
      reg2_ren_out = `Disable;
      reg2_addr_out = `RegCountLog2'd0;
      immed = `ZeroWord;
      link_addr_out = `ZeroWord;
      abnormal_type_out = `ZeroWord;
      ins_out = `ZeroWord;
      current_id_pc_addr_out = `ZeroWord;
      pause_req = `Disable;
    end else begin
      exop_out = ctrl_exop;
      wreg_wen_out = ctrl_wreg_wen;
      wreg_addr_out = ctrl_wreg_addr;
      reg1_ren_out = ctrl_reg1_ren;
      reg1_addr_out = ctrl_reg1_addr;
      reg2_ren_out = ctrl_reg2_ren;
      reg2_addr_out = ctrl_reg2_addr;
      immed = ctrl_immed;
      link_addr_out = ctrl_link_addr;
      abnormal_type_out = ctrl_abnormal_type;
      ins_out = ins_in;
      current_id_pc_addr_out = pc_in;
      pause_req = `Disable; // 暂无暂停请求
    end
  end

  // 根据controller的分支类型和真实操作数决定是否跳转
  always @(*) begin
    branch_en_out = `Disable;
    branch_addr_out = `ZeroWord;
    next_in_delayslot_out = `Disable;

    if (rst == `Enable) begin
      // 复位保持默认
    end else if (ctrl_is_branch == `Enable) begin
      case (ctrl_branch_type)
        BR_J: begin
          branch_en_out = `Enable;
          branch_addr_out = ctrl_branch_imm_target;
          next_in_delayslot_out = `Enable;
        end
        BR_JAL: begin
          branch_en_out = `Enable;
          branch_addr_out = ctrl_branch_imm_target;
          next_in_delayslot_out = `Enable;
        end
        BR_JR: begin
          branch_en_out = `Enable;
          branch_addr_out = data1_out;
          next_in_delayslot_out = `Enable;
        end
        BR_JALR: begin
          branch_en_out = `Enable;
          branch_addr_out = data1_out;
          next_in_delayslot_out = `Enable;
        end
        BR_BEQ: begin
          if (data1_out == data2_out) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        BR_BNE: begin
          if (data1_out != data2_out) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        BR_BGTZ: begin
          if (data1_out[31] == 1'b0 && data1_out != `ZeroWord) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        BR_BLEZ: begin
          if (data1_out[31] == 1'b1 || data1_out == `ZeroWord) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        BR_BGEZ: begin
          if (data1_out[31] == 1'b0) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        BR_BLTZ: begin
          if (data1_out[31] == 1'b1) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        BR_BGEZAL: begin
          if (data1_out[31] == 1'b0) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        BR_BLTZAL: begin
          if (data1_out[31] == 1'b1) begin
            branch_en_out = `Enable;
            branch_addr_out = ctrl_branch_pc4;
            next_in_delayslot_out = `Enable;
          end
        end
        default: begin
          // 其余保持默认
        end
      endcase
    end
  end

  always @(rst or in_delayslot_in) begin
    if (rst == `Enable) begin
      in_delayslot_out = `Disable;     
    end else begin
      in_delayslot_out = in_delayslot_in;
    end
  end

  // 下面开始确定送到EX的数据具体来自于哪里
  // 这取决于来源是寄存器，还是立即数
  always @(*) begin
    // rst时固定出0x0
    if (rst == `Enable) begin
      data1_out = `ZeroWord;
    // 解决相隔0条（ID-EX）的流水数据相关
    // 如果前面的EX要写的就是后面的ID要读的，则穿透（转发）
    end else if (ex_wreg_en_in == `Enable && reg1_ren_out == `Enable && reg1_addr_out == ex_wreg_addr_in) begin
      data1_out = ex_wreg_data_in;
    // 解决相隔1条（ID-MEM）的流水数据相关
    // 如果前面的MEM要写的就是后面的ID要读的，则穿透（转发）
    end else if (mem_wreg_en_in == `Enable && reg1_ren_out == `Enable && reg1_addr_out == mem_wreg_addr_in) begin
      data1_out = mem_wreg_data_in;  
    // 如果指令译码的结果需要读reg1，就说明操作数1来自寄存器（rs）
    end else if (reg1_ren_out == `Enable) begin
      data1_out = reg1_data_in;
    // 如果指令译码的结果不需要读reg1，就说明操作数1是立即数
    end else if (reg1_ren_out == `Disable) begin
      data1_out = immed;
    // 兜底
    end else begin
      data1_out = `ZeroWord;
    end
  end

  // 逻辑同上
  always @(*) begin
    if (rst == `Enable) begin
      data2_out = `ZeroWord;
    end else if (ex_wreg_en_in == `Enable && reg2_ren_out == `Enable && reg2_addr_out == ex_wreg_addr_in) begin
      data2_out = ex_wreg_data_in;
    end else if (mem_wreg_en_in == `Enable && reg2_ren_out == `Enable && reg2_addr_out == mem_wreg_addr_in) begin
      data2_out = mem_wreg_data_in;  
    end else if (reg2_ren_out == `Enable) begin //（rt）
      data2_out = reg2_data_in;
    end else if (reg2_ren_out == `Disable) begin
      data2_out = immed;
    end else begin
      data2_out = `ZeroWord;
    end
  end

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/16 20:47:17
// Design Name: 
// Module Name: controller
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

// 只根据指令字段和 PC 产生各类控制信号
// 不做前递/暂停/比较，只做这条指令是什么，要干什么的决策

module controller (

  input  wire              rst,
  input  wire[`WordRange]  pc_in,
  input  wire[`WordRange]  ins_in,

  // GPR 读写控制
  output reg               reg1_ren_out,
  output reg               reg2_ren_out,
  output reg[`RegRangeLog2] reg1_addr_out,
  output reg[`RegRangeLog2] reg2_addr_out,

  output reg               wreg_wen_out,
  output reg[`RegRangeLog2] wreg_addr_out,

  // 执行阶段操作码（ALU/EX模块统一用这个）
  output reg[`ALUOpRange]  exop_out,

  // 译码阶段形成的立即数（扩展/拼接好的）
  output reg[`WordRange]   immed_out,

  // 分支/跳转相关（只描述类型和立即数，不做比较）
  output reg               is_branch_out,      // 是否是分支/跳转类指令
  output reg [3:0]         branch_type_out,    // 0:无; 1:J;2:JAL;3:JR;4:JALR;5:BEQ;6:BNE;7:BGTZ;8:BLEZ;9:BGEZ;10:BLTZ;11:BGEZAL;12:BLTZAL
  output reg[`WordRange]   branch_imm_target,  // J/JAL的绝对目标 {4'b0000, address, 2'b00}
  output reg[`WordRange]   branch_rel_offset,  // 各种B*的偏移 (sign-ext(offset)<<2)

  // Link 相关（给EX用来写回返回地址）
  output reg[`WordRange]   link_addr_out,      // 一般是PC+8，非link指令为0

  // 异常相关（传给CP0的abnormal_type）
  output reg[`WordRange]   abnormal_type_out

);

  // 指令字段
  wire[5:0] op      = ins_in[`OpRange];
  wire[4:0] rs      = ins_in[`RsRange];
  wire[4:0] rt      = ins_in[`RtRange];
  wire[4:0] rd      = ins_in[`RdRange];
  wire[4:0] shamt   = ins_in[`ShamtRange];
  wire[5:0] func    = ins_in[`FuncRange];
  wire[15:0] imm16  = ins_in[`ImmedRange];
  wire[15:0] offset = ins_in[`OffsetRange];
  wire[25:0] addr26 = ins_in[`AddressRange];

  // 分支类型编码
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

  always @(*) begin
    // 默认值
    exop_out           = `ALUOP_NOP;
    wreg_wen_out       = `Disable;
    reg1_ren_out       = `Disable;
    reg2_ren_out       = `Disable;
    reg1_addr_out      = `RegCountLog2'd0;
    reg2_addr_out      = `RegCountLog2'd0;
    wreg_addr_out      = `RegCountLog2'd0;
    immed_out          = `ZeroWord;

    is_branch_out      = 1'b0;
    branch_type_out    = BR_NONE;
    branch_imm_target  = `ZeroWord;
    branch_rel_offset  = `ZeroWord;
    link_addr_out      = `ZeroWord;

    abnormal_type_out  = `ZeroWord;

    if (rst == `Enable) begin
      // 复位时保持默认
    end else if (ins_in == 32'd0) begin
      // NOP
    end else begin
      // R型
      if (op == `OP_RTYPE) begin
        case (func)
          // 逻辑运算
          `FUNC_OR: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_OR;
          end
          `FUNC_AND: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_AND;
          end
          `FUNC_XOR: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_XOR;
          end
          `FUNC_NOR: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_NOR;
          end

          // 移位（可变/固定）
          `FUNC_SLLV: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable; // 移位量
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable; // 被移位数
            reg2_addr_out = rt;
            exop_out      = `ALUOP_SLL;
          end
          `FUNC_SRLV: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_SRL;
          end
          `FUNC_SRAV: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_SRA;
          end
          `FUNC_SLL: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Disable;              // 用立即数作为移位量
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            immed_out     = {27'h0, shamt};
            exop_out      = `ALUOP_SLL;
          end
          `FUNC_SRL: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Disable;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            immed_out     = {27'h0, shamt};
            exop_out      = `ALUOP_SRL;
          end
          `FUNC_SRA: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Disable;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            immed_out     = {27'h0, shamt};
            exop_out      = `ALUOP_SRA;
          end

          // HI/LO 相关
          `FUNC_MFHI: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Disable;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_MFHI;
          end
          `FUNC_MFLO: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Disable;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_MFLO;
          end
          `FUNC_MTHI: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_MTHI;
          end
          `FUNC_MTLO: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_MTLO;
          end

          // 比较
          `FUNC_SLT: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_SLT;
          end
          `FUNC_SLTU: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_SLTU;
          end

          // 加减
          `FUNC_ADD: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_ADD;
          end
          `FUNC_ADDU: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_ADDU;
          end
          `FUNC_SUB: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_SUB;
          end
          `FUNC_SUBU: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rd;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_SUBU;
          end

          // 乘除
          `FUNC_DIV: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_DIV;
          end
          `FUNC_DIVU: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_DIVU;
          end
          `FUNC_MULT: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_MULT;
          end
          `FUNC_MULTU: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `ALUOP_MULTU;
          end

          // 跳转类
          `FUNC_JR: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Enable;
            reg1_addr_out  = rs;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_JR;
            is_branch_out  = 1'b1;
            branch_type_out= BR_JR;
            // 真正的跳转地址=rs 值，留给ID用data1_out去算
          end
          `FUNC_JALR: begin
            wreg_wen_out   = `Enable;
            wreg_addr_out  = rd;
            reg1_ren_out   = `Enable;
            reg1_addr_out  = rs;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_JALR;
            is_branch_out  = 1'b1;
            branch_type_out= BR_JALR;
            link_addr_out  = pc_in + 32'd8;
          end

          // 异常相关
          `FUNC_SYSCALL: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Disable;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_SYSTEMCALL;
            abnormal_type_out[6:2] = `ABN_SYSTEMCALL;
          end
          `FUNC_BREAK: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Disable;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_SYSTEMCALL;
            abnormal_type_out[6:2] = `ABN_BREAK;
          end
          default: begin end
        endcase

      end else begin
        // I/J型
        case (op)
          // 逻辑立即数
          `OP_ORI: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {16'h0, imm16};
            exop_out      = `ALUOP_OR;
          end
          `OP_ANDI: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {16'h0, imm16};
            exop_out      = `ALUOP_AND;
          end
          `OP_XORI: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {16'h0, imm16};
            exop_out      = `ALUOP_XOR;
          end
          `OP_LUI: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;  // rs应该是$0
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {imm16, 16'h0};
            exop_out      = `ALUOP_OR;
          end

          // 比较立即数
          `OP_SLTI: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {{16{imm16[15]}}, imm16};
            exop_out      = `ALUOP_SLT;
          end
          `OP_SLTIU: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {{16{imm16[15]}}, imm16};
            exop_out      = `ALUOP_SLTU;
          end

          // 加法立即数
          `OP_ADDI: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {{16{imm16[15]}}, imm16};
            exop_out      = `ALUOP_ADD;
          end
          `OP_ADDIU: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            immed_out     = {{16{imm16[15]}}, imm16};
            exop_out      = `ALUOP_ADDU;
          end

          // 绝对跳转
          `OP_J: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Disable;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_J;
            is_branch_out  = 1'b1;
            branch_type_out= BR_J;
            branch_imm_target = {4'b0000, addr26, 2'b00};
          end
          `OP_JAL: begin
            wreg_wen_out   = `Enable;
            wreg_addr_out  = `RegCountLog2'd31; // $ra
            reg1_ren_out   = `Disable;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_JAL;
            is_branch_out  = 1'b1;
            branch_type_out= BR_JAL;
            branch_imm_target = {4'b0000, addr26, 2'b00};
            link_addr_out  = pc_in + 32'd8;
          end

          // 条件分支只给出类型和偏移，真正是否跳转留给ID用数据判断
          `OP_BEQ: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Enable;
            reg1_addr_out  = rs;
            reg2_ren_out   = `Enable;
            reg2_addr_out  = rt;
            exop_out       = `EXOP_BEQ;
            is_branch_out  = 1'b1;
            branch_type_out= BR_BEQ;
            branch_rel_offset = {{14{offset[15]}}, offset, 2'b00};
          end
          `OP_BGTZ: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Enable;
            reg1_addr_out  = rs;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_BGTZ;
            is_branch_out  = 1'b1;
            branch_type_out= BR_BGTZ;
            branch_rel_offset = {{14{offset[15]}}, offset, 2'b00};
          end
          `OP_BLEZ: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Enable;
            reg1_addr_out  = rs;
            reg2_ren_out   = `Disable;
            exop_out       = `EXOP_BLEZ;
            is_branch_out  = 1'b1;
            branch_type_out= BR_BLEZ;
            branch_rel_offset = {{14{offset[15]}}, offset, 2'b00};
          end
          `OP_BNE: begin
            wreg_wen_out   = `Disable;
            reg1_ren_out   = `Enable;
            reg1_addr_out  = rs;
            reg2_ren_out   = `Enable;
            reg2_addr_out  = rt;
            exop_out       = `EXOP_BNE;
            is_branch_out  = 1'b1;
            branch_type_out= BR_BNE;
            branch_rel_offset = {{14{offset[15]}}, offset, 2'b00};
          end
          `OP_BGEZ: begin // bgez / bltz / bgezal / bltzal
            reg1_ren_out   = `Enable;
            reg1_addr_out  = rs;
            reg2_ren_out   = `Disable;
            is_branch_out  = 1'b1;
            branch_rel_offset = {{14{offset[15]}}, offset, 2'b00};
            if (rt == 5'b00001) begin          // BGEZ
              wreg_wen_out    = `Disable;
              exop_out        = `EXOP_BGEZ;
              branch_type_out = BR_BGEZ;
            end else if (rt == 5'b00000) begin // BLTZ
              wreg_wen_out    = `Disable;
              exop_out        = `EXOP_BGEZ; // 复用同一个EXOP
              branch_type_out = BR_BLTZ;
            end else if (rt == 5'b10001) begin // BGEZAL
              wreg_wen_out    = `Enable;
              wreg_addr_out   = `RegCountLog2'd31;
              exop_out        = `EXOP_BGEZAL;
              branch_type_out = BR_BGEZAL;
              link_addr_out   = pc_in + 32'd8;
            end else if (rt == 5'b10000) begin // BLTZAL
              wreg_wen_out    = `Enable;
              wreg_addr_out   = `RegCountLog2'd31;
              exop_out        = `EXOP_BLTZAL;
              branch_type_out = BR_BLTZAL;
              link_addr_out   = pc_in + 32'd8;
            end
          end

          // 访存指令（具体读写由EX/MEM根据exop_out处理）
          `OP_LB: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_LB;
          end
          `OP_LBU: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_LBU;
          end
          `OP_LH: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_LH;
          end
          `OP_LHU: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_LHU;
          end
          `OP_SB: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `EXOP_SB;
          end
          `OP_SH: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `EXOP_SH;
          end
          `OP_LW: begin
            wreg_wen_out  = `Enable;
            wreg_addr_out = rt;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Disable;
            exop_out      = `EXOP_LW;
          end
          `OP_SW: begin
            wreg_wen_out  = `Disable;
            reg1_ren_out  = `Enable;
            reg1_addr_out = rs;
            reg2_ren_out  = `Enable;
            reg2_addr_out = rt;
            exop_out      = `EXOP_SW;
          end

          // CP0 相关
          `OP_CP0: begin
            if (rs == 5'b00000) begin         // MFC0
              wreg_wen_out  = `Enable;
              wreg_addr_out = rt;
              reg1_ren_out  = `Disable;
              reg2_ren_out  = `Disable;
              exop_out      = `EXOP_MFC0;
            end else if (rs == 5'b00100) begin // MTC0
              wreg_wen_out  = `Disable;
              reg1_ren_out  = `Enable;
              reg1_addr_out = rt;
              reg2_ren_out  = `Disable;
              exop_out      = `EXOP_MTC0;
            end
            // ERET
            if (ins_in[25:0] == 26'b10000000000000000000011000) begin
              wreg_wen_out   = `Disable;
              reg1_ren_out   = `Disable;
              reg2_ren_out   = `Disable;
              exop_out       = `EXOP_ERET;
              abnormal_type_out[6:2] = `ABN_ERET;
            end
          end

          default: begin end
        endcase
      end
    end
  end

endmodule

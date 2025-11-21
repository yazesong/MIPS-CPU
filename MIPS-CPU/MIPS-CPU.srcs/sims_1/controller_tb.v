`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// controller 译码自检 tb：对典型指令编码进行断言
module controller_tb;

  reg               rst;
  reg [`WordRange]  pc_in;
  reg [`WordRange]  ins_in;

  wire              reg1_ren_out;
  wire              reg2_ren_out;
  wire[`RegRangeLog2] reg1_addr_out;
  wire[`RegRangeLog2] reg2_addr_out;
  wire              wreg_wen_out;
  wire[`RegRangeLog2] wreg_addr_out;
  wire[`ALUOpRange] exop_out;
  wire[`WordRange]  immed_out;
  wire              is_branch_out;
  wire [3:0]        branch_type_out;
  wire[`WordRange]  branch_imm_target;
  wire[`WordRange]  branch_rel_offset;
  wire[`WordRange]  link_addr_out;
  wire[`WordRange]  abnormal_type_out;

  controller dut (
    .rst(rst), .pc_in(pc_in), .ins_in(ins_in),
    .reg1_ren_out(reg1_ren_out), .reg2_ren_out(reg2_ren_out),
    .reg1_addr_out(reg1_addr_out), .reg2_addr_out(reg2_addr_out),
    .wreg_wen_out(wreg_wen_out), .wreg_addr_out(wreg_addr_out),
    .exop_out(exop_out), .immed_out(immed_out),
    .is_branch_out(is_branch_out), .branch_type_out(branch_type_out),
    .branch_imm_target(branch_imm_target), .branch_rel_offset(branch_rel_offset),
    .link_addr_out(link_addr_out), .abnormal_type_out(abnormal_type_out)
  );

  // 简易断言
  task assert_eq;
    input [1023:0] name;
    input [31:0]   got;
    input [31:0]   exp;
    begin
      if (got !== exp) begin
        $display("FAIL %s got=0x%08x exp=0x%08x ins=0x%08x", name, got, exp, ins_in);
        $fatal;
      end
    end
  endtask

  // 构造 R 型
  function [31:0] r_ins;
    input [4:0] rs, rt, rd, shamt;
    input [5:0] func;
    begin
      r_ins = {`OP_RTYPE, rs, rt, rd, shamt, func};
    end
  endfunction

  // 构造 I 型
  function [31:0] i_ins;
    input [5:0] op; input [4:0] rs, rt; input [15:0] imm;
    begin
      i_ins = {op, rs, rt, imm};
    end
  endfunction

  // 构造 J 型
  function [31:0] j_ins;
    input [5:0] op; input [25:0] addr;
    begin
      j_ins = {op, addr};
    end
  endfunction

  initial begin
    pc_in = 32'h3000;
    rst   = 1'b1; ins_in = 32'h0; #1;
    rst   = 1'b0;

    // OR rd=5, rs=1, rt=2
    ins_in = r_ins(5'd1, 5'd2, 5'd5, 5'd0, `FUNC_OR); #1;
    assert_eq("OR_reg1_ren", reg1_ren_out, `Enable);
    assert_eq("OR_reg1_addr", reg1_addr_out, 5'd1);
    assert_eq("OR_reg2_addr", reg2_addr_out, 5'd2);
    assert_eq("OR_waddr",     wreg_addr_out, 5'd5);
    assert_eq("OR_exop",      exop_out, `ALUOP_OR);

    // SLL rd=3, rt=2, shamt=4
    ins_in = r_ins(5'd0, 5'd2, 5'd3, 5'd4, `FUNC_SLL); #1;
    assert_eq("SLL_reg1_ren", reg1_ren_out, `Disable);
    assert_eq("SLL_immed",    immed_out, {27'h0,5'd4});
    assert_eq("SLL_exop",     exop_out, `ALUOP_SLL);

    // JR rs=4
    ins_in = r_ins(5'd4, 5'd0, 5'd0, 5'd0, `FUNC_JR); #1;
    assert_eq("JR_reg1_ren",   reg1_ren_out, `Enable);
    assert_eq("JR_branch",     is_branch_out, 1);
    assert_eq("JR_type",       branch_type_out, 4'd3);
    assert_eq("JR_exop",       exop_out, `EXOP_JR);

    // ADDI rs=1 rt=2 imm=0x8001 (负数)
    ins_in = i_ins(`OP_ADDI, 5'd1, 5'd2, 16'h8001); #1;
    assert_eq("ADDI_reg1_ren", reg1_ren_out, `Enable);
    assert_eq("ADDI_reg2_ren", reg2_ren_out, `Disable);
    assert_eq("ADDI_waddr",    wreg_addr_out, 5'd2);
    // 0x8001 按有符号数扩展应该是 0xFFFF_8001
    assert_eq("ADDI_immed",    immed_out, 32'hFFFF_8001);
    assert_eq("ADDI_exop",     exop_out, `ALUOP_ADD);

    // BEQ rs=1 rt=2 offset=4
    ins_in = i_ins(`OP_BEQ, 5'd1, 5'd2, 16'h0004); #1;
    assert_eq("BEQ_branch",     is_branch_out, 1);
    assert_eq("BEQ_type",       branch_type_out, 4'd5);
    assert_eq("BEQ_rel",        branch_rel_offset, {14'h0,16'h0004,2'b00});
    assert_eq("BEQ_exop",       exop_out, `EXOP_BEQ);

    // JAL addr=1
    ins_in = j_ins(`OP_JAL, 26'h1); #1;
    assert_eq("JAL_branch",     is_branch_out, 1);
    assert_eq("JAL_type",       branch_type_out, 4'd2);
    assert_eq("JAL_waddr",      wreg_addr_out, 5'd31);
    assert_eq("JAL_link",       link_addr_out, pc_in + 32'd8);

    // SYSCALL
    ins_in = r_ins(5'd0,5'd0,5'd0,5'd0,`FUNC_SYSCALL); #1;
    assert_eq("SYSCALL_abn", abnormal_type_out[6:2], `ABN_SYSTEMCALL);

    $display("controller TB PASS");
    $finish;
  end

endmodule

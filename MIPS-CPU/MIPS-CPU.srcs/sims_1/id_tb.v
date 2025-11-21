`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// ID 阶段 tb：覆盖译码、前递、分支决策
module id_tb;
  reg rst;
  reg [`WordRange] pc_in;
  reg [`WordRange] ins_in;
  reg [`WordRange] reg1_data_in;
  reg [`WordRange] reg2_data_in;

  reg ex_wreg_en_in;
  reg [`WordRange] ex_wreg_data_in;
  reg [`RegRangeLog2] ex_wreg_addr_in;

  reg mem_wreg_en_in;
  reg [`WordRange] mem_wreg_data_in;
  reg [`RegRangeLog2] mem_wreg_addr_in;

  reg in_delayslot_in;

  wire reg1_ren_out, reg2_ren_out;
  wire [`RegRangeLog2] reg1_addr_out, reg2_addr_out;
  wire [`ALUOpRange]   exop_out;
  wire [`WordRange]    data1_out, data2_out;
  wire wreg_wen_out;
  wire [`RegRangeLog2] wreg_addr_out;
  wire pause_req;
  wire in_delayslot_out, next_in_delayslot_out;
  wire branch_en_out;
  wire [`WordRange] branch_addr_out, link_addr_out, ins_out;
  wire [`WordRange] abnormal_type_out, current_id_pc_addr_out;

  id dut(
    .rst(rst), .pc_in(pc_in), .ins_in(ins_in),
    .reg1_data_in(reg1_data_in), .reg2_data_in(reg2_data_in),
    .reg1_ren_out(reg1_ren_out), .reg2_ren_out(reg2_ren_out),
    .reg1_addr_out(reg1_addr_out), .reg2_addr_out(reg2_addr_out),
    .exop_out(exop_out), .data1_out(data1_out), .data2_out(data2_out),
    .wreg_wen_out(wreg_wen_out), .wreg_addr_out(wreg_addr_out),
    .ex_wreg_en_in(ex_wreg_en_in), .ex_wreg_data_in(ex_wreg_data_in), .ex_wreg_addr_in(ex_wreg_addr_in),
    .mem_wreg_en_in(mem_wreg_en_in), .mem_wreg_data_in(mem_wreg_data_in), .mem_wreg_addr_in(mem_wreg_addr_in),
    .pause_req(pause_req),
    .in_delayslot_in(in_delayslot_in), .in_delayslot_out(in_delayslot_out), .next_in_delayslot_out(next_in_delayslot_out),
    .branch_en_out(branch_en_out), .branch_addr_out(branch_addr_out), .link_addr_out(link_addr_out),
    .ins_out(ins_out), .abnormal_type_out(abnormal_type_out), .current_id_pc_addr_out(current_id_pc_addr_out)
  );

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

  task check;
    input cond;
    input [1023:0] msg;
    begin
      if (!cond) begin
        $display("FAIL %s ins=0x%08x", msg, ins_in);
        $fatal;
      end
    end
  endtask

  initial begin
    rst = `Enable; pc_in = 32'h3000;
    ins_in = 0; reg1_data_in = 0; reg2_data_in = 0;
    ex_wreg_en_in = 0; ex_wreg_data_in = 0; ex_wreg_addr_in = 0;
    mem_wreg_en_in = 0; mem_wreg_data_in = 0; mem_wreg_addr_in = 0;
    in_delayslot_in = 0;
    #1;
    rst = `Disable;

    // 用例1：OR rd=3, rs=1, rt=2
    reg1_data_in = 32'hAAAA_0001;
    reg2_data_in = 32'h5555_0002;
    ins_in = r_ins(5'd1,5'd2,5'd3,5'd0,`FUNC_OR); #1;
    check(reg1_ren_out==`Enable && reg2_ren_out==`Enable, "OR ren");
    check(reg1_addr_out==5'd1 && reg2_addr_out==5'd2, "OR addr");
    check(wreg_wen_out==`Enable && wreg_addr_out==5'd3, "OR wreg");
    check(exop_out==`ALUOP_OR, "OR exop");
    check(data1_out==reg1_data_in && data2_out==reg2_data_in, "OR data pass");
    check(branch_en_out==`Disable, "OR no branch");

    // 用例2：SLL rd=4, rt=2, shamt=3 -> data1_out取 immed
    ins_in = r_ins(5'd0,5'd2,5'd4,5'd3,`FUNC_SLL); #1;
    check(reg1_ren_out==`Disable && reg2_ren_out==`Enable, "SLL ren");
    check(data1_out=={27'h0,5'd3}, "SLL immed to data1");
    check(exop_out==`ALUOP_SLL, "SLL exop");

    // 用例3：BEQ 命中，跳转地址 pc+4+offset<<2
    reg1_data_in = 32'h1111_1111;
    reg2_data_in = 32'h1111_1111;
    ins_in = i_ins(`OP_BEQ,5'd6,5'd7,16'h0002); #1;
    check(branch_en_out==`Enable, "BEQ taken");
    check(branch_addr_out==pc_in+32'd4+{{14{1'b0}},16'h0002,2'b00}, "BEQ addr");
    check(next_in_delayslot_out==`Enable, "BEQ delay slot");

    // 用例4：BEQ 不命中
    reg2_data_in = 32'h2222_2222;
    ins_in = i_ins(`OP_BEQ,5'd6,5'd7,16'h0002); #1;
    check(branch_en_out==`Disable, "BEQ not taken");

    // 用例5：前递 EX（reg1读）
    ex_wreg_en_in   = `Enable;
    ex_wreg_addr_in = 5'd1;
    ex_wreg_data_in = 32'hDEAD_BEEF;
    reg1_data_in    = 32'h0000_1111;
    reg2_data_in    = 32'h0000_2222;
    ins_in = i_ins(`OP_ADDI,5'd1,5'd8,16'h0001); #1; // reg1_ren=1
    check(data1_out==32'hDEAD_BEEF, "EX forward");
    ex_wreg_en_in = `Disable;

    // 用例6：前递 MEM（reg2读）
    mem_wreg_en_in   = `Enable;
    mem_wreg_addr_in = 5'd9;
    mem_wreg_data_in = 32'hFEED_FACE;
    reg1_data_in     = 32'h0000_AAAA;
    reg2_data_in     = 32'h0000_3333;
    ins_in = r_ins(5'd1,5'd9,5'd10,5'd0,`FUNC_OR); #1;
    check(data2_out==32'hFEED_FACE, "MEM forward");
    mem_wreg_en_in = `Disable;

    // 用例7：JR 跳转地址来自 data1_out
    reg1_data_in = 32'h8888_0000;
    ins_in = r_ins(5'd4,5'd0,5'd0,5'd0,`FUNC_JR); #1;
    check(branch_en_out==`Enable, "JR branch");
    check(branch_addr_out==reg1_data_in, "JR addr");
    check(next_in_delayslot_out==`Enable, "JR delay");

    $display("id TB PASS");
    $finish;
  end
endmodule

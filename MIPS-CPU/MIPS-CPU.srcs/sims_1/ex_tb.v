`timescale 1ns / 1ps
`include "public.v"

// 简易 EX 阶段验证：加法、MFHI、乘/除法握手
module ex_tb;
  reg rst;
  reg[`ALUOpRange] aluop_in;
  reg[`WordRange]  data1_in, data2_in;
  reg[`RegRangeLog2] wreg_addr_in;
  reg wreg_e_in;
  reg[`WordRange] hi_in, lo_in;
  reg mem_hilo_we_in, wb_hilo_we_in;
  reg[`WordRange] mem_hi_in, mem_lo_in, wb_hi_in, wb_lo_in;
  reg[`WordRange] link_addr_in;
  reg[`WordRange] ins_in;
  reg[`WordRange] cp0_data_in;
  reg f_mem_cp0_we_in, f_wb_cp0_we_in;
  reg[4:0] f_mem_cp0_w_addr, f_wb_cp0_w_addr;
  reg[`WordRange] f_mem_cp0_w_data, f_wb_cp0_w_data;
  reg[`WordRange] ex_pc_in, abn_in;
  // div/mul stub输入
  reg[`DivMulResultRange] div_res_s, div_res_u, mul_res;
  reg div_v_s, div_v_u, mul_v;

  wire pause_req;
  wire[`WordRange] div_d1_s, div_d2_s, div_d1_u, div_d2_u;
  wire div_valid_s, div_valid_u;
  wire[`WordRange] mem_addr_out, mem_data_out;
  wire[`WordRange] wreg_data_out;
  wire hilo_we_out;
  wire[`WordRange] hi_out, lo_out;
  wire cp0_we_out;
  wire[4:0] cp0_waddr_out;
  wire[`WordRange] cp0_wdata_out;

  task check(input cond, input [256*8-1:0] msg);
    if(!cond) begin $display("FAIL %s", msg); $fatal; end
    else $display("PASS %s", msg);
  endtask

  ex dut(
    .rst(rst),
    .aluop_in(aluop_in),
    .data1_in(data1_in),
    .data2_in(data2_in),
    .wreg_addr_in(wreg_addr_in),
    .wreg_e_in(wreg_e_in),
    .wreg_addr_out(), .wreg_e_out(), .wreg_data_out(wreg_data_out),
    .hi_data_in(hi_in), .lo_data_in(lo_in),
    .mem_hilo_we_in(mem_hilo_we_in), .mem_hi_data_in(mem_hi_in), .mem_lo_data_in(mem_lo_in),
    .wb_hilo_we_in(wb_hilo_we_in), .wb_hi_data_in(wb_hi_in), .wb_lo_data_in(wb_lo_in),
    .hilo_we_out(hilo_we_out), .hi_data_out(hi_out), .lo_data_out(lo_out),
    .pause_req(pause_req),
    .link_addr_in(link_addr_in),
    .div_data1_signed(div_d1_s), .div_data2_signed(div_d2_s),
    .div_data1_unsigned(div_d1_u), .div_data2_unsigned(div_d2_u),
    .div_data_valid_signed(div_valid_s), .div_data_valid_unsigned(div_valid_u),
    .div_result_signed(div_res_s), .div_result_valid_signed(div_v_s),
    .div_result_unsigned(div_res_u), .div_result_valid_unsigned(div_v_u),
    .mul_data1(), .mul_data2(), .mul_type(), .mul_valid(),
    .mul_result(mul_res), .mul_result_valid(mul_v),
    .is_in_delayslot(1'b0),
    .ins_in(ins_in),
    .aluop_out(), .mem_addr_out(mem_addr_out), .mem_data_out(mem_data_out),
    .cp0_data_in(cp0_data_in), .cp0_raddr_out(),
    .f_mem_cp0_we_in(f_mem_cp0_we_in), .f_mem_cp0_w_addr(f_mem_cp0_w_addr), .f_mem_cp0_w_data(f_mem_cp0_w_data),
    .f_wb_cp0_we_in(f_wb_cp0_we_in),  .f_wb_cp0_w_addr(f_wb_cp0_w_addr), .f_wb_cp0_w_data(f_wb_cp0_w_data),
    .cp0_we_out(cp0_we_out), .cp0_waddr_out(cp0_waddr_out), .cp0_w_data_out(cp0_wdata_out),
    .ins_out(), .current_ex_pc_addr_in(ex_pc_in), .abnormal_type_in(abn_in),
    .abnormal_type_out(), .current_ex_pc_addr_out()
  );

  initial begin
    rst = 1;
    aluop_in = `ALUOP_NOP; data1_in = 0; data2_in = 0; wreg_addr_in = 0; wreg_e_in = 0;
    hi_in = 0; lo_in = 0; mem_hilo_we_in = 0; wb_hilo_we_in = 0;
    mem_hi_in = 0; mem_lo_in = 0; wb_hi_in = 0; wb_lo_in = 0;
    link_addr_in = 0; ins_in = 0; cp0_data_in = 0;
    f_mem_cp0_we_in = 0; f_wb_cp0_we_in = 0;
    f_mem_cp0_w_addr = 0; f_wb_cp0_w_addr = 0;
    f_mem_cp0_w_data = 0; f_wb_cp0_w_data = 0;
    ex_pc_in = 0; abn_in = 0;
    div_res_s = 64'h1; div_res_u = 64'h2; mul_res = 64'h3;
    div_v_s = 1; div_v_u = 1; mul_v = 1;
    #5 rst = 0;

    // 普通加法
    aluop_in = `ALUOP_ADD; data1_in = 32'h1; data2_in = 32'h2; wreg_e_in = 1; wreg_addr_in = 5'd1;
    ins_in   = {`OP_RTYPE, 5'd0, 5'd0, 5'd1, 5'd0, `FUNC_ADD};
    #1; check(wreg_data_out==32'h3,"add result");

    // MFHI 前递
    aluop_in = `EXOP_MFHI; hi_in = 32'haaaa0001; mem_hilo_we_in = 1; mem_hi_in = 32'hbbbb0002;
    #1; check(wreg_data_out==32'hbbbb0002,"mfhi forward from mem");

    // 有符号除法触发暂停
    aluop_in = `ALUOP_DIV; data1_in = 32'h10; data2_in = 32'h3; div_v_s = 0;
    #1 div_v_s = 1; div_res_s = 64'h0000_0002_0000_0005; // hi=2 lo=5
    #1; check(pause_req==1'b0 && hilo_we_out==1'b1 && hi_out==32'h0000_0002 && lo_out==32'h0000_0005,"div signed write hilo");

    // 乘法
    aluop_in = `ALUOP_MULT; mul_v = 0; data1_in = 3; data2_in = 4;
    #1 mul_v = 1; mul_res = 64'd12;
    #1; check(hilo_we_out && hi_out==0 && lo_out==12,"mul hilo write");
    #3;
    $display("ex TB PASS");
    $finish;
  end
endmodule

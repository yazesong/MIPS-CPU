`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

module mem_tb;
  reg rst;
  reg wreg_e_in;
  reg[`WordRange] wreg_data_in;
  reg[`RegRangeLog2] wreg_addr_in;
  reg hilo_we_in;
  reg[`WordRange] hi_data_in, lo_data_in;
  reg[`ALUOpRange] aluop_in;
  reg[`WordRange] mem_addr_in, mem_store_data_in, mem_read_data_in;
  reg cp0_we_in;
  reg[4:0] cp0_waddr_in;
  reg[`WordRange] cp0_wdata_in;
  reg[`WordRange] mem_pc_in, mem_abn_in, cp0_stat_in, cp0_cause_in, cp0_epc_in;

  wire wreg_e_out;
  wire[`WordRange] wreg_data_out;
  wire[`RegRangeLog2] wreg_addr_out;
  wire hilo_we_out;
  wire[`WordRange] hi_data_out, lo_data_out;
  wire[`WordRange] mem_addr_out, mem_store_data_out;
  wire mem_we_out, mem_e_out;
  wire[3:0] mem_byte_sel_out;
  wire cp0_we_out;
  wire[4:0] cp0_waddr_out;
  wire[`WordRange] cp0_wdata_out;
  wire[`WordRange] mem_abn_out, mem_pc_out;

  task check;
    input cond;
    input [256*8-1:0] msg;
    begin
      if(!cond) begin $display("FAIL %s", msg); $fatal; end
      else $display("PASS %s", msg);
    end
  endtask

  mem dut(
    .rst(rst),
    .wreg_e_in(wreg_e_in), .wreg_data_in(wreg_data_in), .wreg_addr_in(wreg_addr_in),
    .wreg_e_out(wreg_e_out), .wreg_data_out(wreg_data_out), .wreg_addr_out(wreg_addr_out),
    .hilo_we_in(hilo_we_in), .hi_data_in(hi_data_in), .lo_data_in(lo_data_in),
    .hilo_we_out(hilo_we_out), .hi_data_out(hi_data_out), .lo_data_out(lo_data_out),
    .aluop_in(aluop_in), .mem_addr_in(mem_addr_in), .mem_store_data_in(mem_store_data_in),
    .mem_read_data_in(mem_read_data_in),
    .mem_addr_out(mem_addr_out), .mem_store_data_out(mem_store_data_out),
    .mem_we_out(mem_we_out), .mem_byte_sel_out(mem_byte_sel_out), .mem_e_out(mem_e_out),
    .cp0_we_in(cp0_we_in), .cp0_waddr_in(cp0_waddr_in), .cp0_wdata_in(cp0_wdata_in),
    .cp0_we_out(cp0_we_out), .cp0_waddr_out(cp0_waddr_out), .cp0_wdata_out(cp0_wdata_out),
    .current_mem_pc_addr_in(mem_pc_in), .abnormal_type_in(mem_abn_in),
    .cp0_status_in(cp0_stat_in), .cp0_cause_in(cp0_cause_in), .cp0_epc_in(cp0_epc_in),
    .abnormal_type_out(mem_abn_out), .current_mem_pc_addr_out(mem_pc_out)
  );

  initial begin
    rst=1; wreg_e_in=0; wreg_data_in=0; wreg_addr_in=0;
    hilo_we_in=0; hi_data_in=0; lo_data_in=0;
    aluop_in=`ALUOP_NOP; mem_addr_in=0; mem_store_data_in=0; mem_read_data_in=32'hCAFEBABE;
    cp0_we_in=0; cp0_waddr_in=0; cp0_wdata_in=0;
    mem_pc_in=0; mem_abn_in=0; cp0_stat_in=32'h1; cp0_cause_in=0; cp0_epc_in=0;
    #5 rst=0;

    // LW
    aluop_in = `EXOP_LW;
    mem_addr_in = 32'h8000_0004;
    mem_read_data_in = 32'hAABB_CCDD;
    #1;
    check(wreg_data_out==32'hAABB_CCDD && mem_we_out==0 && mem_e_out==1 && mem_byte_sel_out==4'b1111, "LW read");
    // LB
    aluop_in = `EXOP_LB;
    mem_addr_in = 32'h8000_0001;
    mem_read_data_in = 32'h0000_00FF;
    #1;
    check(wreg_data_out[7:0]==8'hFF && wreg_data_out[31]==1'b1 && mem_byte_sel_out==4'b0010, "LB sign");
    // LBU
    aluop_in = `EXOP_LBU;
    mem_addr_in = 32'h8000_0003;
    mem_read_data_in = 32'hFF00_0000;
    #1;
    check(wreg_data_out==32'h0000_00FF && mem_byte_sel_out==4'b1000, "LBU zero extend");
    // LH
    aluop_in = `EXOP_LH;
    mem_addr_in = 32'h8000_0002;
    mem_read_data_in = 32'h8001_0000;
    #1;
    check(wreg_data_out[31]==1'b1 && mem_byte_sel_out==4'b1100, "LH sign");
    // LHU
    aluop_in = `EXOP_LHU;
    mem_addr_in = 32'h8000_0000;
    mem_read_data_in = 32'h0000_8001;
    #1;
    check(wreg_data_out==32'h0000_8001 && mem_byte_sel_out==4'b0011, "LHU zero extend");
    // SH
    aluop_in = `EXOP_SH;
    mem_addr_in = 32'h8000_0002;
    mem_store_data_in = 32'h1122_3344;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b1100, "SH write");
    // SB
    aluop_in = `EXOP_SB;
    mem_addr_in = 32'h8000_0001;
    mem_store_data_in = 32'hFFFF_FFEE;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b0010, "SB write");
    // SW
    aluop_in = `EXOP_SW;
    mem_addr_in = 32'h8000_0008;
    mem_store_data_in = 32'h5566_7788;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b1111, "SW write");
    // 异常输入
    mem_abn_in = 32'h0000_0400;
    mem_pc_in = 32'h100;
    cp0_stat_in[0] = 1'b1;
    cp0_cause_in[13:8] = 6'h3;
    #2;
    check(mem_abn_out!=0 && mem_pc_out==32'h100, "exception pass");
    $display("mem TB PASS");
    $finish;
  end
endmodule

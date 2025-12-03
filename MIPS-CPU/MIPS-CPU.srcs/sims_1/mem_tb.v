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
    // LB：按 addr[1:0] 选字节，这里选最低字节并检查符号扩展
    aluop_in = `EXOP_LB;
    mem_addr_in = 32'h8000_0000;      // addr[1:0]=2'b00 -> 取 [7:0]
    mem_read_data_in = 32'h0000_00FF; // [7:0]=0xFF
    #1;
    check(wreg_data_out == 32'hFFFF_FFFF && mem_byte_sel_out==4'b0001, "LB sign");
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
    // 异常输入（中断使能时传递）
    mem_abn_in = 32'h0000_0400;
    mem_pc_in = 32'h100;
    cp0_stat_in[0] = 1'b1;
    cp0_cause_in[13:8] = 6'h3;
    #2;
    check(mem_abn_out!=0 && mem_pc_out==32'h100, "exception pass");

    // ========== 补充测试：数据透传（非访存指令）==========
    aluop_in = `ALUOP_NOP;  // 非访存操作
    wreg_e_in = 1'b1;
    wreg_data_in = 32'h1234_5678;
    wreg_addr_in = 5'd10;
    mem_read_data_in = 32'hDEAD_BEEF;  // 不应该影响结果
    #1;
    check(wreg_e_out && wreg_data_out==32'h1234_5678 && wreg_addr_out==5'd10, "ALU data passthrough");
    check(mem_e_out==0, "ALU no mem access");

    // ========== 补充测试：HI/LO 透传 ==========
    wreg_e_in = 0;
    hilo_we_in = 1'b1;
    hi_data_in = 32'hAAAA_AAAA;
    lo_data_in = 32'hBBBB_BBBB;
    aluop_in = `ALUOP_NOP;
    #1;
    check(hilo_we_out && hi_data_out==32'hAAAA_AAAA && lo_data_out==32'hBBBB_BBBB, "HILO passthrough");

    // ========== 补充测试：CP0 透传 ==========
    hilo_we_in = 0;
    cp0_we_in = 1'b1;
    cp0_waddr_in = 5'd12;  // Status 寄存器
    cp0_wdata_in = 32'h0000_0001;
    aluop_in = `ALUOP_NOP;
    #1;
    check(cp0_we_out && cp0_waddr_out==5'd12 && cp0_wdata_out==32'h0000_0001, "CP0 passthrough");

    // ========== 补充测试：异常屏蔽（status[0]=0）==========
    cp0_we_in = 0;
    mem_abn_in = 32'h0000_0400;  // 有异常
    mem_pc_in = 32'h200;
    cp0_stat_in[0] = 1'b0;  // 中断被屏蔽
    #1;
    check(mem_abn_out==0, "exception masked when status[0]=0");

    // ========== 补充测试：ERET 不被屏蔽 ==========
    // ERET 异常类型编码：abnormal_type[6:2] = ABN_ERET (5'b01111)
    mem_abn_in = {16'h0, 6'h0, 1'b0, `ABN_ERET, 2'b00};  // bit[6:2]=01111
    mem_pc_in = 32'h300;
    cp0_stat_in[0] = 1'b0;  // 即使屏蔽，ERET 也应传递
    cp0_cause_in = 32'h0;
    #1;
    check(mem_abn_out!=0, "ERET not masked even when status[0]=0");
    check(mem_pc_out==32'h300, "ERET PC correct");

    // ========== 补充测试：LB 所有字节对齐情况 ==========
    // addr[1:0] = 2'b00 -> 字节 [7:0]
    aluop_in = `EXOP_LB;
    mem_addr_in = 32'h8000_0000;
    mem_read_data_in = 32'h0000_00AA;  // [7:0]=0xAA (负数)
    #1;
    check(wreg_data_out==32'hFFFF_FFAA && mem_byte_sel_out==4'b0001, "LB addr[1:0]=00");

    // addr[1:0] = 2'b01 -> 字节 [15:8]
    mem_addr_in = 32'h8000_0001;
    mem_read_data_in = 32'h0000_BB00;  // [15:8]=0xBB (负数)
    #1;
    check(wreg_data_out==32'hFFFF_FFBB && mem_byte_sel_out==4'b0010, "LB addr[1:0]=01");

    // addr[1:0] = 2'b10 -> 字节 [23:16]
    mem_addr_in = 32'h8000_0002;
    mem_read_data_in = 32'h00CC_0000;  // [23:16]=0xCC (负数)
    #1;
    check(wreg_data_out==32'hFFFF_FFCC && mem_byte_sel_out==4'b0100, "LB addr[1:0]=10");

    // addr[1:0] = 2'b11 -> 字节 [31:24]
    mem_addr_in = 32'h8000_0003;
    mem_read_data_in = 32'hDD00_0000;  // [31:24]=0xDD (负数)
    #1;
    check(wreg_data_out==32'hFFFF_FFDD && mem_byte_sel_out==4'b1000, "LB addr[1:0]=11");

    // ========== 补充测试：LBU 所有字节对齐（零扩展）==========
    aluop_in = `EXOP_LBU;
    // addr[1:0] = 2'b00
    mem_addr_in = 32'h8000_0000;
    mem_read_data_in = 32'h0000_00EE;  // [7:0]=0xEE
    #1;
    check(wreg_data_out==32'h0000_00EE && mem_byte_sel_out==4'b0001, "LBU addr[1:0]=00 zero extend");

    // addr[1:0] = 2'b01
    mem_addr_in = 32'h8000_0001;
    mem_read_data_in = 32'h0000_FF00;  // [15:8]=0xFF
    #1;
    check(wreg_data_out==32'h0000_00FF && mem_byte_sel_out==4'b0010, "LBU addr[1:0]=01 zero extend");

    // ========== 补充测试：LH 两种对齐情况 ==========
    aluop_in = `EXOP_LH;
    // addr[1] = 0 -> 低半字 [15:0]
    mem_addr_in = 32'h8000_0000;
    mem_read_data_in = 32'h0000_8765;  // [15:0]=0x8765 (负数)
    #1;
    check(wreg_data_out==32'hFFFF_8765 && mem_byte_sel_out==4'b0011, "LH addr[1]=0 sign extend");

    // addr[1] = 1 -> 高半字 [31:16]
    mem_addr_in = 32'h8000_0002;
    mem_read_data_in = 32'h9ABC_0000;  // [31:16]=0x9ABC (负数)
    #1;
    check(wreg_data_out==32'hFFFF_9ABC && mem_byte_sel_out==4'b1100, "LH addr[1]=1 sign extend");

    // ========== 补充测试：LHU 两种对齐（零扩展）==========
    aluop_in = `EXOP_LHU;
    // addr[1] = 0
    mem_addr_in = 32'h8000_0000;
    mem_read_data_in = 32'h0000_FEDC;
    #1;
    check(wreg_data_out==32'h0000_FEDC && mem_byte_sel_out==4'b0011, "LHU addr[1]=0 zero extend");

    // addr[1] = 1
    mem_addr_in = 32'h8000_0002;
    mem_read_data_in = 32'hBA98_0000;
    #1;
    check(wreg_data_out==32'h0000_BA98 && mem_byte_sel_out==4'b1100, "LHU addr[1]=1 zero extend");

    // ========== 补充测试：SB 所有字节对齐情况 ==========
    aluop_in = `EXOP_SB;
    // addr[1:0] = 2'b00 -> 写入字节 [7:0]
    mem_addr_in = 32'h8000_0000;
    mem_store_data_in = 32'hFFFF_FF11;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b0001, "SB addr[1:0]=00");

    // addr[1:0] = 2'b01 -> 写入字节 [15:8]
    mem_addr_in = 32'h8000_0001;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b0010, "SB addr[1:0]=01");

    // addr[1:0] = 2'b10 -> 写入字节 [23:16]
    mem_addr_in = 32'h8000_0002;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b0100, "SB addr[1:0]=10");

    // addr[1:0] = 2'b11 -> 写入字节 [31:24]
    mem_addr_in = 32'h8000_0003;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b1000, "SB addr[1:0]=11");

    // ========== 补充测试：SH 两种对齐情况 ==========
    aluop_in = `EXOP_SH;
    // addr[1] = 0 -> 写入低半字 [15:0]
    mem_addr_in = 32'h8000_0000;
    mem_store_data_in = 32'h5678_1234;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b0011, "SH addr[1]=0");

    // addr[1] = 1 -> 写入高半字 [31:16]
    mem_addr_in = 32'h8000_0002;
    #1;
    check(mem_we_out==1 && mem_byte_sel_out==4'b1100, "SH addr[1]=1");

    // ========== 补充测试：复位清零 ==========
    rst = 1;
    wreg_e_in = 1;
    hilo_we_in = 1;
    cp0_we_in = 1;
    aluop_in = `EXOP_LW;
    #1;
    check(wreg_e_out==0 && hilo_we_out==0 && cp0_we_out==0 && mem_e_out==0, "reset clears all outputs");
    rst = 0;

    // ========== 补充测试：异常 PC 为 0 时不传递 ==========
    mem_abn_in = 32'h0000_0400;
    mem_pc_in = 32'h0;  // PC 为 0
    cp0_stat_in[0] = 1'b1;
    aluop_in = `ALUOP_NOP;
    #1;
    check(mem_abn_out==0 && mem_pc_out==0, "no exception when PC=0");

    // ========== 所有测试完成 ==========
    $display("============================================");
    $display("===== MEM 阶段测试全部通过 =====");
    $display("============================================");
    $finish;
  end
endmodule

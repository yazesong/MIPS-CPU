`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

module id_ex_tb;
  reg clk, rst, pause, flush;
  reg[`ALUOpRange] id_aluop;
  reg[`WordRange]  id_data1, id_data2;
  reg              id_wreg_e;
  reg[`RegRangeLog2] id_wreg_addr;
  reg[`WordRange]  id_link_addr;
  reg              id_in_delayslot;
  reg              id_next_in_delayslot;
  reg[`WordRange]  id_ins;
  reg[`WordRange]  id_pc, id_abn;

  wire[`ALUOpRange] ex_aluop;
  wire[`WordRange]  ex_data1, ex_data2;
  wire              ex_wreg_e;
  wire[`RegRangeLog2] ex_wreg_addr;
  wire[`WordRange]  ex_link_addr;
  wire              ex_in_delayslot;
  wire              ex_next_in_delayslot;
  wire[`WordRange]  ex_ins;
  wire[`WordRange]  ex_pc, ex_abn;

  // clk
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task check;
    input cond;
    input [256*8-1:0] msg;
    begin
      if (!cond) begin
        $display("FAIL %s", msg);
        $fatal;
      end else begin
        $display("PASS %s", msg);
      end
    end
  endtask

  id_ex dut(
    .clk(clk), .rst(rst),
    .id_aluop(id_aluop), .id_data1(id_data1), .id_data2(id_data2),
    .id_wreg_addr(id_wreg_addr), .id_wreg_e(id_wreg_e),
    .id_link_addr(id_link_addr),
    .id_in_delayslot(id_in_delayslot), .id_next_in_delayslot(id_next_in_delayslot),
    .id_ins(id_ins),
    .f_id_current_pc_addr_in(id_pc), .f_id_abnormal_type_in(id_abn),
    .pause(pause), .flush(flush),
    .ex_aluop(ex_aluop), .ex_data1(ex_data1), .ex_data2(ex_data2),
    .ex_wreg_e(ex_wreg_e), .ex_wreg_addr(ex_wreg_addr), .ex_link_addr(ex_link_addr),
    .ex_in_delayslot(ex_in_delayslot), .ex_next_in_delayslot(ex_next_in_delayslot),
    .ex_ins(ex_ins), .t_ex_current_pc_addr_out(ex_pc), .t_ex_abnormal_type_out(ex_abn)
  );

  initial begin
    // 初始
    rst = 1; pause = 0; flush = 0;
    id_aluop = `ALUOP_NOP; id_data1 = 0; id_data2 = 0;
    id_wreg_e = 0; id_wreg_addr = 0; id_link_addr = 0;
    id_in_delayslot = 0; id_next_in_delayslot = 0;
    id_ins = 0; id_pc = 0; id_abn = 0;
    #12 rst = 0;

    // 正常传递
    @(posedge clk);
    id_aluop = `ALUOP_ADD;
    id_data1 = 32'h1;
    id_data2 = 32'h2;
    id_wreg_e = 1'b1;
    id_wreg_addr = 5'd10;
    id_link_addr = 32'h100;
    id_in_delayslot = 1'b1;
    id_next_in_delayslot = 1'b0;
    id_ins = 32'h12345678;
    id_pc = 32'h3000_0000;
    id_abn = 32'h8;
    @(posedge clk);
    check(ex_aluop == `ALUOP_ADD, "latch aluop");
    check(ex_data1 == 32'h1 && ex_data2 == 32'h2, "latch data");
    check(ex_wreg_e && ex_wreg_addr == 5'd10, "latch wreg");
    check(ex_link_addr == 32'h100, "latch link");
    check(ex_in_delayslot && !ex_next_in_delayslot, "latch delay flags");
    check(ex_ins == 32'h12345678 && ex_pc == 32'h3000_0000 && ex_abn == 32'h8, "latch misc");

    // pause 保持
    pause = 1'b1;
    id_data1 = 32'hdead_beef;
    @(posedge clk);
    check(ex_data1 == 32'h1, "pause holds");
    pause = 1'b0;

    // flush 清泡
    flush = 1'b1;
    @(posedge clk);
    check(ex_aluop == `ALUOP_NOP && ex_wreg_e == 1'b0 && ex_ins == `ZeroWord, "flush clears");
    flush = 1'b0;

    // 复位再检查
    rst = `Enable;
    @(posedge clk);
    check(ex_aluop == `ALUOP_NOP && ex_wreg_e == 1'b0, "reset clears");
    rst = `Disable;

    $display("id_ex TB PASS");
    $finish;
  end
endmodule

`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

module pipeline_tb;
  reg rst;
  reg pause_req_id, pause_req_ex;
  reg[`WordRange] abnormal_type, epc;
  wire pause_res_pc, pause_res_if, pause_res_id, pause_res_ex, pause_res_mem, pause_res_wb;
  wire flush;
  wire[`WordRange] interrupt_pc_out;

  task check;
    input cond;
    input [256*8-1:0] msg;
    begin
      if(!cond) begin $display("FAIL %s", msg); $fatal; end
      else $display("PASS %s", msg);
    end
  endtask

  pipeline dut(
    .rst(rst),
    .pause_req_id(pause_req_id),
    .pause_req_ex(pause_req_ex),
    .pause_res_pc(pause_res_pc),
    .pause_res_if(pause_res_if),
    .pause_res_id(pause_res_id),
    .pause_res_ex(pause_res_ex),
    .pause_res_mem(pause_res_mem),
    .pause_res_wb(pause_res_wb),
    .abnormal_type(abnormal_type),
    .cp0_epc_in(epc),
    .interrupt_pc_out(interrupt_pc_out),
    .flush(flush)
  );

  initial begin
    rst=1; pause_req_id=0; pause_req_ex=0; abnormal_type=0; epc=32'h1234;
    #5 rst=0;
    // 暂停
    pause_req_id = 1'b1;
    #1;
    pause_req_id = 1'b0;
    check(pause_res_pc && pause_res_if && pause_res_id && pause_res_ex, "pause asserted");

    // 异常：syscall
    abnormal_type = {16'h0, 6'd0, 1'b0, `ABN_SYSTEMCALL, 2'b00};
    #1;
    check(flush && interrupt_pc_out==32'h0000F000, "syscall flush");
    abnormal_type = 0;

    // 异常：overflow
    abnormal_type = {16'h0, 6'd0, 1'b0, `ABN_OVERFLOW, 2'b00};
    #1;
    check(flush && interrupt_pc_out==32'h0000F000, "overflow flush");
    abnormal_type = 0;

    // ERET
    abnormal_type = {16'h0, 6'd0, 1'b0, `ABN_ERET, 2'b00};
    #1;
    check(flush && interrupt_pc_out==epc, "eret jump");
    abnormal_type = 0;

    $display("pipeline TB PASS");
    $finish;
  end
endmodule

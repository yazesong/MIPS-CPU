`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// CP0 自检：寄存器读写、syscall/eret、timer_int
module cp0_tb;
  reg clk;
  reg rst;
  reg we_in;
  reg [4:0] waddr_in;
  reg [4:0] raddr_in;
  reg [`WordRange] data_in;
  reg [5:0] int_in;
  reg [`WordRange] abnormal_type;
  reg [`WordRange] current_pc;
  wire [`WordRange] data_out;
  wire [`WordRange] count_out;
  wire [`WordRange] compare_out;
  wire [`WordRange] status_out;
  wire [`WordRange] cause_out;
  wire [`WordRange] epc_out;
  wire [`WordRange] config_out;
  wire timer_int_o;

  cp0 dut(
    .clk(clk),
    .rst(rst),
    .we_in(we_in),
    .waddr_in(waddr_in),
    .data_in(data_in),
    .raddr_in(raddr_in),
    .int_in(int_in),
    .data_out(data_out),
    .count_out(count_out),
    .compare_out(compare_out),
    .status_out(status_out),
    .cause_out(cause_out),
    .epc_out(epc_out),
    .config_out(config_out),
    .timer_int_o(timer_int_o),
    .abnormal_type(abnormal_type),
    .current_pc_addr_in(current_pc)
  );

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

  initial begin
    rst = `Enable;
    we_in = `Disable;
    waddr_in = 0;
    raddr_in = 0;
    data_in = 0;
    int_in = 0;
    abnormal_type = 0;
    current_pc = 0;
    @(posedge clk);
    rst = `Disable;

    // 写 COUNT / COMPARE
    we_in = `Enable;
    waddr_in = `CP0_REG_COUNT;
    data_in = 32'h0000_0010;
    @(posedge clk);
    waddr_in = `CP0_REG_COMPARE;
    data_in = 32'h0000_0014;
    @(posedge clk);
    check(compare_out == 32'h0000_0014, "write compare");

    // SYS call 异常
    abnormal_type = {16'h0, 6'd0, 1'b0, `ABN_SYSTEMCALL, 2'b00};
    current_pc = 32'h8000_0100;
    @(posedge clk);
    check(status_out[0] == 1'b0, "syscall mask int");
    check(epc_out == 32'h8000_0100, "syscall epc");
    abnormal_type = 0;

    // ERET
    abnormal_type = {16'h0, 6'd0, 1'b0, `ABN_ERET, 2'b00};
    @(posedge clk);
    check(status_out[0] == 1'b1, "eret enable int");
    check(epc_out == 32'h0, "eret clear epc");
    abnormal_type = 0;

    // 触发 timer_int：count==compare
    repeat(20) @(posedge clk);
    check(timer_int_o == `Enable, "timer interrupt");

    // 异步读
    raddr_in = `CP0_REG_STATUE;
    #1;
    check(data_out == status_out, "read status");

    $display("cp0 TB PASS");
    $finish;
  end
endmodule

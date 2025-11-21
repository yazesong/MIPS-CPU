`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// gpr 时序/前递 自检 tb
module gpr_tb;
  reg clk;
  reg rst;
  reg we;
  reg [`RegRangeLog2] waddr;
  reg [`WordRange]    wdata;
  reg re1, re2;
  reg [`RegRangeLog2] raddr1, raddr2;
  wire[`WordRange]    rdata1, rdata2;

  gpr dut(
    .rst(rst), .clk(clk),
    .we(we), .waddr(waddr), .wdata(wdata),
    .re1(re1), .raddr1(raddr1), .rdata1(rdata1),
    .re2(re2), .raddr2(raddr2), .rdata2(rdata2)
  );

  // 时钟
  initial clk = 0;
  always #5 clk = ~clk;

  task write_reg;
    input [4:0] addr; input [31:0] data;
    begin
      @(negedge clk);
      we    = `Enable;
      waddr = addr;
      wdata = data;
      @(posedge clk);
      we    = `Disable;
    end
  endtask

  task async_read;
    input enable1; input [4:0] addr1;
    input enable2; input [4:0] addr2;
    begin
      re1    = enable1;
      raddr1 = addr1;
      re2    = enable2;
      raddr2 = addr2;
      #1; // 组合逻辑稳定
    end
  endtask

  initial begin
    // 初始化
    rst   = `Enable;
    we    = `Disable;
    re1   = `Disable;
    re2   = `Disable;
    waddr = 0; wdata = 0; raddr1 = 0; raddr2 = 0;

    @(posedge clk);
    // 复位时读应为 0
    async_read(`Enable, 5'd1, `Enable, 5'd2);
    if (rdata1 !== `ZeroWord || rdata2 !== `ZeroWord) begin
      $display("FAIL reset read not zero");
      $fatal;
    end

    // 解除复位
    rst = `Disable;
    @(posedge clk);

    // 写寄存器 5，再异步读（写入后再等一个上升沿，避免调度差异带来的影响）
    write_reg(5'd5, 32'h1234_5678);
    @(posedge clk);
    async_read(`Enable, 5'd5, `Enable, 5'd5);
    if (rdata1 !== 32'h1234_5678 || rdata2 !== 32'h1234_5678) begin
      $display("FAIL normal write/read");
      $fatal;
    end

    // $0 不可写
    write_reg(5'd0, 32'hFFFF_FFFF);
    @(posedge clk);
    async_read(`Enable, 5'd0, `Enable, 5'd0);
    if (rdata1 !== `ZeroWord || rdata2 !== `ZeroWord) begin
      $display("FAIL $0 protection");
      $fatal;
    end

    // 读使能关闭返回 0
    async_read(`Disable, 5'd5, `Disable, 5'd6);
    if (rdata1 !== `ZeroWord || rdata2 !== `ZeroWord) begin
      $display("FAIL read disable not zero");
      $fatal;
    end

    // 前递：同周期写读同地址
    @(negedge clk);
    we    = `Enable;
    waddr = 5'd6;
    wdata = 32'hDEAD_BEEF;
    re1   = `Enable;
    raddr1= 5'd6;
    #1;
    if (rdata1 !== 32'hDEAD_BEEF) begin
      $display("FAIL bypass on same cycle");
      $fatal;
    end
    @(posedge clk);
    we = `Disable; re1 = `Disable;

    $display("gpr TB PASS");
    $finish;
  end

endmodule

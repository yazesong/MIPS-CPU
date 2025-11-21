`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// IF/ID 流水寄存器 tb
module if_id_tb;
  reg clk;
  reg rst;
  reg pause;
  reg flush;
  reg [`WordRange] if_pc;
  reg [`WordRange] if_ins;
  wire[`WordRange] id_pc;
  wire[`WordRange] id_ins;

  if_id dut(
    .clk(clk), .rst(rst),
    .if_pc(if_pc), .if_ins(if_ins),
    .id_pc(id_pc), .id_ins(id_ins),
    .pause(pause), .flush(flush)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst   = `Enable;
    pause = `Disable;
    flush = `Disable;
    if_pc = 0; if_ins = 0;

    @(posedge clk);
    if (id_pc !== `ZeroWord || id_ins !== `ZeroWord) begin
      $display("FAIL reset clear");
      $fatal;
    end

    rst = `Disable;
    // 正常传递
    if_pc = 32'h3000; if_ins = 32'hDEAD_BEEF;
    @(posedge clk);
    if (id_pc !== 32'h3000 || id_ins !== 32'hDEAD_BEEF) begin
      $display("FAIL pass through");
      $fatal;
    end

    // pause 保持
    pause = `Enable;
    if_pc = 32'h3004; if_ins = 32'hAAAA_5555;
    @(posedge clk);
    if (id_pc !== 32'h3000 || id_ins !== 32'hDEAD_BEEF) begin
      $display("FAIL pause hold");
      $fatal;
    end
    pause = `Disable;

    // flush 清零
    flush = `Enable;
    @(posedge clk);
    if (id_pc !== `ZeroWord || id_ins !== `ZeroWord) begin
      $display("FAIL flush clear");
      $fatal;
    end
    flush = `Disable;

    $display("if_id TB PASS");
    $finish;
  end
endmodule

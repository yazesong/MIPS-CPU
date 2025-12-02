`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// CPU 顶层自检：指令流、分支/跳转、访存、写回
module cpu_tb;
  reg clk;
  reg rst;
  wire[`WordRange] imem_addr;
  wire[`WordRange] imem_data;
  wire imem_en;
  wire[`WordRange] bus_addr;
  wire[`WordRange] bus_wdata;
  wire bus_en;
  wire bus_we;
  wire[3:0] bus_byte_sel;
  wire[`WordRange] bus_rdata;
  wire[5:0] interrupt_in;

  // 简易 ROM/RAM
  reg [31:0] rom [0:63];
  reg [31:0] ram [0:63];
  integer i;

  // CPU 实例
  cpu dut(
    .rst(rst),
    .clk(clk),
    .imem_data_in(imem_data),
    .imem_addr_out(imem_addr),
    .imem_e_out(imem_en),
    .bus_addr_out(bus_addr),
    .bus_write_data_out(bus_wdata),
    .bus_en_out(bus_en),
    .bus_we_out(bus_we),
    .bus_byte_sel_out(bus_byte_sel),
    .bus_read_in(bus_rdata),
    .interrupt_in(interrupt_in)
  );

  assign interrupt_in = 6'b0;

  // ROM 组合读
  assign imem_data = rom[imem_addr[31:2]];

  // RAM 组合读（简单字对齐）
  assign bus_rdata = ram[bus_addr[31:2]];

  // RAM 写，支持 byte enable
  always @(posedge clk) begin
    if (bus_en && bus_we) begin
      if (bus_byte_sel[0]) ram[bus_addr[31:2]][7:0]   <= bus_wdata[7:0];
      if (bus_byte_sel[1]) ram[bus_addr[31:2]][15:8]  <= bus_wdata[15:8];
      if (bus_byte_sel[2]) ram[bus_addr[31:2]][23:16] <= bus_wdata[23:16];
      if (bus_byte_sel[3]) ram[bus_addr[31:2]][31:24] <= bus_wdata[31:24];
    end
  end

  // 时钟
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // 构造指令
  function [31:0] r_ins;
    input [4:0] rs;
    input [4:0] rt;
    input [4:0] rd;
    input [4:0] shamt;
    input [5:0] func;
    begin
      r_ins = {`OP_RTYPE, rs, rt, rd, shamt, func};
    end
  endfunction

  function [31:0] i_ins;
    input [5:0] op;
    input [4:0] rs;
    input [4:0] rt;
    input [15:0] imm;
    begin
      i_ins = {op, rs, rt, imm};
    end
  endfunction

  function [31:0] j_ins;
    input [5:0] op;
    input [25:0] addr;
    begin
      j_ins = {op, addr};
    end
  endfunction

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
    // 初始化 ROM/RAM
    for (i = 0; i < 64; i = i + 1) begin
      rom[i] = 32'h0000_0000;
      ram[i] = 32'h0000_0000;
    end

    // 程序装载
    rom[0]  = i_ins(`OP_ORI, 5'd0, 5'd1, 16'h1234);                 // $1 = 0x1234
    rom[1]  = i_ins(`OP_ADDI,5'd1, 5'd2, 16'h0001);                 // $2 = 0x1235
    rom[2]  = i_ins(`OP_SW,  5'd0, 5'd2, 16'h0000);                 // MEM[0] = $2
    rom[3]  = i_ins(`OP_LW,  5'd0, 5'd3, 16'h0000);                 // $3 = MEM[0]
    rom[4]  = i_ins(`OP_BEQ, 5'd3, 5'd2, 16'h0002);                 // branch to 7 if equal
    rom[5]  = i_ins(`OP_ORI, 5'd0, 5'd4, 16'hDEAD);                 // delay slot, always execute
    rom[6]  = 32'h0000_0000;                                        // skipped if branch taken
    rom[7]  = j_ins(`OP_J, 26'd9);                                  // jump to 9
    rom[8]  = 32'h0000_0000;                                        // delay slot
    rom[9]  = i_ins(`OP_ORI, 5'd0, 5'd5, 16'hABCD);                 // $5 = 0xABCD
    rom[10] = r_ins(5'd5, 5'd1, 5'd6, 5'd0, `FUNC_ADD);             // $6 = $5 + $1
    rom[11] = i_ins(`OP_SW,  5'd0, 5'd6, 16'h0004);                 // MEM[1] = $6
    rom[12] = i_ins(`OP_LW,  5'd0, 5'd7, 16'h0004);                 // $7 = MEM[1]
    rom[13] = 32'h0000_0000;

    // 复位
    rst = `Enable;
    @(posedge clk);
    rst = `Disable;

    // 跑一段时间
    repeat(40) @(posedge clk);

    // 检查寄存器和内存
    check(dut.u_gpr.regs[1] == 32'h0000_1234, "reg1 value");
    check(dut.u_gpr.regs[2] == 32'h0000_1235, "reg2 value");
    check(dut.u_gpr.regs[3] == 32'h0000_1235, "reg3 value");
    check(dut.u_gpr.regs[4] == 32'h0000_DEAD, "reg4 delay slot");
    check(dut.u_gpr.regs[5] == 32'h0000_ABCD, "reg5 ori");
    check(dut.u_gpr.regs[6] == 32'h0000_BE01, "reg6 add");
    check(dut.u_gpr.regs[7] == 32'h0000_BE01, "reg7 load");
    check(ram[0] == 32'h0000_1235, "ram word0");
    check(ram[1] == 32'h0000_BE01, "ram word1");

    $display("cpu TB PASS");
    $finish;
  end
endmodule

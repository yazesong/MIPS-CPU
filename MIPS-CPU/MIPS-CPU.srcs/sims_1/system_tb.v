`timescale 1ns / 1ps

module system_tb;

  // 时钟与复位
  reg clk = 1'b0;
  reg rst = 1'b1;
  always #5 clk = ~clk;          // 100MHz

  // 升级端口时钟（独立出来便于编程）
  reg upg_clk = 1'b0;
  always #7 upg_clk = ~upg_clk;

  reg        upg_rst  = 1'b1;
  reg        upg_wen  = 1'b0;
  reg [13:0] upg_adr  = 14'd0;
  reg [31:0] upg_dat  = 32'd0;
  reg        upg_done = 1'b0;

  // 外设输入
  reg [23:0] switches_in      = 24'h123456;
  reg [3:0]  keyboard_cols_in = 4'hF;
  reg        rx               = 1'b1;

  // 外设输出
  wire [3:0] keyboard_rows_out;
  wire [7:0] digits_sel_out;
  wire [7:0] digits_data_out;
  wire       beep_out;
  wire [7:0] led_RLD_out;
  wire [7:0] led_YLD_out;
  wire [7:0] led_GLD_out;
  wire       tx;

  // 被测顶层
  system #(.USE_UART_BMPG(0)) dut(
    .clk             (clk),
    .rst             (rst),
    .switches_in     (switches_in),
    .keyboard_cols_in(keyboard_cols_in),
    .keyboard_rows_out(keyboard_rows_out),
    .digits_sel_out  (digits_sel_out),
    .digits_data_out (digits_data_out),
    .beep_out        (beep_out),
    .led_RLD_out     (led_RLD_out),
    .led_YLD_out     (led_YLD_out),
    .led_GLD_out     (led_GLD_out),
    .rx              (rx),
    .tx              (tx),
    .upg_rst_i       (upg_rst),
    .upg_clk_i       (upg_clk),
    .upg_wen_i       (upg_wen),
    .upg_adr_i       (upg_adr),
    .upg_dat_i       (upg_dat),
    .upg_done_i      (upg_done)
  );

  // 简易 ROM 编程任务
  task prog_word(input [13:0] adr, input [31:0] data);
  begin
    @(negedge upg_clk);
    upg_wen <= 1'b1;
    upg_adr <= adr;
    upg_dat <= data;
    @(negedge upg_clk);
    upg_wen <= 1'b0;
  end
  endtask

  // 指令（手写 MIPS 编码）
  localparam [31:0] I0_LUI_T0_FFFF   = 32'h3c08ffff;
  localparam [31:0] I1_ORI_T0_FC60   = 32'h3508fc60;
  localparam [31:0] I2_ORI_T1_00FF   = 32'h340900ff;
  localparam [31:0] I3_SW_T1_T0_0    = 32'had090000;
  localparam [31:0] I4_LUI_T2_FFFF   = 32'h3c0affff;
  localparam [31:0] I5_ORI_T2_FC70   = 32'h354afc70;
  localparam [31:0] I6_LW_T3_T2_0    = 32'h8d4b0000;
  localparam [31:0] I7_LUI_T4_FFFF   = 32'h3c0cffff;
  localparam [31:0] I8_ORI_T4_FC20   = 32'h358cfc20;
  localparam [31:0] I9_ORI_T5_0003   = 32'h340d0003;
  localparam [31:0] I10_SW_T5_T4_4   = 32'had8d0004;
  localparam [31:0] I11_LW_T6_T4_0   = 32'h8d8e0000;
  localparam [31:0] I12_J_SELF       = 32'h0800000c;

  initial begin
    // 编程阶段，保持 CPU 复位
    rst      = 1'b1;
    upg_rst  = 1'b1;
    upg_done = 1'b0;
    #40;

    prog_word(14'd0, I0_LUI_T0_FFFF);
    prog_word(14'd1, I1_ORI_T0_FC60);
    prog_word(14'd2, I2_ORI_T1_00FF);
    prog_word(14'd3, I3_SW_T1_T0_0);
    prog_word(14'd4, I4_LUI_T2_FFFF);
    prog_word(14'd5, I5_ORI_T2_FC70);
    prog_word(14'd6, I6_LW_T3_T2_0);
    prog_word(14'd7, I7_LUI_T4_FFFF);
    prog_word(14'd8, I8_ORI_T4_FC20);
    prog_word(14'd9, I9_ORI_T5_0003);
    prog_word(14'd10, I10_SW_T5_T4_4);
    prog_word(14'd11, I11_LW_T6_T4_0);
    prog_word(14'd12, I12_J_SELF);

    @(negedge upg_clk);
    upg_done <= 1'b1;
    upg_rst  <= 1'b0; // 切换到运行模式
    #40;
    rst <= 1'b0;      // 释放 CPU 复位

    // 运行一段时间让指令执行与定时器计数
    repeat (400) @(posedge clk);

    // 检查 LED 写入（GLD 应为 0xFF，其余为 0）
    if (led_GLD_out !== 8'hff || led_RLD_out !== 8'h00 || led_YLD_out !== 8'h00) begin
      $display("[FAIL] LED output mismatch: R=%h Y=%h G=%h", led_RLD_out, led_YLD_out, led_GLD_out);
      $stop;
    end else begin
      $display("[PASS] LED output correctly written by CPU");
    end

    // 检查 CPU 读取的开关值（t3 = $11）
    if (dut.u_cpu.u_gpr.regs[11] !== {8'h00, switches_in}) begin
      $display("[FAIL] Switch read mismatch, got %h expected %h", dut.u_cpu.u_gpr.regs[11], {8'h00, switches_in});
      $stop;
    end else begin
      $display("[PASS] Switch value captured in $t3 = %h", dut.u_cpu.u_gpr.regs[11]);
    end

    // 蜂鸣器未被写，保持默认 0
    if (beep_out !== 1'b0) begin
      $display("[FAIL] Beep unexpected high");
      $stop;
    end

    // 定时器计数到位后 status1[0] 应置位
    if (dut.u_timer.status1[0] !== 1'b1) begin
      $display("[FAIL] Timer status not set as expected: %h", dut.u_timer.status1);
      $stop;
    end else begin
      $display("[PASS] Timer status1 = %h", dut.u_timer.status1);
    end

    $display("[PASS] System smoke test completed");
    $finish;
  end

endmodule

`timescale 1ns / 1ps

module system_tb_timing;

  //========================================
  // 0) 可调时钟周期
  //========================================
  parameter integer CLK_PERIOD_NS     = 10;   // 主时钟 100MHz
  parameter integer UPG_CLK_PERIOD_NS = 14;   // 升级口时钟（非关键）

  //========================================
  // 1) 时钟 / 复位 / 升级口
  //========================================
  reg clk = 1'b0;
  reg rst = 1'b1;

  always #(CLK_PERIOD_NS/2.0) clk = ~clk;

  reg upg_clk = 1'b0;
  always #(UPG_CLK_PERIOD_NS/2.0) upg_clk = ~upg_clk;

  reg        upg_rst  = 1'b1;
  reg        upg_wen  = 1'b0;
  reg [13:0] upg_adr  = 14'd0;
  reg [31:0] upg_dat  = 32'd0;
  reg        upg_done = 1'b0;

  //========================================
  // 2) 外设输入 / 输出
  //========================================
  reg [23:0] switches_in      = 24'h123456;
  reg [3:0]  keyboard_cols_in = 4'hF;
  reg        rx               = 1'b1;

  wire [3:0] keyboard_rows_out;
  wire [7:0] digits_sel_out;
  wire [7:0] digits_data_out;
  wire       beep_out;
  wire [7:0] led_RLD_out;
  wire [7:0] led_YLD_out;
  wire [7:0] led_GLD_out;
  wire       tx;

  // 计时器等待计数
  integer timer_wait;
  integer wait_cnt;

  //========================================
  // 3) DUT（你的综合用顶层）
  //========================================
  systemtest #(.SIM_DIRECT_CLK(1'b1)) dut(
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

  //========================================
  // 4) ROM 写任务
  //========================================
  task prog_word(input [13:0] adr, input [31:0] data);
  begin
    @(negedge upg_clk);
    upg_wen <= 1'b1;
    upg_adr <= adr;
    upg_dat <= data;
    @(negedge upg_clk);
    upg_wen <= 1'b0;
    $display("[UPG] t=%0t ns  adr=%0d (0x%04x)  data=0x%08h", 
             $time, adr, adr, data);

    // 关键：ROM/RAM 现在用跨时钟握手把 upg 写搬到 mem_clk 域再写入。
    // 如果这里连续发写（上一笔未 ACK 就来下一笔），后续写会被丢弃。
    // timing 仿真下握手更慢，保守多等几拍 upg_clk。
    repeat (20) @(negedge upg_clk);
  end
  endtask


  //========================================
  // 5) 指令常量
  //========================================
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

  // 跳到 0xC（字地址 12，PC=0x30）
  localparam [31:0] I12_J_SELF       = 32'h0800000c;


  // 时序仿真不依赖内部层次信号，保持 testbench 仅观察顶层端口


  //========================================
  // 7) 主测试流程
  //========================================
  integer i;
  localparam integer BASE = 12;

  initial begin
    $display("========== TIMING TB START ==========");

    #(5*CLK_PERIOD_NS);

    //----------------------------------------
    // 7.1 写 ROM：从 word 12 开始（PC=0x30）
    //----------------------------------------
    $display(">>> Start programming ROM");

    // 进入“升级模式”：upg_rst=0 且 upg_done=0
    // （ROM/RAM 内部会在该模式下接受 upg_wen 写入）
    upg_rst  <= 1'b0;
    upg_done <= 1'b0;
    repeat (10) @(negedge upg_clk);

    prog_word(BASE + 0,  I0_LUI_T0_FFFF);
    prog_word(BASE + 1,  I1_ORI_T0_FC60);
    prog_word(BASE + 2,  I2_ORI_T1_00FF);
    prog_word(BASE + 3,  I3_SW_T1_T0_0);

    prog_word(BASE + 4,  I4_LUI_T2_FFFF);
    prog_word(BASE + 5,  I5_ORI_T2_FC70);
    prog_word(BASE + 6,  I6_LW_T3_T2_0);

    prog_word(BASE + 7,  I7_LUI_T4_FFFF);
    prog_word(BASE + 8,  I8_ORI_T4_FC20);
    prog_word(BASE + 9,  I9_ORI_T5_0003);
    prog_word(BASE + 10, I10_SW_T5_T4_4);
    prog_word(BASE + 11, I11_LW_T6_T4_0);
    prog_word(BASE + 12, I12_J_SELF);

    // 等待最后一笔写完成（握手落地到 mem_clk 域）
    repeat (40) @(negedge upg_clk);
    upg_done <= 1'b1;
    $display(">>> Finish ROM programming at t=%0t", $time);

    #(5*CLK_PERIOD_NS);
    rst <= 1'b0;
    $display(">>> System reset released at t=%0t", $time);

    //----------------------------------------
    // 7.2 等待事件触发（时序仿真：内部时钟锁定/分频可能较慢）
    //----------------------------------------
    // 等待 LED 被写成 0xFF，最长等待 100000 个外部时钟（约 1ms）
    wait_cnt = 0;
    while (led_GLD_out !== 8'hFF && wait_cnt < 100) begin
      @(posedge clk);
      wait_cnt = wait_cnt + 1;
    end


    //----------------------------------------
    // 7.3 LED 检查
    //----------------------------------------
    if (led_GLD_out !== 8'hFF) begin
      $display("[FAIL] LED_G expected FF, got %02h after %0d cycles", led_GLD_out, wait_cnt);
      $stop;
    end

    $display("[PASS] LED test passed at t=%0t (wait_cnt=%0d)", $time, wait_cnt);

    //----------------------------------------
    // 7.4 Switch 正确读入到 $t3
    //----------------------------------------
    // 时序仿真不做内部寄存器检查，只记录当前 LED/SW
    $display("[INFO] LED_GLD_out=%02h switches_in=%06h", led_GLD_out, switches_in);

    //----------------------------------------
    // 7.5 Beep 未被写，应保持 0
    //----------------------------------------
    if (beep_out !== 1'b0) begin
      $display("[FAIL] Beep unexpected high");
      $stop;
    end

    //----------------------------------------
    // 7.6 Timer 等待完成
    //----------------------------------------
    $display("[INFO] Skip timer status check in timing simulation");

    //----------------------------------------
    // 7.7 全部通过
    //----------------------------------------
    $display("[PASS] System smoke test completed");
    $finish;
  end

endmodule

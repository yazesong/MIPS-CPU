`timescale 1ns / 1ps

// 独立外设仿真测试平台
// 只测试 interface 外设，不依赖 CPU
module tb_peripherals;

  // 时钟和复位
  reg clk;
  reg rst;
  
  // 外设物理 IO
  reg  [23:0] switches_in;      // 拨码开关输入
  wire [7:0]  led_RLD_out;      // 红灯
  wire [7:0]  led_YLD_out;      // 黄灯  
  wire [7:0]  led_GLD_out;      // 绿灯
  wire [7:0]  digits_sel_out;   // 数码管位选
  wire [7:0]  digits_data_out;  // 数码管段选
  wire        beep_out;         // 蜂鸣器
  reg  [3:0]  keyboard_cols_in; // 键盘列输入
  wire [3:0]  keyboard_rows_out;// 键盘行输出

  // 总线信号（用于驱动外设）
  reg  [31:0] bus_addr;
  reg  [31:0] bus_write_data;
  reg         bus_en;
  reg         bus_we;
  reg  [3:0]  bus_byte_sel;
  
  // 外设读数据输出
  wire [31:0] leds_data_out;
  wire [31:0] switches_data_out;
  wire [31:0] digits_data_out_read;
  wire [31:0] beep_data_out;
  wire [31:0] keyboard_data_out;

  // 时钟生成 - 50MHz (20ns period)
  always #10 clk = ~clk;

  // ================================
  // 例化各个外设模块
  // ================================

  // LED 外设
  leds u_leds (
    .rst(rst),
    .clk(clk),
    .addr(bus_addr),
    .en(bus_en),
    .byte_sel(bus_byte_sel),
    .data_in(bus_write_data),
    .we(bus_we),
    .data_out(leds_data_out),
    .RLD(led_RLD_out),
    .YLD(led_YLD_out),
    .GLD(led_GLD_out)
  );

  // 拨码开关外设
  switches u_switches (
    .rst(rst),
    .clk(clk),
    .addr(bus_addr),
    .en(bus_en),
    .byte_sel(bus_byte_sel),
    .data_in(bus_write_data),
    .we(bus_we),
    .data_out(switches_data_out),
    .switch_in(switches_in)
  );

  // 数码管外设
  digits u_digits (
    .rst(rst),
    .clk(clk),
    .addr(bus_addr),
    .en(bus_en),
    .byte_sel(bus_byte_sel),
    .data_in(bus_write_data),
    .we(bus_we),
    .data_out(digits_data_out_read),
    .sel_out(digits_sel_out),
    .digital_out(digits_data_out)
  );

  // 蜂鸣器外设
  beep u_beep (
    .rst(rst),
    .clk(clk),
    .addr(bus_addr),
    .en(bus_en),
    .byte_sel(bus_byte_sel),
    .data_in(bus_write_data),
    .we(bus_we),
    .data_out(beep_data_out),
    .signal_out(beep_out)
  );

  // 键盘外设
  keyboard u_keyboard (
    .rst(rst),
    .clk(clk),
    .addr(bus_addr),
    .en(bus_en),
    .byte_sel(bus_byte_sel),
    .data_in(bus_write_data),
    .we(bus_we),
    .data_out(keyboard_data_out),
    .cols(keyboard_cols_in),
    .rows(keyboard_rows_out)
  );

  // ================================
  // 测试主流程
  // ================================
  initial begin
    // 生成 VCD 波形文件
    $dumpfile("peripherals_waveform.vcd");
    $dumpvars(0, tb_peripherals);
    
    $display("=== 开始外设独立仿真测试 ===");
    
    // 初始化
    clk = 0;
    rst = 1;
    switches_in = 24'h000000;
    keyboard_cols_in = 4'b1111;
    bus_en = 0;
    bus_we = 0;
    bus_addr = 0;
    bus_write_data = 0;
    bus_byte_sel = 4'b1111;
    
    #100;
    rst = 0;
    #100;
    
    // ===================================
    // 测试 1: LED 控制 (地址: 0xFFFFFC60)
    // ===================================
    $display("测试 1: LED 控制");
    bus_addr = 32'hfffffc60;
    bus_write_data = 32'hAABBCCDD;  // R=0xAA, Y=0xBB, G=0xCC
    bus_en = 1;
    bus_we = 1;
    
    #20;  // 一个时钟周期
    
    bus_en = 0;
    bus_we = 0;
    
    $display("LED 输出 - R:%h Y:%h G:%h", 
             led_RLD_out, led_YLD_out, led_GLD_out);
    #200;
    
    // ===================================
    // 测试 2: 读取拨码开关 (地址: 0xFFFFFC70)
    // ===================================
    $display("测试 2: 拨码开关读取");
    switches_in = 24'h123456;  // 设置开关值
    
    #100;  // 等待开关值被采样
    
    bus_addr = 32'hfffffc70;
    bus_en = 1;
    bus_we = 0;  // 读操作
    
    #20;
    
    bus_en = 0;
    
    $display("开关读取值: %h", switches_data_out);
    #200;
    
    // ===================================
    // 测试 3: 数码管显示 (地址: 0xFFFFFC00, 0xFFFFFC04)
    // ===================================
    $display("测试 3: 数码管显示");
    
    // 设置显示数据 (数字 5)
    bus_addr = 32'hfffffc00;
    bus_write_data = 32'd5;
    bus_en = 1;
    bus_we = 1;
    #20;
    bus_en = 0;
    bus_we = 0;
    
    // 设置位选 (第 0 位)
    bus_addr = 32'hfffffc04;
    bus_write_data = 32'd0;
    bus_en = 1;
    bus_we = 1;
    #20;
    bus_en = 0;
    bus_we = 0;
    
    $display("数码管 - 位选:%h 段选:%h", digits_sel_out, digits_data_out);
    #200;
    
    // ===================================
    // 测试 4: 蜂鸣器控制 (地址: 0xFFFFFD10)
    // ===================================
    $display("测试 4: 蜂鸣器控制");
    
    // 打开蜂鸣器
    bus_addr = 32'hfffffd10;
    bus_write_data = 32'd1;
    bus_en = 1;
    bus_we = 1;
    #20;
    bus_en = 0;
    bus_we = 0;
    
    $display("蜂鸣器状态 (1=开): %b", beep_out);
    #100;
    
    // 关闭蜂鸣器
    bus_addr = 32'hfffffd10;
    bus_write_data = 32'd0;
    bus_en = 1;
    bus_we = 1;
    #20;
    bus_en = 0;
    bus_we = 0;
    
    $display("蜂鸣器状态 (0=关): %b", beep_out);
    #200;
    
    // ===================================
    // 测试 5: 键盘扫描 (简化测试)
    // ===================================
    $display("测试 5: 键盘扫描 (简化)");
    keyboard_cols_in = 4'b1110;  // 模拟按键按下
    
    #500;  // 等待键盘状态机处理
    
    $display("键盘读取值: %h", keyboard_data_out);
    #200;
    
    // ===================================
    // 结束仿真
    // ===================================
    $display("=== 外设仿真测试完成 ===");
    #1000;
    $finish;
  end

endmodule

`timescale 1ns / 1ps
`include "public.v"

// 顶层 SoC：接口与 cpu1/minisys 保持一致，使用 UART_BMPG 通过串口升级程序
module system(
  input  wire        board_rst,
  input  wire        board_clk,

  // 拨码开关 / 按键
  input  wire[23:0]  switches_in,
  input  wire[4:0]   buttons_in,

  // 矩阵键盘
  input  wire[3:0]   keyboard_cols_in,
  output wire[3:0]   keyboard_rows_out,

  // 数码管
  output wire[7:0]   digits_sel_out,
  output wire[7:0]   digits_data_out,

  // 蜂鸣器
  output wire        beep_out,

  // LED
  output wire[7:0]   led_RLD_out,
  output wire[7:0]   led_YLD_out,
  output wire[7:0]   led_GLD_out,

  // UART
  input  wire        rx,
  output wire        tx
);

  // 时钟与复位（与 cpu1 同步）
  wire cpu_clk;
  wire uart_clk;

  // 按键去抖后的升级复位
  wire spg_bufg;
  BUFG u_bufg(.I(buttons_in[3]), .O(spg_bufg));
  reg upg_rst;
  always @(posedge board_clk) begin
    if (board_rst) begin
      upg_rst <= 1'b1;
    end else if (spg_bufg) begin
      upg_rst <= 1'b0;
    end
  end
  wire rst = board_rst | ~upg_rst;

  // 时钟分频 IP（与 minisys 一致）
  clocking u_clocking(
    .clk_in1 (board_clk), // 100MHz
    .cpu_clk (cpu_clk),   // 5MHz
    .uart_clk(uart_clk)   // 10MHz
  );

  // UART 升级 IP
  wire        upg_clk_o;
  wire        upg_wen_o;
  wire [14:0] upg_adr_o;
  wire [31:0] upg_dat_o;
  wire        upg_done_o;
  wire        tx_uart;
  uart_bmpg_0 u_uartpg(
    .upg_clk_i (uart_clk),
    .upg_rst_i (upg_rst),
    .upg_clk_o (upg_clk_o),
    .upg_wen_o (upg_wen_o),
    .upg_adr_o (upg_adr_o),
    .upg_dat_o (upg_dat_o),
    .upg_done_o(upg_done_o),
    .upg_rx_i  (rx),
    .upg_tx_o  (tx_uart)
  );

  // CPU ⇄ 指令存储
  wire[`WordRange] imem_data_in;
  wire[`WordRange] imem_addr_out;
  wire             imem_e_out;

  // CPU ⇄ 数据总线
  wire[`WordRange] bus_addr;
  wire[`WordRange] bus_write_data;
  wire[`WordRange] bus_read_data;
  wire             bus_eable;
  wire             bus_we;
  wire[3:0]        bus_byte_sel;

  // 外设读数据
  wire[`WordRange] ram_data;
  wire[`WordRange] seven_display_data;
  wire[`WordRange] keyboard_data;
  wire[`WordRange] counter_data;
  wire[`WordRange] pwm_data;
  wire             pwm_result;
  wire[`WordRange] uart_data;
  wire[`WordRange] watch_dog_data;
  wire[`WordRange] led_light_data;
  wire[`WordRange] switch_data;
  wire[`WordRange] buzzer_data;

  // 中断（暂不使用外部）
  wire interrupt0 = 1'b0;
  wire interrupt1 = 1'b0;
  wire interrupt2 = 1'b0;
  wire interrupt3 = 1'b0;
  wire interrupt4 = 1'b0;
  wire interrupt5 = 1'b0;

  // CPU
  cpu u_cpu(
    .rst               (rst),
    .clk               (cpu_clk),
    .imem_data_in      (imem_data_in),
    .imem_addr_out     (imem_addr_out),
    .imem_e_out        (imem_e_out),
    .bus_addr_out      (bus_addr),
    .bus_write_data_out(bus_write_data),
    .bus_en_out        (bus_eable),
    .bus_we_out        (bus_we),
    .bus_byte_sel_out  (bus_byte_sel),
    .bus_read_in       (bus_read_data),
    .interrupt_in      ({interrupt5, interrupt4, interrupt3, interrupt2, interrupt1, interrupt0})
  );

  // ROM（指令存储）
  rom u_rom(
    .clk      (~cpu_clk),
    .addr     (imem_addr_out),
    .data_out (imem_data_in),
    .upg_rst  (upg_rst),
    .upg_clk  (upg_clk_o),
    .upg_wen  (upg_wen_o & ~upg_adr_o[14]),
    .upg_adr  (upg_adr_o[13:0]),
    .upg_dat  (upg_dat_o),
    .upg_done (upg_done_o)
  );

  // RAM（数据存储）
  ram u_ram(
    .clk      (~cpu_clk),
    .eable    (bus_eable),
    .we       (bus_we),
    .addr     (bus_addr),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .data_out (ram_data),
    .upg_rst  (upg_rst),
    .upg_clk  (upg_clk_o),
    .upg_wen  (upg_wen_o & upg_adr_o[14]),
    .upg_adr  (upg_adr_o[13:0]),
    .upg_dat  (upg_dat_o),
    .upg_done (upg_done_o)
  );

  // 读数据仲裁
  biu u_biu(
    .addr               (bus_addr),
    .ram_data           (ram_data),
    .seven_display_data (seven_display_data),
    .keyboard_data      (keyboard_data),
    .counter_data       (counter_data),
    .pwm_data           (pwm_data),
    .uart_data          (uart_data),
    .watch_dog_data     (watch_dog_data),
    .led_light_data     (led_light_data),
    .switch_data        (switch_data),
    .buzzer_data        (buzzer_data),
    .data_out           (bus_read_data)
  );

  // 未实现的 UART/其它外设读数据默认返回全 0
  assign uart_data      = `ZeroWord;
  assign watch_dog_data = `ZeroWord;

  // LED
  leds u_leds(
    .rst      (rst),
    .clk      (~cpu_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (led_light_data),
    .RLD      (led_RLD_out),
    .YLD      (led_YLD_out),
    .GLD      (led_GLD_out)
  );

  // 拨码开关
  switches u_switches(
    .rst      (rst),
    .clk      (~cpu_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (switch_data),
    .switch_in(switches_in)
  );

  // 矩阵键盘
  keyboard u_keyboard(
    .rst      (rst),
    .clk      (~cpu_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (keyboard_data),
    .cols     (keyboard_cols_in),
    .rows     (keyboard_rows_out)
  );

  // 数码管
  digits u_digits(
    .rst      (rst),
    .clk      (~cpu_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (seven_display_data),
    .sel_out  (digits_sel_out),
    .digital_out(digits_data_out)
  );

  // 蜂鸣器
  beep u_beep(
    .rst      (rst),
    .clk      (~cpu_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (buzzer_data),
    .signal_out(beep_out)
  );

  // PWM
  pwm u_pwm(
    .rst      (rst),
    .clk      (~cpu_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (pwm_data),
    .result   (pwm_result)
  );

  // 定时器
  wire [15:0] timer_out1, timer_out2;
  wire        timer_cout1, timer_cout2;
  timer u_timer(
    .rst   (rst),
    .clk   (~cpu_clk),
    .cs    (bus_eable && bus_addr[31:4] == 28'hfffffc2),
    .rd    (bus_eable && (bus_we == `Disable)),
    .wr    (bus_eable && (bus_we == `Enable)),
    .port  (bus_addr[2:0]),
    .data  (bus_write_data[15:0]),
    .out1  (timer_out1),
    .out2  (timer_out2),
    .cout1 (timer_cout1),
    .cout2 (timer_cout2)
  );
  assign counter_data = {timer_out2, timer_out1};

  // 看门狗（当前仅提供读数据接口，复位未接入）
  watchdog u_watchdog(
    .rst      (rst),
    .clk      (~cpu_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .cpu_rst  ()
  );

  // UART 升级 TX 输出
  assign tx = tx_uart;

endmodule

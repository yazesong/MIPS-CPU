`timescale 1ns / 1ps
`include "public.v"

// 椤跺眰 SoC锛氭帴鍙ｄ笌 cpu1/minisys 淇濇寔涓€鑷达紝浣跨敤 UART_BMPG 閫氳繃涓插彛鍗囩骇绋嬪簭
module system(
  input  wire        board_rst,
  input  wire        board_clk,

  // 鎷ㄧ爜寮€鍏� / 鎸夐敭
  input  wire[23:0]  switches_in,
  input  wire[4:0]   buttons_in,

  // 鐭╅樀閿洏
  input  wire[3:0]   keyboard_cols_in,
  output wire[3:0]   keyboard_rows_out,

  // 鏁扮爜绠�
  output wire[7:0]   digits_sel_out,
  output wire[7:0]   digits_data_out,

  // 铚傞福鍣�
  output wire        beep_out,

  // LED
  output wire[7:0]   led_RLD_out,
  output wire[7:0]   led_YLD_out,
  output wire[7:0]   led_GLD_out,

  // UART
  input  wire        rx,
  output wire        tx
);

	  // 鏃堕挓涓庡浣嶏紙涓� cpu1 鍚屾锛�
	  wire cpu_clk;
	  wire uart_clk;

	  // 鍗囩骇鎸夐敭鍚屾鍒� board_clk锛堟寜閿槸鏅€� IO锛屼笉鑳芥嬁鍘婚┍鍔� BUFG锛�
	  reg btn3_ff1, btn3_ff2;
	  always @(posedge board_clk) begin
	    btn3_ff1 <= buttons_in[3];
	    btn3_ff2 <= btn3_ff1;
	  end
	  wire spg_sync = btn3_ff2;

	  reg upg_rst;
	  always @(posedge board_clk) begin
	    if (board_rst) begin
	      upg_rst <= 1'b1;
	    end else if (spg_sync) begin
	      upg_rst <= 1'b0;
	    end
	  end

	  // 鏃堕挓鍒嗛 IP锛堜笌 minisys 涓€鑷达級
	  clocking u_clocking(
	    .clk_in1 (board_clk), // 100MHz
    .cpu_clk (cpu_clk),   // 5MHz
    .uart_clk(uart_clk)   // 10MHz
  );

  // UART 鍗囩骇 IP
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

	  // 澶嶄綅绛栫暐锛�
	  // - 姝ｅ父涓婄數锛歶pg_rst=1锛孋PU 鐩存帴杩愯锛堜娇鐢� COE 鍒濆鍖栫殑 BIOS锛�
	  // - 鎸夐敭杩涘叆鍗囩骇锛歶pg_rst=0锛孋PU 淇濇寔澶嶄綅鐩村埌 upg_done_o=1
	  wire rst = board_rst | (~upg_rst & ~upg_done_o);

  // CPU 鈬� 鎸囦护瀛樺偍
  wire[`WordRange] imem_data_in;
  wire[`WordRange] imem_addr_out;
  wire             imem_e_out;

  // CPU 鈬� 鏁版嵁鎬荤嚎
  wire[`WordRange] bus_addr;
  wire[`WordRange] bus_write_data;
  wire[`WordRange] bus_read_data;
  wire             bus_eable;
  wire             bus_we;
  wire[3:0]        bus_byte_sel;

  // 澶栬璇绘暟鎹�
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

  // 涓柇锛堟殏涓嶄娇鐢ㄥ閮級
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

  // ROM锛堟寚浠ゅ瓨鍌級
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

  // RAM锛堟暟鎹瓨鍌級
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

  // 璇绘暟鎹徊瑁�
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

  // 鏈疄鐜扮殑 UART/鍏跺畠澶栬璇绘暟鎹粯璁よ繑鍥炲叏 0
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

  // 鎷ㄧ爜寮€鍏�
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

  // 鐭╅樀閿洏
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

  // 鏁扮爜绠�
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

  // 铚傞福鍣�
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

  // 瀹氭椂鍣�
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

  // 鐪嬮棬鐙楋紙褰撳墠浠呮彁渚涜鏁版嵁鎺ュ彛锛屽浣嶆湭鎺ュ叆锛�
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

  // UART 鍗囩骇 TX 杈撳嚭
  assign tx = tx_uart;

endmodule

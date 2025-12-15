`timescale 1ns / 1ps
`include "public.v"

// systemtest：仿真专用顶层，升级口由 testbench 直接驱动
module systemtest#(
  parameter SIM_DIRECT_CLK = 1'b0
)(
  input  wire        clk,      // 100MHz 板级时钟（来自 testbench）
  input  wire        rst,      // 系统复位，高有效（来自 testbench）

  // 外设端口（与 system 一致，方便复用 testbench）
  input  wire [23:0] switches_in,
  input  wire [3:0]  keyboard_cols_in,
  output wire [3:0]  keyboard_rows_out,
  output wire [7:0]  digits_sel_out,
  output wire [7:0]  digits_data_out,
  output wire        beep_out,
  output wire [7:0]  led_RLD_out,
  output wire [7:0]  led_YLD_out,
  output wire [7:0]  led_GLD_out,
  input  wire        rx,
  output wire        tx,

  // 升级口（与 ROM/RAM 直接相连）
  input  wire        upg_rst_i,
  input  wire        upg_clk_i,
  input  wire        upg_wen_i,
  input  wire [13:0] upg_adr_i,
  input  wire [31:0] upg_dat_i,
  input  wire        upg_done_i
);

  //============================================================
  // 1. 时钟与复位
  //============================================================
  wire cpu_clk;
  wire uart_clk;
  wire mem_clk;

  // 与上板用 clocking IP 一致，保证时序仿真/上板行为一致
  generate
    if (SIM_DIRECT_CLK) begin : gen_sim_clk_bypass
      assign cpu_clk  = clk;
      assign uart_clk = clk;
    end else begin : gen_clk_ip
      clocking u_clocking (
        .clk_in1 (clk),
        .cpu_clk (cpu_clk),   // 5MHz
        .uart_clk(uart_clk)   // 10MHz
      );
    end
  endgenerate

  assign mem_clk = cpu_clk;

  // 为了保险：在升级未完成 (upg_done_i=0) 时保持 CPU 处于复位
  wire rst_int = rst | ~upg_done_i;

  //============================================================
  // 2. CPU 与总线（与 system 完全一致）
  //============================================================
  wire[`WordRange] imem_data_in;
  wire[`WordRange] imem_addr_out;
  wire             imem_e_out;

  wire[`WordRange] bus_addr;
  wire[`WordRange] bus_write_data;
  wire[`WordRange] bus_read_data;
  wire             bus_eable;
  wire             bus_we;
  wire[3:0]        bus_byte_sel;

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

  wire interrupt0 = 1'b0;
  wire interrupt1 = 1'b0;
  wire interrupt2 = 1'b0;
  wire interrupt3 = 1'b0;
  wire interrupt4 = 1'b0;
  wire interrupt5 = 1'b0;

  cpu u_cpu (
    .rst               (rst_int),
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

  //============================================================
  // 3. ROM / RAM（升级口由 testbench 直接控制）
  //============================================================
  rom u_rom (
    .clk      (mem_clk),
    .addr     (imem_addr_out),
    .data_out (imem_data_in),
    .upg_rst  (upg_rst_i),
    .upg_clk  (upg_clk_i),
    .upg_wen  (upg_wen_i),
    .upg_adr  (upg_adr_i),
    .upg_dat  (upg_dat_i),
    .upg_done (upg_done_i)
  );

  ram u_ram (
    .clk      (mem_clk),
    .eable    (bus_eable),
    .we       (bus_we),
    .addr     (bus_addr),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .data_out (ram_data),
    .upg_rst  (upg_rst_i),
    .upg_clk  (upg_clk_i),
    .upg_wen  (upg_wen_i),
    .upg_adr  (upg_adr_i),
    .upg_dat  (upg_dat_i),
    .upg_done (upg_done_i)
  );

  //============================================================
  // 4. BIU & 外设（与 system 完全一致）
  //============================================================
  biu u_biu (
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

  assign uart_data      = `ZeroWord;
  assign watch_dog_data = `ZeroWord;

  leds u_leds (
    .rst      (rst_int),
    .clk      (mem_clk),
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

  switches u_switches (
    .rst       (rst_int),
    .clk       (mem_clk),
    .addr      (bus_addr),
    .en        (bus_eable),
    .byte_sel  (bus_byte_sel),
    .data_in   (bus_write_data),
    .we        (bus_we),
    .data_out  (switch_data),
    .switch_in (switches_in)
  );

  keyboard u_keyboard (
    .rst      (rst_int),
    .clk      (mem_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (keyboard_data),
    .cols     (keyboard_cols_in),
    .rows     (keyboard_rows_out)
  );

  digits u_digits (
    .rst        (rst_int),
    .clk        (mem_clk),
    .addr       (bus_addr),
    .en         (bus_eable),
    .byte_sel   (bus_byte_sel),
    .data_in    (bus_write_data),
    .we         (bus_we),
    .data_out   (seven_display_data),
    .sel_out    (digits_sel_out),
    .digital_out(digits_data_out)
  );

  beep u_beep (
    .rst       (rst_int),
    .clk       (mem_clk),
    .addr      (bus_addr),
    .en        (bus_eable),
    .byte_sel  (bus_byte_sel),
    .data_in   (bus_write_data),
    .we        (bus_we),
    .data_out  (buzzer_data),
    .signal_out(beep_out)
  );

  pwm u_pwm (
    .rst      (rst_int),
    .clk      (mem_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .data_out (pwm_data),
    .result   (pwm_result)
  );

  wire [15:0] timer_out1, timer_out2;
  wire        timer_cout1, timer_cout2;

  timer u_timer (
    .rst   (rst_int),
    .clk   (mem_clk),
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

  watchdog u_watchdog (
    .rst      (rst_int),
    .clk      (mem_clk),
    .addr     (bus_addr),
    .en       (bus_eable),
    .byte_sel (bus_byte_sel),
    .data_in  (bus_write_data),
    .we       (bus_we),
    .cpu_rst  ()
  );

  // 仿真顶层里暂时不使用 UART 正常通信，所以 tx 直接保持高电平
  // 如果你后续要做 UART 功能测试，可以在这里接上真正的串口 IP。
  assign tx = 1'b1;

endmodule

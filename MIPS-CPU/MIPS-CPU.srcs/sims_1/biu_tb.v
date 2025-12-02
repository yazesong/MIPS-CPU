`timescale 1ns / 1ps
`include "../sources_1/cpu/public.v"

// BIU 仲裁器自检：RAM 优先，IO 选择各设备
module biu_tb;
  reg [`WordRange] addr;
  reg [`WordRange] ram_data;
  reg [`WordRange] seven_display_data;
  reg [`WordRange] keyboard_data;
  reg [`WordRange] counter_data;
  reg [`WordRange] pwm_data;
  reg [`WordRange] uart_data;
  reg [`WordRange] watch_dog_data;
  reg [`WordRange] led_light_data;
  reg [`WordRange] switch_data;
  reg [`WordRange] buzzer_data;
  wire[`WordRange] data_out;

  biu dut(
    .addr(addr),
    .ram_data(ram_data),
    .seven_display_data(seven_display_data),
    .keyboard_data(keyboard_data),
    .counter_data(counter_data),
    .pwm_data(pwm_data),
    .uart_data(uart_data),
    .watch_dog_data(watch_dog_data),
    .led_light_data(led_light_data),
    .switch_data(switch_data),
    .buzzer_data(buzzer_data),
    .data_out(data_out)
  );

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
    // 准备各设备数据
    ram_data           = 32'hAAAA_AAAA;
    seven_display_data = 32'h1111_1111;
    keyboard_data      = 32'h2222_2222;
    counter_data       = 32'h3333_3333;
    pwm_data           = 32'h4444_4444;
    uart_data          = 32'h5555_5555;
    watch_dog_data     = 32'h6666_6666;
    led_light_data     = 32'h7777_7777;
    switch_data        = 32'h8888_8888;
    buzzer_data        = 32'h9999_9999;

    // RAM 区间
    addr = 32'h8000_0004;
    #1 check(data_out == ram_data, "RAM select");

    // IO: 数码管 addr[9:4]=0
    addr = 32'hFFFF_FC00;
    #1 check(data_out == seven_display_data, "IO seven_display");

    // IO: 键盘 addr[9:4]=1
    addr = 32'hFFFF_FC10;
    #1 check(data_out == keyboard_data, "IO keyboard");

    // IO: 计数器
    addr = 32'hFFFF_FC20;
    #1 check(data_out == counter_data, "IO counter");

    // IO: PWM
    addr = 32'hFFFF_FC30;
    #1 check(data_out == pwm_data, "IO pwm");

    // IO: UART
    addr = 32'hFFFF_FC40;
    #1 check(data_out == uart_data, "IO uart");

    // IO: Watchdog
    addr = 32'hFFFF_FC50;
    #1 check(data_out == watch_dog_data, "IO watchdog");

    // IO: LED
    addr = 32'hFFFF_FC60;
    #1 check(data_out == led_light_data, "IO led");

    // IO: Switch
    addr = 32'hFFFF_FC70;
    #1 check(data_out == switch_data, "IO switch");

    // IO: Buzzer（0xFFFF_FD00，addr[9:4]=0x10）
    addr = 32'hFFFF_FD00;
    #1 check(data_out == buzzer_data, "IO buzzer");

    // 未匹配
    addr = 32'h1234_0000;
    #1 check(data_out == `ZeroWord, "default zero");

    $display("biu TB PASS");
    $finish;
  end
endmodule

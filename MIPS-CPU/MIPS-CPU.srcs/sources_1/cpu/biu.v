`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/01 13:08:32
// Design Name: 
// Module Name: biu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "public.v"

// 读数据仲裁器
// 根据地址选择 RAM 或各外设的数据返回给 CPU
module biu(
  input  wire[`WordRange] addr,              // 来自 CPU 的总线地址
  input  wire[`WordRange] ram_data,          // RAM 读数据
  input  wire[`WordRange] seven_display_data,// 数码管
  input  wire[`WordRange] keyboard_data,     // 键盘
  input  wire[`WordRange] counter_data,      // 计时器/计数器
  input  wire[`WordRange] pwm_data,          // PWM
  input  wire[`WordRange] uart_data,         // 串口
  input  wire[`WordRange] watch_dog_data,    // 看门狗
  input  wire[`WordRange] led_light_data,    // LED
  input  wire[`WordRange] switch_data,       // 拨码开关
  input  wire[`WordRange] buzzer_data,       // 蜂鸣器
  output reg [`WordRange] data_out           // 选出的读数据返回 CPU
);

  always @(*) begin
    data_out = `ZeroWord;
    // 先判断是不是内存
    if (`IS_RAM(addr)) begin
      data_out = ram_data;
    end else if (`IS_IO(addr)) begin
      // IO 区域再根据设备 ID 选择
      case (addr[9:4])  // 与 public 中宏的编码对应
        `IO_SEVEN_DISPLAY: data_out = seven_display_data;
        `IO_KEYBORAD    : data_out = keyboard_data;
        `IO_COUNTER     : data_out = counter_data;
        `IO_PWM         : data_out = pwm_data;
        `IO_UART        : data_out = uart_data;
        `IO_WATCH_DOG   : data_out = watch_dog_data;
        `IO_LED_LIGHT   : data_out = led_light_data;
        `IO_SWITCH      : data_out = switch_data;
        `IO_BUZZER      : data_out = buzzer_data;
        default         : data_out = `ZeroWord;
      endcase
    end
  end

endmodule

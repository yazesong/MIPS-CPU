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
    // IO 地址空间：0xFFFF_FC00 ~ 0xFFFF_FC7F 以及 0xFFFF_FD10 (蜂鸣器)
    if (addr[31:12] == 20'hfffff) begin
      case (addr[11:4])
        8'hC0: data_out = seven_display_data; // 0xFFFFFC00
        8'hC1: data_out = keyboard_data;      // 0xFFFFFC10
        8'hC2: data_out = counter_data;       // 0xFFFFFC20
        8'hC3: data_out = pwm_data;           // 0xFFFFFC30
        8'hC4: data_out = uart_data;          // 0xFFFFFC40
        8'hC5: data_out = watch_dog_data;     // 0xFFFFFC50
        8'hC6: data_out = led_light_data;     // 0xFFFFFC60
        8'hC7: data_out = switch_data;        // 0xFFFFFC70
        8'hD1: data_out = buzzer_data;        // 0xFFFFFD10
        default: data_out = `ZeroWord;
      endcase
    end else if (addr[31:16] == 16'h8000) begin
      data_out = ram_data;
    end
  end

endmodule

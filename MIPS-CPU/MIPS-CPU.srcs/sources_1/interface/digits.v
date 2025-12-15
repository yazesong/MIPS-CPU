// digits.v


`include "public.v"

// 八位七段共阳极数码管驱动
// 地址范围：0xFFFFFC00 ~ 0xFFFFFC0F
// 寄存器定义（根据 4.6 节）：
//   0xFFFFFC00 - 低四位数码管数据（每四位对应一个数码管）
//   0xFFFFFC02 - 高四位数码管数据（每四位对应一个数码管）  
//   0xFFFFFC04 - 特殊显示寄存器（低8位=小数点，高8位=位使能）
module digits (

  input rst, // 复位
  input clk, // 时钟

  //从总线来的数据 所有外设驱动都应有以下信号
  input wire[`WordRange] addr,
  input wire en, // 使能
  input wire[3:0] byte_sel,
  input wire[`WordRange] data_in, // 数据输入（来自cpu）
  input wire we, //写使能

  //发送给仲裁器 所有外设都应有此输出
  output reg[`WordRange] data_out,

  //发送给外设
  output reg[7:0] sel_out, // 位使能（低有效）
  output reg[7:0] digital_out // 段使能（DP, G-A，低有效）

);

  reg[31:0] low_digits_data;   // 0xFFFFFC00 - 低4位数码管数据
  reg[31:0] high_digits_data;  // 0xFFFFFC02 - 高4位数码管数据
  reg[31:0] special_reg;       // 0xFFFFFC04 - 特殊显示寄存器

  // 7段码转换函数
  function [7:0] digit_to_7seg;
    input [3:0] digit;
    begin
      case (digit)
        4'd0: digit_to_7seg = 8'b1100_0000; // ABCDEF
        4'd1: digit_to_7seg = 8'b1111_1001; // BC
        4'd2: digit_to_7seg = 8'b1010_0100; // ABDEG
        4'd3: digit_to_7seg = 8'b1011_0000; // ABCDG
        4'd4: digit_to_7seg = 8'b1001_1001; // BCFG
        4'd5: digit_to_7seg = 8'b1001_0010; // ACDFG
        4'd6: digit_to_7seg = 8'b1000_0010; // ACDEFG
        4'd7: digit_to_7seg = 8'b1111_1000; // ABC
        4'd8: digit_to_7seg = 8'b1000_0000; // ABCDEFG
        4'd9: digit_to_7seg = 8'b1001_1000; // ABCFG
        4'd10: digit_to_7seg = 8'b1000_1000; // ABCEFG (A)
        4'd11: digit_to_7seg = 8'b1000_0011; // CDEFG (b)
        4'd12: digit_to_7seg = 8'b1010_0111; // DEG (C)
        4'd13: digit_to_7seg = 8'b1010_0001; // BCDEG (d)
        4'd14: digit_to_7seg = 8'b1000_0110; // ADEFG (E)
        4'd15: digit_to_7seg = 8'b1000_1110; // AEFG (F)
        default: digit_to_7seg = 8'b1100_0000;
      endcase
    end
  endfunction

  // 写操作
  always @(posedge clk) begin
    if (rst == `Enable) begin
      low_digits_data <= 32'h0;
      high_digits_data <= 32'h0;
      special_reg <= 32'h0;
      sel_out <= 8'hff;
      digital_out <= 8'hff;
    end else if (en == `Enable && we == `Enable) begin
      case (addr[3:0])
        4'h0: low_digits_data <= data_in;           // 0xFFFFFC00
        4'h2: high_digits_data <= data_in;          // 0xFFFFFC02
        4'h4: special_reg <= data_in;               // 0xFFFFFC04
      endcase
    end
    
    // 根据特殊寄存器更新输出
    // 位使能：special_reg[15:8]，1=显示该位
    // 小数点：special_reg[7:0]，1=点亮小数点
    sel_out <= ~special_reg[15:8];
    
    // 这里简化处理：只显示低4位的第一个数码管
    // 实际应用中需要动态扫描所有8位
    digital_out <= digit_to_7seg(low_digits_data[3:0]);
  end

  // 读操作
  always @(*) begin
    if(rst == `Enable) begin
      data_out <= `ZeroWord;
    end else if (en == `Enable && we ==`Disable) begin
      case (addr[3:0])
        4'h0: data_out <= low_digits_data;
        4'h2: data_out <= high_digits_data;
        4'h4: data_out <= special_reg;
        default: data_out <= `ZeroWord;
      endcase
    end else begin
      data_out <= `ZeroWord;
    end
  end
endmodule

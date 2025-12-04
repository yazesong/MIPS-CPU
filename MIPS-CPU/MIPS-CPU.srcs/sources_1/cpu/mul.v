`timescale 1ns / 1ps
`include "public.v"

// 乘法器
// start 拉高时锁存一组操作数，IP 延迟 LATENCY 拍后 valid 脉冲
module mul(
    input  wire              clk,
    input  wire[`WordRange]  dataA,
    input  wire[`WordRange]  dataB,
    input  wire              start,
    input  wire              if_signed,   // 1: 有符号
    output reg [`DivMulResultRange] result,
    output reg               valid
);

  localparam integer LATENCY = 6; // 从 XCI 读取的管线级数

  reg [`WordRange] a_reg, b_reg;
  reg [3:0]        cnt;
  reg              busy;
  wire[`DivMulResultRange] p_signed, p_unsigned;

  // IP 实例
  mult_gen_signed u_mul_signed (
    .CLK (clk),
    .A   (a_reg),
    .B   (b_reg),
    .P   (p_signed)
  );

  mult_gen_unsigned u_mul_unsigned (
    .CLK (clk),
    .A   (a_reg),
    .B   (b_reg),
    .P   (p_unsigned)
  );

  always @(posedge clk) begin
    valid <= `Disable; // 默认不拉高

    if (!busy && start == `Enable) begin
      a_reg <= dataA;
      b_reg <= dataB;
      busy  <= 1'b1;
      cnt   <= 4'd1;
    end else if (busy) begin
      if (cnt == LATENCY) begin
        busy  <= 1'b0;
        cnt   <= 4'd0;
        valid <= `Enable;
        result<= if_signed ? p_signed : p_unsigned;
      end else begin
        cnt <= cnt + 1'b1;
      end
    end else begin
      busy <= 1'b0;
      cnt  <= 4'd0;
    end
  end

endmodule

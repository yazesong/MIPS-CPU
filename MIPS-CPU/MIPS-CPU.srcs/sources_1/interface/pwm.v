// pwm.v


`include "public.v"

// PWM 脉冲宽度调制
// 地址范围：0xFFFFFC30~0xFFFFFC3F
// 寄出器个数：3
// 寄存器地址： 0xFFFFFC30 0xFFFFFC32 0xFFFFFC34
// 寄存器功能：  最大值       对比值       控制
module pwm (
  input rst, // 重置，全部灭灯
  input clk, // 时钟

  //从总线来的数据 所有外设驱动都应有以下信号
  input wire[`WordRange] addr,
  input wire en, // 使能
  input wire[3:0] byte_sel,
  input wire[`WordRange] data_in, // 数据输入（来自cpu）
  input wire we, //写使能

  //发送给仲裁器 所有外设都应有此输出
  output reg[`WordRange] data_out,

  output reg result // PWM调制结果
);

  reg[15:0] threshold; // 最大值寄存器
  reg[15:0] compare; // 对比值寄存器
  reg[7:0] ctrl; // 控制寄存器
  reg[15:0] current; // 当前值


  always @(*)begin //读是随时读
    if(rst == `Enable)begin
      data_out = `ZeroWord;
    end else begin
      if(addr[31:4] == {28'hfffffc3} && en == `Enable && we == `Disable)begin
          if(addr[3:2] == 2'b00)begin
            data_out = {compare,threshold};
          end else if(addr[3:2] == 2'b01)begin
            data_out = {24'h000000, ctrl};
          end else begin
            data_out = `ZeroWord;
          end
      end else begin
        data_out = `ZeroWord;
      end
    end
  end

  wire [15:0] current_next = (current >= threshold) ? 16'd0 : (current + 16'd1);

  always @(posedge clk) begin
    if (rst == `Enable) begin
      threshold <= 16'hffff;
      compare   <= 16'h7fff;
      ctrl      <= 8'd1;
      current   <= 16'd0;
      result    <= `Enable;
    end else begin
      // 写寄存器（总线写）
      if (addr[31:4] == {28'hfffffc3} && en == `Enable && we == `Enable) begin
        if (addr[3:2] == 2'b00) begin
          if (byte_sel[0]) threshold[7:0]  <= data_in[7:0];
          if (byte_sel[1]) threshold[15:8] <= data_in[15:8];
          if (byte_sel[2]) compare[7:0]    <= data_in[23:16];
          if (byte_sel[3]) compare[15:8]   <= data_in[31:24];
        end else if (addr[3:2] == 2'b01) begin
          if (byte_sel[0]) ctrl <= data_in[7:0];
        end
      end

      // PWM 计数与输出
      current <= current_next;
      if (ctrl[0]) begin
        result <= (current_next > compare) ? `Disable : `Enable;
      end
    end
  end


endmodule

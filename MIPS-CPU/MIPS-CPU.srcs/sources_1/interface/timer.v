// timer.v


`include "public.v"

// 定时器
module timer (

  input rst, // 复位
  input clk, // 时钟

  input cs, // 片选
  input rd, // 读模式
  input wr, // 写模式
  input [2:0] port, // 内部寄存器端口选择，方式寄存器：0/2，初始值寄存器：4/6

  input [15:0] data, // 输入数据

  output reg[15:0] out1, // CNT1输出
  output reg[15:0] out2, // CNT2输出

  output reg cout1, // COUT1，低电平有效
  output reg cout2 // COUT2，低电平有效

);

  // 方式寄存器
  reg[15:0] config1;
  reg[15:0] config2;
  // 状态寄存器
  reg[15:0] status1;
  reg[15:0] status2;
  // 初始值寄存器
  reg[15:0] init1;
  reg[15:0] init2;
  // 当前值寄存器
  reg[15:0] current1;
  reg[15:0] current2;

  // 单 always 管理读写/计数，避免多驱动
  always @(posedge clk) begin
    if (rst == `Enable) begin
      config1  <= 16'd0;   config2  <= 16'd0;
      status1  <= 16'd0;   status2  <= 16'd0;
      init1    <= 16'd0;   init2    <= 16'd0;
      current1 <= 16'd0;   current2 <= 16'd0;
      out1     <= 16'd0;   out2     <= 16'd0;
      cout1    <= `Enable; cout2    <= `Enable;
    end else begin
      // 默认保持输出
      out1   <= out1;
      out2   <= out2;
      cout1  <= cout1;
      cout2  <= cout2;

      // 写寄存器
      if (cs == `Enable && wr == `Enable) begin
        case (port)
          3'h0: begin config1 <= data; status1 <= status1 & 16'h7FFF; end
          3'h2: begin config2 <= data; status2 <= status2 & 16'h7FFF; end
          3'h4: begin init1   <= data; current1 <= data; status1 <= 16'h8000; cout1 <= `Enable; end
          3'h6: begin init2   <= data; current2 <= data; status2 <= 16'h8000; cout2 <= `Enable; end
          default: ;
        endcase
      end

      // 读寄存器
      if (cs == `Enable && rd == `Enable) begin
        case (port)
          3'h0: out1 <= status1;
          3'h2: out2 <= status2;
          3'h4: out1 <= current1;
          3'h6: out1 <= current2;
          default: ;
        endcase
      end

      // 重复模式自动重装
      if (cout1 == `Disable && config1[1] == `Enable) begin
        current1 <= init1;
        cout1    <= `Enable;
      end
      if (cout2 == `Disable && config2[1] == `Enable) begin
        current2 <= init2;
        cout2    <= `Enable;
      end

      // CNT1 计数（写初值当拍不递减）
      if (!(cs == `Enable && wr == `Enable && port == 3'h4) && cout1 == `Enable) begin
        current1 <= current1 - 16'd1;
        if (config1[0] == `Disable) begin
          if (current1 == 16'd1) begin
            status1 <= status1 & 16'h7FFF | 16'h0001;
            cout1   <= `Disable;
          end
        end else begin
          if (current1 == 16'd0) begin
            status1 <= status1 & 16'h7FFF | 16'h0002;
            cout1   <= `Disable;
          end
        end
      end

      // CNT2 计数（写初值当拍不递减）
      if (!(cs == `Enable && wr == `Enable && port == 3'h6) && cout2 == `Enable) begin
        current2 <= current2 - 16'd1;
        if (config2[0] == `Disable) begin
          if (current2 == 16'd1) begin
            status2 <= status2 & 16'h7FFF | 16'h0001;
            cout2   <= `Disable;
          end
        end else begin
          if (current2 == 16'd0) begin
            status2 <= status2 & 16'h7FFF | 16'h0002;
            cout2   <= `Disable;
          end
        end
      end
    end
  end

endmodule

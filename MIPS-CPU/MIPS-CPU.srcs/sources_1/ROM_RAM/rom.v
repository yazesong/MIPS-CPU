module rom(
    input wire clk,
    input wire [31:0] addr,
    output wire [31:0] data_out,

    input wire upg_rst,
    input wire upg_clk,
    input wire upg_wen,
    input wire[13:0] upg_adr,
    input wire[31:0] upg_dat,
    input wire upg_done
);

// 运行/升级模式选择（与 system.v 的复位策略匹配）：
// - upg_rst=1：不升级，CPU 直接运行（从 COE 初始化内容取指）
// - upg_rst=0 且 upg_done=0：升级中，UART 写 ROM
// - upg_rst=0 且 upg_done=1：升级完成，CPU 运行（使用 UART 覆盖后的内容取指）
wire cpu_mode = upg_rst | upg_done;

// ============================================================
// 关键修复：去除 clka 上的时钟 MUX
//
// 之前的实现用 `clka = cpu_mode ? clk : upg_clk`，会把 LUT 放到时钟树上（TIMING-14）。
// 这里改为：ROM 始终用 `clk` 时钟；升级口通过一个简单握手把 upg 写命令搬运到 `clk` 域，
// 再在 `clk` 域发起 1 个周期的写使能。
// ============================================================

// upg_clk 域：捕获写命令并发起请求（写请求很稀疏：UART 128kbps，握手足够快）
reg        upg_req_toggle;
reg [13:0] upg_adr_buf;
reg [31:0] upg_dat_buf;
reg        ack_sync1, ack_sync2;

// clk 域：同步请求并执行写
reg        req_sync1, req_sync2;
reg        ack_toggle;
reg        wr_pending;
reg [13:0] wr_adr;
reg [31:0] wr_dat;

always @(posedge upg_clk) begin
  if (cpu_mode) begin
    upg_req_toggle <= 1'b0;
    upg_adr_buf    <= 14'd0;
    upg_dat_buf    <= 32'd0;
    ack_sync1      <= 1'b0;
    ack_sync2      <= 1'b0;
  end else begin
    // ack 从 clk 域同步回来
    ack_sync1 <= ack_toggle;
    ack_sync2 <= ack_sync1;

    // 仅在上一笔已应答时接受新写命令
    if (upg_wen && (ack_sync2 == upg_req_toggle)) begin
      upg_adr_buf    <= upg_adr;
      upg_dat_buf    <= upg_dat;
      upg_req_toggle <= ~upg_req_toggle;
    end
  end
end

always @(posedge clk) begin
  if (cpu_mode) begin
    req_sync1   <= 1'b0;
    req_sync2   <= 1'b0;
    ack_toggle  <= 1'b0;
    wr_pending  <= 1'b0;
    wr_adr      <= 14'd0;
    wr_dat      <= 32'd0;
  end else begin
    // 请求从 upg_clk 域同步进来
    req_sync1 <= upg_req_toggle;
    req_sync2 <= req_sync1;

    if (!wr_pending && (req_sync2 != ack_toggle)) begin
      // 收到新请求：缓存写命令，下一拍执行写
      wr_adr     <= upg_adr_buf;
      wr_dat     <= upg_dat_buf;
      wr_pending <= 1'b1;
    end else if (wr_pending) begin
      // 本拍完成写（wea=1），并应答
      wr_pending <= 1'b0;
      ack_toggle <= req_sync2;
    end
  end
end

wire [13:0] addra_mux = cpu_mode ? addr[15:2] : wr_adr;
wire [31:0] dina_mux  = cpu_mode ? 32'h0      : wr_dat;
wire        wea_mux   = cpu_mode ? 1'b0       : wr_pending;

blk_mem_gen_0 u_blk_mem_gen_0 (
    .clka  (clk),
    .wea   (wea_mux),
    .addra (addra_mux),
    .dina  (dina_mux),
    .douta (data_out)
);


endmodule

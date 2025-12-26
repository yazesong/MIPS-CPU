module ram(
    input wire clk,
    input wire eable,
    input wire we,
    input wire [31:0] addr,
    input wire [3:0] byte_sel,
    input wire [31:0] data_in,
    output wire [31:0] data_out,

    input wire upg_rst,
    input wire upg_clk,
    input wire upg_wen,
    input wire [13:0] upg_adr,
    input wire [31:0] upg_dat,
    input wire upg_done
);

// 运行/升级模式选择（与 system.v 的复位策略匹配）：
// - upg_rst=1：不升级，CPU 访问 RAM
// - upg_rst=0 且 upg_done=0：升级中，UART 写 RAM
// - upg_rst=0 且 upg_done=1：升级完成，CPU 访问 RAM
wire cpu_mode = upg_rst | upg_done;

wire ram_eable;
wire weA, weB, weC, weD;

assign ram_eable = (addr[31:16] == 16'h8000) && eable;
assign weA = byte_sel[0] & we;
assign weB = byte_sel[1] & we;
assign weC = byte_sel[2] & we;
assign weD = byte_sel[3] & we;

// ============================================================
// 关键修复：去除 clka 上的时钟 MUX
//
// 之前的实现用 `clka = cpu_mode ? clk : upg_clk`，会把 LUT 放到时钟树上（TIMING-14）。
// 这里改为：RAM 始终用 `clk` 时钟；升级口通过简单握手把 upg 写命令搬运到 `clk` 域，
// 再在 `clk` 域发起 1 个周期的写使能（四个 byte lane 同时写）。
// ============================================================

// upg_clk 域：捕获写命令并发起请求
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
    ack_sync1 <= ack_toggle;
    ack_sync2 <= ack_sync1;

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
    req_sync1 <= upg_req_toggle;
    req_sync2 <= req_sync1;

    if (!wr_pending && (req_sync2 != ack_toggle)) begin
      wr_adr     <= upg_adr_buf;
      wr_dat     <= upg_dat_buf;
      wr_pending <= 1'b1;
    end else if (wr_pending) begin
      wr_pending <= 1'b0;
      ack_toggle <= req_sync2;
    end
  end
end

wire [13:0] addra_mux = cpu_mode ? addr[15:2] : wr_adr;
wire        ena_mux   = cpu_mode ? ram_eable  : 1'b1;

wire [7:0] dinaA_mux  = cpu_mode ? data_in[7:0]   : wr_dat[7:0];
wire [7:0] dinaB_mux  = cpu_mode ? data_in[15:8]  : wr_dat[15:8];
wire [7:0] dinaC_mux  = cpu_mode ? data_in[23:16] : wr_dat[23:16];
wire [7:0] dinaD_mux  = cpu_mode ? data_in[31:24] : wr_dat[31:24];

wire weaA_mux = cpu_mode ? weA : wr_pending;
wire weaB_mux = cpu_mode ? weB : wr_pending;
wire weaC_mux = cpu_mode ? weC : wr_pending;
wire weaD_mux = cpu_mode ? weD : wr_pending;

blk_mem_ram_byte ramA(
    .addra (addra_mux),
    .clka  (clk),
    .dina  (dinaA_mux),
    .douta (data_out[7:0]),
    .ena   (ena_mux),
    .wea   (weaA_mux)
);

blk_mem_ram_byte ramB(
    .addra (addra_mux),
    .clka  (clk),
    .dina  (dinaB_mux),
    .douta (data_out[15:8]),
    .ena   (ena_mux),
    .wea   (weaB_mux)
);

blk_mem_ram_byte ramC(
    .addra (addra_mux),
    .clka  (clk),
    .dina  (dinaC_mux),
    .douta (data_out[23:16]),
    .ena   (ena_mux),
    .wea   (weaC_mux)
);

blk_mem_ram_byte ramD(
    .addra (addra_mux),
    .clka  (clk),
    .dina  (dinaD_mux),
    .douta (data_out[31:24]),
    .ena   (ena_mux),
    .wea   (weaD_mux)
);

endmodule

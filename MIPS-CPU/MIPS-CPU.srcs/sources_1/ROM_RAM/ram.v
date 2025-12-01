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

// ✅ 修复：kickOff 逻辑
// upg_rst=1 时：进入升级模式（使用upg_*信号）
// upg_rst=0 时：进入运行模式（使用clk, addr等信号）
wire kickOff = ~upg_rst;  // 简化版本

wire ram_eable;
wire weA, weB, weC, weD;

assign ram_eable = (addr[31:16] == 16'h8000) && eable;
assign weA = byte_sel[0] & we;
assign weB = byte_sel[1] & we;
assign weC = byte_sel[2] & we;
assign weD = byte_sel[3] & we;

blk_mem_ram_byte ramA(
    // ✅ 修复：反转 mux 选择逻辑
    .addra (kickOff ? addr[15:2]      : upg_adr),
    .clka  (kickOff ? clk             : upg_clk),
    .dina  (kickOff ? data_in[7:0]    : upg_dat[7:0]),
    .douta (data_out[7:0]),
    .ena   (kickOff ? ram_eable       : 1'b1),
    .wea   (kickOff ? weA             : upg_wen)
);

blk_mem_ram_byte ramB(
    .addra (kickOff ? addr[15:2]      : upg_adr),
    .clka  (kickOff ? clk             : upg_clk),
    .dina  (kickOff ? data_in[15:8]   : upg_dat[15:8]),
    .douta (data_out[15:8]),
    .ena   (kickOff ? ram_eable       : 1'b1),
    .wea   (kickOff ? weB             : upg_wen)
);

blk_mem_ram_byte ramC(
    .addra (kickOff ? addr[15:2]      : upg_adr),
    .clka  (kickOff ? clk             : upg_clk),
    .dina  (kickOff ? data_in[23:16]  : upg_dat[23:16]),
    .douta (data_out[23:16]),
    .ena   (kickOff ? ram_eable       : 1'b1),
    .wea   (kickOff ? weC             : upg_wen)
);

blk_mem_ram_byte ramD(
    .addra (kickOff ? addr[15:2]      : upg_adr),
    .clka  (kickOff ? clk             : upg_clk),
    .dina  (kickOff ? data_in[31:24]  : upg_dat[31:24]),
    .douta (data_out[31:24]),
    .ena   (kickOff ? ram_eable       : 1'b1),
    .wea   (kickOff ? weD             : upg_wen)
);

endmodule

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

// ✅ 修复：kickOff 逻辑（保持与ram.v一致）
wire kickOff = ~upg_rst;

blk_mem_gen_0 u_blk_mem_gen_0 (
    .addra (kickOff ? addr[15:2] : upg_adr),
    .clka  (kickOff ? clk        : upg_clk),
    .douta (data_out),
    .wea   (kickOff ? 1'b0       : upg_wen),
    .dina  (kickOff ? 32'h00000000 : upg_dat)
);

endmodule

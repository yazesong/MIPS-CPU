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

// 鉁? 淇锛歬ickOff 閫昏緫
// upg_rst=1 鏃讹細杩涘叆鍗囩骇妯″紡锛堜娇鐢╱pg_*淇″彿锛?
// upg_rst=0 鏃讹細杩涘叆杩愯妯″紡锛堜娇鐢╟lk, addr绛変俊鍙凤級
wire kickOff = ~upg_rst;  // 绠?鍖栫増鏈?

wire ram_eable;
wire weA, weB, weC, weD;

assign ram_eable = (addr[31:16] == 16'h8000) && eable;
assign weA = byte_sel[0] & we;
assign weB = byte_sel[1] & we;
assign weC = byte_sel[2] & we;
assign weD = byte_sel[3] & we;

//blk_mem_ram_byte ramA(
//    // 鉁? 淇锛氬弽杞? mux 閫夋嫨閫昏緫
//    .addra (kickOff ? addr[15:2]      : upg_adr),
//    .clka  (kickOff ? clk             : upg_clk),
//    .dina  (kickOff ? data_in[7:0]    : upg_dat[7:0]),
//    .douta (data_out[7:0]),
//    .ena   (kickOff ? ram_eable       : 1'b1),
//    .wea   (kickOff ? weA             : upg_wen)
//);
blk_mem_ram_byte ramA(
    .clka(kickOff ? clk : upg_clk),
    .ena (kickOff ? ram_eable : 1'b1),
    .wea (kickOff ? weA : upg_wen),   // stub 支持 wea
    .addra(kickOff ? addr[13:2] : upg_adr),
    .dina(kickOff ? data_in[7:0] : upg_dat[7:0]),
    .douta(data_out[7:0])
);
blk_mem_ram_byte ramB(
    .clka(kickOff ? clk : upg_clk),
    .ena (kickOff ? ram_eable : 1'b1),
    .wea (kickOff ? weA : upg_wen),   // stub 支持 wea
    .addra(kickOff ? addr[13:2] : upg_adr),
    .dina(kickOff ? data_in[7:0] : upg_dat[7:0]),
    .douta(data_out[7:0])
);
blk_mem_ram_byte ramC(
    .clka(kickOff ? clk : upg_clk),
    .ena (kickOff ? ram_eable : 1'b1),
    .wea (kickOff ? weA : upg_wen),   // stub 支持 wea
    .addra(kickOff ? addr[13:2] : upg_adr),
    .dina(kickOff ? data_in[7:0] : upg_dat[7:0]),
    .douta(data_out[7:0])
);
blk_mem_ram_byte ramD(
    .clka(kickOff ? clk : upg_clk),
    .ena (kickOff ? ram_eable : 1'b1),
    .wea (kickOff ? weA : upg_wen),   // stub 支持 wea
    .addra(kickOff ? addr[13:2] : upg_adr),
    .dina(kickOff ? data_in[7:0] : upg_dat[7:0]),
    .douta(data_out[7:0])
);

//blk_mem_ram_byte ramB(
//    .addra (kickOff ? addr[15:2]      : upg_adr),
//    .clka  (kickOff ? clk             : upg_clk),
//    .dina  (kickOff ? data_in[15:8]   : upg_dat[15:8]),
//    .douta (data_out[15:8]),
//    .ena   (kickOff ? ram_eable       : 1'b1),
//    .wea   (kickOff ? weB             : upg_wen)
//);

//blk_mem_ram_byte ramC(
//    .addra (kickOff ? addr[15:2]      : upg_adr),
//    .clka  (kickOff ? clk             : upg_clk),
//    .dina  (kickOff ? data_in[23:16]  : upg_dat[23:16]),
//    .douta (data_out[23:16]),
//    .ena   (kickOff ? ram_eable       : 1'b1),
//    .wea   (kickOff ? weC             : upg_wen)
//);

//blk_mem_ram_byte ramD(
//    .addra (kickOff ? addr[15:2]      : upg_adr),
//    .clka  (kickOff ? clk             : upg_clk),
//    .dina  (kickOff ? data_in[31:24]  : upg_dat[31:24]),
//    .douta (data_out[31:24]),
//    .ena   (kickOff ? ram_eable       : 1'b1),
//    .wea   (kickOff ? weD             : upg_wen)
//);

endmodule

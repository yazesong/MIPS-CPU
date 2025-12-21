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

// 鉁? 淇锛歬ickOff 閫昏緫锛堜繚鎸佷笌ram.v涓?鑷达級
wire kickOff = ~upg_rst;

blk_mem_gen_0 u_blk_mem_gen_0 (
    .clka  (kickOff ? clk  : upg_clk),
    .ena   (1'b1),
    .addra (kickOff ? addr[13:2] : upg_adr),
    .douta (data_out)
);


endmodule

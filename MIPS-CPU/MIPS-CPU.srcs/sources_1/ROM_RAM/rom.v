`include "public.v"

module ram(
    input wire clk,
    input wire eable,
    input wire we,
    input wire[`WordRange] addr,
    input wire[3:0] byte_sel,
    input wire[`WordRange] data_in,
    output wire[`WordRange] data_out,

    input wire upg_rst,
    input wire upg_clk,
    input wire upg_wen,
    input wire[13:0] upg_adr,
    input wire[31:0] upg_dat,
    input wire upg_done
);

    // 工作模式控制
    wire kickOff = upg_rst | (~upg_rst & upg_done);

    // 地址和时钟多路选择
    wire [13:0] ram_addr = kickOff ? addr[15:2] : upg_adr;
    wire ram_clk = kickOff ? clk : upg_clk;

    // RAM使能：检查地址范围是否在0x8000_0000 - 0x8000_FFFF
    wire is_ram_addr = ((addr[31:16] == 16'h8000) && eable);

    // 字节写使能信号（修复：weB/weC/weD现在正确对应各字节）
    wire weA = byte_sel[0] & we & is_ram_addr;  // 字节0 [7:0]
    wire weB = byte_sel[1] & we & is_ram_addr;  // 字节1 [15:8]
    wire weC = byte_sel[2] & we & is_ram_addr;  // 字节2 [23:16]
    wire weD = byte_sel[3] & we & is_ram_addr;  // 字节3 [31:24]

    // RAM数据输出（组合逻辑）
    wire [31:0] ram_data_comb;

    // 字节0
    blk_mem_ram_byte ramA(
        .addra      (ram_addr),
        .clka       (ram_clk),
        .dina       (kickOff ? data_in[7:0]   : upg_dat[7:0]),
        .douta      (ram_data_comb[7:0]),
        .ena        (kickOff ? is_ram_addr : 1'b1),
        .wea        (kickOff ? weA : upg_wen)
    );

    // 字节1（修复：dina和wea）
    blk_mem_ram_byte ramB(
        .addra      (ram_addr),
        .clka       (ram_clk),
        .dina       (kickOff ? data_in[15:8]  : upg_dat[15:8]),
        .douta      (ram_data_comb[15:8]),
        .ena        (kickOff ? is_ram_addr : 1'b1),
        .wea        (kickOff ? weB : upg_wen)
    );

    // 字节2（修复：dina和wea）
    blk_mem_ram_byte ramC(
        .addra      (ram_addr),
        .clka       (ram_clk),
        .dina       (kickOff ? data_in[23:16] : upg_dat[23:16]),
        .douta      (ram_data_comb[23:16]),
        .ena        (kickOff ? is_ram_addr : 1'b1),
        .wea        (kickOff ? weC : upg_wen)
    );

    // 字节3（修复：dina和wea）
    blk_mem_ram_byte ramD(
        .addra      (ram_addr),
        .clka       (ram_clk),
        .dina       (kickOff ? data_in[31:24] : upg_dat[31:24]),
        .douta      (ram_data_comb[31:24]),
        .ena        (kickOff ? is_ram_addr : 1'b1),
        .wea        (kickOff ? weD : upg_wen)
    );

    // 读同步延迟：下一拍返回数据
    reg [31:0] data_out_reg;
    
    always @(posedge clk) begin
        if (kickOff && is_ram_addr)
            data_out_reg <= ram_data_comb;
        else
            data_out_reg <= 32'h0;
    end
    
    assign data_out = data_out_reg;

endmodule

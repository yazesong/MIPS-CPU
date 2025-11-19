`include "public.v" //这个需要把ROM_RAM/public.v合并至cpu整体的public.v中

module ram(
    // CPU读写接口
    input  wire                 clk,
    input  wire                 en,
    input  wire                 we,
    input  wire [`WordRange]    addr,
    input  wire [3:0]           byte_sel,
    input  wire [`WordRange]    data_in,
    output wire [`WordRange]    data_out,

    // UART编程接口
    input  wire                 upg_rst,
    input  wire                 upg_clk,
    input  wire                 upg_wen,
    input  wire [13:0]          upg_adr,
    input  wire [31:0]          upg_dat,
    input  wire                 upg_done
);

    // ========== 控制逻辑 ==========
    wire kickOff = upg_rst | (~upg_rst & upg_done);

    // ========== 地址译码 ==========
    // RAM地址范围：0x10000000 - 0x1000FFFF
    // 取低16位中的[15:2]作为RAM内部地址（14bits，寻址16K×4B）
    wire [13:0] ram_addr_internal = addr[15:2];
    
    // 检查是否在RAM地址范围内
    wire is_ram_addr = (`IS_RAM(addr)) && en;
    
    // ========== 字节写使能 ==========
    // 根据byte_sel和we信号生成各字节的写使能
    wire weA = byte_sel[0] & we & is_ram_addr;  // 字节0 [7:0]
    wire weB = byte_sel[1] & we & is_ram_addr;  // 字节1 [15:8]  改进
    wire weC = byte_sel[2] & we & is_ram_addr;  // 字节2 [23:16] 改进
    wire weD = byte_sel[3] & we & is_ram_addr;  // 字节3 [31:24] 改进

    // ========== 字节RAM实例 ==========
    // 每个BRAM存储一个字节，通过byte_sel选择
    
    wire [31:0] ram_data_comb;
    
    blk_mem_ram_byte ramA(
        .addra   (kickOff ? ram_addr_internal : upg_adr),
        .clka    (kickOff ? clk : upg_clk),
        .dina    (kickOff ? data_in[7:0]   : upg_dat[7:0]),      //改进
        .douta   (ram_data_comb[7:0]),
        .ena     (kickOff ? is_ram_addr : 1'b1),
        .wea     (kickOff ? weA : upg_wen)
    );
    
    blk_mem_ram_byte ramB(
        .addra   (kickOff ? ram_addr_internal : upg_adr),
        .clka    (kickOff ? clk : upg_clk),
        .dina    (kickOff ? data_in[15:8]  : upg_dat[15:8]),     //改进
        .douta   (ram_data_comb[15:8]),
        .ena     (kickOff ? is_ram_addr : 1'b1),
        .wea     (kickOff ? weB : upg_wen)                        //改进
    );
    
    blk_mem_ram_byte ramC(
        .addra   (kickOff ? ram_addr_internal : upg_adr),
        .clka    (kickOff ? clk : upg_clk),
        .dina    (kickOff ? data_in[23:16] : upg_dat[23:16]),    //改进
        .douta   (ram_data_comb[23:16]),
        .ena     (kickOff ? is_ram_addr : 1'b1),
        .wea     (kickOff ? weC : upg_wen)                        //改进
    );
    
    blk_mem_ram_byte ramD(
        .addra   (kickOff ? ram_addr_internal : upg_adr),
        .clka    (kickOff ? clk : upg_clk),
        .dina    (kickOff ? data_in[31:24] : upg_dat[31:24]),    //改进
        .douta   (ram_data_comb[31:24]),
        .ena     (kickOff ? is_ram_addr : 1'b1),
        .wea     (kickOff ? weD : upg_wen)                        //改进
    );

    // ========== 读同步管道（实现"下一拍返回"）==========
    reg [31:0] data_out_reg;
    
    always @(posedge clk) begin
        if (kickOff && is_ram_addr)
            data_out_reg <= ram_data_comb;
        else
            data_out_reg <= 32'h0;
    end
    
    assign data_out = data_out_reg;

endmodule

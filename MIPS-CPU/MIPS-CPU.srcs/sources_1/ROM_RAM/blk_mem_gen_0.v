`timescale 1ns / 1ps

module blk_mem_gen_0 (
    input  wire [13:0] addra,
    input  wire        clka,
    input  wire [31:0] dina,
    output wire [31:0] douta,
    input  wire        wea
);

    reg [31:0] memory [0:16383];
    reg [31:0] data_reg;
    integer i;
    assign douta = data_reg;

    initial begin
        for (i = 0; i < 16384; i = i + 1)
            memory[i] = 32'hDEADBEEF;
        
        memory[0] = 32'h00400000;
        memory[1] = 32'h20000008;
        memory[2] = 32'h8C080000;
    end

    always @(posedge clka) begin
        // ✅ 修复：区分读写操作
        if (wea) begin
            memory[addra] <= dina;
            data_reg <= dina;  // 写时输出新值
        end else begin
            data_reg <= memory[addra];  // 读时输出该地址的值
        end
    end

endmodule

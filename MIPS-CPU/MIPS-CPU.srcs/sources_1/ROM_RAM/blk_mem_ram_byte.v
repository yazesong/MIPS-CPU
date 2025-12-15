`timescale 1ns / 1ps

module blk_mem_ram_byte (
    input  wire [13:0] addra,
    input  wire        clka,
    input  wire [7:0]  dina,
    output wire [7:0]  douta,
    input  wire        ena,
    input  wire        wea
);

    reg [7:0] memory [0:16383];
    reg [7:0] data_reg;
    integer i;
    assign douta = data_reg;

    initial begin
        for (i = 0; i < 16384; i = i + 1)
            memory[i] = 8'h00;
    end

    always @(posedge clka) begin
        if (ena) begin
            // ✅ 修复：写前读行为（Write-First）
            // 写入时，data_reg 读的是更新前的旧值
            // 读出时，data_reg 读的是该地址的值
            if (wea) begin
                memory[addra] <= dina;
                data_reg <= dina;  // ✅ 写时直接输出新值（更符合实际Block RAM）
            end else begin
                data_reg <= memory[addra];  // 读模式
            end
        end
    end

endmodule

`timescale 1ns / 1ps

module rom_ram_sim();
    
    // ==================== ROM 信号 ====================
    reg clk;
    reg [31:0] rom_addr;
    wire [31:0] rom_data_out;
    
    // ==================== RAM 信号 ====================
    reg ram_en, ram_we;
    reg [31:0] ram_addr;
    reg [3:0] ram_byte_sel;
    reg [31:0] ram_data_in;
    wire [31:0] ram_data_out;
    
    // ==================== UART 编程信号 ====================
    reg upg_rst, upg_clk, upg_wen, upg_done;
    reg [13:0] upg_adr;
    reg [31:0] upg_dat;
    
    // ==================== 例化 ROM 模块 ====================
    rom u_rom(
        .clk(clk),
        .addr(rom_addr),
        .data_out(rom_data_out),
        .upg_rst(upg_rst),
        .upg_clk(upg_clk),
        .upg_wen(upg_wen),
        .upg_adr(upg_adr),
        .upg_dat(upg_dat),
        .upg_done(upg_done)
    );
    
    // ==================== 例化 RAM 模块 ====================
    ram u_ram(
        .clk(clk),
        .eable(ram_en),
        .we(ram_we),
        .addr(ram_addr),
        .byte_sel(ram_byte_sel),
        .data_in(ram_data_in),
        .data_out(ram_data_out),
        .upg_rst(upg_rst),
        .upg_clk(upg_clk),
        .upg_wen(upg_wen),
        .upg_adr(upg_adr),
        .upg_dat(upg_dat),
        .upg_done(upg_done)
    );
    
    // ==================== 生成波形文件 ====================
    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, rom_ram_sim);
    end
    
    // ==================== 主时钟生成（100MHz） ====================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns 周期
    end
    
    // ==================== 升级时钟生成（20MHz） ====================
    // ✅ 新增：生成 upg_clk
    initial begin
        upg_clk = 0;
        forever #25 upg_clk = ~upg_clk;  // 50ns 周期
    end
    
    // ==================== 初始化和测试过程 ====================
    initial begin
        // 初始化所有信号
        upg_rst = 0;      // ✅ 修改：初始为0（运行模式）
        upg_wen = 0;
        upg_done = 1;     // ✅ 修改：初始为1
        upg_adr = 14'b0;
        upg_dat = 32'h0;
        
        rom_addr = 32'h0;
        ram_en = 0;
        ram_we = 0;
        ram_addr = 32'h0;
        ram_byte_sel = 4'b0000;
        ram_data_in = 32'h0;
        
        // 等待系统稳定
        #100;
        
        // ==================== 第1组测试：ROM读取 ====================
        $display("\n========== TEST 1: ROM READ ==========");
        $display("Time: %t, Test ROM read operation", $time);
        #100;
        
        // 读ROM地址0x00000000
        $display("Time: %t, Reading ROM address 0x00000000", $time);
        rom_addr = 32'h0000_0000;
        @(posedge clk);  // ✅ 等待时钟上升沿
        #2;
        $display("Time: %t, ROM[0x00000000] = 0x%h (expected: 0x00400000)", $time, rom_data_out);
        
        // 读ROM地址0x00000004
        @(posedge clk);
        #2;
        rom_addr = 32'h0000_0004;
        @(posedge clk);
        #2;
        $display("Time: %t, ROM[0x00000004] = 0x%h (expected: 0x20000008)", $time, rom_data_out);
        
        // 读ROM地址0x00000008
        @(posedge clk);
        #2;
        rom_addr = 32'h0000_0008;
        @(posedge clk);
        #2;
        $display("Time: %t, ROM[0x00000008] = 0x%h (expected: 0x8C080000)", $time, rom_data_out);
        
        // ==================== 第2组测试：RAM字写 (SW) ====================
        $display("\n========== TEST 2: RAM WORD WRITE (SW) ==========");
        $display("Time: %t, Test RAM word write operation", $time);
        #100;
        
        $display("Time: %t, Writing to RAM[0x80000000] <= 0xABCD1234", $time);
        ram_en = 1;
        ram_we = 1;
        ram_addr = 32'h8000_0000;
        ram_data_in = 32'hABCD_1234;
        ram_byte_sel = 4'b1111;  // 写入全部4个字节
        @(posedge clk);
        #2;
        
        // ==================== 第3组测试：RAM字读 (LW) ====================
        $display("\n========== TEST 3: RAM WORD READ (LW) ==========");
        $display("Time: %t, Test RAM word read operation", $time);
        
        // 准备读取
        ram_we = 0;
        ram_addr = 32'h8000_0000;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000000] = 0x%h (expected: 0xABCD1234)", $time, ram_data_out);
        
        // ==================== 第4组测试：RAM半字写 (SH) ====================
        $display("\n========== TEST 4: RAM HALF WORD WRITE (SH) ==========");
        $display("Time: %t, Test RAM half-word write operation", $time);
        #100;
        
        $display("Time: %t, Writing to RAM[0x80000004] <= 0x0000FFFF (byte_sel=0011)", $time);
        ram_we = 1;
        ram_addr = 32'h8000_0004;
        ram_data_in = 32'h0000_FFFF;
        ram_byte_sel = 4'b0011;  // 写入字节0和1（低16位）
        @(posedge clk);
        #2;
        
        // 立即读取验证
        ram_we = 0;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000004] = 0x%h (expected: 0x0000FFFF)", $time, ram_data_out);
        
        // ==================== 第5组测试：RAM字节写 (SB) ====================
        $display("\n========== TEST 5: RAM BYTE WRITE (SB) ==========");
        $display("Time: %t, Test RAM byte write operation", $time);
        #100;
        
        $display("Time: %t, Writing to RAM[0x80000008] <= 0x000000AA (byte_sel=0001)", $time);
        ram_we = 1;
        ram_addr = 32'h8000_0008;
        ram_data_in = 32'h0000_00AA;
        ram_byte_sel = 4'b0001;  // 只写字节0
        @(posedge clk);
        #2;
        
        // 立即读取验证
        ram_we = 0;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000008] = 0x%h (expected: 0x000000AA)", $time, ram_data_out);
        
        // ==================== 第6组测试：RAM多字节写入 ====================
        $display("\n========== TEST 6: RAM MULTI-BYTE WRITE ==========");
        $display("Time: %t, Test RAM multi-byte write operation", $time);
        #100;
        
        // 写入地址 0x80000010，只写高两个字节（字节2和3）
        $display("Time: %t, Writing to RAM[0x80000010] <= 0x12340000 (byte_sel=1100)", $time);
        ram_we = 1;
        ram_addr = 32'h8000_0010;
        ram_data_in = 32'h1234_0000;
        ram_byte_sel = 4'b1100;  // 写入字节2和3（高16位）
        @(posedge clk);
        #2;
        
        // 读取验证
        ram_we = 0;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000010] = 0x%h (expected: 0x12340000)", $time, ram_data_out);
        
        // ==================== 第7组测试：连续读写 ====================
        $display("\n========== TEST 7: SEQUENTIAL READ/WRITE ==========");
        $display("Time: %t, Test sequential read/write operations", $time);
        #100;
        
        // 写入4个不同的地址
        for (integer i = 0; i < 4; i = i + 1) begin
            ram_we = 1;
            ram_addr = 32'h8000_0020 + (i << 2);
            ram_data_in = 32'h1000_0000 * (i + 1);
            ram_byte_sel = 4'b1111;
            $display("Time: %t, Writing to RAM[0x%h] <= 0x%h", $time, ram_addr, ram_data_in);
            @(posedge clk);
            #2;
        end
        
        // 读取验证
        ram_we = 0;
        #100;
        $display("Time: %t, Reading back sequential data", $time);
        
        for (integer i = 0; i < 4; i = i + 1) begin
            ram_addr = 32'h8000_0020 + (i << 2);
            @(posedge clk);
            #2;
            $display("Time: %t, RAM[0x%h] = 0x%h (expected: 0x%h)", 
                     $time, ram_addr, ram_data_out, 32'h1000_0000 * (i + 1));
        end
        
        // ==================== 第8组测试：地址边界检查 ====================
        $display("\n========== TEST 8: ADDRESS BOUNDARY CHECK ==========");
        $display("Time: %t, Test address boundary conditions", $time);
        #100;
        
        // 测试有效地址 0x80000000
        $display("Time: %t, Testing valid address 0x80000000", $time);
        ram_we = 1;
        ram_en = 1;
        ram_addr = 32'h8000_0000;
        ram_data_in = 32'hAAAA_AAAA;
        ram_byte_sel = 4'b1111;
        @(posedge clk);
        #2;
        
        // 测试无效地址 0x7FFF0000（高16位不是0x8000）
        $display("Time: %t, Testing invalid address 0x7FFF0000 (should not write)", $time);
        ram_en = 1;
        ram_addr = 32'h7FFF_0000;
        ram_data_in = 32'hBBBB_BBBB;
        @(posedge clk);
        #2;
        
        // 读取有效地址验证
        ram_we = 0;
        ram_en = 1;
        ram_addr = 32'h8000_0000;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000000] = 0x%h (should be 0xAAAAAAAA)", $time, ram_data_out);
        
        // ==================== 第9组测试：禁用RAM ====================
        $display("\n========== TEST 9: RAM DISABLE TEST ==========");
        $display("Time: %t, Test RAM enable/disable control", $time);
        #100;
        
        // 禁用RAM，写入应该被忽略
        $display("Time: %t, Writing with RAM disabled (eable=0)", $time);
        ram_en = 0;  // 禁用
        ram_we = 1;
        ram_addr = 32'h8000_0030;
        ram_data_in = 32'hDEAD_BEEF;
        ram_byte_sel = 4'b1111;
        @(posedge clk);
        #2;
        
        // 启用RAM，读取之前写入的数据
        $display("Time: %t, Reading with RAM enabled", $time);
        ram_en = 1;
        ram_we = 0;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000030] = 0x%h (expected: 0x00000000, not modified)", 
                 $time, ram_data_out);
        
        // ==================== 第10组测试：UART升级模式 ====================
        $display("\n========== TEST 10: UART UPGRADE MODE ==========");
        $display("Time: %t, Test UART upgrade mode", $time);
        #100;
        
        // 进入升级模式
        $display("Time: %t, Entering upgrade mode (upg_rst=1)", $time);
        upg_rst = 1;
        upg_done = 0;
        @(posedge upg_clk);
        #2;
        
        // 通过升级接口写入数据到RAM地址0
        $display("Time: %t, Writing via upgrade interface: upg_adr=0, upg_dat=0x11223344", $time);
        upg_wen = 1;
        upg_adr = 14'h0000;
        upg_dat = 32'h1122_3344;
        @(posedge upg_clk);
        #2;
        
        // 写入第二个地址
        $display("Time: %t, Writing via upgrade interface: upg_adr=1, upg_dat=0x55667788", $time);
        upg_adr = 14'h0001;
                upg_dat = 32'h5566_7788;
        @(posedge upg_clk);
        #2;
        
        // 写入第三个地址
        $display("Time: %t, Writing via upgrade interface: upg_adr=2, upg_dat=0x99AABBCC", $time);
        upg_adr = 14'h0002;
        upg_dat = 32'h99AA_BBCC;
        @(posedge upg_clk);
        #2;
        
        // 退出升级模式，进入运行模式
        $display("Time: %t, Exiting upgrade mode (upg_rst=0, upg_done=1)", $time);
        upg_rst = 0;
        upg_done = 1;
        upg_wen = 0;
        @(posedge clk);
        #2;
        
        // 在运行模式下读取升级写入的数据
        $display("Time: %t, Reading upgrade data in run mode", $time);
        ram_en = 1;
        ram_we = 0;
        ram_addr = 32'h8000_0000;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000000] = 0x%h (should be 0x11223344 from upgrade)", $time, ram_data_out);
        
        ram_addr = 32'h8000_0004;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000004] = 0x%h (should be 0x55667788 from upgrade)", $time, ram_data_out);
        
        ram_addr = 32'h8000_0008;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000008] = 0x%h (should be 0x99AABBCC from upgrade)", $time, ram_data_out);
        
        // ==================== 第11组测试：ROM升级模式 ====================
        $display("\n========== TEST 11: ROM UPGRADE MODE ==========");
        $display("Time: %t, Test ROM upgrade functionality", $time);
        #100;
        
        // 进入升级模式
        $display("Time: %t, Entering ROM upgrade mode (upg_rst=1)", $time);
        upg_rst = 1;
        upg_done = 0;
        @(posedge upg_clk);
        #2;
        
        // 通过升级接口写入ROM数据
        $display("Time: %t, Writing to ROM via upgrade: upg_adr=0, upg_dat=0xDEADBEEF", $time);
        upg_wen = 1;
        upg_adr = 14'h0000;
        upg_dat = 32'hDEAD_BEEF;
        @(posedge upg_clk);
        #2;
        
        $display("Time: %t, Writing to ROM via upgrade: upg_adr=1, upg_dat=0xCAFEBABE", $time);
        upg_adr = 14'h0001;
        upg_dat = 32'hCAFE_BABE;
        @(posedge upg_clk);
        #2;
        
        // 退出升级模式
        $display("Time: %t, Exiting ROM upgrade mode", $time);
        upg_rst = 0;
        upg_done = 1;
        upg_wen = 0;
        @(posedge clk);
        #2;
        
        // 在运行模式下读取ROM数据
        $display("Time: %t, Reading ROM data in run mode", $time);
        rom_addr = 32'h0000_0000;
        @(posedge clk);
        #2;
        $display("Time: %t, ROM[0x00000000] = 0x%h (should be 0xDEADBEEF from upgrade)", $time, rom_data_out);
        
        rom_addr = 32'h0000_0004;
        @(posedge clk);
        #2;
        $display("Time: %t, ROM[0x00000004] = 0x%h (should be 0xCAFEBABE from upgrade)", $time, rom_data_out);
        
                // ==================== 第12组测试：混合读写 ====================
        $display("\n========== TEST 12: MIXED READ/WRITE PATTERN ==========");
        $display("Time: %t, Test mixed RAM read/write patterns", $time);
        #100;
        
        begin
            integer write_data;
            integer test_addr;
            for (integer i = 0; i < 3; i = i + 1) begin
                // 写
                write_data = 32'hF0000000 + (i * 32'h00010000);
                test_addr = 32'h80000040 + (i * 4);
                ram_we = 1;
                ram_en = 1;
                ram_addr = test_addr;
                ram_data_in = write_data;
                ram_byte_sel = 4'b1111;
                $display("Time: %t, Writing to RAM[0x%08h] <= 0x%08h", $time, test_addr, write_data);
                @(posedge clk);
                #2;
                
                // 读
                ram_we = 0;
                @(posedge clk);
                #2;
                $display("Time: %t, RAM[0x%08h] = 0x%08h", $time, test_addr, ram_data_out);
            end
        end
        
        // ==================== 第13组测试：字节粒度写入验证 ====================
        $display("\n========== TEST 13: BYTE GRANULARITY VERIFICATION ==========");
        $display("Time: %t, Test byte granularity write/read", $time);
        #100;
        
        // 先写入一个完整的字
        ram_we = 1;
        ram_en = 1;
        ram_addr = 32'h80000050;
        ram_data_in = 32'h01020304;
        ram_byte_sel = 4'b1111;
        $display("Time: %t, Initial write: RAM[0x80000050] <= 0x01020304", $time);
        @(posedge clk);
        #2;
        
        // 只修改字节0
        ram_data_in = 32'h000000AA;
        ram_byte_sel = 4'b0001;
        $display("Time: %t, Partial write (byte 0): RAM[0x80000050] <= 0x000000AA", $time);
        @(posedge clk);
        #2;
        
        // 读取验证（应该是 0x010203AA）
        ram_we = 0;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000050] = 0x%08h (expected: 0x010203AA)", $time, ram_data_out);
        
        // 只修改字节1
        ram_we = 1;
        ram_data_in = 32'h0000BB00;
        ram_byte_sel = 4'b0010;
        $display("Time: %t, Partial write (byte 1): RAM[0x80000050] <= 0x0000BB00", $time);
        @(posedge clk);
        #2;
        
        // 读取验证（应该是 0x0102BBAA）
        ram_we = 0;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000050] = 0x%08h (expected: 0x0102BBAA)", $time, ram_data_out);
        
        // 只修改字节2和3
        ram_we = 1;
        ram_data_in = 32'hCCDD0000;
        ram_byte_sel = 4'b1100;
        $display("Time: %t, Partial write (bytes 2-3): RAM[0x80000050] <= 0xCCDD0000", $time);
        @(posedge clk);
        #2;
        
        // 读取验证（应该是 0xCCDDBBAA）
        ram_we = 0;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x80000050] = 0x%08h (expected: 0xCCDDBBAA)", $time, ram_data_out);
        
        // ==================== 第14组测试：地址掩码验证 ====================
        $display("\n========== TEST 14: ADDRESS MASKING VERIFICATION ==========");
        $display("Time: %t, Test address high 16 bits checking", $time);
        #100;
        
        // 有效地址范围：0x8000_0000 - 0x8000_FFFF
        ram_we = 1;
        ram_en = 1;
        
        $display("Time: %t, Valid address: 0x8000FFFC", $time);
        ram_addr = 32'h8000FFFC;
        ram_data_in = 32'hAAAAAAAA;
        ram_byte_sel = 4'b1111;
        @(posedge clk);
        #2;
        
        // 无效地址：0x8001_0000
        $display("Time: %t, Invalid address: 0x80010000 (high 16 bits != 0x8000)", $time);
        ram_addr = 32'h80010000;
        ram_data_in = 32'hBBBBBBBB;
        @(posedge clk);
        #2;
        
        // 读取有效地址验证写入成功
        ram_we = 0;
        ram_addr = 32'h8000FFFC;
        @(posedge clk);
        #2;
        $display("Time: %t, RAM[0x8000FFFC] = 0x%08h (should contain valid data)", $time, ram_data_out);
        
        // ==================== 第15组测试：长时序验证 ====================
        $display("\n========== TEST 15: EXTENDED TIMING VERIFICATION ==========");
        $display("Time: %t, Test extended read/write timing", $time);
        #100;
        
        // 写入模式
        $display("Time: %t, Starting burst write", $time);
        begin
            integer burst_addr;
            integer burst_data;
            for (integer i = 0; i < 8; i = i + 1) begin
                burst_addr = 32'h80000060 + (i * 4);
                burst_data = 32'h10000000 + i;
                ram_we = 1;
                ram_addr = burst_addr;
                ram_data_in = burst_data;
                ram_byte_sel = 4'b1111;
                @(posedge clk);
                #2;
            end
        end
        
        // 读取模式
        $display("Time: %t, Starting burst read", $time);
        ram_we = 0;
        begin
            integer read_addr;
            for (integer i = 0; i < 8; i = i + 1) begin
                read_addr = 32'h80000060 + (i * 4);
                ram_addr = read_addr;
                @(posedge clk);
                #2;
                if (i > 0) begin
                    $display("Time: %t, RAM[0x%08h] = 0x%08h", $time, read_addr, ram_data_out);
                end
            end
        end
        
        // ==================== 测试完成 ====================
        $display("\n========== ALL TESTS COMPLETED ==========");
        $display("Time: %t, Simulation finished successfully", $time);
        
        #100;
        
        // 强制结束仿真
        $display("Time: %t, Stopping simulation", $time);
        $finish;  // ✅ 改用 $finish 代替 $stop
        
    end

endmodule



# ROM/RAM 模块设计文档

## 概述

本文档描述Minisys-1A CPU的ROM和RAM存储器模块的设计和实现。

- ROM容量：64KB (16K×4B)，只读，用于存储程序
- RAM容量：64KB (16K×4B)，读写，用于数据存储
- 都支持UART在线编程和字节级访问控制

---

## 地址映射

```
0x00000000 ~ 0x0000FFFF  →  ROM (64KB) 指令存储
0x80000000 ~ 0x8000FFFF  →  RAM (64KB) 数据存储
0xFFFF0000 ~ 0xFFFFFFFF  →  IO  (64KB) 外设映射
```

### 地址位宽分配

```
ROM/RAM地址: addr[15:2] → 14bits → 寻址16K个32位字

字节选择: byte_sel[3:0]
    [0] = 字节0 [7:0]
    [1] = 字节1 [15:8]
    [2] = 字节2 [23:16]
    [3] = 字节3 [31:24]
```

---

## ROM模块

### 端口说明

```verilog
module rom(
    // CPU读接口
    input wire clk,
    input wire[31:0] addr,           // 来自CPU PC
    output wire[31:0] data_out,      // 返回指令数据
    
    // UART编程接口
    input wire upg_rst,              // UART重置
    input wire upg_clk,              // UART时钟
    input wire upg_wen,              // UART写使能
    input wire[13:0] upg_adr,        // UART上传地址
    input wire[31:0] upg_dat,        // UART上传数据
    input wire upg_done              // UART编程完成标志
);
```

### 工作模式

1. **UART编程模式** (upg_done=0)：UART将程序数据写入ROM
2. **CPU运行模式** (upg_done=1)：CPU从ROM读取指令执行

### 读同步延迟

实现"上一拍锁存地址，下一拍返回数据"，有利于时序收敛：

```verilog
// 组合读出
wire [31:0] rom_data_comb;
blk_mem_gen_0 u_rom(...);

// 寄存器延迟
reg [31:0] data_out_reg;
always @(posedge clk) begin
    if (kickOff)
        data_out_reg <= rom_data_comb;
    else
        data_out_reg <= 32'h0;
end

assign data_out = data_out_reg;
```

---

## RAM模块

### 端口说明

```verilog
module ram(
    // CPU总线接口
    input wire clk,
    input wire eable,                // 读写使能
    input wire we,                   // 写使能
    input wire[31:0] addr,           // 数据地址（检查[31:16]==0x8000）
    input wire[3:0] byte_sel,        // 字节选择
    input wire[31:0] data_in,        // 写入数据
    output wire[31:0] data_out,      // 读出数据
    
    // UART编程接口
    input wire upg_rst,
    input wire upg_clk,
    input wire upg_wen,
    input wire[13:0] upg_adr,
    input wire[31:0] upg_dat,
    input wire upg_done
);
```

### 地址范围检查

```verilog
wire is_ram_addr = ((addr[31:16] == 16'h8000) && eable);
```

只有地址在0x8000_0000 ~ 0x8000_FFFF范围内时，RAM才响应读写。

### 字节写控制

RAM由4个8位BRAM组成(ramA/B/C/D)，对应32位数据的4个字节。

```verilog
wire weA = byte_sel[0] & we & is_ram_addr;  // 字节0 [7:0]
wire weB = byte_sel[1] & we & is_ram_addr;  // 字节1 [15:8]
wire weC = byte_sel[2] & we & is_ram_addr;  // 字节2 [23:16]
wire weD = byte_sel[3] & we & is_ram_addr;  // 字节3 [31:24]
```

支持的访问方式：

```
SW (字写)   : byte_sel = 4'b1111
SH (半字写) : addr[1]=0→4'b0011, addr[1]=1→4'b1100
SB (字节写) : addr[1:0]=00→4'b0001, 01→4'b0010, 10→4'b0100, 11→4'b1000
LW (字读)   : byte_sel = 4'b1111
LH/LHU      : addr[1]=0→读字节0,1, addr[1]=1→读字节2,3
LB/LBU      : addr[1:0]决定读哪个字节
```

### UART数据分配

关键改进：上传32bit数据时，按字节正确分配到4个BRAM

```verilog
ramA: dina = upg_dat[7:0]      // 低8位
ramB: dina = upg_dat[15:8]     // 次8位 (修复：之前是upg_dat[7:0])
ramC: dina = upg_dat[23:16]    // 第三8位 (修复：之前是upg_dat[7:0])
ramD: dina = upg_dat[31:24]    // 高8位 (修复：之前是upg_dat[7:0])
```

### 读同步延迟

与ROM相同，实现下一拍返回数据：

```verilog
reg [31:0] data_out_reg;

always @(posedge clk) begin
    if (kickOff && is_ram_addr)
        data_out_reg <= ram_data_comb;
    else
        data_out_reg <= 32'h0;
end

assign data_out = data_out_reg;
```

---

## Public.v 地址定义

```verilog
// 内存映射地址范围
`define ROM_BASE_ADDR       32'h00000000
`define ROM_SIZE            32'h00010000  // 64KB

`define RAM_BASE_ADDR       32'h80000000
`define RAM_SIZE            32'h00010000  // 64KB

`define IO_BASE_ADDR        32'hFFFF0000
`define IO_SIZE             32'h00010000  // 64KB
```

---

## 关键改进点

1. **地址映射清晰**：ROM和RAM不再冲突（原来都在0x0000，现在RAM在0x8000）
2. **字节写修复**：ramB/C/D的wea信号现在正确对应weB/weC/weD（原来都是weA）
3. **UART数据修复**：ramB/C/D现在接收正确的upg_dat字节（原来都是upg_dat[7:0]）
4. **读同步延迟**：实现下一拍返回，符合文档"上一拍锁存地址，下一拍返回数据"的要求

---

## 使用注意

1. arbitration.v 需要修改1行：将RAM地址检查从0x0000改为0x8000
2. ROM通过.coe文件初始化，UART编程完成后自动切换到CPU运行模式
3. RAM支持动态读写，字节粒度可控制

```

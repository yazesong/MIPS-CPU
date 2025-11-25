#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VCD波形绘制工具 - 改进版本（修复字体超出问题）
用于解析Verilog VCD文件并生成波形图
"""

import re
from collections import defaultdict
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Rectangle
import numpy as np

# ✅ 设置中文字体（如果需要）
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'SimHei', 'Arial Unicode MS']
plt.rcParams['axes.unicode_minus'] = False

class VCDParser:
    def __init__(self, filename):
        self.filename = filename
        self.timescale = 1
        self.signals = {}  # {signal_name: signal_id}
        self.signal_data = defaultdict(list)  # {signal_id: [(time, value), ...]}
        self.signal_width = {}  # {signal_id: width}
        self.parse()

    def parse(self):
        """解析VCD文件"""
        with open(self.filename, 'r') as f:
            content = f.read()

        lines = content.split('\n')
        
        in_header = True
        current_time = 0
        scope_stack = []
        var_definitions = {}

        i = 0
        while i < len(lines):
            line = lines[i].strip()
            i += 1

            if in_header:
                if line.startswith('$timescale'):
                    for j in range(i, min(i+5, len(lines))):
                        val = lines[j].strip()
                        if val and val != '$end':
                            try:
                                self.timescale = int(val.split()[0])
                            except:
                                pass
                            break

                elif line.startswith('$scope'):
                    parts = line.split()
                    if len(parts) >= 3:
                        scope_name = parts[-1]
                        scope_stack.append(scope_name)

                elif line.startswith('$upscope'):
                    if scope_stack:
                        scope_stack.pop()

                elif line.startswith('$var'):
                    parts = line.split()
                    if len(parts) >= 5:
                        signal_type = parts[1]
                        try:
                            width = int(parts[2])
                        except:
                            width = 1
                        signal_id = parts[3]
                        signal_name = parts[4]
                        
                        full_name = '.'.join(scope_stack + [signal_name])
                        
                        self.signals[signal_name] = signal_id
                        self.signals[full_name] = signal_id
                        self.signal_width[signal_id] = width
                        var_definitions[signal_id] = (signal_name, width)

                elif line == '$enddefinitions' or line == '$enddefinitions $end':
                    in_header = False

            else:
                if line.startswith('#'):
                    try:
                        current_time = int(line[1:])
                    except:
                        pass

                elif line and not line.startswith('$'):
                    if len(line) > 1:
                        if line[0] in ['0', '1', 'x', 'z', 'X', 'Z']:
                            value = line[0]
                            signal_id = line[1:].strip()
                            if signal_id:
                                self.signal_data[signal_id].append((current_time, value))

                        elif line[0] == 'b' or line[0] == 'B':
                            parts = line.split()
                            if len(parts) >= 2:
                                value = parts[0][1:]
                                signal_id = parts[1].strip()
                                if signal_id:
                                    self.signal_data[signal_id].append((current_time, value))

    def list_all_signals(self):
        """列出所有信号"""
        return sorted(set(self.signals.keys()))

    def get_signal_by_pattern(self, pattern):
        """通过正则表达式获取信号"""
        regex = re.compile(pattern, re.IGNORECASE)
        return {name: sid for name, sid in self.signals.items() if regex.search(name)}

    def get_signal_value_at_time(self, signal_id, time):
        """获取特定时刻的信号值"""
        if signal_id not in self.signal_data:
            return None

        data = self.signal_data[signal_id]
        for i in range(len(data)-1, -1, -1):
            if data[i][0] <= time:
                return data[i][1]
        return data[0][1] if data else None


class VCDPlotter:
    def __init__(self, vcd_parser):
        self.parser = vcd_parser
        self.colors = {
            '0': '#FF6B6B',  # 红色
            '1': '#4ECDC4',  # 青色
            'x': '#95A5A6',  # 灰色
            'z': '#F39C12',  # 橙色
            'X': '#95A5A6',
            'Z': '#F39C12'
        }

    def plot_signal(self, signal_id, ax, y_pos, signal_name, height=0.8):
        """绘制单个信号的波形"""
        if signal_id not in self.parser.signal_data:
            return

        data = self.parser.signal_data[signal_id]
        if not data:
            return

        width = self.parser.signal_width.get(signal_id, 1)
        is_multibit = width > 1

        prev_time = data[0][0]
        prev_value = data[0][1]

        for idx, (current_time, current_value) in enumerate(data):
            if idx == 0:
                continue

            if current_time > prev_time:
                if is_multibit:
                    color = '#3498DB'
                    rect = Rectangle((prev_time, y_pos - height/2), 
                                   current_time - prev_time, height,
                                   facecolor=color, edgecolor='black', linewidth=0.5, alpha=0.7)
                    ax.add_patch(rect)

                    try:
                        hex_value = hex(int(prev_value, 2))
                    except:
                        hex_value = prev_value

                    if current_time - prev_time > 10000:
                        ax.text((prev_time + current_time) / 2, y_pos, hex_value,
                               ha='center', va='center', fontsize=5, fontweight='bold')
                else:
                    color = self.colors.get(prev_value, '#95A5A6')
                    rect = Rectangle((prev_time, y_pos - height/2),
                                   current_time - prev_time, height,
                                   facecolor=color, edgecolor='black', linewidth=0.5, alpha=0.8)
                    ax.add_patch(rect)

                    if current_time - prev_time > 5000:
                        ax.text((prev_time + current_time) / 2, y_pos, prev_value,
                               ha='center', va='center', fontsize=6, fontweight='bold', color='white')

                ax.plot([current_time, current_time], [y_pos - height/2, y_pos + height/2],
                       'k-', linewidth=1)

            prev_time = current_time
            prev_value = current_value

        if data:
            final_time = max(t[0] for t in data) + (data[-1][0] - data[-2][0] if len(data) > 1 else 10000)
            if is_multibit:
                color = '#3498DB'
                rect = Rectangle((prev_time, y_pos - height/2),
                               final_time - prev_time, height,
                               facecolor=color, edgecolor='black', linewidth=0.5, alpha=0.7)
                ax.add_patch(rect)
                try:
                    hex_value = hex(int(prev_value, 2))
                except:
                    hex_value = prev_value
                if final_time - prev_time > 10000:
                    ax.text((prev_time + final_time) / 2, y_pos, hex_value,
                           ha='center', va='center', fontsize=5, fontweight='bold')
            else:
                color = self.colors.get(prev_value, '#95A5A6')
                rect = Rectangle((prev_time, y_pos - height/2),
                               final_time - prev_time, height,
                               facecolor=color, edgecolor='black', linewidth=0.5, alpha=0.8)
                ax.add_patch(rect)
                if final_time - prev_time > 5000:
                    ax.text((prev_time + final_time) / 2, y_pos, prev_value,
                           ha='center', va='center', fontsize=6, fontweight='bold', color='white')

    def plot_signals(self, signal_patterns, title="VCD Waveform", output_file=None, 
                    time_range=None, signal_labels=None):
        """
        绘制多个信号的波形

        Args:
            signal_patterns: 信号名称列表或正则表达式模式列表
            title: 图表标题
            output_file: 输出文件名
            time_range: 时间范围 (start_time, end_time)
            signal_labels: 自定义信号标签字典 {signal_name: short_label}
        """
        signals_to_plot = {}

        for pattern in signal_patterns:
            if pattern in self.parser.signals:
                signals_to_plot[pattern] = self.parser.signals[pattern]
            else:
                matched = self.parser.get_signal_by_pattern(pattern)
                signals_to_plot.update(matched)

        if not signals_to_plot:
            print(f"未找到匹配的信号: {signal_patterns}")
            return

        all_times = []
        for signal_id in signals_to_plot.values():
            if signal_id in self.parser.signal_data:
                times = [t[0] for t in self.parser.signal_data[signal_id]]
                all_times.extend(times)

        if not all_times:
            print("没有信号数据")
            return

        min_time = min(all_times)
        max_time = max(all_times)

        if time_range:
            min_time = max(min_time, time_range[0])
            max_time = min(max_time, time_range[1])

        # ✅ 改进：根据信号数量动态调整图表大小
        num_signals = len(signals_to_plot)
        fig_height = max(8, num_signals * 0.7)
        fig, ax = plt.subplots(figsize=(18, fig_height))

        # 绘制信号
        for idx, (signal_name, signal_id) in enumerate(sorted(signals_to_plot.items())):
            y_pos = num_signals - idx - 1
            self.plot_signal(signal_id, ax, y_pos, signal_name)

        # 设置坐标轴
        ax.set_xlim(min_time, max_time)
        ax.set_ylim(-1, num_signals)
        ax.set_xlabel('Time (ps)', fontsize=11, fontweight='bold')
        ax.set_title(title, fontsize=13, fontweight='bold', pad=20)

        # ✅ 改进：Y轴标签处理
        signal_names = list(sorted(signals_to_plot.keys()))
        
        # 简化长的信号名（只保留最后一部分）
        if signal_labels:
            short_labels = [signal_labels.get(name, name.split('.')[-1]) for name in signal_names]
        else:
            short_labels = [name.split('.')[-1] for name in signal_names]
        
        ax.set_yticks(range(num_signals))
        ax.set_yticklabels(short_labels[::-1], fontsize=9, family='monospace')

        # 添加网格
        ax.grid(True, axis='x', alpha=0.3, linestyle='--')
        ax.set_axisbelow(True)

        # 添加图例
        legend_elements = [
            mpatches.Patch(facecolor='#FF6B6B', edgecolor='black', label='0 (Low)'),
            mpatches.Patch(facecolor='#4ECDC4', edgecolor='black', label='1 (High)'),
            mpatches.Patch(facecolor='#95A5A6', edgecolor='black', label='X (Unknown)'),
            mpatches.Patch(facecolor='#F39C12', edgecolor='black', label='Z (High-Z)'),
            mpatches.Patch(facecolor='#3498DB', edgecolor='black', label='Multi-bit'),
        ]
        ax.legend(handles=legend_elements, loc='upper right', fontsize=9)

        # ✅ 改进：使用tight_layout和subplots_adjust确保没有内容被裁剪
        plt.tight_layout()
        plt.subplots_adjust(left=0.15, right=0.95, top=0.93, bottom=0.08)

        if output_file:
            plt.savefig(output_file, dpi=300, bbox_inches='tight', pad_inches=0.3)
            print(f"✅ 波形已保存到: {output_file}")
        else:
            plt.show()

        plt.close()
        return fig, ax


def main():
    """主函数"""
    vcd_file = 'sim.vcd'
    print(f"正在解析VCD文件: {vcd_file}")
    parser = VCDParser(vcd_file)

    print(f"找到 {len(parser.signals)} 个信号")
    
    all_signals = parser.list_all_signals()
    print("\n可用的信号:")
    for name in all_signals[:30]:
        print(f"  - {name}")
    if len(all_signals) > 30:
        print(f"  ... 还有 {len(all_signals) - 30} 个信号")

    plotter = VCDPlotter(parser)

    # ✅ 定义信号标签映射（简化长名称）
    labels = {
        'rom_addr': 'rom_addr',
        'rom_data_out': 'rom_data_out',
        'ram_addr': 'ram_addr',
        'ram_data_in': 'ram_data_in',
        'ram_data_out': 'ram_data_out',
        'ram_we': 'ram_we',
        'ram_en': 'ram_en',
        'ram_byte_sel': 'ram_byte_sel',
        'clk': 'clk',
        'upg_rst': 'upg_rst',
        'upg_done': 'upg_done',
        'upg_adr': 'upg_adr',
        'upg_dat': 'upg_dat',
                'upg_dat': 'upg_dat',
        'upg_wen': 'upg_wen',
        'upg_clk': 'upg_clk',
    }

    # ============ 绘制 TEST 1: ROM READ ============
    print("\n绘制 TEST 1: ROM READ 波形...")
    plotter.plot_signals(
        ['rom_addr', 'rom_data_out'],
        title="TEST 1: ROM READ Operation",
        output_file="waveform_test1_rom_read.png",
        time_range=(200000, 250000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 2-3: RAM WRITE/READ ============
    print("绘制 TEST 2-3: RAM WRITE/READ 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_data_in', 'ram_data_out', 'ram_we', 'ram_en', 'ram_byte_sel'],
        title="TEST 2-3: RAM WORD WRITE/READ",
        output_file="waveform_test2_ram_write_read.png",
        time_range=(300000, 400000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 4: RAM半字写 ============
    print("绘制 TEST 4: RAM半字写 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_byte_sel', 'ram_data_in', 'ram_data_out', 'ram_we'],
        title="TEST 4: RAM HALF WORD WRITE (SH)",
        output_file="waveform_test4_half_word.png",
        time_range=(400000, 550000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 5: RAM字节写 ============
    print("绘制 TEST 5: RAM字节写 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_byte_sel', 'ram_data_in', 'ram_data_out', 'ram_we'],
        title="TEST 5: RAM BYTE WRITE (SB)",
        output_file="waveform_test5_byte_write.png",
        time_range=(550000, 700000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 6: RAM多字节写入 ============
    print("绘制 TEST 6: RAM多字节写入 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_byte_sel', 'ram_data_in', 'ram_data_out', 'ram_we'],
        title="TEST 6: RAM MULTI-BYTE WRITE",
        output_file="waveform_test6_multi_byte.png",
        time_range=(650000, 800000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 7: 连续读写 ============
    print("绘制 TEST 7: 连续读写 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_data_in', 'ram_data_out', 'ram_we', 'clk'],
        title="TEST 7: Sequential READ/WRITE",
        output_file="waveform_test7_sequential.png",
        time_range=(800000, 1100000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 8: 地址边界检查 ============
    print("绘制 TEST 8: 地址边界检查 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_data_in', 'ram_data_out', 'ram_en', 'ram_we'],
        title="TEST 8: ADDRESS BOUNDARY CHECK",
        output_file="waveform_test8_address_boundary.png",
        time_range=(1050000, 1200000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 9: RAM禁用测试 ============
    print("绘制 TEST 9: RAM禁用测试 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_data_out', 'ram_en', 'ram_we'],
        title="TEST 9: RAM DISABLE TEST",
        output_file="waveform_test9_ram_disable.png",
        time_range=(1150000, 1350000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 10: UART升级模式 ============
    print("绘制 TEST 10: UART升级模式 波形...")
    plotter.plot_signals(
        ['upg_rst', 'upg_done', 'upg_adr', 'upg_dat', 'upg_wen', 'ram_data_out'],
        title="TEST 10: UART Upgrade Mode (RAM)",
        output_file="waveform_test10_uart_upgrade.png",
        time_range=(1300000, 1600000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 11: ROM升级模式 ============
    print("绘制 TEST 11: ROM升级模式 波形...")
    plotter.plot_signals(
        ['upg_rst', 'upg_done', 'upg_adr', 'upg_dat', 'upg_wen', 'rom_data_out'],
        title="TEST 11: UART Upgrade Mode (ROM)",
        output_file="waveform_test11_rom_upgrade.png",
        time_range=(1600000, 1850000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 12: 混合读写 ============
    print("绘制 TEST 12: 混合读写 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_data_in', 'ram_data_out', 'ram_we'],
        title="TEST 12: MIXED READ/WRITE PATTERN",
        output_file="waveform_test12_mixed_rw.png",
        time_range=(1800000, 2000000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 13: 字节粒度验证 ============
    print("绘制 TEST 13: 字节粒度验证 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_byte_sel', 'ram_data_in', 'ram_data_out', 'ram_we'],
        title="TEST 13: BYTE GRANULARITY VERIFICATION",
        output_file="waveform_test13_byte_granularity.png",
        time_range=(2000000, 2200000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 14: 地址掩码验证 ============
    print("绘制 TEST 14: 地址掩码验证 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_data_in', 'ram_data_out', 'ram_en', 'ram_we'],
        title="TEST 14: ADDRESS MASKING VERIFICATION",
        output_file="waveform_test14_address_mask.png",
        time_range=(2150000, 2350000),
        signal_labels=labels
    )

    # ============ 绘制 TEST 15: 突发传输 ============
    print("绘制 TEST 15: 突发传输 波形...")
    plotter.plot_signals(
        ['ram_addr', 'ram_data_in', 'ram_data_out', 'ram_we', 'clk'],
        title="TEST 15: EXTENDED TIMING VERIFICATION (BURST)",
        output_file="waveform_test15_burst.png",
        time_range=(2300000, 2550000),
        signal_labels=labels
    )

    # ============ 绘制 CLK信号 ============
    print("绘制 系统时钟 波形...")
    plotter.plot_signals(
        ['clk'],
        title="System Clock (100MHz)",
        output_file="waveform_clock.png",
        time_range=(0, 500000),
        signal_labels=labels
    )

    # ============ 绘制升级时钟 ============
    print("绘制 升级时钟 波形...")
    plotter.plot_signals(
        ['upg_clk', 'clk'],
        title="Clock Comparison (System vs Upgrade)",
        output_file="waveform_clocks_comparison.png",
        time_range=(0, 500000),
        signal_labels=labels
    )

    # ============ 绘制完整的RAM控制信号 ============
    print("绘制 完整的RAM控制信号 波形...")
    plotter.plot_signals(
        ['ram_en', 'ram_we', 'ram_byte_sel', 'ram_addr', 'ram_data_in', 'ram_data_out'],
        title="Complete RAM Control Signals",
        output_file="waveform_ram_complete.png",
        time_range=(300000, 600000),
        signal_labels=labels
    )

    # ============ 绘制ROM信号 ============
    print("绘制 ROM读取操作 波形...")
    plotter.plot_signals(
        ['rom_addr', 'rom_data_out', 'clk'],
        title="ROM Read Operations",
        output_file="waveform_rom_operations.png",
        time_range=(150000, 350000),
        signal_labels=labels
    )

    # ============ 绘制升级控制信号 ============
    print("绘制 升级控制信号 波形...")
    plotter.plot_signals(
        ['upg_rst', 'upg_done', 'upg_wen', 'upg_clk'],
        title="Upgrade Control Signals",
        output_file="waveform_upgrade_control.png",
        time_range=(1200000, 1850000),
        signal_labels=labels
    )

    print("\n" + "="*70)
    print("✅ 所有波形绘制完成！")
    print("="*70)
    print("\n生成的波形文件:")
    print("  1. waveform_test1_rom_read.png - ROM读取")
    print("  2. waveform_test2_ram_write_read.png - RAM读写")
    print("  3. waveform_test4_half_word.png - 半字写入")
    print("  4. waveform_test5_byte_write.png - 字节写入")
    print("  5. waveform_test6_multi_byte.png - 多字节写入")
    print("  6. waveform_test7_sequential.png - 连续读写")
    print("  7. waveform_test8_address_boundary.png - 地址边界")
    print("  8. waveform_test9_ram_disable.png - RAM禁用")
    print("  9. waveform_test10_uart_upgrade.png - RAM升级")
    print(" 10. waveform_test11_rom_upgrade.png - ROM升级")
    print(" 11. waveform_test12_mixed_rw.png - 混合读写")
    print(" 12. waveform_test13_byte_granularity.png - 字节粒度")
    print(" 13. waveform_test14_address_mask.png - 地址掩码")
    print(" 14. waveform_test15_burst.png - 突发传输")
    print(" 15. waveform_clock.png - 系统时钟")
    print(" 16. waveform_clocks_comparison.png - 时钟对比")
    print(" 17. waveform_ram_complete.png - 完整RAM信号")
    print(" 18. waveform_rom_operations.png - ROM操作")
    print(" 19. waveform_upgrade_control.png - 升级控制")
    print("="*70 + "\n")


if __name__ == '__main__':
    main()


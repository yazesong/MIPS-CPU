#!/usr/bin/env python3
"""
仿真结果验证脚本
"""

import re
from collections import defaultdict

def verify_simulation_log(log_file='simulation.log'):
    """验证仿真结果"""
    
    with open(log_file, 'r') as f:
        lines = f.readlines()
    
    # 提取所有的测试结果
    test_results = {}
    current_test = None
    
    for line in lines:
        # 匹配测试标题
        if 'TEST' in line and '==========' in line:
            match = re.search(r'TEST (\d+):', line)
            if match:
                current_test = f"TEST {match.group(1)}"
                test_results[current_test] = {'passed': 0, 'total': 0, 'data': []}
        
        # 匹配数据验证行
        if current_test and '(expected:' in line:
            test_results[current_test]['total'] += 1
            
            # 提取实际值和期望值
            match = re.search(r'= (0x[\da-fA-F]+|0b[\d01]+|\d+).*expected: (0x[\da-fA-F]+|0b[\d01]+|\d+)', line)
            if match:
                actual = match.group(1).lower()
                expected = match.group(2).lower()
                
                if actual == expected:
                    test_results[current_test]['passed'] += 1
                    status = "✅ PASS"
                else:
                    status = "❌ FAIL"
                
                test_results[current_test]['data'].append({
                    'actual': actual,
                    'expected': expected,
                    'status': status,
                    'line': line.strip()
                })
    
    # 打印结果
    print("\n" + "="*80)
    print("🔍 仿真结果验证报告")
    print("="*80)
    
    total_tests = 0
    total_passed = 0
    
    for test_name in sorted(test_results.keys()):
        result = test_results[test_name]
        passed = result['passed']
        total = result['total']
        total_tests += total
        total_passed += passed
        
        if total > 0:
            percentage = (passed / total) * 100
            status = "✅ PASS" if passed == total else "⚠️ PARTIAL"
            print(f"\n{test_name}: {status}")
            print(f"  通过: {passed}/{total} ({percentage:.1f}%)")
            
            # 显示失败的详情
            for data in result['data']:
                if 'FAIL' in data['status']:
                    print(f"    {data['status']}")
                    print(f"      实际值: {data['actual']}")
                    print(f"      期望值: {data['expected']}")
    
    print("\n" + "="*80)
    print(f"总体结果: {total_passed}/{total_tests} ({(total_passed/total_tests*100):.1f}%)")
    
    if total_passed == total_tests:
        print("🎉 所有测试通过！仿真结果正确！")
    else:
        print(f"⚠️ 有 {total_tests - total_passed} 个测试失败")
    
    print("="*80 + "\n")
    
    return total_passed == total_tests


def verify_vcd_file(vcd_file='sim.vcd'):
    """验证VCD文件的完整性"""
    
    print("\n" + "="*80)
    print("🔍 VCD文件验证")
    print("="*80)
    
    with open(vcd_file, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    # 检查header
    has_timescale = any('$timescale' in line for line in lines[:50])
    has_scope = any('$scope' in line for line in lines[:100])
    has_var = any('$var' in line for line in lines[:200])
    has_enddefs = any('$enddefinitions' in line for line in lines[:300])
    
    print(f"✅ Timescale: {has_timescale}")
    print(f"✅ Scope定义: {has_scope}")
    print(f"✅ 变量定义: {has_var}")
    print(f"✅ 定义结束标记: {has_enddefs}")
    
    # 统计信号变化
    signal_changes = 0
    timestamp_count = 0
    
    for line in lines:
        if line.startswith('#'):
            timestamp_count += 1
        elif line and not line.startswith('$') and (line[0] in ['0', '1', 'b', 'x', 'z']):
            signal_changes += 1
    
    print(f"\n时间戳数量: {timestamp_count}")
    print(f"信号变化数: {signal_changes}")
    
    # 检查文件大小
    file_size = len(content)
    print(f"文件大小: {file_size / 1024:.2f} KB")
    
    if has_timescale and has_scope and has_var and has_enddefs and timestamp_count > 0:
        print("\n✅ VCD文件格式正确！")
        return True
    else:
        print("\n❌ VCD文件可能有问题")
        return False
    
    print("="*80 + "\n")


def main():
    """主函数"""
    print("\n📊 开始验证仿真结果...\n")
    
    # 验证VCD文件
    vcd_ok = verify_vcd_file('sim.vcd')
    
    # 验证日志文件
    try:
        log_ok = verify_simulation_log('simulation.log')
    except FileNotFoundError:
        print("❌ 找不到 simulation.log 文件")
        log_ok = False
    
    # 最终结论
    print("\n" + "="*80)
    if vcd_ok and log_ok:
        print("✅ 仿真完全成功！可以进行后续处理")
    else:
        print("⚠️ 仿真有问题，需要检查")
    print("="*80 + "\n")


if __name__ == '__main__':
    main()

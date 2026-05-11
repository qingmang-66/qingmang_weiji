#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
合并词库数据脚本
将 cet4_full.json 的完整数据 (例句等) 合并到 CET4-Core.json
"""

import json
import os

def load_json(filepath):
    """加载 JSON 文件"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(data, filepath):
    """保存 JSON 文件"""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def merge_wordbooks():
    """合并词库数据"""
    core_path = 'assets/wordbooks/CET4-Core.json'
    full_path = 'assets/wordbooks/cet4_full.json'
    backup_path = 'assets/wordbooks/CET4-Core.json.backup'
    
    print(f"📖 加载核心词库：{core_path}")
    core_data = load_json(core_path)
    
    print(f"📖 加载完整词库：{full_path}")
    full_data = load_json(full_path)
    
    # 创建单词索引 (word -> full_data)
    full_index = {word['word'].lower(): word for word in full_data['words']}
    
    print(f"📊 核心词库：{len(core_data['words'])} 词")
    print(f"📊 完整词库：{len(full_data['words'])} 词")
    
    # 合并数据
    merged_count = 0
    missing_count = 0
    
    for word in core_data['words']:
        word_lower = word['word'].lower()
        if word_lower in full_index:
            full_word = full_index[word_lower]
            
            # 如果核心词库缺少例句，从完整词库补充
            if not word.get('example') and full_word.get('example'):
                word['example'] = full_word['example']
                merged_count += 1
            
            if not word.get('example_translation') and full_word.get('exampleTranslation'):
                word['example_translation'] = full_word['exampleTranslation']
                merged_count += 1
            
            # 如果核心词库缺少音标，从完整词库补充
            if not word.get('phonetic') and full_word.get('phonetic'):
                word['phonetic'] = full_word['phonetic']
                merged_count += 1
            
            # 如果核心词库缺少词性，从完整词库补充
            if not word.get('pos') and full_word.get('pos'):
                word['pos'] = full_word['pos']
        else:
            missing_count += 1
    
    # 备份原文件
    import shutil
    shutil.copy(core_path, backup_path)
    print(f"💾 已备份原文件：{backup_path}")
    
    # 保存合并后的数据
    save_json(core_data, core_path)
    
    print(f"\n✅ 合并完成!")
    print(f"   补充数据：{merged_count} 项")
    print(f"   未找到匹配：{missing_count} 词")
    print(f"   总词数：{len(core_data['words'])}")
    
    # 验证结果
    sample = core_data['words'][0]
    print(f"\n📝 示例单词:")
    print(f"   单词：{sample['word']}")
    print(f"   音标：{sample.get('phonetic', '无')}")
    print(f"   释义：{sample.get('definition', '无')[:50]}...")
    print(f"   例句：{sample.get('example', '无')[:50] if sample.get('example') else '无'}...")

if __name__ == '__main__':
    merge_wordbooks()

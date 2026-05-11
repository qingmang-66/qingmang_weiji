#!/usr/bin/env python3
"""
从 ECDICT 下载并生成 CET-4/CET-6/考研词库
"""

import urllib.request
import csv
import json
import os
import gzip
from io import StringIO

# 输出目录
OUTPUT_DIR = r"C:\qingmang_weiji\assets\wordbooks"
CSV_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.mini.csv"

def download_csv():
    """下载 ECDICT CSV 文件"""
    print("正在下载 ECDICT 词库数据...")
    try:
        req = urllib.request.Request(
            CSV_URL,
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        )
        with urllib.request.urlopen(req, timeout=120) as response:
            content = response.read().decode('utf-8')
            print(f"下载成功！大小：{len(content)} 字符")
            return content
    except Exception as e:
        print(f"下载失败：{e}")
        return None

def process_csv_to_wordbooks(csv_content):
    """处理 CSV 内容，生成词库"""
    print("正在处理词库数据...")
    
    lines = csv_content.splitlines()
    if len(lines) < 2:
        print("CSV 内容为空或格式错误")
        return None, None, None
    
    # 解析 CSV
    reader = csv.DictReader(lines)
    
    cet4_words = []
    cet6_words = []
    kaoyan_words = []
    
    seen_cet4 = set()
    seen_cet6 = set()
    seen_kaoyan = set()
    
    for row in reader:
        word = row.get('word', '').strip()
        if not word:
            continue
            
        tag = row.get('tag', '')
        phonetic = row.get('phonetic', '').strip()
        definition = row.get('translation', '').strip()
        
        # 清理 definition 中的换行符
        definition = definition.replace('\\n', ' ').replace('\n', ' ')
        
        word_data = {
            "word": word,
            "phonetic": phonetic,
            "definition": definition,
            "example": "",
            "exampleTranslation": ""
        }
        
        # CET-4: 包含 cet4 但不包含 cet6
        if 'cet4' in tag and 'cet6' not in tag:
            if word.lower() not in seen_cet4:
                seen_cet4.add(word.lower())
                cet4_words.append(word_data)
        
        # CET-6: 包含 cet6
        if 'cet6' in tag:
            if word.lower() not in seen_cet6:
                seen_cet6.add(word.lower())
                cet6_words.append(word_data)
        
        # 考研：包含 gk (高考/考研) 或 pos (核心词汇)
        if 'gk' in tag or 'pos' in tag:
            if word.lower() not in seen_kaoyan:
                seen_kaoyan.add(word.lower())
                kaoyan_words.append(word_data)
    
    print(f"CET-4: {len(cet4_words)} 词")
    print(f"CET-6: {len(cet6_words)} 词")
    print(f"考研：{len(kaoyan_words)} 词")
    
    return cet4_words, cet6_words, kaoyan_words

def save_wordbook(words, filename):
    """保存词库到 JSON 文件"""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    print(f"已保存 {filename} ({len(words)} 词)")

def main():
    print("=" * 60)
    print("ECDICT 词库下载与处理")
    print("=" * 60)
    
    # 确保输出目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # 下载 CSV
    csv_content = download_csv()
    if not csv_content:
        print("下载失败，程序退出")
        return
    
    # 处理词库
    cet4, cet6, kaoyan = process_csv_to_wordbooks(csv_content)
    if not cet4 or not cet6 or not kaoyan:
        print("处理失败，程序退出")
        return
    
    # 保存词库
    print("\n保存词库文件...")
    save_wordbook(cet4, 'cet4_full.json')
    save_wordbook(cet6, 'cet6_full.json')
    save_wordbook(kaoyan, 'kaoyan_full.json')
    
    print("\n" + "=" * 60)
    print("词库生成完成!")
    print("=" * 60)
    print(f"CET-4: {len(cet4)} 词")
    print(f"CET-6: {len(cet6)} 词")
    print(f"考研：{len(kaoyan)} 词")
    print(f"\n文件已保存到：{OUTPUT_DIR}")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
下载并生成 CET-4 / CET-6 / 考研词库
数据来源: ECDICT (https://github.com/skywind3000/ECDICT)
"""

import urllib.request
import gzip
import csv
import json
import os
from io import BytesIO

# ECDICT CSV 下载地址
ECDICT_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"

# 输出目录
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "wordbooks")

def download_ecdict():
    """下载 ECDICT CSV 文件"""
    print("正在下载 ECDICT 词库...")
    try:
        req = urllib.request.Request(
            ECDICT_URL,
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=60) as response:
            # GitHub 可能返回压缩内容
            content = response.read()
            # 尝试解压
            try:
                content = gzip.decompress(content)
            except:
                pass
            return content.decode('utf-8')
    except Exception as e:
        print(f"下载失败: {e}")
        return None

def filter_words(csv_content, tag_filter):
    """
    根据 tag 筛选词汇
    tag_filter: 'cet4' 或 'cet6' 或 'gk' (高考/考研)
    """
    words = []
    reader = csv.DictReader(csv_content.splitlines(), delimiter=',')
    
    for row in reader:
        tag = row.get('tag', '')
        word = row.get('word', '').strip()
        phonetic = row.get('phonetic', '').strip()
        definition = row.get('translation', '').strip()
        
        if not word:
            continue
            
        # 检查 tag 是否包含目标标签
        if tag_filter in tag:
            words.append({
                "word": word,
                "phonetic": phonetic,
                "definition": definition,
                "example": "",
                "exampleTranslation": ""
            })
    
    return words

def filter_words_exclude(csv_content, include_tags, exclude_tags):
    """
    筛选包含某些标签但不包含其他标签的词汇
    用于区分 CET-4 和 CET-6
    """
    words = []
    reader = csv.DictReader(csv_content.splitlines(), delimiter=',')
    
    for row in reader:
        tag = row.get('tag', '')
        word = row.get('word', '').strip()
        phonetic = row.get('phonetic', '').strip()
        definition = row.get('translation', '').strip()
        
        if not word:
            continue
        
        # 检查是否包含任一包含标签
        has_include = any(t in tag for t in include_tags)
        # 检查是否包含任一排除标签
        has_exclude = any(t in tag for t in exclude_tags)
        
        if has_include and not has_exclude:
            words.append({
                "word": word,
                "phonetic": phonetic,
                "definition": definition,
                "example": "",
                "exampleTranslation": ""
            })
    
    return words

def save_words(words, filename):
    """保存词汇到 JSON 文件"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    print(f"已保存 {len(words)} 个单词到 {filename}")
    return len(words)

def main():
    print("=" * 50)
    print("ECDICT 词库下载与处理")
    print("=" * 50)
    
    # 下载词库
    csv_content = download_ecdict()
    if not csv_content:
        print("下载失败，尝试备用方案...")
        return
    
    print("正在处理词库...")
    
    # CET-4: 只包含 cet4 标签，不包含 cet6
    print("\n[1/3] 生成 CET-4 词库...")
    cet4_words = filter_words_exclude(csv_content, ['cet4'], ['cet6'])
    # 去重并保持顺序
    seen = set()
    cet4_unique = []
    for w in cet4_words:
        if w['word'].lower() not in seen:
            seen.add(w['word'].lower())
            cet4_unique.append(w)
    save_words(cet4_unique, 'cet4_full.json')
    
    # CET-6: 只包含 cet6 标签
    print("\n[2/3] 生成 CET-6 词库...")
    cet6_words = filter_words(csv_content, 'cet6')
    seen = set()
    cet6_unique = []
    for w in cet6_words:
        if w['word'].lower() not in seen:
            seen.add(w['word'].lower())
            cet6_unique.append(w)
    save_words(cet6_unique, 'cet6_full.json')
    
    # 考研英语: 包含 gk(高考) 或 core(核心) 的词汇，排除简单词汇
    # 考研英语通常需要 CET-4 + CET-6 + 一些额外词汇
    # 这里我们用 gk 标签 + 核心词汇
    print("\n[3/3] 生成考研英语词库...")
    kaoyan_words = filter_words_exclude(csv_content, ['gk', 'pos'], ['zk', 'nz'])
    seen = set()
    kaoyan_unique = []
    for w in kaoyan_words:
        if w['word'].lower() not in seen:
            seen.add(w['word'].lower())
            kaoyan_unique.append(w)
    save_words(kaoyan_unique, 'kaoyan_full.json')
    
    print("\n" + "=" * 50)
    print("词库生成完成!")
    print("=" * 50)
    print(f"CET-4: {len(cet4_unique)} 词")
    print(f"CET-6: {len(cet6_unique)} 词")
    print(f"考研: {len(kaoyan_unique)} 词")

if __name__ == "__main__":
    main()
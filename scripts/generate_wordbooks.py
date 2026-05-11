#!/usr/bin/env python3
"""
使用现有词库生成更完整的 CET-6 和考研词库
"""

import json
import os

# 词库目录
WORDBOOK_DIR = r"C:\qingmang_weiji\assets\wordbooks"

def load_wordbook(filename):
    """加载词库文件"""
    filepath = os.path.join(WORDBOOK_DIR, filename)
    if not os.path.exists(filepath):
        print(f"文件不存在: {filename}")
        return []
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_wordbook(words, filename):
    """保存词库文件"""
    filepath = os.path.join(WORDBOOK_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    print(f"已保存 {filename}, 共 {len(words)} 个词")

def get_word_set(words):
    """获取单词小写的集合"""
    return set(w['word'].lower() for w in words)

def main():
    print("=" * 50)
    print("使用现有词库生成更完整的词库")
    print("=" * 50)
    
    # 加载现有词库
    print("\n加载现有词库...")
    cet4 = load_wordbook('cet4_full.json')
    cet6 = load_wordbook('cet6_full.json')
    kaoyan = load_wordbook('kaoyan_full.json')
    google = load_wordbook('google_10000_full.json')
    common = load_wordbook('common_english_words_full.json')
    
    print(f"CET-4: {len(cet4)} 词")
    print(f"CET-6: {len(cet6)} 词")
    print(f"考研: {len(kaoyan)} 词")
    print(f"Google 10000: {len(google)} 词")
    print(f"常用英语: {len(common)} 词")
    
    # 1. CET-4 词库保持不变（已经是比较完整的）
    print("\n[1/3] 处理 CET-4 词库...")
    cet4_set = get_word_set(cet4)
    # 去除重复
    cet4_unique = []
    seen = set()
    for w in cet4:
        key = w['word'].lower()
        if key not in seen:
            seen.add(key)
            cet4_unique.append(w)
    save_wordbook(cet4_unique, 'cet4_full.json')
    
    # 2. CET-6 词库：合并现有 CET-6 + Google 10000 中不在 CET-4 中的词汇
    # Google 10000 后面部分的词汇通常更难，适合作为 CET-6 补充
    print("\n[2/3] 处理 CET-6 词库...")
    cet6_set = get_word_set(cet6)
    cet4_words = get_word_set(cet4)
    
    # 从 google_10000 提取CET-6词汇 (跳过前2000个基础词，从后面选)
    google_subset = google[2000:]  # 跳过最基础的2000词
    cet6_words = list(cet6)  # 保留现有的 CET-6
    
    for w in google_subset:
        word_lower = w['word'].lower()
        # 排除已经在 CET-4 中的词
        if word_lower not in cet4_words and word_lower not in cet6_set:
            # 排除太简单的词（通常是短词）
            if len(w['word']) > 4:  # 只添加长度大于4的词
                cet6_words.append(w)
                cet6_set.add(word_lower)
    
    # 去重并保存
    cet6_unique = []
    seen = set()
    for w in cet6_words:
        key = w['word'].lower()
        if key not in seen:
            seen.add(key)
            cet6_unique.append(w)
    save_wordbook(cet6_unique, 'cet6_full.json')
    
    # 3. 考研词库：合并 CET-6 + 高考+ 一些进阶词汇
    print("\n[3/3] 处理考研词库...")
    kaoyan_set = get_word_set(kaoyan)
    
    # 考研词库 = CET-6 + 现有考研 + 从 Google 10000 补充
    kaoyan_words = list(cet6_unique)  # 先包含所有 CET-6
    
    # 添加现有考研词汇（如果不在 CET-6 中）
    for w in kaoyan:
        word_lower = w['word'].lower()
        if word_lower not in kaoyan_set:
            kaoyan_words.append(w)
            kaoyan_set.add(word_lower)
    
    # 从 google_10000 补充更多高难度词汇
    google_hard = google[5000:]  # 从中间部分开始
    for w in google_hard:
        word_lower = w['word'].lower()
        if word_lower not in kaoyan_set and len(w['word']) > 5:
            kaoyan_words.append(w)
            kaoyan_set.add(word_lower)
    
    # 去重并保存
    kaoyan_unique = []
    seen = set()
    for w in kaoyan_words:
        key = w['word'].lower()
        if key not in seen:
            seen.add(key)
            kaoyan_unique.append(w)
    save_wordbook(kaoyan_unique, 'kaoyan_full.json')
    
    print("\n" + "=" * 50)
    print("词库生成完成!")
    print("=" * 50)
    print(f"CET-4: {len(cet4_unique)} 词")
    print(f"CET-6: {len(cet6_unique)} 词")
    print(f"考研: {len(kaoyan_unique)} 词")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
从 ECDICT SQLite 数据库提取 CET-4/CET-6/考研词库
"""

import sqlite3
import json
import os

# 数据库路径
DB_PATH = r"C:\qingmang_weiji\assets\db\ecdict.db"
OUTPUT_DIR = r"C:\qingmang_weiji\assets\wordbooks"

def extract_wordbooks():
    """从 SQLite 数据库提取词库"""
    print("正在读取 SQLite 数据库...")
    
    if not os.path.exists(DB_PATH):
        print(f"错误：数据库文件不存在：{DB_PATH}")
        print("请先下载 ecdict-sqlite-28.zip 并解压，将 ecdict.db 放入 assets/db/ 目录")
        return None, None, None
    
    # 连接数据库
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 查询 CET-4 词汇 (包含 cet4 标签，不包含 cet6)
    print("提取 CET-4 词汇...")
    cursor.execute("""
        SELECT word, phonetic, translation 
        FROM ec_dict 
        WHERE tag LIKE '%cet4%' 
        AND (tag IS NULL OR tag NOT LIKE '%cet6%')
    """)
    cet4_rows = cursor.fetchall()
    
    # 查询 CET-6 词汇 (包含 cet6 标签)
    print("提取 CET-6 词汇...")
    cursor.execute("""
        SELECT word, phonetic, translation 
        FROM ec_dict 
        WHERE tag LIKE '%cet6%'
    """)
    cet6_rows = cursor.fetchall()
    
    # 查询考研词汇 (包含 gk 或 pos 标签)
    print("提取考研词汇...")
    cursor.execute("""
        SELECT word, phonetic, translation 
        FROM ec_dict 
        WHERE tag LIKE '%gk%' OR tag LIKE '%pos%'
    """)
    kaoyan_rows = cursor.fetchall()
    
    conn.close()
    
    # 转换为 JSON 格式
    def rows_to_words(rows):
        words = []
        seen = set()
        for row in rows:
            word = row[0].strip()
            if not word or word.lower() in seen:
                continue
            seen.add(word.lower())
            
            phonetic = row[1].strip() if row[1] else ""
            definition = row[2].strip() if row[2] else ""
            
            # 清理 definition 中的换行符
            definition = definition.replace('\\n', ' ').replace('\n', ' ')
            
            words.append({
                "word": word,
                "phonetic": phonetic,
                "definition": definition,
                "example": "",
                "exampleTranslation": ""
            })
        return words
    
    cet4_words = rows_to_words(cet4_rows)
    cet6_words = rows_to_words(cet6_rows)
    kaoyan_words = rows_to_words(kaoyan_rows)
    
    return cet4_words, cet6_words, kaoyan_words

def save_wordbook(words, filename):
    """保存词库到 JSON 文件"""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    print(f"已保存 {filename} ({len(words)} 词)")

def main():
    print("=" * 60)
    print("从 ECDICT SQLite 提取词库")
    print("=" * 60)
    
    # 确保输出目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # 提取词库
    cet4, cet6, kaoyan = extract_wordbooks()
    if not cet4 or not cet6 or not kaoyan:
        print("提取失败")
        return
    
    # 保存词库
    print("\n保存词库文件...")
    save_wordbook(cet4, 'cet4_full.json')
    save_wordbook(cet6, 'cet6_full.json')
    save_wordbook(kaoyan, 'kaoyan_full.json')
    
    print("\n" + "=" * 60)
    print("词库提取完成!")
    print("=" * 60)
    print(f"CET-4: {len(cet4)} 词")
    print(f"CET-6: {len(cet6)} 词")
    print(f"考研：{len(kaoyan)} 词")
    print(f"\n文件已保存到：{OUTPUT_DIR}")

if __name__ == "__main__":
    main()
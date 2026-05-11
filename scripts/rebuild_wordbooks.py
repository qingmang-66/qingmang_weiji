import sqlite3
import json
import os

# 数据库路径
DB_PATH = r'D:\edge\English\ecdict-sqlite-28\stardict.db'
OUTPUT_DIR = r'C:\qingmang_weiji\assets\wordbooks'

def extract_wordbooks():
    """从 SQLite 数据库提取词库"""
    print("=" * 60)
    print("正在从 ECDICT 数据库提取词库...")
    print("=" * 60)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 提取 CET-4 词汇 (包含 cet4 标签)
    print("提取 CET-4 词汇...")
    cursor.execute("""
        SELECT word, phonetic, translation 
        FROM stardict 
        WHERE tag LIKE '%cet4%'
        ORDER BY word
    """)
    cet4_rows = cursor.fetchall()
    print(f"  找到 {len(cet4_rows)} 条记录")
    
    # 提取 CET-6 词汇 (包含 cet6 标签)
    print("提取 CET-6 词汇...")
    cursor.execute("""
        SELECT word, phonetic, translation 
        FROM stardict 
        WHERE tag LIKE '%cet6%'
        ORDER BY word
    """)
    cet6_rows = cursor.fetchall()
    print(f"  找到 {len(cet6_rows)} 条记录")
    
    # 提取考研词汇 (包含 gk 标签)
    print("提取考研词汇...")
    cursor.execute("""
        SELECT word, phonetic, translation 
        FROM stardict 
        WHERE tag LIKE '%gk%'
        ORDER BY word
    """)
    kaoyan_rows = cursor.fetchall()
    print(f"  找到 {len(kaoyan_rows)} 条记录")
    
    conn.close()
    
    # 转换为 JSON 格式并去重
    def rows_to_words(rows):
        words = []
        seen = set()
        for row in rows:
            word = row[0].strip() if row[0] else ""
            if not word or word.lower() in seen:
                continue
            seen.add(word.lower())
            
            phonetic = row[1].strip() if row[1] else ""
            definition = row[2].strip() if row[2] else ""
            
            # 清理 definition 中的换行符
            definition = definition.replace('\\n', ' ').replace('\n', ' ').replace('  ', ' ')
            
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
    print(f"  已保存 {filename} ({len(words)} 词)")

def main():
    print("\n" + "=" * 60)
    print("从 ECDICT SQLite 重新构建词库")
    print("=" * 60)
    
    # 确保输出目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # 提取词库
    cet4, cet6, kaoyan = extract_wordbooks()
    
    # 保存词库
    print("\n保存词库文件...")
    save_wordbook(cet4, 'cet4_full.json')
    save_wordbook(cet6, 'cet6_full.json')
    save_wordbook(kaoyan, 'kaoyan_full.json')
    
    print("\n" + "=" * 60)
    print("词库重建完成!")
    print("=" * 60)
    print(f"CET-4: {len(cet4)} 词")
    print(f"CET-6: {len(cet6)} 词")
    print(f"考研：{len(kaoyan)} 词")
    print(f"\n文件已保存到：{OUTPUT_DIR}")
    
    # 显示样本
    print("\n" + "=" * 60)
    print("样本数据预览")
    print("=" * 60)
    print(f"CET-4 第一个词: {cet4[0]['word']} - {cet4[0]['definition'][:60]}...")
    print(f"CET-6 第一个词: {cet6[0]['word']} - {cet6[0]['definition'][:60]}...")
    print(f"考研 第一个词: {kaoyan[0]['word']} - {kaoyan[0]['definition'][:60]}...")

if __name__ == "__main__":
    main()
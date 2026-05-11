import urllib.request
import zipfile
import os
import sqlite3
import json

OUTPUT_DIR = r"C:\qingmang_weiji\assets\wordbooks"
ZIP_PATH = r"C:\qingmang_weiji\ecdict-sqlite-28.zip"
DB_PATH = r"C:\qingmang_weiji\ecdict.db"

print("下载 ECDICT SQLite 版本...")

# 下载 zip 文件
url = "https://github.com/skywind3000/ECDICT/releases/download/1.0.28/ecdict-sqlite-28.zip"
req = urllib.request.Request(url, headers={
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/zip,application/octet-stream,*/*',
    'Accept-Encoding': 'identity'
})

try:
    with urllib.request.urlopen(req, timeout=300) as response:
        total = int(response.headers.get('Content-Length', 0))
        print(f"文件大小: {total / 1024 / 1024:.1f} MB")
        
        downloaded = 0
        chunk_size = 8192
        with open(ZIP_PATH, 'wb') as f:
            while True:
                chunk = response.read(chunk_size)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
                if total > 0:
                    print(f"\r下载进度: {downloaded * 100 / total:.1f}%", end="", flush=True)
    
    print("\n下载完成！正在解压...")
    
    # 解压
    with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
        zip_ref.extractall(r"C:\qingmang_weiji")
    
    print("解压完成！正在读取数据库...")
    
    # 读取 SQLite 数据库
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 获取所有词汇
    print("查询 CET-4 词汇...")
    cursor.execute("SELECT word, phonetic, translation FROM ec_dict WHERE tag LIKE '%cet4%' AND (tag IS NULL OR tag NOT LIKE '%cet6%')")
    cet4_words = []
    seen = set()
    for row in cursor.fetchall():
        word = row[0].strip()
        if word.lower() not in seen:
            seen.add(word.lower())
            cet4_words.append({
                "word": word,
                "phonetic": row[1].strip() if row[1] else "",
                "definition": row[2].strip() if row[2] else "",
                "example": "",
                "exampleTranslation": ""
            })
    
    print(f"CET-4: {len(cet4_words)} 词")
    
    print("查询 CET-6 词汇...")
    cursor.execute("SELECT word, phonetic, translation FROM ec_dict WHERE tag LIKE '%cet6%'")
    cet6_words = []
    seen = set()
    for row in cursor.fetchall():
        word = row[0].strip()
        if word.lower() not in seen:
            seen.add(word.lower())
            cet6_words.append({
                "word": word,
                "phonetic": row[1].strip() if row[1] else "",
                "definition": row[2].strip() if row[2] else "",
                "example": "",
                "exampleTranslation": ""
            })
    
    print(f"CET-6: {len(cet6_words)} 词")
    
    print("查询考研词汇 (gk 标签)...")
    cursor.execute("SELECT word, phonetic, translation FROM ec_dict WHERE tag LIKE '%gk%' OR tag LIKE '%pos%'")
    kaoyan_words = []
    seen = set()
    for row in cursor.fetchall():
        word = row[0].strip()
        if word.lower() not in seen:
            seen.add(word.lower())
            kaoyan_words.append({
                "word": word,
                "phonetic": row[1].strip() if row[1] else "",
                "definition": row[2].strip() if row[2] else "",
                "example": "",
                "exampleTranslation": ""
            })
    
    print(f"考研: {len(kaoyan_words)} 词")
    
    conn.close()
    
    # 保存词库
    print("保存词库文件...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    with open(os.path.join(OUTPUT_DIR, 'cet4_full.json'), 'w', encoding='utf-8') as f:
        json.dump(cet4_words, f, ensure_ascii=False, indent=2)
    
    with open(os.path.join(OUTPUT_DIR, 'cet6_full.json'), 'w', encoding='utf-8') as f:
        json.dump(cet6_words, f, ensure_ascii=False, indent=2)
    
    with open(os.path.join(OUTPUT_DIR, 'kaoyan_full.json'), 'w', encoding='utf-8') as f:
        json.dump(kaoyan_words, f, ensure_ascii=False, indent=2)
    
    # 清理临时文件
    try:
        os.remove(ZIP_PATH)
        os.remove(DB_PATH)
    except:
        pass
    
    print("\n" + "=" * 50)
    print("词库生成完成!")
    print("=" * 50)
    print(f"CET-4: {len(cet4_words)} 词")
    print(f"CET-6: {len(cet6_words)} 词")
    print(f"考研: {len(kaoyan_words)} 词")
    
except Exception as e:
    print(f"错误: {e}")
    import traceback
    traceback.print_exc()
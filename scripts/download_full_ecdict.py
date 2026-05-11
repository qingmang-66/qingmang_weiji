#!/usr/bin/env python3
"""
从 ECDICT 下载完整词库并生成 CET-4/CET-6/考研词库
使用分块下载避免内存溢出
"""

import urllib.request
import csv
import json
import os
from io import StringIO

# 输出目录
OUTPUT_DIR = r"C:\qingmang_weiji\assets\wordbooks"
CSV_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"

def download_and_process_csv():
    """下载并处理 CSV 文件"""
    print("正在下载 ECDICT 完整词库数据...")
    print("这可能需要几分钟，请耐心等待...")
    
    try:
        req = urllib.request.Request(
            CSV_URL,
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        )
        
        with urllib.request.urlopen(req, timeout=300) as response:
            total_size = int(response.headers.get('Content-Length', 0))
            print(f"文件大小：{total_size / 1024 / 1024:.1f} MB")
            
            # 初始化计数器
            cet4_count = 0
            cet6_count = 0
            kaoyan_count = 0
            
            seen_cet4 = set()
            seen_cet6 = set()
            seen_kaoyan = set()
            
            cet4_words = []
            cet6_words = []
            kaoyan_words = []
            
            downloaded = 0
            chunk_size = 8192
            
            # 读取 CSV 头
            header_line = response.readline().decode('utf-8').strip()
            reader = csv.DictReader(StringIO(header_line + '\n'), delimiter=',')
            fieldnames = reader.fieldnames
            
            print("开始处理数据...")
            
            # 逐行读取和处理
            for line in response:
                downloaded += len(line)
                if total_size > 0 and downloaded % (1024 * 1024) < chunk_size:
                    progress = downloaded * 100 / total_size
                    print(f"\r下载进度：{progress:.1f}% ({downloaded/1024/1024:.1f}/{total_size/1024/1024:.1f} MB)", end="", flush=True)
                
                try:
                    line_str = line.decode('utf-8').strip()
                    if not line_str:
                        continue
                    
                    # 解析单行 CSV
                    reader_single = csv.DictReader([header_line, line_str], delimiter=',')
                    for row in reader_single:
                        word = row.get('word', '').strip()
                        if not word:
                            continue
                        
                        tag = row.get('tag', '')
                        phonetic = row.get('phonetic', '').strip()
                        definition = row.get('translation', '').strip()
                        
                        # 清理 definition
                        definition = definition.replace('\\n', ' ').replace('\n', ' ')
                        
                        word_data = {
                            "word": word,
                            "phonetic": phonetic,
                            "definition": definition,
                            "example": "",
                            "exampleTranslation": ""
                        }
                        
                        # CET-4
                        if 'cet4' in tag and 'cet6' not in tag:
                            if word.lower() not in seen_cet4:
                                seen_cet4.add(word.lower())
                                cet4_words.append(word_data)
                                cet4_count += 1
                        
                        # CET-6
                        if 'cet6' in tag:
                            if word.lower() not in seen_cet6:
                                seen_cet6.add(word.lower())
                                cet6_words.append(word_data)
                                cet6_count += 1
                        
                        # 考研
                        if 'gk' in tag or 'pos' in tag:
                            if word.lower() not in seen_kaoyan:
                                seen_kaoyan.add(word.lower())
                                kaoyan_words.append(word_data)
                                kaoyan_count += 1
                                
                except Exception as e:
                    continue
            
            print("\n")
            print(f"CET-4: {cet4_count} 词")
            print(f"CET-6: {cet6_count} 词")
            print(f"考研：{kaoyan_count} 词")
            
            return cet4_words, cet6_words, kaoyan_words
            
    except Exception as e:
        print(f"\n下载/处理失败：{e}")
        import traceback
        traceback.print_exc()
        return None, None, None

def save_wordbook(words, filename):
    """保存词库到 JSON 文件"""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    print(f"已保存 {filename} ({len(words)} 词)")

def main():
    print("=" * 60)
    print("ECDICT 完整词库下载与处理")
    print("=" * 60)
    
    # 确保输出目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # 下载并处理
    cet4, cet6, kaoyan = download_and_process_csv()
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
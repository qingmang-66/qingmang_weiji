import urllib.request
import os
import json

# 使用多个镜像源
MIRRORS = [
    "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv",
    "https://cdn.jsdelivr.net/gh/skywind3000/ECDICT@master/ecdict.csv",
    "https://gitee.com/skywind3000/ECDICT/raw/master/ecdict.csv",
]

OUTPUT_DIR = r"C:\qingmang_weiji\assets\wordbooks"

def try_download(url):
    print(f"尝试: {url[:60]}...")
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
    })
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            content = response.read()
            print(f"成功! 大小: {len(content) / 1024 / 1024:.1f} MB")
            return content.decode('utf-8')
    except Exception as e:
        print(f"失败: {str(e)[:50]}")
        return None

def process_words(csv_content):
    """处理CSV内容，提取CET-4/CET-6词库"""
    lines = csv_content.splitlines()
    if not lines:
        return [], []
    
    # 跳过表头
    header = lines[0]
    
    cet4_words = []
    cet6_words = []
    seen_cet4 = set()
    seen_cet6 = set()
    
    for line in lines[1:]:
        if not line.strip():
            continue
        # 简单解析CSV (可能不完全正确，但够用)
        parts = line.split(',')
        if len(parts) < 4:
            continue
        
        word = parts[0].strip().strip('"')
        tag = parts[3].strip().strip('"') if len(parts) > 3 else ""
        phonetic = parts[1].strip().strip('"') if len(parts) > 1 else ""
        translation = parts[2].strip().strip('"') if len(parts) > 2 else ""
        
        if not word:
            continue
            
        word_data = {
            "word": word,
            "phonetic": phonetic,
            "definition": translation,
            "example": "",
            "exampleTranslation": ""
        }
        
        # CET-4: 包含cet4但不包含cet6
        if 'cet4' in tag and 'cet6' not in tag:
            if word.lower() not in seen_cet4:
                seen_cet4.add(word.lower())
                cet4_words.append(word_data)
        
        # CET-6: 包含cet6
        if 'cet6' in tag:
            if word.lower() not in seen_cet6:
                seen_cet6.add(word.lower())
                cet6_words.append(word_data)
    
    return cet4_words, cet6_words

def main():
    print("尝试从镜像下载 ECDICT 词库...")
    
    content = None
    for url in MIRRORS:
        content = try_download(url)
        if content:
            break
    
    if not content:
        print("所有镜像都失败了")
        return
    
    print("正在处理词库...")
    cet4_words, cet6_words = process_words(content)
    
    print(f"\n结果:")
    print(f"CET-4: {len(cet4_words)} 词")
    print(f"CET-6: {len(cet6_words)} 词")
    
    # 保存
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    with open(os.path.join(OUTPUT_DIR, 'cet4_full.json'), 'w', encoding='utf-8') as f:
        json.dump(cet4_words, f, ensure_ascii=False, indent=2)
    
    with open(os.path.join(OUTPUT_DIR, 'cet6_full.json'), 'w', encoding='utf-8') as f:
        json.dump(cet6_words, f, ensure_ascii=False, indent=2)
    
    # 考研 = CET-4 + CET-6
    kaoyan_words = cet4_words + cet6_words
    with open(os.path.join(OUTPUT_DIR, 'kaoyan_full.json'), 'w', encoding='utf-8') as f:
        json.dump(kaoyan_words, f, ensure_ascii=False, indent=2)
    
    print(f"考研: {len(kaoyan_words)} 词")
    print("\n完成!")

if __name__ == "__main__":
    main()
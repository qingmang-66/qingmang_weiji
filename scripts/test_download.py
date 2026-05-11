import urllib.request
import csv
import json
import os
import gzip

OUTPUT_DIR = r"C:\qingmang_weiji\assets\wordbooks"

print('开始下载 ECDICT...')
url = 'https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})

try:
    with urllib.request.urlopen(req, timeout=300) as response:
        print('读取中...')
        content = response.read()
        try:
            content = gzip.decompress(content)
        except:
            pass
        content = content.decode('utf-8')
        print(f'下载完成，大小: {len(content)} 字符')
        
        # 处理词库
        cet4_words = []
        cet6_words = []
        kaoyan_words = []
        
        lines = content.splitlines()
        reader = csv.DictReader(lines, delimiter=',')
        
        for row in reader:
            word = row.get('word', '').strip()
            tag = row.get('tag', '')
            phonetic = row.get('phonetic', '').strip()
            definition = row.get('translation', '').strip()
            
            if not word:
                continue
            
            word_data = {
                "word": word,
                "phonetic": phonetic,
                "definition": definition,
                "example": "",
                "exampleTranslation": ""
            }
            
            # CET-4: 包含 cet4
            if 'cet4' in tag and 'cet6' not in tag:
                cet4_words.append(word_data)
            
            # CET-6: 包含 cet6
            if 'cet6' in tag:
                cet6_words.append(word_data)
            
            # 考研: 包含 gk (高考/考研核心)
            if 'gk' in tag or 'pos' in tag:
                kaoyan_words.append(word_data)
        
        # 去重
        def dedup(words):
            seen = set()
            result = []
            for w in words:
                key = w['word'].lower()
                if key not in seen:
                    seen.add(key)
                    result.append(w)
            return result
        
        cet4_words = dedup(cet4_words)
        cet6_words = dedup(cet6_words)
        kaoyan_words = dedup(kaoyan_words)
        
        print(f'CET-4: {len(cet4_words)} 词')
        print(f'CET-6: {len(cet6_words)} 词')
        print(f'考研: {len(kaoyan_words)} 词')
        
        # 保存
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        
        with open(os.path.join(OUTPUT_DIR, 'cet4_full.json'), 'w', encoding='utf-8') as f:
            json.dump(cet4_words, f, ensure_ascii=False, indent=2)
        print('已保存 CET-4')
        
        with open(os.path.join(OUTPUT_DIR, 'cet6_full.json'), 'w', encoding='utf-8') as f:
            json.dump(cet6_words, f, ensure_ascii=False, indent=2)
        print('已保存 CET-6')
        
        with open(os.path.join(OUTPUT_DIR, 'kaoyan_full.json'), 'w', encoding='utf-8') as f:
            json.dump(kaoyan_words, f, ensure_ascii=False, indent=2)
        print('已保存 考研')
        
        print('完成!')
        
except Exception as e:
    print(f'错误: {e}')
    import traceback
    traceback.print_exc()
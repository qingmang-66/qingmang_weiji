#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用有道词典 API 批量抓取词库
读取 assets/words/*.txt，生成 assets/wordbooks/<name>_full.json
"""

import json, time, pathlib, sys, warnings
try:
    import requests
except ImportError:
    print("请先安装 requests: pip install requests")
    sys.exit(1)

warnings.filterwarnings('ignore')

BASE_URL = "https://dict.youdao.com/suggest"

def fetch_definition(word: str) -> dict | None:
    try:
        params = {'num': '1', 'ver': '3.0', 'doctype': 'json', 'le': 'en', 'q': word}
        resp = requests.get(BASE_URL, params=params, timeout=8, verify=False)
        if resp.status_code != 200:
            return None
        data = resp.json()
        entries = data.get('data', {}).get('entries', [])
        if not entries:
            return None
        definition = entries[0].get('explain', '').strip()
        return {'definition': definition, 'phonetic': '', 'example': '', 'exampleTranslation': ''}
    except Exception as e:
        print(f"❌ {word}: {e}")
        return None

def process_file(txt_path: pathlib.Path, out_path: pathlib.Path):
    print(f"📖 读取词表: {txt_path.name}")
    words = [ln.strip() for ln in txt_path.read_text(encoding='utf-8').splitlines() if ln.strip()]
    results = []
    for i, w in enumerate(words, 1):
        print(f"[{i}/{len(words)}] {w}")
        info = fetch_definition(w)
        if info:
            results.append({'word': w, 'phonetic': info['phonetic'], 'definition': info['definition'], 'example': info['example'], 'exampleTranslation': info['exampleTranslation']})
        else:
            results.append({'word': w, 'phonetic': '', 'definition': f"[释义待补充] {w}", 'example': '', 'exampleTranslation': ''})
        time.sleep(0.12)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"✅ 完成 {txt_path.name} → {out_path.name}（{len(results)} 条）\n")

def main():
    # 只处理指定的词库文件
    txt_dir = pathlib.Path('assets/wordbooks')
    out_dir = pathlib.Path('assets/wordbooks')
    
    # 指定要处理的文件
    target_files = ['cet4.txt', 'cet6.txt', 'kaoyan.txt']
    
    for filename in target_files:
        txt_path = txt_dir / filename
        if not txt_path.exists():
            print(f'⚠ 文件不存在: {filename}')
            continue
        
        out_name = f"{txt_path.stem}_full.json"
        out_path = out_dir / out_name
        process_file(txt_path, out_path)
    
    print("🎉 全部完成!")

if __name__ == '__main__':
    main()
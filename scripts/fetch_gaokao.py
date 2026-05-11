#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
抓取 gaokao_english.txt 和 kaoyan_english.txt
"""

import json, time, pathlib, sys, warnings
try:
    import requests
except ImportError:
    sys.exit(1)

warnings.filterwarnings('ignore')

BASE_URL = "https://dict.youdao.com/suggest"

def fetch(word):
    try:
        r = requests.get(BASE_URL, params={'num':'1','ver':'3.0','doctype':'json','le':'en','q':word}, timeout=8, verify=False)
        if r.status_code != 200: return None
        data = r.json()
        entries = data.get('data',{}).get('entries',[])
        if not entries: return None
        return entries[0].get('explain','').strip()
    except: return None

txt_files = [
    ('assets/words/gaokao_english.txt', 'gaokao_full.json'),
    ('assets/words/kaoyan_english.txt', 'kaoyan_full.json'),
]

for txt_path, json_name in txt_files:
    txt = pathlib.Path(txt_path)
    if not txt.exists():
        print(f"⚠ {txt_path} 不存在")
        continue
    print(f"📖 处理: {txt.name}")
    words = [ln.strip() for ln in txt.read_text(encoding='utf-8').splitlines() if ln.strip() and not ln.startswith('#')]
    results = []
    for i,w in enumerate(words,1):
        print(f"[{i}/{len(words)}] {w}")
        definition = fetch(w)
        if definition:
            results.append({'word':w,'phonetic':'','definition':definition,'example':'','exampleTranslation':''})
        else:
            results.append({'word':w,'phonetic':'','definition':f"[释义待补充] {w}",'example':'','exampleTranslation':''})
        time.sleep(0.12)
    out = pathlib.Path(f'assets/wordbooks/{json_name}')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"✅ 完成 {json_name}（{len(results)} 条）\n")

print("🎉 全部完成!")
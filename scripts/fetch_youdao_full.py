#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用有道词典 API 批量抓取所有资产词表（gaokao、ielts、toefl、daily、etc）
- 输入：assets/wordlists/*.txt（每行一个单词）
- 输出：assets/wordbooks/<name>_full.json（包含 word, phonetic, definition, example, exampleTranslation）

使用方法：
    cd C:\qingmang_weiji
    pip install requests   # 如未安装
    python scripts/fetch_youdao_full.py

生成的 JSON 可以直接放入项目的内置词库列表中。
"""

import json, time, pathlib, sys

try:
    import requests
except ImportError:
    print("请先安装 requests: pip install requests")
    sys.exit(1)

# 关闭 SSL 警告（国内网络经常出现证书问题）
import warnings
warnings.filterwarnings('ignore')

BASE_URL = "https://dict.youdao.com/suggest"

def fetch_definition(word: str) -> dict | None:
    """从有道词典获取中文释义（返回 dict）"""
    try:
        params = {
            'num': '1',
            'ver': '3.0',
            'doctype': 'json',
            'le': 'en',
            'q': word,
        }
        resp = requests.get(BASE_URL, params=params, timeout=8, verify=False)
        if resp.status_code != 200:
            return None
        data = resp.json()
        entries = data.get('data', {}).get('entries', [])
        if not entries:
            return None
        # 只取第一条
        entry = entries[0]
        definition = entry.get('explain', '')
        # 有道的解释通常是 "n. xxxx; v. xxxx"，直接存入
        return {
            'definition': definition.strip(),
            'phonetic': '',
            'example': '',
            'exampleTranslation': '',
        }
    except Exception as e:
        print(f"❌ {word}: {e}")
        return None

def process_file(txt_path: pathlib.Path, out_path: pathlib.Path):
    print(f"📖 读取词表: {txt_path.name}")
    words = [line.strip() for line in txt_path.read_text(encoding='utf-8').splitlines() if line.strip()]
    results = []
    for i, w in enumerate(words, 1):
        print(f"[{i}/{len(words)}] 抓取: {w}")
        info = fetch_definition(w)
        if info:
            results.append({
                'word': w,
                'phonetic': info['phonetic'],
                'definition': info['definition'],
                'example': info['example'],
                'exampleTranslation': info['exampleTranslation'],
            })
        else:
            # 若未抓到，仍保留占位符，以免丢词
            results.append({
                'word': w,
                'phonetic': '',
                'definition': f"[释义待补充] {w}",
                'example': '',
                'exampleTranslation': '',
            })
        time.sleep(0.15)  # 控制请求频率，防止限流
    # 写入 JSON
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"✅ 完成 {txt_path.name} → {out_path.name}（{len(results)} 条）\n")

def main():
    base_txt = pathlib.Path('assets/wordlists')
    base_out = pathlib.Path('assets/wordbooks')
    txt_files = list(base_txt.glob('*.txt'))
    if not txt_files:
        print('⚠ 没有找到任何 .txt 词表')
        return
    for txt in txt_files:
        # 生成类似 gaokao_full.json、ielts_full.json
        out_name = f"{txt.stem}_full.json"
        out_path = base_out / out_name
        process_file(txt, out_path)

if __name__ == '__main__':
    main()

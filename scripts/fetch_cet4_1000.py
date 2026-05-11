#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为 CET-4 词库前 1000 个词抓取完整释义
输入：assets/wordbooks/cet4.txt（每行一个单词）
输出：assets/wordbooks/cet4_complete_1000.json（包含 phonetic, definition, example）
"""

import json
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("请先安装 requests: pip install requests")
    sys.exit(1)

API_URL = "https://api.dictionaryapi.dev/api/v2/entries/en"


def fetch_definition(word: str):
    """从 Free Dictionary API 获取单词信息"""
    try:
        resp = requests.get(f"{API_URL}/{word.lower()}", timeout=10)
        if resp.status_code != 200:
            return None
        data = resp.json()
        if not data:
            return None
        entry = data[0]
        phonetic = ""
        definition = ""
        example = ""

        # 提取音标
        for p in entry.get("phonetics", []):
            if p.get("text"):
                phonetic = p["text"]
                break

        # 提取释义（取第一个含义的第一个定义）
        for meaning in entry.get("meanings", []):
            defs = meaning.get("definitions", [])
            if defs:
                definition = defs[0].get("definition", "")
                if definition:
                    break

        # 提取例句
        for meaning in entry.get("meanings", []):
            defs = meaning.get("definitions", [])
            for d in defs:
                if d.get("example"):
                    example = d["example"]
                    break
            if example:
                break

        return {
            "phonetic": phonetic,
            "definition": definition,
            "example": example,
        }
    except Exception as e:
        print(f"  ❌ {word}: {e}")
        return None


def main():
    wordlist_path = Path("assets/wordbooks/cet4.txt")
    output_path = Path("assets/wordbooks/cet4_complete_1000.json")

    if not wordlist_path.exists():
        print(f"❌ 文件不存在: {wordlist_path}")
        print("请确保你在项目根目录，并且 cet4.txt 存在")
        sys.exit(1)

    print(f"📖 读取单词列表: {wordlist_path}")
    with open(wordlist_path, "r", encoding="utf-8") as f:
        words = [line.strip() for line in f if line.strip()]

    print(f"✅ 找到 {len(words)} 个单词，将抓取前 1000 个（可修改为 [:100] 快速测试）")
    target_words = words[:1000]

    results = []
    failed = []

    for i, word in enumerate(target_words, 1):
        print(f"[{i:4d}/100] 抓取: {word}")
        result = fetch_definition(word)
        if result:
            results.append({
                "word": word,
                "phonetic": result["phonetic"],
                "definition": result["definition"],
                "example": result["example"],
                "exampleTranslation": "",  # API 不提供，留空
            })
        else:
            failed.append(word)
        # 控制频率
        import time
        time.sleep(0.2)

    # 保存
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n✅ 完成！")
    print(f"   成功: {len(results)} 个词")
    print(f"   失败: {len(failed)} 个词")
    if failed:
        print(f"   失败列表: {failed[:20]}...")

    print(f"📄 输出文件: {output_path}")
    print("\n下一步：")
    print("  1. 备份原文件: rename assets\\wordbooks\\cet4_full.json cet4_full.json.bak")
    print("  2. 替换: copy assets\\wordbooks\\cet4_complete_1000.json assets\\wordbooks\\cet4_full.json")
    print("  3. 重启应用: flutter clean && flutter run")


if __name__ == "__main__":
    main()

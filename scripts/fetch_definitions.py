#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量抓取单词释义脚本
用途：更新 assets/wordbooks/*.json 中的占位符释义，调用 Free Dictionary API
用法：
  python fetch_definitions.py --file assets/wordbooks/cet4_full.json
  python fetch_definitions.py --all  # 批量处理所有词库
"""

import argparse
import json
import sys
import time
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


def process_file(filepath: Path, limit: int = None, dry_run: bool = False):
    """处理单个 JSON 词库文件"""
    print(f"\n📖 处理: {filepath.name}")
    with open(filepath, "r", encoding="utf-8") as f:
        words = json.load(f)

    total = len(words)
    updated = 0
    skipped = 0
    failed = 0

    # 确定处理范围
    indices = range(total) if limit is None else range(min(limit, total))

    for i in indices:
        w = words[i]
        word = w.get("word", "")
        def_cur = w.get("definition", "").strip()

        # 判断是否需要更新
        needs_update = (
            not def_cur or
            "释义待补充" in def_cur or
            def_cur.startswith("[") or
            def_cur == word
        )
        if not needs_update:
            skipped += 1
            continue

        print(f"[{i+1}/{total}] 正在获取: {word}")
        result = fetch_definition(word)

        if result:
            # 合并更新
            if result["phonetic"]:
                w["phonetic"] = result["phonetic"]
            if result["definition"]:
                w["definition"] = result["definition"]
            if result["example"]:
                w["example"] = result["example"]
            updated += 1
        else:
            failed += 1

        # 控制请求频率，避免触发限流
        time.sleep(0.3)

    # 保存
    if not dry_run:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(words, f, ensure_ascii=False, indent=2)
        print(f"✅ 完成: {filepath.name} | 更新={updated}, 跳过={skipped}, 失败={failed}")
    else:
        print(f"[DRY RUN] 将保存: 更新={updated}, 跳过={skipped}, 失败={failed}")

    return updated, skipped, failed


def main():
    parser = argparse.ArgumentParser(description="批量抓取单词释义")
    parser.add_argument("--file", type=Path, help="单个 JSON 词库文件路径")
    parser.add_argument("--all", action="store_true", help="处理 assets/wordbooks 下所有 json 文件")
    parser.add_argument("--limit", type=int, help="限制每个文件处理的最大单词数（测试用）")
    parser.add_argument("--dry-run", action="store_true", help="只打印，不保存文件")
    args = parser.parse_args()

    # 默认 all
    if not args.file and not args.all:
        args.all = True

    if args.all:
        wordbooks_dir = Path("assets/wordbooks")
        if not wordbooks_dir.exists():
            print(f"错误: 目录不存在 {wordbooks_dir}")
            sys.exit(1)
        json_files = list(wordbooks_dir.glob("*.json"))
        if not json_files:
            print(f"在 {wordbooks_dir} 中没有找到 JSON 文件")
            sys.exit(1)
        for jf in json_files:
            process_file(jf, limit=args.limit, dry_run=args.dry_run)
    else:
        if not args.file.exists():
            print(f"文件不存在: {args.file}")
            sys.exit(1)
        process_file(args.file, limit=args.limit, dry_run=args.dry_run)


if __name__ == "__main__":
    main()

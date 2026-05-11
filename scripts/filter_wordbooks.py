#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从 ECDICT CSV 中筛选出 CET-4、CET-6、考研词汇
用法：
  python filter_wordbooks.py --input ECDICT-cvs.csv --cet4 assets/wordbooks/cet4.txt --output assets/wordbooks/cet4_complete.json
"""

import argparse
import json
import csv
from pathlib import Path


def load_word_list(list_file: Path) -> set:
    """加载单词列表（每行一个单词）"""
    words = set()
    if not list_file.exists():
        print(f"⚠️ 单词列表文件不存在: {list_file}")
        return words
    with open(list_file, "r", encoding="utf-8") as f:
        for line in f:
            w = line.strip().lower()
            if w:
                words.add(w)
    print(f"✅ 加载单词列表 {list_file.name}: {len(words)} 个词")
    return words


def process_ecdict(csv_path: Path, target_words: set, max_words: int = None) -> list:
    """处理 ECDICT CSV，筛选出目标单词"""
    print(f"\n📖 正在筛选 ECDICT...")
    results = []
    found = set()

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            word = row.get("word", "").strip().lower()
            if not word:
                continue
            if word in target_words and word not in found:
                # 提取字段（ECDICT 字段名可能不同，需适配）
                definition = row.get("definition", "") or row.get("translation", "")
                phonetic = row.get("phonetic", "") or row.get("uk_phon", "") or row.get("us_phon", "")
                example = row.get("example", "") or row.get("example_sentences", "")
                example_trans = row.get("example_translation", "") or row.get("example_zh", "")

                results.append({
                    "word": word,
                    "phonetic": phonetic,
                    "definition": definition,
                    "example": example,
                    "exampleTranslation": example_trans,
                })
                found.add(word)

                if max_words and len(results) >= max_words:
                    break

    print(f"✅ 找到 {len(results)} 个词（目标 {len(target_words)}）")
    missing = target_words - found
    if missing:
        print(f"⚠️ 缺失 {len(missing)} 个词：{list(missing)[:20]}")
    return results


def main():
    parser = argparse.ArgumentParser(description="从 ECDICT CSV 筛选词库")
    parser.add_argument("--input", type=Path, required=True, help="ECDICT CSV 文件路径")
    parser.add_argument("--cet4", type=Path, help="CET-4 单词列表文件（每行一个词）")
    parser.add_argument("--cet6", type=Path, help="CET-6 单词列表文件")
    parser.add_argument("--kaoyan", type=Path, help="考研单词列表文件")
    parser.add_argument("--output-dir", type=Path, default=Path("assets/wordbooks"), help="输出目录")
    parser.add_argument("--limit", type=int, help="限制每个词库的最大词数（测试用）")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)

    if args.cet4:
        words = load_word_list(args.cet4)
        data = process_ecdict(args.input, words, max_words=args.limit)
        out_path = args.output_dir / "cet4_complete.json"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ CET-4 词库已生成: {out_path} ({len(data)} 词)")

    if args.cet6:
        words = load_word_list(args.cet6)
        data = process_ecdict(args.input, words, max_words=args.limit)
        out_path = args.output_dir / "cet6_complete.json"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ CET-6 词库已生成: {out_path} ({len(data)} 词)")

    if args.kaoyan:
        words = load_word_list(args.kaoyan)
        data = process_ecdict(args.input, words, max_words=args.limit)
        out_path = args.output_dir / "kaoyan_complete.json"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ 考研词库已生成: {out_path} ({len(data)} 词)")


if __name__ == "__main__":
    main()

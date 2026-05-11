#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用有道词典 API 批量填充词库释义
输入：assets/wordbooks/cet4_full.json
输出：cet4_full.json（已填充中文释义）
"""

import json
import time
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("pip install requests")
    sys.exit(1)


def fetch_youdao(word: str) -> dict:
    """从有道词典 API 获取中文释义"""
    try:
        url = f"https://dict.youdao.com/suggest?num=1&ver=3.0&doctype=json&le=en&q={word}"
        resp = requests.get(url, timeout=8, verify=False)
        if resp.status_code != 200:
            return None
        
        data = resp.json()
        entries = data.get("data", {}).get("entries", [])
        if not entries:
            return None
        
        # 取第一个结果
        first = entries[0]
        definition = first.get("explain", "")
        
        if not definition:
            return None
            
        # 解析中文释义（可能有多个，用分号或句号分隔）
        # 取第一个完整的释义
        defs = definition.split(";")[:2]  # 取前2个
        clean_def = "; ".join([d.strip() for d in defs if d.strip()])
        
        return {
            "definition": clean_def,
            "example": "",
            "exampleTranslation": "",
        }
    except Exception as e:
        print(f"  ❌ {word}: {e}")
        return None


def main():
    input_file = Path("assets/wordbooks/cet4_full.json")
    output_file = Path("assets/wordbooks/cet4_full.json")
    max_words = 1000  # 可修改为 5431 填满全部
    
    print(f"📖 读取词库: {input_file}")
    with open(input_file, "r", encoding="utf-8") as f:
        words = json.load(f)
    
    print(f"✅ 词库共有 {len(words)} 个词，将填充前 {max_words} 个")
    
    success = 0
    failed = 0
    
    for i, w in enumerate(words[:max_words], 1):
        word = w.get("word", "")
        current_def = w.get("definition", "")
        
        # 检查是否需要更新
        if current_def and "释义待补充" not in current_def and current_def.strip():
            print(f"[{i:4d}/{max_words}] 跳过 {word}（已有释义）")
            continue
            
        result = fetch_youdao(word)
        
        if result:
            w["definition"] = result["definition"]
            # 有道不提供音标，保留原字段
            success += 1
            print(f"[{i:4d}/{max_words}] ✅ {word}: {result['definition'][:30]}...")
        else:
            failed += 1
            print(f"[{i:4d}/{max_words}] ❌ {word}")
        
        time.sleep(0.15)  # 避免太快触发限流
    
    # 保存
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    
    print(f"\n✅ 完成！")
    print(f"   成功: {success} 个")
    print(f"   失败: {failed} 个")
    print(f"   已保存到: {output_file}")


if __name__ == "__main__":
    main()
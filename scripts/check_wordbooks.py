import json

files = [
    r"C:\qingmang_weiji\assets\wordbooks\cet4_full.json",
    r"C:\qingmang_weiji\assets\wordbooks\cet6_full.json",
    r"C:\qingmang_weiji\assets\wordbooks\kaoyan_full.json",
    r"C:\qingmang_weiji\assets\wordbooks\google_10000_full.json",
    r"C:\qingmang_weiji\assets\wordbooks\common_english_words_full.json",
]

for filepath in files:
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        name = filepath.split('\\')[-1].replace('_full.json', '')
        print(f"{name}: {len(data)} 词")
        if data:
            print(f"  示例: {data[0]['word']} - {data[0]['definition'][:40]}")
    except Exception as e:
        print(f"{filepath}: 错误 - {e}")
import json
import os

# 词库目录
WORD_DIR = r"C:\qingmang_weiji\assets\wordbooks"

def load_json(filename):
    path = os.path.join(WORD_DIR, filename)
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(words, filename):
    path = os.path.join(WORD_DIR, filename)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(words, f, ensure_ascii=False, indent=2)

print("=" * 50)
print("生成完整词库")
print("=" * 50)

# 加载所有词库
cet4 = load_json('cet4_full.json')
google = load_json('google_10000_full.json')
common = load_json('common_english_words_full.json')

print(f"CET-4: {len(cet4)} 词")
print(f"Google: {len(google)} 词")

# 构建词汇集合
cet4_words = {w['word'].lower(): w for w in cet4}
google_words = {w['word'].lower(): w for w in google}

print("\n[1/3] 处理 CET-4 词库...")
# CET-4: 保留现有词汇
cet4_final = list(cet4_words.values())
save_json(cet4_final, 'cet4_full.json')
print(f"  CET-4: {len(cet4_final)} 词")

print("\n[2/3] 生成 CET-6 词库...")
# CET-6: 现有CET-6词汇 + 从Google 10000中选取较长词汇（>=5字母）
cet6_words = {}

# 先添加现有CET-6词汇
for w in load_json('cet6_full.json'):
    cet6_words[w['word'].lower()] = w

# 从Google 10000中补充（选择长度>=6的词汇，排除已存在于CET-4的）
for word_lower, word_data in google_words.items():
    if word_lower not in cet4_words:  # 不在CET-4中
        if len(word_lower) >= 6:  # 较长的词汇
            if word_lower not in cet6_words:
                cet6_words[word_lower] = word_data

cet6_final = list(cet6_words.values())
save_json(cet6_final, 'cet6_full.json')
print(f"  CET-6: {len(cet6_final)} 词")

print("\n[3/3] 生成考研词库...")
# 考研: CET-6 + 从Google补充更多高难度词汇
kaoyan_words = {}

# 添加CET-6所有词汇
for w in cet6_final:
    kaoyan_words[w['word'].lower()] = w

# 从Google 10000后半部分补充（更难的词汇）
google_mid = google[500:]
for w in google_mid:
    word_lower = w['word'].lower()
    if word_lower not in kaoyan_words and len(word_lower) >= 5:
        kaoyan_words[word_lower] = w

kaoyan_final = list(kaoyan_words.values())
save_json(kaoyan_final, 'kaoyan_full.json')
print(f"  考研: {len(kaoyan_final)} 词")

print("\n" + "=" * 50)
print("完成!")
print("=" * 50)
print(f"CET-4: {len(cet4_final)} 词")
print(f"CET-6: {len(cet6_final)} 词")
print(f"考研: {len(kaoyan_final)} 词")
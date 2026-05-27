import json
import random
import os

# 设置随机种子，确保每次生成的顺序一致
random.seed(42)

# 词库配置
wordbooks = [
    {'id': 'chuzhong', 'name': '初中英语词汇', 'description': '初中英语必背词汇（含音标、释义、短语、例句）'},
    {'id': 'gaozhong', 'name': '高中英语词汇', 'description': '高中英语必背词汇（含音标、释义、短语、例句）'},
    {'id': 'cet4', 'name': '大学英语四级', 'description': '大学英语四级考试核心词汇（含音标、释义、短语、例句）'},
    {'id': 'cet6', 'name': '大学英语六级', 'description': '大学英语六级考试核心词汇（含音标、释义、短语、例句）'},
    {'id': 'kaoyan', 'name': '考研英语词汇', 'description': '研究生入学考试英语词汇（含音标、释义、短语、例句）'},
    {'id': 'toefl', 'name': '托福词汇', 'description': '托福考试核心词汇（含音标、释义、短语、例句）'},
    {'id': 'sat', 'name': 'SAT词汇', 'description': 'SAT考试核心词汇（含音标、释义、短语、例句）'},
]

# 词库目录
wordbook_dir = 'assets/wordbooks'

for wb in wordbooks:
    original_file = os.path.join(wordbook_dir, f"{wb['id']}.json")
    shuffled_file = os.path.join(wordbook_dir, f"{wb['id']}_shuffled.json")
    
    print(f"处理: {wb['name']}")
    
    # 读取原词库
    with open(original_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # 提取单词列表
    words = data.get('words', [])
    print(f"  原词数: {len(words)}")
    
    # 打乱顺序
    random.shuffle(words)
    print(f"  已打乱顺序")
    
    # 生成新词库数据
    shuffled_data = {
        'name': f"{wb['name']}（乱序）",
        'description': f"{wb['description']}（单词顺序已打乱）",
        'is_built_in': 1,
        'total_words': len(words),
        'version': '2.0.0',
        'source': 'ECDICT merged txt (shuffled)',
        'words': words
    }
    
    # 写入新文件
    with open(shuffled_file, 'w', encoding='utf-8') as f:
        json.dump(shuffled_data, f, ensure_ascii=False, indent=2)
    
    print(f"  已生成: {shuffled_file}")
    print()

print("所有乱序词库生成完成！")

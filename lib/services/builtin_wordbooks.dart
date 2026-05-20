/// 内置词库数据定义 - v2.0.0 (ECDICT 数据源)
/// 
/// 词书配置与 assets/wordbooks/wordbook_index.json 保持一致
/// 实际词书数据存储在 JSON 文件中，由 SeedService 负责导入
class BuiltInWordBooks {
  /// 获取内置词库配置列表（用于 UI 展示，不包含实际单词数据）
  static List<Map<String, dynamic>> getWordBooks() {
    return [
      {
        'id': 'chuzhong',
        'name': '初中英语词汇',
        'description': '初中英语必背词汇（含音标、释义、短语、例句）',
        'wordCount': 1990,
        'icon': 'school',
      },
      {
        'id': 'gaozhong',
        'name': '高中英语词汇',
        'description': '高中英语必背词汇（含音标、释义、短语、例句）',
        'wordCount': 3750,
        'icon': 'school',
      },
      {
        'id': 'cet4',
        'name': '大学英语四级',
        'description': '大学英语四级考试核心词汇（含音标、释义、短语、例句）',
        'wordCount': 4544,
        'icon': 'menu_book',
      },
      {
        'id': 'cet6',
        'name': '大学英语六级',
        'description': '大学英语六级考试核心词汇（含音标、释义、短语、例句）',
        'wordCount': 3991,
        'icon': 'menu_book',
      },
      {
        'id': 'kaoyan',
        'name': '考研英语词汇',
        'description': '研究生入学考试英语词汇（含音标、释义、短语、例句）',
        'wordCount': 5052,
        'icon': 'school',
      },
      {
        'id': 'toefl',
        'name': '托福词汇',
        'description': '托福考试核心词汇（含音标、释义、短语、例句）',
        'wordCount': 10287,
        'icon': 'public',
      },
      {
        'id': 'sat',
        'name': 'SAT词汇',
        'description': 'SAT考试核心词汇（含音标、释义、短语、例句）',
        'wordCount': 4451,
        'icon': 'public',
      },
    ];
  }

  /// 获取词库ID列表
  static List<String> getWordBookIds() {
    return getWordBooks().map((wb) => wb['id'] as String).toList();
  }
}

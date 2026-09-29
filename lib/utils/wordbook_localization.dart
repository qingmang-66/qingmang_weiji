import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/providers/theme_provider.dart';

/// 内置词库名称的英文对照
///
/// 数据库里存的仍是中文原名（导入时的 `isBookNameExists` 判断、
/// 词库去重逻辑都依赖它），这里只做**显示层**的翻译：
/// 英文界面下把内置词库名换成对应的英文说法，用户自定义的词库保持原样。
const Map<String, String> _builtInBookNamesEn = {
  '初中英语词汇': 'Junior High Vocabulary',
  '初中英语词汇（乱序）': 'Junior High Vocabulary (Shuffled)',
  '高中英语词汇': 'Senior High Vocabulary',
  '高中英语词汇（乱序）': 'Senior High Vocabulary (Shuffled)',
  '大学英语四级': 'CET-4 Vocabulary',
  '大学英语四级（乱序）': 'CET-4 Vocabulary (Shuffled)',
  '大学英语六级': 'CET-6 Vocabulary',
  '大学英语六级（乱序）': 'CET-6 Vocabulary (Shuffled)',
  '考研英语词汇': 'Postgraduate Exam Vocabulary',
  '考研英语词汇（乱序）': 'Postgraduate Exam Vocabulary (Shuffled)',
  '托福词汇': 'TOEFL Vocabulary',
  '托福词汇（乱序）': 'TOEFL Vocabulary (Shuffled)',
  'SAT词汇': 'SAT Vocabulary',
  'SAT词汇（乱序）': 'SAT Vocabulary (Shuffled)',
};

/// 内置词库描述的英文对照（完整映射，避免"中文名 + 英文后缀"的半翻译）。
///
/// 资产里的描述与名称不完全一致（如"初中英语必背词汇" vs "初中英语词汇"），
/// 用 `startsWith` 替换名称会漏掉大部分条目，导致英文界面下描述仍是中文。
const Map<String, String> _builtInBookDescriptionsEn = {
  '初中英语必背词汇（含音标、释义、短语、例句）':
      'Junior high school essential vocabulary (with phonetics, definitions, phrases and examples)',
  '初中英语必背词汇（含音标、释义、短语、例句）（单词顺序已打乱）':
      'Junior high school essential vocabulary (with phonetics, definitions, phrases and examples) (shuffled order)',
  '高中英语必背词汇（含音标、释义、短语、例句）':
      'Senior high school essential vocabulary (with phonetics, definitions, phrases and examples)',
  '高中英语必背词汇（含音标、释义、短语、例句）（单词顺序已打乱）':
      'Senior high school essential vocabulary (with phonetics, definitions, phrases and examples) (shuffled order)',
  '大学英语四级考试核心词汇（含音标、释义、短语、例句）':
      'CET-4 core vocabulary (with phonetics, definitions, phrases and examples)',
  '大学英语四级考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）':
      'CET-4 core vocabulary (with phonetics, definitions, phrases and examples) (shuffled order)',
  '大学英语六级考试核心词汇（含音标、释义、短语、例句）':
      'CET-6 core vocabulary (with phonetics, definitions, phrases and examples)',
  '大学英语六级考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）':
      'CET-6 core vocabulary (with phonetics, definitions, phrases and examples) (shuffled order)',
  '研究生入学考试英语词汇（含音标、释义、短语、例句）':
      'Postgraduate entrance exam vocabulary (with phonetics, definitions, phrases and examples)',
  '研究生入学考试英语词汇（含音标、释义、短语、例句）（单词顺序已打乱）':
      'Postgraduate entrance exam vocabulary (with phonetics, definitions, phrases and examples) (shuffled order)',
  '托福考试核心词汇（含音标、释义、短语、例句）':
      'TOEFL core vocabulary (with phonetics, definitions, phrases and examples)',
  '托福考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）':
      'TOEFL core vocabulary (with phonetics, definitions, phrases and examples) (shuffled order)',
  'SAT考试核心词汇（含音标、释义、短语、例句）':
      'SAT core vocabulary (with phonetics, definitions, phrases and examples)',
  'SAT考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）':
      'SAT core vocabulary (with phonetics, definitions, phrases and examples) (shuffled order)',
};

/// 词库名英文化：只翻译内置词库，其余（用户自建 / 导入的）原样返回
String localizeWordBookName(String rawName, bool english) {
  if (!english) return rawName;
  return _builtInBookNamesEn[rawName] ?? rawName;
}

/// 词库描述英文化：优先查完整映射，未命中的描述原样返回
String localizeWordBookDescription(String rawDescription, bool english) {
  if (!english || rawDescription.isEmpty) return rawDescription;
  return _builtInBookDescriptionsEn[rawDescription] ?? rawDescription;
}

/// 便捷入口：`context.wordBookName(book.name)`
///
/// 这里刻意用 `read`（而不是 `select`）：词库名既会在 build 里取，
/// 也会在弹窗回调、`initState` 之后的异步加载里取，而 `context.select`
/// 一旦不在 build 中调用就会直接触发 provider 断言把整段逻辑打断。
/// 语言切换时的刷新由上层负责：首页在语言变化时会重建五个 Tab 页面，
/// 设置页各分组本身也订阅了 ThemeProvider。
extension WordBookLocalizationX on BuildContext {
  bool get _isEnglishLocale =>
      read<ThemeProvider>().isEnglishLocale;

  String wordBookName(String rawName) =>
      localizeWordBookName(rawName, _isEnglishLocale);

  String wordBookDescription(String rawDescription) =>
      localizeWordBookDescription(rawDescription, _isEnglishLocale);
}

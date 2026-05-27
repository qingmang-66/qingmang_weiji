import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

/// 从资产文件读取内置词库（不使用网络，完全离线）
/// 注意：此服务使用与 SeedService 相同的词库配置，确保名称一致
class AssetWordBookService {
  /// 预定义的词库列表（与 SeedService._builtInWordBooks 保持一致）
  static const List<Map<String, String>> _bookDefinitions = [
    {
      'name': '初中英语词汇',
      'description': '初中英语必背词汇（含音标、释义、短语、例句）',
      'file': 'chuzhong.json',
    },
    {
      'name': '初中英语词汇（乱序）',
      'description': '初中英语必背词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'chuzhong_shuffled.json',
    },
    {
      'name': '高中英语词汇',
      'description': '高中英语必背词汇（含音标、释义、短语、例句）',
      'file': 'gaozhong.json',
    },
    {
      'name': '高中英语词汇（乱序）',
      'description': '高中英语必背词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'gaozhong_shuffled.json',
    },
    {
      'name': '大学英语四级',
      'description': '大学英语四级考试核心词汇（含音标、释义、短语、例句）',
      'file': 'cet4.json',
    },
    {
      'name': '大学英语四级（乱序）',
      'description': '大学英语四级考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'cet4_shuffled.json',
    },
    {
      'name': '大学英语六级',
      'description': '大学英语六级考试核心词汇（含音标、释义、短语、例句）',
      'file': 'cet6.json',
    },
    {
      'name': '大学英语六级（乱序）',
      'description': '大学英语六级考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'cet6_shuffled.json',
    },
    {
      'name': '考研英语词汇',
      'description': '研究生入学考试英语词汇（含音标、释义、短语、例句）',
      'file': 'kaoyan.json',
    },
    {
      'name': '考研英语词汇（乱序）',
      'description': '研究生入学考试英语词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'kaoyan_shuffled.json',
    },
    {
      'name': '托福词汇',
      'description': '托福考试核心词汇（含音标、释义、短语、例句）',
      'file': 'toefl.json',
    },
    {
      'name': '托福词汇（乱序）',
      'description': '托福考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'toefl_shuffled.json',
    },
    {
      'name': 'SAT 词汇',
      'description': 'SAT 考试核心词汇（含音标、释义、短语、例句）',
      'file': 'sat.json',
    },
    {
      'name': 'SAT 词汇（乱序）',
      'description': 'SAT 考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'sat_shuffled.json',
    },
  ];

  /// 获取所有内置词库信息
  static Future<List<Map<String, dynamic>>> getAllBuiltInBooks() async {
    final result = <Map<String, dynamic>>[];

    for (final book in _bookDefinitions) {
      final words = await _loadWordsFromAsset(book['file']!);
      result.add({
        'name': book['name'],
        'description': book['description'],
        'wordCount': words.length,
        'words': words,
      });
    }

    return result;
  }

  /// 从单个资产文件加载单词（JSON 格式）
  static Future<List<Map<String, String>>> _loadWordsFromAsset(String fileName) async {
    try {
      final String raw = await rootBundle.loadString('assets/wordbooks/$fileName');
      final jsonData = jsonDecode(raw) as Map<String, dynamic>;
      final wordsList = jsonData['words'] as List<dynamic>;
      
      final words = <Map<String, String>>[];
      
      for (final wordData in wordsList) {
        final wordMap = wordData as Map<String, dynamic>;
        words.add({
          'word': wordMap['word'] as String? ?? '',
          'phonetic': wordMap['phonetic'] as String? ?? '',
          'definition': wordMap['definition'] as String? ?? '',
          'phrases': wordMap['phrases'] as String? ?? '',
          'example': wordMap['example'] as String? ?? '',
          'exampleTranslation': wordMap['exampleTranslation'] as String? ?? '',
        });
      }
      
      return words;
    } catch (e) {
      debugPrint('Error loading word list $fileName: $e');
      return [];
    }
  }
}

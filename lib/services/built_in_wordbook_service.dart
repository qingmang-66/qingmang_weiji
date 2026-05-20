import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// 内置词库加载服务 - 从 assets 加载，不依赖网络
class BuiltInWordBookService {
  /// 获取内置词库列表
  static List<Map<String, dynamic>> getBuiltInOptions() {
    return [
      {
        'name': 'CET-4 词汇',
        'description': '大学英语四级词汇（约 2500 词）',
        'assetPath': 'assets/wordbooks/cet4_full.json',
        'version': '1.0',
      },
      {
        'name': 'CET-6 词汇',
        'description': '大学英语六级词汇（约 2500 词）',
        'assetPath': 'assets/wordbooks/cet6_full.json',
        'version': '1.0',
      },
      {
        'name': '考研英语词汇',
        'description': '考研英语大纲词汇',
        'assetPath': 'assets/wordbooks/kaoyan_full.json',
        'version': '1.0',
      },
      {
        'name': '高考英语词汇',
        'description': '高考英语必背词汇（约 3500 词）',
        'assetPath': 'assets/wordbooks/gaokao_full.json',
        'version': '1.0',
        'isSimple': true, // 纯单词格式
      },
    ];
  }

  /// 按分类获取词库
  static Map<String, List<Map<String, dynamic>>> getOptionsByCategory() {
    final options = getBuiltInOptions();
    final result = <String, List<Map<String, dynamic>>>{};
    
    for (final opt in options) {
      final category = _getCategory(opt['name'] as String);
      final list = result.putIfAbsent(category, () => []);
      list.add(opt);
    }
    
    return result;
  }

  static String _getCategory(String name) {
    if (name.contains('CET-4') || name.contains('CET-6')) return '🌟 大学英语 (CET)';
    if (name.contains('考研')) return '📚 考研英语';
    if (name.contains('高考')) return '🎓 高考英语';
    return '📖 基础词汇';
  }

  /// 从 assets 导入词库
  /// 返回导入的单词数量，失败返回 -1
  static Future<int> importFromAssets(String name, String assetPath, bool isSimple) async {
    try {
      // 加载 asset 内容
      final String content = await rootBundle.loadString(assetPath);
      
      List<Word> words;
      
      if (isSimple) {
        // 纯单词格式（每行一个单词）
        final lines = content.split('\n');
        words = lines
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .map((word) => Word(
                  word: word,
                  phonetic: '',
                  definition: '',
                  wordBookId: 0, // 临时
                ))
            .toList();
      } else {
        // JSON 格式
        final List<dynamic> data = jsonDecode(content);
        words = data.map((item) {
          final map = item as Map<String, dynamic>;
          return Word(
            word: map['word'] ?? '',
            phonetic: map['phonetic'] ?? '',
            definition: map['definition'] ?? '',
            example: map['example'],
            exampleTranslation: map['example_translation'],
            wordBookId: 0,
          );
        }).where((w) => w.word.isNotEmpty).toList();
      }

      return words.length;
    } catch (e) {
      return -1;
    }
  }
}
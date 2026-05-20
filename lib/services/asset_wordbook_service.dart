import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// 从资产文件读取内置词库（不使用网络，完全离线）
class AssetWordBookService {
  /// 预定义的词库列表
  static const List<Map<String, String>> _bookDefinitions = [
    {
      'name': '初中词汇',
      'description': '初中英语必背词汇（约 2000 词）',
      'file': 'chuzhong.txt',
    },
    {
      'name': '高中词汇',
      'description': '高中英语必背词汇（约 3750 词）',
      'file': 'gaozhong.txt',
    },
    {
      'name': '四级词汇',
      'description': '大学英语四级词汇（约 4500 词）',
      'file': 'cet4.txt',
    },
    {
      'name': '六级词汇',
      'description': '大学英语六级词汇（约 4000 词）',
      'file': 'cet6.txt',
    },
    {
      'name': '考研词汇',
      'description': '考研英语大纲词汇（约 5050 词）',
      'file': 'kaoyan.txt',
    },
    {
      'name': '托福词汇',
      'description': '托福考试核心词汇（约 10300 词）',
      'file': 'toefl.txt',
    },
    {
      'name': 'SAT词汇',
      'description': 'SAT考试核心词汇（约 4460 词）',
      'file': 'sat.txt',
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

  /// 从单个资产文件加载单词
  static Future<List<Map<String, String>>> _loadWordsFromAsset(String fileName) async {
    try {
      final String raw = await rootBundle.loadString('assets/wordlists/$fileName');
      final lines = raw.split('\n');
      final words = <Map<String, String>>[];
      
      for (final line in lines) {
        var trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        // 去除可能存在的首尾双引号
        if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
          trimmed = trimmed.substring(1, trimmed.length - 1);
        }
        
        // 格式解析：单词 音标 释义（制表符分隔）
        // 例: ability ə'bɪləti [n] 能力，能耐；才能
        final parts = _parseWordLine(trimmed);
        final word = parts['word'];
        if (word != null && word.isNotEmpty) {
          words.add({
            'word': word,
            'phonetic': parts['phonetic'] ?? '',
            'definition': parts['definition'] ?? '',
          });
        }
      }
      
      return words;
    } catch (e) {
      debugPrint('Error loading word list $fileName: $e');
      return [];
    }
  }

  /// 解析单词行（支持制表符分隔格式）
  static Map<String, String?> _parseWordLine(String line) {
    // 使用制表符分割
    final parts = line.split('	');
    
    if (parts.length >= 3) {
      return {
        'word': parts[0].trim(),
        'phonetic': parts[1].trim(),
        'definition': parts[2].trim(),
      };
    } else if (parts.length == 2) {
      return {
        'word': parts[0].trim(),
        'phonetic': parts[1].trim(),
        'definition': '',
      };
    } else if (parts.length == 1) {
      return {
        'word': parts[0].trim(),
        'phonetic': '',
        'definition': '',
      };
    }
    
    return {'word': null, 'phonetic': null, 'definition': null};
  }
}

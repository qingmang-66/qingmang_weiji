import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// 从资产文件读取内置词库（不使用网络，完全离线）
class AssetWordBookService {
  /// 预定义的词库列表（已清空）
  static const List<Map<String, String>> _bookDefinitions = [];


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
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        // 格式解析：单词 音标 释义（空格分隔）
        // 例: abandon /əˈbændən/ v. 放弃，遗弃
        final parts = _parseWordLine(trimmed);
        if (parts['word'] != null && parts['word']!.isNotEmpty) {
          words.add({
            'word': parts['word']!,
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

  /// 解析单词行（支持多种格式）
  static Map<String, String?> _parseWordLine(String line) {
    // 移除多余空格
    final clean = line.trim();
    
    // 尝试用正则匹配：word phonetic definition
    final regex = RegExp(r'^(\S+)\s+(\S+)\s+(.+)$');
    final match = regex.firstMatch(clean);
    
    if (match != null) {
      return {
        'word': match.group(1),
        'phonetic': match.group(2),
        'definition': match.group(3)?.trim(),
      };
    }
    
    // 回退：只有单词
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      return {
        'word': parts[0],
        'phonetic': parts.length > 1 ? parts[1] : '',
        'definition': parts.length > 2 ? parts.sublist(2).join(' ') : '',
      };
    }
    
    return {'word': null, 'phonetic': null, 'definition': null};
  }
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'import_io.dart' if (dart.library.html) 'import_web.dart' as io;
import 'database_service.dart';

class ImportResult {
  final int count;
  final int wordBookId;
  const ImportResult(this.count, this.wordBookId);
}

class WordImportService {
  static Future<ImportResult> importWordsFromFile(
    String filePath,
    String wordBookName, {
    String? description,
    Database? database,
  }) async {
    final content = await io.readText(filePath);
    if (content == null) throw Exception('文件不存在：$filePath');
    final ext = path.extension(filePath.split('|').last).toLowerCase();
    final rows = _parse(content, ext);
    if (rows.isEmpty) throw Exception('文件中没有有效的单词');
    final db = database ?? await DatabaseService.database;
    return db.transaction((txn) async {
      final duplicate = await txn.query(
        'word_books',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [wordBookName],
        limit: 1,
      );
      if (duplicate.isNotEmpty) throw Exception('词库名称已存在');
      final bookId = await txn.insert('word_books', {
        'name': wordBookName,
        'description': description ?? '从文件导入的单词列表',
        'is_built_in': 0,
        'total_words': rows.length,
      });
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert('words', {
          'word': row['word']!,
          'phonetic': row['phonetic'] ?? '',
          'definition': row['definition'] ?? '',
          'example': row['example'],
          'example_translation': row['exampleTranslation'],
          'word_book_id': bookId,
          'mastery_level': 0,
          'review_count': 0,
          'correct_count': 0,
          'wrong_count': 0,
        });
      }
      await batch.commit(noResult: true);
      return ImportResult(rows.length, bookId);
    });
  }

  static List<Map<String, String?>> _parse(String content, String ext) {
    if (ext == '.json') return _parseJson(content);
    return _parseLines(content);
  }

  static List<Map<String, String?>> _parseLines(String content) {
    final rows = <Map<String, String?>>[];
    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.contains(',')) {
        final parts = trimmed.split(',');
        rows.add({
          'word': parts[0].trim(),
          'phonetic': parts.length > 1 ? parts[1].trim() : null,
          'definition': parts.length > 2 ? parts[2].trim() : null,
        });
      } else if (trimmed.contains('\t')) {
        final parts = trimmed.split('\t');
        rows.add({
          'word': parts[0].trim(),
          'definition': parts.length > 1 ? parts[1].trim() : null,
        });
      } else {
        rows.add({'word': trimmed});
      }
    }
    return rows.where((r) => (r['word'] ?? '').isNotEmpty).toList();
  }

  static List<Map<String, String?>> _parseJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! List) throw const FormatException('JSON 必须是数组');
    return decoded.map((item) {
      if (item is! Map) throw const FormatException('JSON 数组项必须是对象');
      final word = item['word']?.toString().trim() ?? '';
      if (word.isEmpty) throw const FormatException('JSON 单词字段不能为空');
      return <String, String?>{
        'word': word,
        'phonetic': item['phonetic']?.toString(),
        'definition': item['definition']?.toString(),
        'example': item['example']?.toString(),
        'exampleTranslation':
            (item['exampleTranslation'] ?? item['example_translation'])
                ?.toString(),
      };
    }).toList();
  }

  static Future<void> importAllWordBooks() async {
    if (kIsWeb) return;
    // 桌面/移动端批量导入逻辑由调用方触发，Web 跳过
  }
}

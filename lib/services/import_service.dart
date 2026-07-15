import 'dart:convert';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import '../utils/file_compat.dart';
import '../utils/picked_file_helper.dart';
import 'import_io.dart' if (dart.library.html) 'import_web.dart' as io;
import 'database_service.dart';

/// 词库导入服务 - 支持CSV和JSON格式导入
class ImportService {
  static const int _maxImportBytes = 10 * 1024 * 1024;
  static const int _maxImportWords = 50000;

  static Future<ImportResult> importFromFile(
    int wordBookId, {
    String? filePath,
    Function(int completed, int total)? onProgress,
  }) async {
    try {
      String path;
      if (filePath != null) {
        path = filePath;
      } else {
        final picked = await PickedFileHelper.pickSingleFile(
          extensions: ['txt', 'csv', 'json'],
          dialogTitle: '选择词库文件',
        );
        if (picked == null) {
          return ImportResult(success: false, message: '未选择文件');
        }
        path = picked.path;
      }

      final content = await io.readText(path);
      if (content == null) {
        return ImportResult(success: false, message: '文件不存在或无法读取');
      }
      if (content.length > _maxImportBytes) {
        return ImportResult(success: false, message: '文件过大，请选择小于 10MB 的词库文件');
      }
      final ext = p.extension(path.split('|').last).toLowerCase();
      final words = _parseContent(content, ext, wordBookId);
      if (words == null) {
        return ImportResult(success: false, message: '不支持的文件格式');
      }
      if (words.isEmpty) {
        return ImportResult(success: false, message: '文件中没有有效的单词数据');
      }
      if (words.length > _maxImportWords) {
        return ImportResult(
          success: false,
          message: '词条过多，单次最多导入 $_maxImportWords 个单词',
        );
      }
      await DatabaseService.insertWordsBatchFast(words, onProgress: onProgress);
      return ImportResult(
        success: true,
        message: '成功导入 ${words.length} 个单词',
        count: words.length,
      );
    } catch (e) {
      return ImportResult(success: false, message: '导入失败：$e');
    }
  }

  static Future<ImportResult> importFromBuiltIn(
    int wordBookId,
    List<Map<String, String>> words,
  ) async {
    try {
      if (words.isEmpty) {
        return ImportResult(success: false, message: '词库为空');
      }
      final wordList = words
          .map(
            (w) => Word(
              word: w['word'] ?? '',
              phonetic: w['phonetic'] ?? '',
              definition: w['definition'] ?? '',
              example: w['example']?.isNotEmpty == true ? w['example'] : null,
              exampleTranslation: w['exampleTranslation']?.isNotEmpty == true
                  ? w['exampleTranslation']
                  : null,
              wordBookId: wordBookId,
            ),
          )
          .where((w) => w.word.isNotEmpty)
          .toList();
      await DatabaseService.insertWordsBatchFast(wordList);
      return ImportResult(
        success: true,
        message: '成功导入 ${wordList.length} 个单词',
        count: wordList.length,
      );
    } catch (e) {
      return ImportResult(success: false, message: '导入失败：$e');
    }
  }

  static List<Word>? _parseContent(String content, String ext, int wordBookId) {
    switch (ext) {
      case '.txt':
        return _parseTxt(content, wordBookId);
      case '.csv':
        return _parseCsv(content, wordBookId);
      case '.json':
        return _parseJson(content, wordBookId);
      default:
        return null;
    }
  }

  static List<Word> _parseCsv(String content, int wordBookId) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return [];
    final words = <Word>[];
    int startIndex = lines[0].toLowerCase().contains('word') ? 1 : 0;
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = _splitCsvLine(line);
      if (parts.isEmpty) continue;
      words.add(
        Word(
          word: _sanitizeWord(parts[0].trim()),
          phonetic: parts.length > 1 ? parts[1].trim() : '',
          definition: parts.length > 2 ? parts[2].trim() : '',
          example: parts.length > 3 ? parts[3].trim() : null,
          exampleTranslation: parts.length > 4 ? parts[4].trim() : null,
          wordBookId: wordBookId,
        ),
      );
    }
    return words.where((w) => w.word.isNotEmpty).toList();
  }

  static List<Word> _parseTxt(String content, int wordBookId) {
    final lines = const LineSplitter().convert(content);
    final words = <Word>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          trimmed.startsWith('//')) {
        continue;
      }
      words.add(
        Word(
          word: _sanitizeWord(trimmed),
          phonetic: '',
          definition: '',
          wordBookId: wordBookId,
        ),
      );
    }
    return words;
  }

  static List<Word> _parseJson(String content, int wordBookId) {
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('JSON 词库必须是数组');
    }
    final words = <Word>[];
    for (var item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      words.add(
        Word(
          word: _sanitizeWord('${map['word'] ?? ''}'),
          phonetic: '${map['phonetic'] ?? ''}',
          definition: '${map['definition'] ?? ''}',
          example: map['example']?.toString(),
          exampleTranslation: map['example_translation']?.toString(),
          wordBookId: wordBookId,
        ),
      );
    }
    return words.where((w) => w.word.isNotEmpty).toList();
  }

  static String _sanitizeWord(String value) {
    return value.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int count;
  ImportResult({required this.success, required this.message, this.count = 0});
}

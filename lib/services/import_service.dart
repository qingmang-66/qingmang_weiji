import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import 'database_service.dart';

/// 词库导入服务 - 支持CSV和JSON格式导入
class ImportService {
  static const int _maxImportBytes = 10 * 1024 * 1024;
  static const int _maxImportWords = 50000;

  /// 从文件选择器导入词库
  static Future<ImportResult> importFromFile(int wordBookId, {String? filePath, Function(int completed, int total)? onProgress}) async {
    try {
      String filePathUsed;
      List<Word> words;
      
      if (filePath != null) {
        // 从指定路径导入
        filePathUsed = filePath;
        final file = File(filePath);
        if (!await file.exists()) {
          return ImportResult(success: false, message: '文件不存在');
        }
        final sizeError = await _validateFileSize(file);
        if (sizeError != null) return sizeError;
        words = await _parseTxt(file, wordBookId);
      } else {
        // 从文件选择器选择
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['txt', 'csv', 'json'],
          dialogTitle: '选择词库文件',
        );

        if (result == null || result.files.isEmpty) {
          return ImportResult(success: false, message: '未选择文件');
        }

        filePathUsed = result.files.first.path!;
        final file = File(filePathUsed);
        final sizeError = await _validateFileSize(file);
        if (sizeError != null) return sizeError;
        final extension = p.extension(file.path).toLowerCase();

        if (extension == '.txt') {
          words = await _parseTxt(file, wordBookId);
        } else if (extension == '.csv') {
          words = await _parseCsv(file, wordBookId);
        } else if (extension == '.json') {
          words = await _parseJson(file, wordBookId);
        } else {
          return ImportResult(success: false, message: '不支持的文件格式');
        }
      }

      if (words.isEmpty) {
        return ImportResult(success: false, message: '文件中没有有效的单词数据');
      }
      if (words.length > _maxImportWords) {
        return ImportResult(success: false, message: '词条过多，单次最多导入 $_maxImportWords 个单词');
      }

      // 批量写入数据库，带进度回调
      await DatabaseService.insertWordsBatch(words, onProgress: onProgress);

      return ImportResult(
        success: true,
        message: '成功导入 ${words.length} 个单词',
        count: words.length,
      );
    } catch (e) {
      return ImportResult(success: false, message: '导入失败：$e');
    }
  }

  /// 从内置词库导入
  static Future<ImportResult> importFromBuiltIn(int wordBookId, List<Map<String, String>> words) async {
    try {
      if (words.isEmpty) {
        return ImportResult(success: false, message: '词库为空');
      }

      // 转换为 Word 对象（包含完整字段：音标、释义、例句）
      final wordList = words.map((w) => Word(
        word: w['word'] ?? '',
        phonetic: w['phonetic'] ?? '',
        definition: w['definition'] ?? '',
        example: w['example']?.isNotEmpty == true ? w['example'] : null,
        exampleTranslation: w['exampleTranslation']?.isNotEmpty == true ? w['exampleTranslation'] : null,
        wordBookId: wordBookId,
      )).where((w) => w.word.isNotEmpty).toList();

      // 批量写入数据库
      await DatabaseService.insertWordsBatch(wordList);

      return ImportResult(
        success: true,
        message: '成功导入 ${wordList.length} 个单词',
        count: wordList.length,
      );
    } catch (e) {
      return ImportResult(success: false, message: '导入失败：$e');
    }
  }

  static Future<ImportResult?> _validateFileSize(File file) async {
    final size = await file.length();
    if (size > _maxImportBytes) {
      return ImportResult(success: false, message: '文件过大，请选择小于 10MB 的词库文件');
    }
    return null;
  }

  /// 解析CSV文件
  static Future<List<Word>> _parseCsv(File file, int wordBookId) async {
    final lines = await file.readAsLines(encoding: utf8);
    if (lines.isEmpty) return [];
    final words = <Word>[];
    int startIndex = lines[0].toLowerCase().contains('word') ? 1 : 0;
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = _splitCsvLine(line);
      if (parts.isEmpty) continue;
      words.add(Word(
        word: _sanitizeWord(parts[0].trim()),
        phonetic: parts.length > 1 ? parts[1].trim() : '',
        definition: parts.length > 2 ? parts[2].trim() : '',
        example: parts.length > 3 ? parts[3].trim() : null,
        exampleTranslation: parts.length > 4 ? parts[4].trim() : null,
        wordBookId: wordBookId,
      ));
    }
    return words.where((w) => w.word.isNotEmpty).toList();
  }

  /// 解析纯文本文件
  static Future<List<Word>> _parseTxt(File file, int wordBookId) async {
    final lines = await file.readAsLines(encoding: utf8);
    final words = <Word>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('//')) continue;
      words.add(Word(word: _sanitizeWord(trimmed), phonetic: '', definition: '', wordBookId: wordBookId));
    }
    return words;
  }

  /// 解析JSON文件
  static Future<List<Word>> _parseJson(File file, int wordBookId) async {
    final content = await file.readAsString(encoding: utf8);
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('JSON 词库必须是数组');
    }
    final data = decoded;
    final words = <Word>[];
    for (var item in data) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      words.add(Word(
        word: _sanitizeWord('${map['word'] ?? ''}'),
        phonetic: '${map['phonetic'] ?? ''}',
        definition: '${map['definition'] ?? ''}',
        example: map['example']?.toString(),
        exampleTranslation: map['example_translation']?.toString(),
        wordBookId: wordBookId,
      ));
    }
    return words.where((w) => w.word.isNotEmpty).toList();
  }

  static String _sanitizeWord(String value) {
    return value.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// CSV行分割
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

/// 导入结果
class ImportResult {
  final bool success;
  final String message;
  final int count;
  ImportResult({required this.success, required this.message, this.count = 0});
}

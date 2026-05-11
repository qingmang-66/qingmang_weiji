import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import 'database_service.dart';

/// 词库导入服务 - 支持CSV和JSON格式导入
class ImportService {
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

      // 转换为 Word 对象
      final wordList = words.map((w) => Word(
        word: w['word'] ?? '',
        phonetic: w['phonetic'] ?? '',
        definition: w['definition'] ?? '',
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

  /// 解析CSV文件
  static Future<List<Word>> _parseCsv(File file, int wordBookId) async {
    final lines = await file.readAsLines(encoding: utf8);
    final words = <Word>[];
    int startIndex = lines[0].toLowerCase().contains('word') ? 1 : 0;
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = _splitCsvLine(line);
      if (parts.isEmpty) continue;
      words.add(Word(
        word: parts[0].trim(),
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
      words.add(Word(word: trimmed, phonetic: '', definition: '', wordBookId: wordBookId));
    }
    return words;
  }

  /// 解析JSON文件
  static Future<List<Word>> _parseJson(File file, int wordBookId) async {
    final content = await file.readAsString(encoding: utf8);
    final List<dynamic> data = jsonDecode(content);
    final words = <Word>[];
    for (var item in data) {
      final map = item as Map<String, dynamic>;
      words.add(Word(
        word: map['word'] ?? '',
        phonetic: map['phonetic'] ?? '',
        definition: map['definition'] ?? '',
        example: map['example'],
        exampleTranslation: map['example_translation'],
        wordBookId: wordBookId,
      ));
    }
    return words.where((w) => w.word.isNotEmpty).toList();
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
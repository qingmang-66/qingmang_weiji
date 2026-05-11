import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/models.dart';
import 'database_service.dart';

/// 从文本文件导入单词列表
/// 文件格式：每行一个单词
class WordImportService {
  /// 从文本文件导入单词到指定词库
  static Future<void> importWordsFromFile(
    String filePath,
    String wordBookName, {
    String? description,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在：$filePath');
      }

      final content = await file.readAsString();
      final lines = content
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        throw Exception('文件中没有有效的单词');
      }

      // 数据验证：检查每个单词的格式
      final List<String> invalidWords = [];
      for (final line in lines) {
        // 检查单词是否包含非法字符（只允许字母、数字、连字符、撇号、点）
        final regex = RegExp(r"^[a-zA-Z0-9\-'\.]+$");
        if (!regex.hasMatch(line)) {
          invalidWords.add(line);
        }
      }

      if (invalidWords.isNotEmpty) {
        // 记录无效单词，但不中断导入
        debugPrint('警告：发现 ${invalidWords.length} 个格式可能不规范的单词');
        debugPrint('示例：${invalidWords.take(5).join(", ")}');
        // 可以选择跳过这些单词或继续导入
      }

      debugPrint('准备导入 ${lines.length} 个单词到 "$wordBookName"');

      // 检查词库是否已存在
      final existingBooks = await DatabaseService.getAllWordBooks();
      WordBook? existingBook;
      for (final book in existingBooks) {
        if (book.name == wordBookName) {
          existingBook = book;
          break;
        }
      }

      // 如果词库不存在，创建新词库
      if (existingBook == null) {
        existingBook = WordBook(
          id: null,
          name: wordBookName,
          description: description ?? '从文件导入的单词列表',
          isBuiltIn: true,
          totalWords: lines.length,
        );
        final bookId = await DatabaseService.insertWordBook(existingBook);
        existingBook = existingBook.copyWith(id: bookId);
      }

      // 检查是否已有单词（避免重复导入）
      final hasWords = await DatabaseService.hasWordsInBook(existingBook.id!);
      if (hasWords) {
        debugPrint('词库 "$wordBookName" 中已有单词，跳过导入');
        return;
      }

      // 批量插入单词
      final words = <Word>[];
      for (final wordText in lines) {
        // 简单的单词处理（可以扩展为从网络获取发音和定义）
        words.add(
          Word(
            id: null,
            word: wordText,
            phonetic: '', // 后续可以通过有道 API 获取
            definition: '', // 后续可以通过有道 API 获取
            example: null,
            exampleTranslation: null,
            wordBookId: existingBook.id!,
            root: null,
            suffix: null,
            synonym: null,
            antonym: null,
            derivative: null,
          ),
        );
      }

      // 分批插入（避免内存溢出）
      const batchSize = 100;
      for (var i = 0; i < words.length; i += batchSize) {
        final batch = words.skip(i).take(batchSize).toList();
        await DatabaseService.insertWordsBatch(batch);
        debugPrint('已导入 ${i + batch.length}/${words.length} 个单词');
      }

      // 更新词库总词数
      await DatabaseService.updateWordBookTotalWords(existingBook.id!);
      debugPrint('✓ 成功导入 ${words.length} 个单词到 "$wordBookName"');
    } catch (e) {
      debugPrint('✗ 导入失败：$e');
      rethrow;
    }
  }

  /// 导入所有可用的词库文件
  static Future<void> importAllWordBooks() async {
    try {
      // 获取 assets/words 目录
      final appDir = await getApplicationDocumentsDirectory();
      final wordsDir = Directory(path.join(appDir.path, 'words'));

      // 如果目录不存在，创建并复制默认词库
      if (!await wordsDir.exists()) {
        await wordsDir.create(recursive: true);
        // 复制内置词库
        final defaultWordFile = File('assets/words/common_english_words.txt');
        if (await defaultWordFile.exists()) {
          final destFile = File(path.join(wordsDir.path, 'common_english_words.txt'));
          await defaultWordFile.copy(destFile.path);
        }
      }

      // 扫描所有 txt 文件
      final files = await wordsDir
          .list()
          .where((f) => f is File && f.path.endsWith('.txt'))
          .map((f) => f as File)
          .toList();

      if (files.isEmpty) {
        debugPrint('未找到任何单词文件');
        return;
      }

      debugPrint('找到 ${files.length} 个单词文件');

      for (final file in files) {
        final fileName = path.basenameWithoutExtension(file.path);
        final bookName = _formatBookName(fileName);
        try {
          await importWordsFromFile(
            file.path,
            bookName,
            description: '从 $fileName.txt 导入',
          );
        } catch (e) {
          debugPrint('导入 ${file.path} 失败：$e');
        }
      }

      debugPrint('\n✓ 所有词库导入完成！');
    } catch (e) {
      debugPrint('✗ 导入所有词库失败：$e');
      rethrow;
    }
  }

  /// 格式化词库名称
  static String _formatBookName(String name) {
    // 将下划线或连字符转换为空格，并首字母大写
    return name
        .replaceAll(RegExp(r'[_-]'), ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

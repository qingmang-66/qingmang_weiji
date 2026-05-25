import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/word.dart';
import '../models/word_book.dart';
import 'database_service.dart';

/// 内置词库初始化服务 - v2.0.0 (ECDICT 数据源)
class SeedService {
  // 当前词库版本
  static const String currentVersion = '2.0.0';

  /// 旧词库名称到新词库名称的映射（用于清理重复词库）
  static const Map<String, String> _oldToNewNameMap = {
    '初中词汇': '初中英语词汇',
    '高中词汇': '高中英语词汇',
    '四级词汇': '大学英语四级',
    '六级词汇': '大学英语六级',
    '考研词汇': '考研英语词汇',
    '托福词汇': '托福词汇',
    'SAT 词汇': 'SAT 词汇',
  };

  /// 内置词书配置（与 wordbook_index.json 保持一致）
  static const List<Map<String, dynamic>> _builtInWordBooks = [
    {
      'id': 'chuzhong',
      'name': '初中英语词汇',
      'description': '初中英语必背词汇（含音标、释义、短语、例句）',
      'file': 'assets/wordbooks/chuzhong.json',
      'icon': 'school',
    },
    {
      'id': 'gaozhong',
      'name': '高中英语词汇',
      'description': '高中英语必背词汇（含音标、释义、短语、例句）',
      'file': 'assets/wordbooks/gaozhong.json',
      'icon': 'school',
    },
    {
      'id': 'cet4',
      'name': '大学英语四级',
      'description': '大学英语四级考试核心词汇（含音标、释义、短语、例句）',
      'file': 'assets/wordbooks/cet4.json',
      'icon': 'menu_book',
    },
    {
      'id': 'cet6',
      'name': '大学英语六级',
      'description': '大学英语六级考试核心词汇（含音标、释义、短语、例句）',
      'file': 'assets/wordbooks/cet6.json',
      'icon': 'menu_book',
    },
    {
      'id': 'kaoyan',
      'name': '考研英语词汇',
      'description': '研究生入学考试英语词汇（含音标、释义、短语、例句）',
      'file': 'assets/wordbooks/kaoyan.json',
      'icon': 'school',
    },
    {
      'id': 'toefl',
      'name': '托福词汇',
      'description': '托福考试核心词汇（含音标、释义、短语、例句）',
      'file': 'assets/wordbooks/toefl.json',
      'icon': 'public',
    },
    {
      'id': 'sat',
      'name': 'SAT词汇',
      'description': 'SAT考试核心词汇（含音标、释义、短语、例句）',
      'file': 'assets/wordbooks/sat.json',
      'icon': 'public',
    },
  ];

  /// 初始化或更新内置词库
  static Future<void> seedBuiltInData() async {
    try {
      // 先清理旧名称的重复词库
      await _cleanupOldDuplicateBooks();

      // 再导入新词库
      for (final config in _builtInWordBooks) {
        await _importWordBook(config);
      }
      debugPrint('✓ 内置词库初始化完成（v$currentVersion）');
    } catch (e) {
      debugPrint('❌ 内置词库初始化失败：$e');
    }
  }

  /// 清理旧名称的重复词库
  static Future<void> _cleanupOldDuplicateBooks() async {
    try {
      final existingBooks = await DatabaseService.getAllWordBooks();

      for (final book in existingBooks) {
        // 检查是否是旧名称的词库
        final newName = _oldToNewNameMap[book.name];
        if (newName != null) {
          // 检查是否已经存在对应的新名称词库
          final hasNewBook = existingBooks.any((b) => b.name == newName);
          if (hasNewBook) {
            // 如果新名称词库已存在，删除旧名称词库
            debugPrint('🗑 清理重复词库：删除旧名称 "${book.name}"（已有新名称 "$newName"）');
            await DatabaseService.deleteWordBook(book.id!);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠ 清理重复词库失败：$e');
    }
  }

  /// 重置内置词库（删除并重新导入）
  static Future<void> resetBuiltInData() async {
    try {
      final existingBooks = await DatabaseService.getAllWordBooks();
      for (final book in existingBooks) {
        if (book.isBuiltIn) {
          await DatabaseService.deleteWordBook(book.id!);
        }
      }
      await seedBuiltInData();
      debugPrint('✓ 内置词库已重置');
    } catch (e) {
      debugPrint('❌ 重置内置词库失败：$e');
    }
  }

  /// 从 assets 导入单个词书
  static Future<void> _importWordBook(Map<String, dynamic> config) async {
    final bookName = config['name'] as String;
    final description = config['description'] as String;
    final assetPath = config['file'] as String;

    try {
      // 检查是否已存在且版本一致
      final existingBooks = await DatabaseService.getAllWordBooks();
      final existingBook = existingBooks
          .where((b) => b.name == bookName)
          .firstOrNull;
      if (existingBook != null && existingBook.version == currentVersion) {
        final actualWordCount = await DatabaseService.getWordCountInBook(
          existingBook.id!,
        );
        if (actualWordCount > 0) {
          debugPrint('✓ 词库 "$bookName" 版本已是最新 ($currentVersion)，跳过');
          return;
        }
        debugPrint('⚠ 词库 "$bookName" 记录存在但单词为空，正在重新导入...');
        await DatabaseService.deleteWordBook(existingBook.id!);
      }

      // 从 assets 加载 JSON 数据
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = jsonDecode(jsonString);

      // v2.0.0 格式: {"name": ..., "version": ..., "words": [...]}
      List<dynamic> wordsList;
      if (jsonData is Map && jsonData.containsKey('words')) {
        wordsList = jsonData['words'] as List<dynamic>;
      } else if (jsonData is List) {
        wordsList = jsonData;
      } else {
        debugPrint('⚠ 词库 "$bookName" 格式无效，跳过');
        return;
      }

      if (wordsList.isEmpty) {
        debugPrint('⚠ 词库 "$bookName" 为空，跳过');
        return;
      }

      // 如果存在旧版本，先删除
      if (existingBook != null) {
        debugPrint('⚠ 词库 "$bookName" 版本过旧 (${existingBook.version})，正在更新...');
        await DatabaseService.deleteWordBook(existingBook.id!);
      }

      debugPrint('正在导入词库：$bookName (${wordsList.length} 个词)');

      // 创建词库
      final book = WordBook(
        name: bookName,
        description: description,
        isBuiltIn: true,
        totalWords: wordsList.length,
        version: currentVersion,
      );
      final dbBookId = await DatabaseService.insertWordBook(book);

      // 批量导入单词（使用高性能批量插入）
      const batchSize = 500;
      for (var i = 0; i < wordsList.length; i += batchSize) {
        final batch = wordsList.skip(i).take(batchSize).toList();
        final wordObjects = batch
            .map(
              (w) => Word(
                word: w['word'] as String? ?? '',
                phonetic: w['phonetic'] as String? ?? '',
                definition: w['definition'] as String? ?? '',
                example: w['example'] as String?,
                exampleTranslation: w['exampleTranslation'] as String?,
                wordBookId: dbBookId,
                // v2.0.0 词书暂无 root/suffix/synonym/antonym/derivative 字段
                // 这些字段留给数据库层面的扩展
              ),
            )
            .toList();
        await DatabaseService.insertWordsBatchFast(wordObjects);
      }

      debugPrint('✓ 词库 "$bookName" 导入完成，共 ${wordsList.length} 个词');
    } catch (e) {
      debugPrint('❌ 导入词库失败 $bookName: $e');
    }
  }
}

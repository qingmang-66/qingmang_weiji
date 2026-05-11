import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/word.dart';
import '../models/word_book.dart';
import 'database_service.dart';

/// 内置词库初始化服务 - 支持版本管理
class SeedService {
  // 当前词库版本（每次更新词库数据时递增）
  static const String currentVersion = '1.0.2';

  /// 初始化或更新内置词库
  static Future<void> seedBuiltInData() async {
    try {
      // 获取应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      final wordbooksDir = Directory(p.join(appDocDir.path, 'wordbooks'));
      
      // 如果目录不存在，创建它
      if (!await wordbooksDir.exists()) {
        await wordbooksDir.create(recursive: true);
        debugPrint('✓ 创建词库目录：${wordbooksDir.path}');
      }

      // 从 assets 加载并导入词库
      await _importFromAssets(
        'assets/wordbooks/google_10000_full.json',
        'Google 10000 词',
        'Google 高频英语词汇（1000词）',
        wordbooksDir,
      );
      
      await _importFromAssets(
        'assets/wordbooks/common_english_words_full.json',
        '常用英语词汇',
        '日常交流必备基础词汇',
        wordbooksDir,
      );
      
      await _importFromAssets(
        'assets/wordbooks/cet4_full.json',
        'CET-4 词汇',
        '大学英语四级核心词汇',
        wordbooksDir,
      );
      
      await _importFromAssets(
        'assets/wordbooks/cet6_full.json',
        'CET-6 词汇',
        '大学英语六级核心词汇',
        wordbooksDir,
      );
      
      await _importFromAssets(
        'assets/wordbooks/kaoyan_full.json',
        '考研英语词汇',
        '考研英语大纲核心词汇',
        wordbooksDir,
      );
      
      debugPrint('✓ 内置词库初始化完成');
    } catch (e) {
      debugPrint('❌ 内置词库初始化失败：$e');
    }
  }

  /// 重置内置词库（删除并重新导入）
  static Future<void> resetBuiltInData() async {
    try {
      // 删除所有内置词库
      final existingBooks = await DatabaseService.getAllWordBooks();
      for (final book in existingBooks) {
        if (book.isBuiltIn) {
          await DatabaseService.deleteWordBook(book.id!);
        }
      }
      // 重新导入
      await seedBuiltInData();
      debugPrint('✓ 内置词库已重置');
    } catch (e) {
      debugPrint('❌ 重置内置词库失败：$e');
    }
  }

  /// 从 assets 加载 JSON 词库并导入
  static Future<void> _importFromAssets(
    String assetPath,
    String bookName,
    String description,
    Directory wordbooksDir,
  ) async {
    try {
      // 检查是否已存在且版本一致
      final existingBooks = await DatabaseService.getAllWordBooks();
      final existingBook = existingBooks.where((b) => b.name == bookName).firstOrNull;
      if (existingBook != null && existingBook.version == currentVersion) {
        debugPrint('✓ 词库 "$bookName" 版本已是最新 ($currentVersion)，跳过');
        return;
      }

      // 从 assets 加载 JSON 数据
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = jsonDecode(jsonString);
      
      // 支持两种格式：
      // 1. 新格式：{"name":..., "words": [...]} 
      // 2. 旧格式：直接数组 [...]
      List<dynamic> wordsList;
      if (jsonData is Map && jsonData.containsKey('words')) {
        // 新格式：提取 words 数组
        wordsList = jsonData['words'] as List<dynamic>;
        debugPrint('  检测到新格式词库');
      } else if (jsonData is List) {
        // 旧格式：直接是数组
        wordsList = jsonData;
        debugPrint('  检测到旧格式词库');
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
      final bookId = await DatabaseService.insertWordBook(book);

      // 批量导入单词（使用高性能批量插入）
      const batchSize = 1000; // 增大批处理大小以提升性能
      for (var i = 0; i < wordsList.length; i += batchSize) {
        final batch = wordsList.skip(i).take(batchSize).toList();
        final wordObjects = batch.map((w) => Word(
              word: w['word'] as String? ?? '',
              phonetic: w['phonetic'] as String? ?? '',
              definition: w['definition'] as String? ?? '',
              example: w['example'] as String?,
              exampleTranslation: w['exampleTranslation'] as String?,
              wordBookId: bookId,
              root: w['root'] as String?,
              suffix: w['suffix'] as String?,
              synonym: w['synonym'] as String?,
              antonym: w['antonym'] as String?,
              derivative: w['derivative'] as String?,
            )).toList();
        await DatabaseService.insertWordsBatchFast(wordObjects);
      }

      debugPrint('✓ 词库 "$bookName" 导入完成，共 ${wordsList.length} 个词');
    } catch (e) {
      debugPrint('❌ 导入词库失败 $bookName: $e');
    }
  }

}

import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../models/word.dart';

/// 单词数据访问层
class WordRepository {
  /// 插入单词
  Future<int> insertWord(Word word) async {
    try {
      return await DatabaseService.insertWord(word);
    } catch (e) {
      debugPrint('WordRepository.insertWord error: $e');
      rethrow;
    }
  }

  /// 批量插入单词
  Future<void> insertWordsBatch(List<Word> words, {Function(int completed, int total)? onProgress}) async {
    try {
      await DatabaseService.insertWordsBatch(words, onProgress: onProgress);
    } catch (e) {
      debugPrint('WordRepository.insertWordsBatch error: $e');
      rethrow;
    }
  }

  /// 高性能批量插入
  Future<void> insertWordsBatchFast(List<Word> words, {Function(int completed, int total)? onProgress}) async {
    try {
      await DatabaseService.insertWordsBatchFast(words, onProgress: onProgress);
    } catch (e) {
      debugPrint('WordRepository.insertWordsBatchFast error: $e');
      rethrow;
    }
  }

  /// 根据词库获取单词
  Future<List<Word>> getWordsByBook(int bookId, {int? limit, int? offset}) async {
    try {
      return await DatabaseService.getWordsByBook(bookId, limit: limit, offset: offset);
    } catch (e) {
      debugPrint('WordRepository.getWordsByBook error: $e');
      return [];
    }
  }

  /// 获取待复习单词
  Future<List<Word>> getDueWords(int bookId, {int limit = 50, int offset = 0}) async {
    try {
      return await DatabaseService.getDueWords(bookId, limit: limit, offset: offset);
    } catch (e) {
      debugPrint('WordRepository.getDueWords error: $e');
      return [];
    }
  }

  /// 获取新单词
  Future<List<Word>> getNewWords(int bookId, int limit, {int offset = 0}) async {
    try {
      return await DatabaseService.getNewWords(bookId, limit, offset: offset);
    } catch (e) {
      debugPrint('WordRepository.getNewWords error: $e');
      return [];
    }
  }

  /// 搜索单词
  Future<List<Word>> searchWords(String query, {int? bookId, int limit = 50, int offset = 0}) async {
    try {
      return await DatabaseService.searchWords(query, bookId: bookId, limit: limit, offset: offset);
    } catch (e) {
      debugPrint('WordRepository.searchWords error: $e');
      return [];
    }
  }

  /// 分页获取单词（支持通用分页）
  Future<List<Word>> getWordsPaginated(int bookId, {int page = 1, int pageSize = 50}) async {
    try {
      final offset = (page - 1) * pageSize;
      return await DatabaseService.getWordsByBook(bookId, limit: pageSize, offset: offset);
    } catch (e) {
      debugPrint('WordRepository.getWordsPaginated error: $e');
      return [];
    }
  }

  /// 全局搜索
  Future<List<Word>> searchAllWords(String query, {int limit = 100}) async {
    try {
      return await DatabaseService.searchAllWords(query, limit: limit);
    } catch (e) {
      debugPrint('WordRepository.searchAllWords error: $e');
      return [];
    }
  }

  /// 更新单词释义
  Future<void> updateWordDefinition({
    required int wordId,
    String? phonetic,
    String? definition,
    String? example,
  }) async {
    try {
      await DatabaseService.updateWordDefinition(
        wordId: wordId,
        phonetic: phonetic,
        definition: definition,
        example: example,
      );
    } catch (e) {
      debugPrint('WordRepository.updateWordDefinition error: $e');
      rethrow;
    }
  }

  /// 获取词库单词数量
  Future<int> getWordCountInBook(int bookId) async {
    try {
      return await DatabaseService.getWordCountInBook(bookId);
    } catch (e) {
      debugPrint('WordRepository.getWordCountInBook error: $e');
      return 0;
    }
  }

  /// 检查词库是否有数据
  Future<bool> hasWordsInBook(int bookId) async {
    try {
      return await DatabaseService.hasWordsInBook(bookId);
    } catch (e) {
      debugPrint('WordRepository.hasWordsInBook error: $e');
      return false;
    }
  }

  /// 获取所有单词（用于备份）
  Future<List<Word>> getAllWords() async {
    try {
      return await DatabaseService.getAllWords();
    } catch (e) {
      debugPrint('WordRepository.getAllWords error: $e');
      return [];
    }
  }

  /// 批量删除单词
  Future<void> deleteWordsBatch(List<int> wordIds) async {
    try {
      await DatabaseService.deleteWordsBatch(wordIds);
    } catch (e) {
      debugPrint('WordRepository.deleteWordsBatch error: $e');
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../daos/word_dao.dart';
import '../../models/word.dart';

/// 单词数据访问层
class WordRepository {
  final WordDao? _wordDaoOverride;

  WordRepository({WordDao? wordDao}) : _wordDaoOverride = wordDao;

  //惰性解析，避免测试Fake构造时触发数据库初始化
  WordDao get _wordDao => _wordDaoOverride ?? DatabaseService.wordDao;

  /// 插入单词
  Future<int> insertWord(Word word) async {
    try {
      return await _wordDao.insertWord(word);
    } catch (e) {
      debugPrint('WordRepository.insertWord error: $e');
      rethrow;
    }
  }

  /// 批量插入单词
  Future<void> insertWordsBatch(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) async {
    try {
      await _wordDao.insertWordsBatch(words, onProgress: onProgress);
    } catch (e) {
      debugPrint('WordRepository.insertWordsBatch error: $e');
      rethrow;
    }
  }

  /// 高性能批量插入
  Future<void> insertWordsBatchFast(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) async {
    try {
      await _wordDao.insertWordsBatchFast(words, onProgress: onProgress);
    } catch (e) {
      debugPrint('WordRepository.insertWordsBatchFast error: $e');
      rethrow;
    }
  }

  /// 根据词库获取单词
  Future<List<Word>> getWordsByBook(
    int bookId, {
    int? limit,
    int? offset,
  }) async {
    try {
      return await _wordDao.getWordsByBook(
        bookId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('WordRepository.getWordsByBook error: $e');
      rethrow;
    }
  }

  /// 获取待复习单词
  Future<List<Word>> getDueWords(
    int bookId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _wordDao.getDueWords(bookId, limit: limit, offset: offset);
    } catch (e) {
      debugPrint('WordRepository.getDueWords error: $e');
      rethrow;
    }
  }

  /// 获取新单词
  Future<List<Word>> getNewWords(
    int bookId,
    int limit, {
    int offset = 0,
  }) async {
    try {
      return await _wordDao.getNewWords(bookId, limit, offset: offset);
    } catch (e) {
      debugPrint('WordRepository.getNewWords error: $e');
      rethrow;
    }
  }

  /// 按今日剩余新词额度获取新单词
  Future<List<Word>> getNewWordsWithinDailyRemaining(
    int bookId, {
    required int dailyLimit,
  }) async {
    try {
      final todayNewCount = await _wordDao.getTodayNewWordCount(bookId);
      final remaining = (dailyLimit - todayNewCount).clamp(0, dailyLimit);
      if (remaining == 0) return [];
      return await _wordDao.getNewWords(bookId, remaining);
    } catch (e) {
      debugPrint('WordRepository.getNewWordsWithinDailyRemaining error: $e');
      rethrow;
    }
  }

  /// 按今日剩余复习额度获取待复习单词
  Future<List<Word>> getDueWordsWithinDailyRemaining(
    int bookId, {
    required int dailyLimit,
  }) async {
    try {
      final todayReviewedCount = await _wordDao.getTodayReviewedWordCount(
        bookId,
      );
      final remaining = (dailyLimit - todayReviewedCount).clamp(0, dailyLimit);
      if (remaining == 0) return [];
      return await _wordDao.getDueWords(bookId, limit: remaining);
    } catch (e) {
      debugPrint('WordRepository.getDueWordsWithinDailyRemaining error: $e');
      rethrow;
    }
  }

  /// 搜索单词
  ///
  /// [inWordFieldOnly] 为 true 时仅在 word 字段中搜索，排序更精简。
  Future<List<Word>> searchWords(
    String query, {
    int? bookId,
    int limit = 50,
    int offset = 0,
    bool inWordFieldOnly = false,
  }) async {
    try {
      return await _wordDao.searchWords(
        query,
        bookId: bookId,
        limit: limit,
        offset: offset,
        inWordFieldOnly: inWordFieldOnly,
      );
    } catch (e) {
      debugPrint('WordRepository.searchWords error: $e');
      rethrow;
    }
  }

  /// 分页获取单词（支持通用分页）
  Future<List<Word>> getWordsPaginated(
    int bookId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      return await _wordDao.getWordsByBook(
        bookId,
        limit: pageSize,
        offset: offset,
      );
    } catch (e) {
      debugPrint('WordRepository.getWordsPaginated error: $e');
      rethrow;
    }
  }

  /// 全局搜索
  ///
  /// [inWordFieldOnly] 为 true 时仅在 word 字段中搜索。
  Future<List<Word>> searchAllWords(
    String query, {
    int limit = 100,
    bool inWordFieldOnly = false,
  }) async {
    try {
      return await _wordDao.searchAllWords(
        query,
        limit: limit,
        inWordFieldOnly: inWordFieldOnly,
      );
    } catch (e) {
      debugPrint('WordRepository.searchAllWords error: $e');
      rethrow;
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
      await _wordDao.updateWordDefinition(
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
      return await _wordDao.getWordCountInBook(bookId);
    } catch (e) {
      debugPrint('WordRepository.getWordCountInBook error: $e');
      rethrow;
    }
  }

  /// 检查词库是否有数据
  Future<bool> hasWordsInBook(int bookId) async {
    try {
      final count = await _wordDao.getWordCountInBook(bookId);
      return count > 0;
    } catch (e) {
      debugPrint('WordRepository.hasWordsInBook error: $e');
      rethrow;
    }
  }

  /// 根据 ID 列表获取单词（用于继续学习等场景）
  Future<List<Word>> getWordsByIds(List<int> ids) async {
    try {
      return await _wordDao.getWordsByIds(ids);
    } catch (e) {
      debugPrint('WordRepository.getWordsByIds error: $e');
      rethrow;
    }
  }

  /// 获取所有单词（用于备份）；备份展示允许失败时降级为空列表
  Future<List<Word>> getAllWords() async {
    try {
      return await _wordDao.getAllWords();
    } catch (e) {
      debugPrint('WordRepository.getAllWords error: $e');
      return [];
    }
  }

  /// 批量删除单词
  Future<void> deleteWordsBatch(List<int> wordIds) async {
    try {
      await _wordDao.deleteWordsBatch(wordIds);
    } catch (e) {
      debugPrint('WordRepository.deleteWordsBatch error: $e');
      rethrow;
    }
  }
}

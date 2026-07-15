import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../daos/review_dao.dart';
import '../daos/word_dao.dart';
import '../../models/review_record.dart';
import '../../models/study_availability.dart';
import '../../models/wordbook_progress.dart';

/// 复习记录数据访问层（带计数缓存）
class ReviewRepository {
  final WordDao? _wordDaoOverride;
  final ReviewDao? _reviewDaoOverride;

  ReviewRepository({WordDao? wordDao, ReviewDao? reviewDao})
    : _wordDaoOverride = wordDao,
      _reviewDaoOverride = reviewDao;

  //惰性解析，避免测试Fake构造时触发数据库初始化
  WordDao get _wordDao => _wordDaoOverride ?? DatabaseService.wordDao;
  ReviewDao get _reviewDao => _reviewDaoOverride ?? DatabaseService.reviewDao;

  // 计数缓存：避免频繁查询数据库统计
  final Map<String, _CountCacheEntry> _countCache = {};
  static const _countCacheValidDuration = Duration(seconds: 10);

  bool _isCountCacheValid(String key) {
    final entry = _countCache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.time) < _countCacheValidDuration;
  }

  /// 使指定词库的计数缓存失效
  void invalidateCountCache(int bookId) {
    _countCache.remove('due_$bookId');
    _countCache.remove('todayNew_$bookId');
    _countCache.remove('todayReviewed_$bookId');
    _countCache.remove('unlearned_$bookId');
  }

  /// 使所有计数缓存失效
  void invalidateAllCountCache() {
    _countCache.clear();
  }

  /// 保存复习记录
  /// [bookId] 可选，传入后可精准失效该词库的计数缓存
  Future<int> saveReviewRecord(ReviewRecord record, {int? bookId}) async {
    try {
      final id = await _reviewDao.saveReviewRecord(record);
      // 保存后使相关缓存失效
      if (bookId != null) {
        invalidateCountCache(bookId);
      } else {
        invalidateAllCountCache();
      }
      return id;
    } catch (e) {
      debugPrint('ReviewRepository.saveReviewRecord error: $e');
      rethrow;
    }
  }

  /// 获取复习记录；无记录与查询失败均返回 null（与缺失难区分）
  Future<ReviewRecord?> getReviewRecord(int wordId) async {
    try {
      return await _reviewDao.getReviewRecord(wordId);
    } catch (e) {
      debugPrint('ReviewRepository.getReviewRecord error: $e');
      return null;
    }
  }

  /// 批量获取复习记录
  Future<Map<int, ReviewRecord?>> getReviewRecordsByWordIds(
    List<int> wordIds,
  ) async {
    try {
      return await _reviewDao.getReviewRecordsByWordIds(wordIds);
    } catch (e) {
      debugPrint('ReviewRepository.getReviewRecordsByWordIds error: $e');
      rethrow;
    }
  }

  /// 获取待复习单词数量（带缓存）
  Future<int> getDueWordCount(int bookId) async {
    final key = 'due_$bookId';
    if (_isCountCacheValid(key)) {
      return _countCache[key]!.count;
    }
    try {
      final count = await _wordDao.getDueWordCount(bookId);
      _countCache[key] = _CountCacheEntry(count);
      return count;
    } catch (e) {
      debugPrint('ReviewRepository.getDueWordCount error: $e');
      rethrow;
    }
  }

  /// 获取今日新学词数量（带缓存）
  Future<int> getTodayNewWordCount(int bookId) async {
    final key = 'todayNew_$bookId';
    if (_isCountCacheValid(key)) {
      return _countCache[key]!.count;
    }
    try {
      final count = await _wordDao.getTodayNewWordCount(bookId);
      _countCache[key] = _CountCacheEntry(count);
      return count;
    } catch (e) {
      debugPrint('ReviewRepository.getTodayNewWordCount error: $e');
      rethrow;
    }
  }

  /// 获取今日已复习词数量（带缓存）
  Future<int> getTodayReviewedWordCount(int bookId) async {
    final key = 'todayReviewed_$bookId';
    if (_isCountCacheValid(key)) {
      return _countCache[key]!.count;
    }
    try {
      final count = await _wordDao.getTodayReviewedWordCount(bookId);
      _countCache[key] = _CountCacheEntry(count);
      return count;
    } catch (e) {
      debugPrint('ReviewRepository.getTodayReviewedWordCount error: $e');
      rethrow;
    }
  }

  /// 获取未学习词数量（带缓存）
  Future<int> getUnlearnedWordCount(int bookId) async {
    final key = 'unlearned_$bookId';
    if (_isCountCacheValid(key)) {
      return _countCache[key]!.count;
    }
    try {
      final count = await _wordDao.getUnlearnedWordCount(bookId);
      _countCache[key] = _CountCacheEntry(count);
      return count;
    } catch (e) {
      debugPrint('ReviewRepository.getUnlearnedWordCount error: $e');
      rethrow;
    }
  }

  ///获取词库进度；仅用于可选展示，失败时降级为全零
  Future<WordBookProgress> getWordBookProgress(int bookId) async {
    try {
      return await _wordDao.getWordBookProgress(bookId);
    } catch (e) {
      debugPrint('ReviewRepository.getWordBookProgress error: $e');
      return WordBookProgress(
        bookId: bookId,
        totalWords: 0,
        unlearnedWords: 0,
        dueWords: 0,
      );
    }
  }

  ///批量进度；展示用，失败时降级为全零
  Future<Map<int, WordBookProgress>> getWordBookProgressMap(
    Iterable<int> bookIds,
  ) async {
    final ids = bookIds.toList();
    if (ids.isEmpty) return {};
    try {
      return await _wordDao.getWordBookProgressMap(ids);
    } catch (e) {
      debugPrint('ReviewRepository.getWordBookProgressMap error: $e');
      return {
        for (final id in ids)
          id: WordBookProgress(
            bookId: id,
            totalWords: 0,
            unlearnedWords: 0,
            dueWords: 0,
          ),
      };
    }
  }

  Future<StudyAvailability> getStudyAvailability(
    int bookId, {
    required bool isReview,
    required int dailyNewLimit,
    required int dailyReviewLimit,
  }) async {
    try {
      final totalWords = await _wordDao.getWordCountInBook(bookId);
      final unlearnedWords = await _wordDao.getUnlearnedWordCount(bookId);
      final dueWords = await _wordDao.getDueWordCount(bookId);
      final todayNewWords = await _wordDao.getTodayNewWordCount(bookId);
      final todayReviewedWords = await _wordDao.getTodayReviewedWordCount(
        bookId,
      );

      if (isReview) {
        return StudyAvailability.forReview(
          totalWords: totalWords,
          unlearnedWords: unlearnedWords,
          dueWords: dueWords,
          todayNewWords: todayNewWords,
          todayReviewedWords: todayReviewedWords,
          dailyNewLimit: dailyNewLimit,
          dailyReviewLimit: dailyReviewLimit,
        );
      }

      return StudyAvailability.forNewWords(
        totalWords: totalWords,
        unlearnedWords: unlearnedWords,
        dueWords: dueWords,
        todayNewWords: todayNewWords,
        todayReviewedWords: todayReviewedWords,
        dailyNewLimit: dailyNewLimit,
        dailyReviewLimit: dailyReviewLimit,
      );
    } catch (e) {
      debugPrint('ReviewRepository.getStudyAvailability error: $e');
      rethrow;
    }
  }

  /// 获取所有复习记录（用于备份）；备份允许失败时降级为空列表
  Future<List<ReviewRecord>> getAllReviewRecords() async {
    try {
      return await _reviewDao.getAllReviewRecords();
    } catch (e) {
      debugPrint('ReviewRepository.getAllReviewRecords error: $e');
      return [];
    }
  }
}

/// 计数缓存条目
class _CountCacheEntry {
  final int count;
  final DateTime time;

  _CountCacheEntry(this.count) : time = DateTime.now();
}

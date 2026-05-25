import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../models/review_record.dart';

/// 复习记录数据访问层（带计数缓存）
class ReviewRepository {
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
      final id = await DatabaseService.saveReviewRecord(record);
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

  /// 获取复习记录
  Future<ReviewRecord?> getReviewRecord(int wordId) async {
    try {
      return await DatabaseService.getReviewRecord(wordId);
    } catch (e) {
      debugPrint('ReviewRepository.getReviewRecord error: $e');
      return null;
    }
  }

  /// 获取待复习单词数量（带缓存）
  Future<int> getDueWordCount(int bookId) async {
    final key = 'due_$bookId';
    if (_isCountCacheValid(key)) {
      return _countCache[key]!.count;
    }
    try {
      final count = await DatabaseService.getDueWordCount(bookId);
      _countCache[key] = _CountCacheEntry(count);
      return count;
    } catch (e) {
      debugPrint('ReviewRepository.getDueWordCount error: $e');
      return 0;
    }
  }

  /// 获取今日新学词数量（带缓存）
  Future<int> getTodayNewWordCount(int bookId) async {
    final key = 'todayNew_$bookId';
    if (_isCountCacheValid(key)) {
      return _countCache[key]!.count;
    }
    try {
      final count = await DatabaseService.getTodayNewWordCount(bookId);
      _countCache[key] = _CountCacheEntry(count);
      return count;
    } catch (e) {
      debugPrint('ReviewRepository.getTodayNewWordCount error: $e');
      return 0;
    }
  }

  /// 获取未学习词数量（带缓存）
  Future<int> getUnlearnedWordCount(int bookId) async {
    final key = 'unlearned_$bookId';
    if (_isCountCacheValid(key)) {
      return _countCache[key]!.count;
    }
    try {
      final count = await DatabaseService.getUnlearnedWordCount(bookId);
      _countCache[key] = _CountCacheEntry(count);
      return count;
    } catch (e) {
      debugPrint('ReviewRepository.getUnlearnedWordCount error: $e');
      return 0;
    }
  }

  /// 获取所有复习记录（用于备份）
  Future<List<ReviewRecord>> getAllReviewRecords() async {
    try {
      return await DatabaseService.getAllReviewRecords();
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

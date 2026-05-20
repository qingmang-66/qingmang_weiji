import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../models/review_record.dart';

/// 复习记录数据访问层
class ReviewRepository {
  /// 保存复习记录
  Future<int> saveReviewRecord(ReviewRecord record) async {
    try {
      return await DatabaseService.saveReviewRecord(record);
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

  /// 获取待复习单词数量
  Future<int> getDueWordCount(int bookId) async {
    try {
      return await DatabaseService.getDueWordCount(bookId);
    } catch (e) {
      debugPrint('ReviewRepository.getDueWordCount error: $e');
      return 0;
    }
  }

  /// 获取今日新学词数量
  Future<int> getTodayNewWordCount(int bookId) async {
    try {
      return await DatabaseService.getTodayNewWordCount(bookId);
    } catch (e) {
      debugPrint('ReviewRepository.getTodayNewWordCount error: $e');
      return 0;
    }
  }

  /// 获取未学习词数量
  Future<int> getUnlearnedWordCount(int bookId) async {
    try {
      return await DatabaseService.getUnlearnedWordCount(bookId);
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

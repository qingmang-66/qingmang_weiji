import 'package:flutter/foundation.dart';
import '../../models/review_forecast.dart';
import '../database_service.dart';

/// 统计数据访问层
class StatsRepository {
  /// 获取学习统计
  Future<Map<String, dynamic>> getStudyStats() async {
    try {
      return await DatabaseService.getStudyStats();
    } catch (e) {
      debugPrint('StatsRepository.getStudyStats error: $e');
      return {};
    }
  }

  /// 获取每日复习统计
  Future<List<Map<String, dynamic>>> getDailyReviewStats({
    int days = 30,
  }) async {
    try {
      return await DatabaseService.getDailyReviewStats(days: days);
    } catch (e) {
      debugPrint('StatsRepository.getDailyReviewStats error: $e');
      return [];
    }
  }

  /// 获取总学习统计
  Future<Map<String, dynamic>> getOverallStats(int bookId) async {
    try {
      return await DatabaseService.getOverallStats(bookId);
    } catch (e) {
      debugPrint('StatsRepository.getOverallStats error: $e');
      return {};
    }
  }

  /// 获取复习质量分布
  Future<List<Map<String, dynamic>>> getQualityDistribution(int bookId) async {
    try {
      return await DatabaseService.getQualityDistribution(bookId);
    } catch (e) {
      debugPrint('StatsRepository.getQualityDistribution error: $e');
      return [];
    }
  }

  /// 获取学习间隔分布
  Future<List<Map<String, dynamic>>> getIntervalDistribution(int bookId) async {
    try {
      return await DatabaseService.getIntervalDistribution(bookId);
    } catch (e) {
      debugPrint('StatsRepository.getIntervalDistribution error: $e');
      return [];
    }
  }

  /// 获取热力图数据（过去一年每天的复习数量）
  Future<Map<DateTime, int>> getHeatmapData() async {
    try {
      return await DatabaseService.getHeatmapData();
    } catch (e) {
      debugPrint('StatsRepository.getHeatmapData error: $e');
      return {};
    }
  }

  Future<ReviewForecast> getReviewForecast({int days = 7}) async {
    try {
      return await DatabaseService.getReviewForecast(days: days);
    } catch (e) {
      debugPrint('StatsRepository.getReviewForecast error: $e');
      return const ReviewForecast(days: []);
    }
  }
}

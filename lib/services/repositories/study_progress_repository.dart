import 'package:flutter/foundation.dart';
import '../database_service.dart';

/// 学习进度数据访问层
class StudyProgressRepository {
  /// 保存学习进度
  Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
  }) async {
    try {
      await DatabaseService.saveStudyProgress(
        wordBookId: wordBookId,
        studyMode: studyMode,
        isReview: isReview,
        currentIndex: currentIndex,
        wordIds: wordIds,
      );
    } catch (e) {
      debugPrint('StudyProgressRepository.saveStudyProgress error: $e');
      rethrow;
    }
  }

  /// 获取学习进度
  Future<Map<String, dynamic>?> getStudyProgress() async {
    try {
      return await DatabaseService.getStudyProgress();
    } catch (e) {
      debugPrint('StudyProgressRepository.getStudyProgress error: $e');
      return null;
    }
  }

  /// 清除学习进度
  Future<void> clearStudyProgress() async {
    try {
      await DatabaseService.clearStudyProgress();
    } catch (e) {
      debugPrint('StudyProgressRepository.clearStudyProgress error: $e');
    }
  }

  /// 检查是否有未完成的学习进度
  Future<bool> hasStudyProgress() async {
    try {
      return await DatabaseService.hasStudyProgress();
    } catch (e) {
      debugPrint('StudyProgressRepository.hasStudyProgress error: $e');
      return false;
    }
  }
}
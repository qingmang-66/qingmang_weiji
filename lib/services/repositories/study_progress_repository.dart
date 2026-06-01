import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../study_progress_logic.dart';

/// 学习进度数据访问层
class StudyProgressRepository {
  /// 保存学习进度
  Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
    String source = 'normal',
    String? progressKey,
    String? title,
  }) async {
    try {
      final safeProgressKey =
          progressKey ??
          StudyProgressLogic.defaultProgressKey(
            source: source,
            wordBookId: wordBookId,
          );
      final safeTitle = StudyProgressLogic.safeProgressTitle(title);

      await DatabaseService.saveStudyProgress(
        wordBookId: wordBookId,
        studyMode: studyMode,
        isReview: isReview,
        currentIndex: currentIndex,
        wordIds: wordIds,
        source: source,
        progressKey: safeProgressKey,
        title: safeTitle,
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

  Future<Map<String, dynamic>?> getResumableStudyProgress() async {
    final progress = await getStudyProgress();
    if (progress == null) return null;

    final wordIds = progress['wordIds'] as List<int>;
    final currentIndex = progress['currentIndex'] as int;
    final remainingWordIds = StudyProgressLogic.remainingWordIds(
      wordIds: wordIds,
      currentIndex: currentIndex,
    );

    if (remainingWordIds.isEmpty) {
      await clearStudyProgress();
      return null;
    }

    return {...progress, 'wordIds': remainingWordIds, 'currentIndex': 0};
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

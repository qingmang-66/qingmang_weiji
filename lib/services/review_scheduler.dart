import '../models/review_record.dart';

/// 复习调度服务 - 基于SM-2算法 + 优化版艾宾浩斯遗忘曲线
/// 
/// 复习间隔：1天 → 2天 → 4天 → 7天 → 15天 → 30天 → 60天
/// SM-2动态调整：根据回忆质量自动调整间隔
class ReviewScheduler {
  /// 艾宾浩斯基础间隔序列（天数）
  static const List<int> _baseIntervals = [1, 2, 4, 7, 15, 30, 60];

  /// 根据SM-2算法计算下次复习时间
  /// 
  /// quality: 回忆质量 (1=完全忘记, 2=困难, 3=模糊, 4=容易, 5=非常简单)
  /// 返回更新后的ReviewRecord
  static ReviewRecord scheduleNextReview(ReviewRecord record, int quality) {
    int repetitions = record.repetitions;
    double easeFactor = record.easeFactor;
    int interval = record.interval;

    if (quality < 3) {
      // 回忆失败：重置到第一步
      repetitions = 0;
      interval = _baseIntervals[0]; // 1天
    } else {
      // 回忆成功
      repetitions++;

      // 根据质量调整难度因子
      easeFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      if (easeFactor < 1.3) easeFactor = 1.3;

      if (repetitions <= _baseIntervals.length) {
        // 在基础间隔序列内，严格使用艾宾浩斯固定间隔，不叠加质量奖励
        // （质量只影响 easeFactor，用于序列结束后的计算）
        interval = _baseIntervals[repetitions - 1];
      } else {
        // 超出基础序列，用 SM-2 公式动态计算，并叠加质量奖励
        interval = (interval * easeFactor).round();
        switch (quality) {
          case 4: // 容易
            interval = (interval * 1.2).round();
            break;
          case 5: // 非常简单
            interval = (interval * 1.5).round();
            break;
        }
      }
    }

    // 确保间隔至少1天
    if (interval < 1) interval = 1;

    final now = DateTime.now();
    final nextReview = now.add(Duration(days: interval));

    return record.copyWith(
      quality: quality,
      interval: interval,
      easeFactor: easeFactor,
      repetitions: repetitions,
      nextReview: nextReview,
      lastReview: now,
    );
  }

  /// 创建初始复习记录（首次学习新单词时调用）
  static ReviewRecord createInitialRecord(int wordId) {
    final now = DateTime.now();
    return ReviewRecord(
      wordId: wordId,
      quality: 0,
      interval: _baseIntervals[0], // 首次1天后复习
      easeFactor: 2.5,
      repetitions: 0,
      nextReview: now.add(const Duration(days: 1)),
      lastReview: now,
    );
  }

  /// 获取单词的记忆阶段描述
  static String getMemoryStage(ReviewRecord record) {
    if (record.repetitions == 0) return '新学';
    if (record.repetitions <= 1) return '初步';
    if (record.repetitions <= 3) return '巩固';
    if (record.repetitions <= 5) return '熟悉';
    return '掌握';
  }

  /// 获取记忆保持率估算（0-100%）
  static double estimateRetention(ReviewRecord record) {
    if (record.repetitions == 0) return 0;
    
    final daysSinceLastReview = DateTime.now().difference(record.lastReview).inDays;
    final daysUntilNextReview = record.nextReview.difference(record.lastReview).inDays;
    
    if (daysUntilNextReview <= 0) return 0.9;
    
    // 基于遗忘曲线估算保持率
    final decay = daysSinceLastReview / daysUntilNextReview;
    final retention = 100 * (1 - decay * 0.5); // 简化估算
    return retention.clamp(0.0, 100.0);
  }
}

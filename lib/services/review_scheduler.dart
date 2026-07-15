import '../models/review_record.dart';

/// 复习调度服务 - 基于SM-2算法 + 优化版艾宾浩斯遗忘曲线
///
/// 复习间隔：1天 → 2天 → 4天 → 7天 → 15天 → 30天 → 60天
/// SM-2动态调整：根据回忆质量自动调整间隔
///
/// 设计思路：
/// 1. 保留艾宾浩斯基础间隔序列作为科学锚点
/// 2. 在基础序列内，根据评分质量进行 ±30% 的浮动微调
///    - 评分3（模糊）：使用基础间隔（不变）
///    - 评分4（容易）：间隔增加20%
///    - 评分5（非常简单）：间隔增加50%
///    - 评分2（困难）：间隔缩短30%
/// 3. 超出基础序列后，使用标准SM-2公式动态计算
/// 4. 评分1（忘记）：立即重置到第1天
class ReviewScheduler {
  /// 艾宾浩斯基础间隔序列（天数）
  /// 科学记忆曲线：1天 → 2天 → 4天 → 7天 → 15天 → 30天 → 60天
  static const List<int> _baseIntervals = [1, 2, 4, 7, 15, 30, 60];

  /// 质量微调系数
  /// 用于在基础序列内根据评分调整间隔
  static const Map<int, double> _qualityMultipliers = {
    1: 0.0, // 忘记：重置
    2: 0.7, // 困难：缩短30%
    3: 1.0, // 模糊：不变
    4: 1.2, // 容易：增加20%
    5: 1.5, // 非常简单：增加50%
  };

  /// 根据SM-2算法计算下次复习时间
  ///
  /// quality: 回忆质量 (1=完全忘记, 2=困难, 3=模糊, 4=容易, 5=非常简单)
  /// 返回更新后的ReviewRecord
  static ReviewRecord scheduleNextReview(ReviewRecord record, int quality) {
    // 确保质量评分在有效范围内
    quality = quality.clamp(1, 5);

    int repetitions = record.repetitions;
    double easeFactor = record.easeFactor;
    int interval;

    if (quality == 1) {
      // 完全忘记：重置到初始状态
      repetitions = 0;
      interval = _baseIntervals[0]; // 1天后重新学习
    } else {
      // 回忆成功
      repetitions++;

      // 根据质量调整难度因子（标准SM-2公式）
      // 公式：EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
      // 评分5：EF增加0.1，评分4：EF不变，评分3：EF减少0.14，评分2：EF减少0.32
      easeFactor =
          easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      if (easeFactor < 1.3) easeFactor = 1.3;

      if (repetitions <= _baseIntervals.length) {
        // 在基础间隔序列内：使用基础间隔 × 质量微调系数
        final baseInterval = _baseIntervals[repetitions - 1];
        final multiplier = _qualityMultipliers[quality] ?? 1.0;
        interval = (baseInterval * multiplier).round();
      } else {
        // 超出基础序列：使用标准SM-2公式动态计算
        // interval = 上次间隔 × 难度因子
        // 注意：easeFactor 已根据评分质量调整（评分高则 EF 增大），
        // 不再额外乘以质量系数，避免双重叠加导致间隔过长
        interval = (record.interval * easeFactor).round();
      }
    }

    // 确保间隔至少1天，最多365天（防止间隔过长）
    interval = interval.clamp(1, 365);

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

    final daysSinceLastReview = DateTime.now()
        .difference(record.lastReview)
        .inDays;
    final daysUntilNextReview = record.nextReview
        .difference(record.lastReview)
        .inDays;

    if (daysUntilNextReview <= 0) return 0.9;

    // 基于遗忘曲线估算保持率
    final decay = daysSinceLastReview / daysUntilNextReview;
    final retention = 100 * (1 - decay * 0.5); // 简化估算
    return retention.clamp(0.0, 100.0);
  }
}

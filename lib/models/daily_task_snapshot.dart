/// 每日任务快照模型
///
/// 记录某一天某个学习计划的目标任务量与已完成量，
/// 用于首页今日任务进度展示和统计页计划完成度。
class DailyTaskSnapshot {
  /// 日期，格式 yyyy-MM-dd
  final String date;

  /// 所属学习计划 ID
  final int planId;

  /// 目标新词数
  final int targetNewWords;

  /// 目标复习数
  final int targetReviewWords;

  /// 已完成新词数
  final int completedNewWords;

  /// 已完成复习数
  final int completedReviewWords;

  /// 完成时间，未完成时为 null
  final String? completedAt;

  const DailyTaskSnapshot({
    required this.date,
    required this.planId,
    required this.targetNewWords,
    required this.targetReviewWords,
    this.completedNewWords = 0,
    this.completedReviewWords = 0,
    this.completedAt,
  });

  /// 目标任务总数
  int get totalTarget => targetNewWords + targetReviewWords;

  /// 已完成任务总数
  int get totalCompleted => completedNewWords + completedReviewWords;

  /// 完成率，目标为 0 时视为已完成（返回 1.0），最大封顶 1.0
  double get completionRate {
    if (totalTarget <= 0) return 1.0;
    final rate = totalCompleted / totalTarget;
    return rate > 1.0 ? 1.0 : rate;
  }

  /// 是否完成：新词与复习都达到目标
  bool get isCompleted =>
      completedNewWords >= targetNewWords &&
      completedReviewWords >= targetReviewWords;

  /// 剩余新词数（不为负）
  int get remainingNewWords {
    final remaining = targetNewWords - completedNewWords;
    return remaining < 0 ? 0 : remaining;
  }

  /// 剩余复习数（不为负）
  int get remainingReviewWords {
    final remaining = targetReviewWords - completedReviewWords;
    return remaining < 0 ? 0 : remaining;
  }

  DailyTaskSnapshot copyWith({
    String? date,
    int? planId,
    int? targetNewWords,
    int? targetReviewWords,
    int? completedNewWords,
    int? completedReviewWords,
    String? completedAt,
  }) {
    return DailyTaskSnapshot(
      date: date ?? this.date,
      planId: planId ?? this.planId,
      targetNewWords: targetNewWords ?? this.targetNewWords,
      targetReviewWords: targetReviewWords ?? this.targetReviewWords,
      completedNewWords: completedNewWords ?? this.completedNewWords,
      completedReviewWords: completedReviewWords ?? this.completedReviewWords,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'plan_id': planId,
      'target_new_words': targetNewWords,
      'target_review_words': targetReviewWords,
      'completed_new_words': completedNewWords,
      'completed_review_words': completedReviewWords,
      'completed_at': completedAt,
    };
  }

  factory DailyTaskSnapshot.fromMap(Map<String, dynamic> map) {
    return DailyTaskSnapshot(
      date: map['date'] as String,
      planId: map['plan_id'] as int,
      targetNewWords: (map['target_new_words'] as int?) ?? 0,
      targetReviewWords: (map['target_review_words'] as int?) ?? 0,
      completedNewWords: (map['completed_new_words'] as int?) ?? 0,
      completedReviewWords: (map['completed_review_words'] as int?) ?? 0,
      completedAt: map['completed_at'] as String?,
    );
  }
}

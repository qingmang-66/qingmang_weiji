import 'package:flutter/foundation.dart';
import 'achievement_definition.dart';
import 'achievement_status.dart';

/// 阶段四：成就的运行时进度
///
/// 由"定义 + 当前值 + 状态 + 解锁时间"组成，是 UI 与 Service 之间的数据契约。
@immutable
class AchievementProgress {
  /// 静态定义
  final AchievementDefinition definition;

  /// 当前统计值
  final int currentValue;

  /// 解锁状态
  final AchievementStatus status;

  /// 解锁时间（未解锁时为 null）
  final DateTime? unlockedAt;

  const AchievementProgress({
    required this.definition,
    required this.currentValue,
    required this.status,
    this.unlockedAt,
  });

  /// 进度比例 0~1，已超过目标也按 1 显示
  double get progressRatio {
    final target = definition.targetValue;
    if (target <= 0) return 0;
    return (currentValue / target).clamp(0.0, 1.0);
  }

  /// 是否已解锁
  bool get isUnlocked => status == AchievementStatus.unlocked;

  /// 复制并修改部分字段
  AchievementProgress copyWith({
    int? currentValue,
    AchievementStatus? status,
    DateTime? unlockedAt,
  }) {
    return AchievementProgress(
      definition: definition,
      currentValue: currentValue ?? this.currentValue,
      status: status ?? this.status,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

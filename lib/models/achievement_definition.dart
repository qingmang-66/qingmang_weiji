import 'package:flutter/material.dart';
import 'achievement_category.dart';
import 'achievement_stat_type.dart';

/// 阶段四：成就的静态定义
///
/// 不可变对象，由 [AchievementService.registry] 集中持有。
/// 不在数据库中存储（属于代码层配置）。
@immutable
class AchievementDefinition {
  /// 全局唯一 id，例如 'study.10'
  final String id;

  /// 标题翻译键，例如 'ach.study10Title'
  final String titleKey;

  /// 详细描述翻译键，例如 'ach.study10Desc'
  final String descriptionKey;

  /// 图标
  final IconData icon;

  /// 类别
  final AchievementCategory category;

  /// 统计来源
  final AchievementStatType statType;

  /// 目标值（达到或超过即解锁）
  final int targetValue;

  /// 排序权重，小的靠前
  final int sortOrder;

  const AchievementDefinition({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.category,
    required this.statType,
    required this.targetValue,
    required this.sortOrder,
  });
}

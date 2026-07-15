/// 阶段四：成就类别
///
/// 决定成就所属业务域，用于 Tab / 类别筛选 / 视觉分组。
enum AchievementCategory {
  /// 学习词数类
  study,

  /// 复习次数类
  review,

  /// 连续学习类
  streak,

  /// 收藏整理类
  favorite,

  /// 自定义词集类
  customSet,

  /// 学习计划类
  plan,

  /// 专项学习 / 错词攻克类
  specialized,

  /// 彩蛋 / 特殊类（预留）
  hidden,
}

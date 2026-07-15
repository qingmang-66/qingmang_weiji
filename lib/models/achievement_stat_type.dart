/// 阶段四：成就的统计来源键
///
/// 名称与 [AchievementService] 内部 snapshot 字段一致（使用 enum.name 作为 Map key）。
/// 引入 enum 是为了在编译期保证所有"键"都被正确使用，避免拼写错误。
enum AchievementStatType {
  /// 累计已学词数
  learnedWords,

  /// 累计复习次数
  totalReviews,

  /// 连续学习天数
  streakDays,

  /// 收藏总数
  favoriteCount,

  /// 收藏分组数
  favoriteGroupCount,

  /// 自定义词集数
  customSetCount,

  /// 本周计划完成天数
  weeklyPlanCompletedDays,

  /// 本周学习天数
  weeklyStudyDays,

  /// 错词最高连续答对次数
  maxWrongWordCorrectStreak,

  /// 词集学习次数（专项）
  customSetStudied,

  /// 收藏学习次数（专项）
  favoriteStudied,

  /// 词库掌握率（百分制，0~100）
  masteryRatio,
}

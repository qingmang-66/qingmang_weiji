/// 阶段四：成就解锁状态
///
/// 与数据库 `achievements.status` 字段一一对应（0=locked, 1=unlocked）。
enum AchievementStatus {
  /// 未解锁
  locked,

  /// 已解锁
  unlocked,
}

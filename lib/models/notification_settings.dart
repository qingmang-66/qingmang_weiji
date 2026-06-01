/// 通知提醒触发条件
enum NotificationCondition {
  /// 有待复习单词时提醒
  hasDue,

  /// 今日计划未完成时提醒
  planIncomplete,

  /// 有待复习或计划未完成时都提醒
  either,
}

/// 本地通知提醒设置
///
/// 包含是否启用、提醒时间和提醒条件，
/// shouldRemind 为纯逻辑，便于单元测试。
class NotificationSettings {
  /// 是否启用提醒
  final bool enabled;

  /// 提醒小时（0-23）
  final int reminderHour;

  /// 提醒分钟（0-59）
  final int reminderMinute;

  /// 提醒触发条件
  final NotificationCondition condition;

  const NotificationSettings({
    this.enabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.condition = NotificationCondition.either,
  });

  /// 默认设置
  static const NotificationSettings defaults = NotificationSettings();

  /// SharedPreferences 存储键
  static const String keyEnabled = 'notificationEnabled';
  static const String keyHour = 'notificationHour';
  static const String keyMinute = 'notificationMinute';
  static const String keyCondition = 'notificationCondition';

  /// 根据当前待复习数量和计划完成情况判断是否应提醒。
  bool shouldRemind({required int dueCount, required bool planIncomplete}) {
    if (!enabled) return false;
    return switch (condition) {
      NotificationCondition.hasDue => dueCount > 0,
      NotificationCondition.planIncomplete => planIncomplete,
      NotificationCondition.either => dueCount > 0 || planIncomplete,
    };
  }

  NotificationSettings copyWith({
    bool? enabled,
    int? reminderHour,
    int? reminderMinute,
    NotificationCondition? condition,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      condition: condition ?? this.condition,
    );
  }
}

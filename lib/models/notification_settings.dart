/// 本地通知提醒设置
///
/// 包含是否启用、提醒时间和提示音开关，启用即到点提醒。
class NotificationSettings {
  /// 是否启用提醒
  final bool enabled;

  /// 提醒小时（0-23）
  final int reminderHour;

  /// 提醒分钟（0-59）
  final int reminderMinute;

  /// 提醒时是否播放提示音（Windows 端由应用侧播放，见 ReminderSoundService）
  final bool soundEnabled;

  const NotificationSettings({
    this.enabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.soundEnabled = true,
  });

  /// 默认设置
  static const NotificationSettings defaults = NotificationSettings();

  /// SharedPreferences 存储键
  static const String keyEnabled = 'notificationEnabled';
  static const String keyHour = 'notificationHour';
  static const String keyMinute = 'notificationMinute';
  static const String keySound = 'notificationSoundEnabled';

  NotificationSettings copyWith({
    bool? enabled,
    int? reminderHour,
    int? reminderMinute,
    bool? soundEnabled,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

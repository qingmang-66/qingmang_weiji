import 'package:test/test.dart';
import 'package:qingmang_weiji/models/notification_settings.dart';

void main() {
  group('NotificationSettings 基础逻辑', () {
    test('未启用提醒时 enabled 为 false', () {
      const s = NotificationSettings(
        enabled: false,
        reminderHour: 20,
        reminderMinute: 0,
      );
      expect(s.enabled, isFalse);
    });

    test('启用提醒时 enabled 为 true', () {
      const s = NotificationSettings(
        enabled: true,
        reminderHour: 20,
        reminderMinute: 0,
      );
      expect(s.enabled, isTrue);
    });

    test('copyWith 修改单个字段', () {
      const s = NotificationSettings(
        enabled: false,
        reminderHour: 20,
        reminderMinute: 0,
      );
      final updated = s.copyWith(enabled: true, reminderHour: 9);
      expect(updated.enabled, isTrue);
      expect(updated.reminderHour, 9);
      expect(updated.reminderMinute, 0);
    });

    test('defaults 默认值', () {
      const d = NotificationSettings.defaults;
      expect(d.enabled, isFalse);
      expect(d.reminderHour, 20);
      expect(d.reminderMinute, 0);
    });
  });
}

import 'package:test/test.dart';
import 'package:qingmang_weiji/models/notification_settings.dart';

void main() {
  group('NotificationSettings.shouldRemind 纯逻辑', () {
    test('未启用提醒时永不提醒', () {
      const s = NotificationSettings(
        enabled: false,
        reminderHour: 20,
        reminderMinute: 0,
        condition: NotificationCondition.either,
      );
      expect(s.shouldRemind(dueCount: 10, planIncomplete: true), isFalse);
    });

    test('条件=有待复习：仅 dueCount > 0 时提醒', () {
      const s = NotificationSettings(
        enabled: true,
        reminderHour: 20,
        reminderMinute: 0,
        condition: NotificationCondition.hasDue,
      );
      expect(s.shouldRemind(dueCount: 5, planIncomplete: false), isTrue);
      expect(s.shouldRemind(dueCount: 0, planIncomplete: true), isFalse);
    });

    test('条件=计划未完成：仅计划未完成时提醒', () {
      const s = NotificationSettings(
        enabled: true,
        reminderHour: 20,
        reminderMinute: 0,
        condition: NotificationCondition.planIncomplete,
      );
      expect(s.shouldRemind(dueCount: 0, planIncomplete: true), isTrue);
      expect(s.shouldRemind(dueCount: 5, planIncomplete: false), isFalse);
    });

    test('条件=两者：任一满足即提醒', () {
      const s = NotificationSettings(
        enabled: true,
        reminderHour: 20,
        reminderMinute: 0,
        condition: NotificationCondition.either,
      );
      expect(s.shouldRemind(dueCount: 5, planIncomplete: false), isTrue);
      expect(s.shouldRemind(dueCount: 0, planIncomplete: true), isTrue);
      expect(s.shouldRemind(dueCount: 0, planIncomplete: false), isFalse);
    });

    test('copyWith 修改单个字段', () {
      const s = NotificationSettings(
        enabled: false,
        reminderHour: 20,
        reminderMinute: 0,
        condition: NotificationCondition.either,
      );
      final updated = s.copyWith(enabled: true, reminderHour: 9);
      expect(updated.enabled, isTrue);
      expect(updated.reminderHour, 9);
      expect(updated.reminderMinute, 0);
      expect(updated.condition, NotificationCondition.either);
    });
  });
}

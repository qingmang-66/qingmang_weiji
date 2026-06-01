import 'package:test/test.dart';
import 'package:qingmang_weiji/services/notification_service.dart';
import 'package:qingmang_weiji/models/notification_settings.dart';

void main() {
  group('NotificationService 单例与 API', () {
    test('工厂构造返回同一实例', () {
      final a = NotificationService();
      final b = NotificationService();
      expect(identical(a, b), isTrue);
    });

    test('dispose 不抛异常', () {
      final service = NotificationService();
      expect(() => service.dispose(), returnsNormally);
    });

    test('cancelReminder 不抛异常', () async {
      final service = NotificationService();
      expect(() => service.cancelReminder(), returnsNormally);
    });

    test('loadNotificationSetting 返回 true', () async {
      final service = NotificationService();
      final result = await service.loadNotificationSetting();
      expect(result, isTrue);
    });

    test('checkAndShowReminder dueCount=0 不抛异常', () async {
      final service = NotificationService();
      expect(() => service.checkAndShowReminder(0), returnsNormally);
    });
  });

  group('NotificationSettings 与服务集成逻辑', () {
    test('shouldRemind 在 enabled=false 时返回 false', () {
      const settings = NotificationSettings(
        enabled: false,
        reminderHour: 20,
        reminderMinute: 0,
        condition: NotificationCondition.either,
      );
      expect(settings.shouldRemind(dueCount: 10, planIncomplete: true), isFalse);
    });

    test('shouldRemind 在 enabled=true + hasDue + dueCount>0 时返回 true', () {
      const settings = NotificationSettings(
        enabled: true,
        reminderHour: 20,
        reminderMinute: 0,
        condition: NotificationCondition.hasDue,
      );
      expect(settings.shouldRemind(dueCount: 5, planIncomplete: false), isTrue);
    });

    test('copyWith 保留未修改字段', () {
      const original = NotificationSettings(
        enabled: true,
        reminderHour: 9,
        reminderMinute: 30,
        condition: NotificationCondition.planIncomplete,
      );
      final modified = original.copyWith(enabled: false);
      expect(modified.enabled, isFalse);
      expect(modified.reminderHour, 9);
      expect(modified.reminderMinute, 30);
      expect(modified.condition, NotificationCondition.planIncomplete);
    });

    test('defaults 工厂构造', () {
      final defaults = NotificationSettings.defaults;
      expect(defaults.enabled, isFalse);
      expect(defaults.reminderHour, 20);
      expect(defaults.reminderMinute, 0);
      expect(defaults.condition, NotificationCondition.either);
    });
  });
}

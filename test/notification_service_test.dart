import 'package:test/test.dart';
import 'package:qingmang_weiji/services/notification_service.dart';
import 'package:qingmang_weiji/models/notification_settings.dart';

void main() {
  group('NotificationService 单例与 API', () {
    test('工厂构造返回同一实例', () {
      expect(identical(NotificationService(), NotificationService()), isTrue);
    });
    test('dispose 不抛异常', () {
      expect(() => NotificationService().dispose(), returnsNormally);
    });
    test('cancelReminder 不抛异常', () async {
      await expectLater(NotificationService().cancelReminder(), completes);
    });
    test('loadNotificationSetting 返回 true', () async {
      expect(await NotificationService().loadNotificationSetting(), isTrue);
    });
    test('checkAndShowReminder dueCount=0 不抛异常', () async {
      await expectLater(
        NotificationService().checkAndShowReminder(0),
        completes,
      );
    });
    test('scheduleDailyReminder 初始化失败时抛异常（避免开关开着却收不到提醒）', () async {
      // 测试环境无平台通道，通知插件初始化必然失败。
      // 这里必须抛 StateError 让调用方回滚开关并提示用户；
      // 旧行为是静默 return，会表现为"开关显示已开启、但永远没有提醒"。
      await expectLater(
        NotificationService().scheduleDailyReminder(
          hour: 20,
          minute: 0,
          title: '提醒',
          body: '学习',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('NotificationSettings 与服务集成逻辑', () {
    test('enabled=false', () {
      const settings = NotificationSettings(
        enabled: false,
        reminderHour: 20,
        reminderMinute: 0,
      );
      expect(settings.enabled, isFalse);
    });
    test('enabled=true', () {
      const settings = NotificationSettings(
        enabled: true,
        reminderHour: 20,
        reminderMinute: 0,
      );
      expect(settings.enabled, isTrue);
    });
    test('copyWith 保留未修改字段', () {
      const original = NotificationSettings(
        enabled: true,
        reminderHour: 9,
        reminderMinute: 30,
      );
      final modified = original.copyWith(enabled: false);
      expect(modified.enabled, isFalse);
      expect(modified.reminderHour, 9);
      expect(modified.reminderMinute, 30);
    });
    test('defaults 工厂构造', () {
      final defaults = NotificationSettings.defaults;
      expect(defaults.enabled, isFalse);
      expect(defaults.reminderHour, 20);
      expect(defaults.reminderMinute, 0);
    });
  });
}

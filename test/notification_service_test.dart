import 'package:test/test.dart';
import 'package:qingmang_weiji/services/notification_service.dart';
import 'package:qingmang_weiji/models/notification_settings.dart';
import 'package:timezone/timezone.dart' as tz;

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
    test('使用系统返回的 IANA 时区', () async {
      final service = NotificationService.forTesting(
        timeZoneNameLoader: () async => 'America/New_York',
        initializer: () async => true,
      );
      await service.init();
      expect(service.localTimeZoneNameForTest, 'America/New_York');
      expect(tz.local.name, 'America/New_York');
    });
    test('默认时区加载器不将非UTC+8环境固定为UTC', () async {
      final service = NotificationService.forTesting(
        timeZoneNameLoader: () async => 'America/New_York',
        initializer: () async => true,
        supported: true,
      );
      await service.init();
      expect(service.localTimeZoneNameForTest, isNot('UTC'));
      expect(service.localTimeZoneNameForTest, 'America/New_York');
    });
    test('偏移降级仅映射固定无夏令时区域', () {
      expect(
        NotificationService.fallbackTimeZoneByOffsetForTest(
          const Duration(hours: 8),
        ),
        'Asia/Shanghai',
      );
      expect(
        NotificationService.fallbackTimeZoneByOffsetForTest(
          const Duration(hours: 9),
        ),
        'Asia/Tokyo',
      );
      expect(
        NotificationService.fallbackTimeZoneByOffsetForTest(Duration.zero),
        'UTC',
      );
      //带半小时或无法唯一映射的偏移不再强行写成UTC+8/UTC之外的错误IANA
      expect(
        NotificationService.fallbackTimeZoneByOffsetForTest(
          const Duration(hours: -5),
        ),
        'UTC',
      );
    });
    test('不支持通知时 scheduleDailyReminder 抛出明确异常', () async {
      final service = NotificationService.forTesting(
        initializer: () async => false,
      );
      await expectLater(
        service.scheduleDailyReminder(
          hour: 20,
          minute: 0,
          title: '提醒',
          body: '学习',
        ),
        throwsA(isA<NotificationException>()),
      );
    });
    test('初始化失败时 scheduleDailyReminder 抛出明确异常', () async {
      final service = NotificationService.forTesting(
        initializer: () async => throw StateError('初始化失败'),
      );
      await expectLater(
        service.scheduleDailyReminder(
          hour: 20,
          minute: 0,
          title: '提醒',
          body: '学习',
        ),
        throwsA(
          isA<NotificationException>().having(
            (e) => e.message,
            'message',
            contains('初始化失败'),
          ),
        ),
      );
    });
    test('调度异常时 scheduleDailyReminder 向上抛出明确异常', () async {
      final service = NotificationService.forTesting(
        initializer: () async => true,
        scheduler:
            ({
              required hour,
              required minute,
              required title,
              required body,
            }) async => throw StateError('插件调度失败'),
      );
      await expectLater(
        service.scheduleDailyReminder(
          hour: 20,
          minute: 0,
          title: '提醒',
          body: '学习',
        ),
        throwsA(
          isA<NotificationException>().having(
            (e) => e.message,
            'message',
            contains('设置每日提醒失败'),
          ),
        ),
      );
    });
    test('Windows 每日提醒同一天只允许触发一次', () {
      final service = NotificationService();
      service.dispose();
      addTearDown(service.dispose);
      expect(
        service.shouldTriggerWindowsDailyReminderForTest(
          now: DateTime(2026, 6, 1, 20),
          hour: 20,
          minute: 0,
        ),
        isTrue,
      );
      expect(
        service.shouldTriggerWindowsDailyReminderForTest(
          now: DateTime(2026, 6, 1, 20, 0, 30),
          hour: 20,
          minute: 0,
        ),
        isFalse,
      );
      expect(
        service.shouldTriggerWindowsDailyReminderForTest(
          now: DateTime(2026, 6, 2, 20),
          hour: 20,
          minute: 0,
        ),
        isTrue,
      );
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
      expect(
        settings.shouldRemind(dueCount: 10, planIncomplete: true),
        isFalse,
      );
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

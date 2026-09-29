import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/notification_settings.dart';
import 'package:qingmang_weiji/services/notification_service.dart';
import 'package:qingmang_weiji/services/providers/study_settings_provider.dart';
import 'package:qingmang_weiji/services/reminder_sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingNotificationService implements NotificationService {
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int? failHour;

  FailingNotificationService({this.failHour});

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    bool ensurePermission = false,
  }) async {
    scheduleCalls++;
    if (failHour == null || failHour == hour) {
      throw Exception('调度失败');
    }
  }

  @override
  Future<void> cancelReminder() async {
    cancelCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('通知调度失败时保留原设置且不通知监听器', () async {
    SharedPreferences.setMockInitialValues({
      NotificationSettings.keyEnabled: false,
      NotificationSettings.keyHour: 20,
      NotificationSettings.keyMinute: 0,
    });
    final service = FailingNotificationService();
    final provider = StudySettingsProvider(notificationService: service);
    await provider.loadPreferences();
    var notifications = 0;
    provider.addListener(() => notifications++);

    final future = provider.updateNotificationSettings(
      provider.notificationSettings.copyWith(
        enabled: true,
        reminderHour: 8,
        reminderMinute: 30,
      ),
    );

    await expectLater(future, throwsA(isA<Exception>()));
    expect(provider.notificationSettings.reminderHour, 20);
    expect(provider.notificationSettings.reminderMinute, 0);
    expect(provider.notificationSettings.enabled, isFalse);
    expect(notifications, 0);
    expect(service.scheduleCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(NotificationSettings.keyHour), 20);
    expect(prefs.getInt(NotificationSettings.keyMinute), 0);
    expect(prefs.getBool(NotificationSettings.keyEnabled), isFalse);
  });

  test('loadPreferences 使用注入依赖并在默认禁用时取消旧提醒', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var loaderCalls = 0;
    final service = FailingNotificationService(failHour: -1);
    final provider = StudySettingsProvider(
      notificationService: service,
      preferencesLoader: () async {
        loaderCalls++;
        return prefs;
      },
    );
    await provider.loadPreferences();
    expect(loaderCalls, 1);
    expect(service.cancelCalls, 1);
    expect(provider.notificationSettings.enabled, isFalse);
  });

  test('提醒声音开关默认开启、可持久化并同步到提示音服务', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = StudySettingsProvider(
      notificationService: FailingNotificationService(failHour: -1),
    );
    await provider.loadPreferences();
    expect(provider.notificationSettings.soundEnabled, isTrue);
    expect(ReminderSoundService.instance.enabled, isTrue);

    await provider.updateNotificationSettings(
      provider.notificationSettings.copyWith(soundEnabled: false),
    );
    expect(provider.notificationSettings.soundEnabled, isFalse);
    expect(ReminderSoundService.instance.enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationSettings.keySound), isFalse);

    //重新加载后仍保持关闭
    final reloaded = StudySettingsProvider(
      notificationService: FailingNotificationService(failHour: -1),
    );
    await reloaded.loadPreferences();
    expect(reloaded.notificationSettings.soundEnabled, isFalse);

    //还原全局状态，避免影响其它用例
    ReminderSoundService.instance.enabled = true;
  });

  test('加载时通知调度失败仍通知其余设置', () async {
    SharedPreferences.setMockInitialValues({
      NotificationSettings.keyEnabled: true,
      NotificationSettings.keyHour: 8,
      NotificationSettings.keyMinute: 30,
    });
    final prefs = await SharedPreferences.getInstance();
    var notifications = 0;
    final service = FailingNotificationService();
    final provider = StudySettingsProvider(
      notificationService: service,
      preferencesLoader: () async => prefs,
    )..addListener(() => notifications++);

    await provider.loadPreferences();

    expect(provider.notificationSettings.enabled, isTrue);
    expect(provider.notificationSettings.reminderHour, 8);
    expect(notifications, 1);
    expect(service.scheduleCalls, 1);
  });
}

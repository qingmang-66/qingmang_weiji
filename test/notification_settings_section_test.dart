import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';
import 'package:qingmang_weiji/widgets/settings_sections.dart';
import 'package:qingmang_weiji/widgets/liquid_controls.dart';
import 'package:qingmang_weiji/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('提醒时间点击直接打开滚轮选择器', (tester) async {
    // 用 fake 通知服务：真实 NotificationService 会走平台通道/isolate，
    // 在测试环境挂起导致本用例超时 10 分钟
    final provider = StudySettingsProvider(
      notificationService: _FakeNotificationService(),
    );
    await provider.loadPreferences();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(body: const NotificationSettingsSection()),
        ),
      ),
    );

    await tester.tap(find.text('提醒时间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 应直接打开滚轮选择器，显示小时/分钟标签
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('分钟'), findsOneWidget);
  });

  testWidgets('开启提醒时 enabled 变为 true', (tester) async {
    // 使用空操作的 NotificationService mock，避免平台通道异常
    final provider = StudySettingsProvider(
      notificationService: _FakeNotificationService(),
    );
    await provider.loadPreferences();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(body: const NotificationSettingsSection()),
        ),
      ),
    );

    expect(provider.notificationSettings.enabled, isFalse);
    // 点击开关开启提醒
    await tester.tap(find.byType(LiquidSwitch).first);
    await tester.pumpAndSettle();
    expect(provider.notificationSettings.enabled, isTrue);
  });

  testWidgets('reminder time 仍可点击', (tester) async {
    final provider = StudySettingsProvider(
      notificationService: _FakeNotificationService(),
    );
    await provider.loadPreferences();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(body: const NotificationSettingsSection()),
        ),
      ),
    );

    final timeTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '提醒时间'),
    );

    expect(timeTile.enabled, isTrue);
    expect(timeTile.onTap, isNotNull);
  });
}

/// 测试用空操作 NotificationService，避免平台通道异常
class _FakeNotificationService implements NotificationService {
  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    bool ensurePermission = false,
  }) async {}

  @override
  Future<void> cancelReminder() async {}

  @override
  Future<void> openSystemSettings() async {}

  @override
  void dispose() {}

  @override
  Future<void> init() async {}

  @override
  Future<void> showReviewReminder(int dueCount) async {}

  @override
  Future<void> checkAndShowReminder(int dueCount) async {}

  @override
  Future<bool> loadNotificationSetting() async => true;

  @override
  ValueNotifier<String?> get pendingLaunchPayload => ValueNotifier(null);

  @override
  void clearPendingLaunchPayload() {}
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/models/notification_settings.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';
import 'package:qingmang_weiji/theme/fluid_theme.dart';
import 'package:qingmang_weiji/widgets/settings_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('提醒条件使用语义图标和明确选中态', (tester) async {
    final provider = StudySettingsProvider();
    await provider.loadPreferences();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(body: NotificationSettingsSection(provider: provider)),
        ),
      ),
    );

    await tester.tap(find.text('提醒条件'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final dueTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '有待复习单词时'),
    );
    final planTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '今日计划未完成时'),
    );
    final eitherFinder = find.widgetWithText(ListTile, '待复习或计划未完成时').last;
    final eitherTile = tester.widget<ListTile>(eitherFinder);
    expect((dueTile.leading! as Icon).icon, Icons.replay);
    expect((planTile.leading! as Icon).icon, Icons.checklist);
    expect(
      (eitherTile.leading! as Icon).icon,
      Icons.notifications_active_outlined,
    );

    final selectedContainer = tester.widget<Container>(
      find.ancestor(of: eitherFinder, matching: find.byType(Container)).first,
    );
    final decoration = selectedContainer.decoration! as BoxDecoration;
    expect(decoration.color, isNot(Colors.transparent));
    expect(
      (eitherTile.leading! as Icon).color,
      FluidTheme.primaryFluidGradient[0],
    );

    await tester.tap(find.text('有待复习单词时'));
    await tester.pumpAndSettle();
    expect(
      provider.notificationSettings.condition,
      NotificationCondition.hasDue,
    );
  });

  testWidgets('提醒时间使用24小时快捷选择并在确定后保存', (tester) async {
    final provider = StudySettingsProvider();
    await provider.loadPreferences();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(body: NotificationSettingsSection(provider: provider)),
        ),
      ),
    );

    await tester.tap(find.text('提醒时间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('20'), findsOneWidget);
    expect(find.text('00'), findsOneWidget);
    expect(find.text('24 小时制'), findsOneWidget);
    for (final time in ['08:00', '12:30', '20:00', '22:00']) {
      expect(find.text(time), findsWidgets);
    }
    expect(find.text('自定义时间'), findsOneWidget);

    await tester.tap(find.text('08:00'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(provider.notificationSettings.reminderHour, 8);
    expect(provider.notificationSettings.reminderMinute, 0);
  });

  testWidgets('取消提醒时间弹窗不保存', (tester) async {
    final provider = StudySettingsProvider();
    await provider.loadPreferences();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(body: NotificationSettingsSection(provider: provider)),
        ),
      ),
    );

    await tester.tap(find.text('提醒时间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('08:00'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(provider.notificationSettings.reminderHour, 20);
  });

  testWidgets('自定义时间使用Fluid小时分钟控件并在确认后回填', (tester) async {
    final provider = StudySettingsProvider();
    await provider.loadPreferences();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(body: NotificationSettingsSection(provider: provider)),
        ),
      ),
    );

    await tester.tap(find.text('提醒时间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('自定义时间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('选择自定义时间'), findsOneWidget);
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('分钟'), findsOneWidget);
    // 确保不是原生 time picker
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(ListView), findsNWidgets(2));

    final lists = find.byType(ListView);
    final hourCtrl =
        tester.widget<ListView>(lists.at(0)).controller as ScrollController;
    final minuteCtrl =
        tester.widget<ListView>(lists.at(1)).controller as ScrollController;

    // 手势拖动验证可滚动
    await tester.drag(lists.at(0), const Offset(0, -180));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(lists.at(1), const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(hourCtrl.offset, isNot(20 * 48.0));

    // 精确定位到 09:25 后回填
    hourCtrl.jumpTo(9 * 48.0);
    minuteCtrl.jumpTo(5 * 48.0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(hourCtrl.offset, closeTo(9 * 48.0, 1));
    expect(minuteCtrl.offset, closeTo(5 * 48.0, 1));

    // 关闭自定义时间弹窗
    await tester.tap(find.text('确定').at(0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    if (find.text('选择自定义时间').evaluate().isNotEmpty) {
      await tester.tap(find.text('确定').last);
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('选择自定义时间'), findsNothing);

    // 外层时间弹窗确定
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.notificationSettings.reminderHour, 9);
    expect(provider.notificationSettings.reminderMinute, 25);
  });

  testWidgets(
    'reminder time and condition remain tappable when reminder is disabled',
    (tester) async {
      final provider = StudySettingsProvider();
      await provider.loadPreferences();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NotificationSettingsSection(provider: provider),
            ),
          ),
        ),
      );

      final timeTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, '提醒时间'),
      );
      final conditionTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, '提醒条件'),
      );

      expect(provider.notificationSettings.enabled, isFalse);
      expect(timeTile.enabled, isTrue);
      expect(timeTile.onTap, isNotNull);
      expect(conditionTile.enabled, isTrue);
      expect(conditionTile.onTap, isNotNull);
    },
  );
}

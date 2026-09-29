import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/screens/settings_screen.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置一级页（设置中心）的冒烟测试。
///
/// 全部铺平后的页面结构：身份区 + 外观与显示（内联）+ 学习（内联）
/// + 提醒（内联）+ 数据管理（内联）+ 帮助与引导 / 关于（内联）。
/// 这里只保证「该有的设置项都在、布局不越界」，不再有任何二级页入口。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('设置中心渲染常用设置与全部分类入口', (tester) async {
    // 放大测试画布，保证所有卡片都在视口内被构建
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => StudySettingsProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    // 外观与显示：已内联进一级页
    expect(find.text('常用设置'), findsOneWidget);
    expect(find.text('显示模式'), findsOneWidget);
    expect(find.text('界面风格'), findsOneWidget);
    expect(find.text('当前语言'), findsOneWidget);

    // 学习分组：发音与词典相关项也已内联
    expect(find.text('学习设置'), findsOneWidget);
    expect(find.text('自动发音'), findsOneWidget);
    expect(find.text('在线真人发音'), findsOneWidget);

    // 更多设置的三个二级页已全部铺平为一级卡片
    expect(find.text('更多设置'), findsNothing);
    expect(find.text('提醒设置'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('帮助与引导'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    // 回忆模式的释义显示只在学习页提供，设置一级页不再有该入口
    expect(find.text('回忆模式 · 释义显示'), findsNothing);
    expect(find.text('外观与显示'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/widgets/liquid_pill_nav_bar.dart';

void main() {
  //回归：条宽远大于条高时，胶囊截面尺寸计算不得抛
  //ArgumentError（旧实现 clamp(cell*0.55, crossSize*0.98) 在
  //宽条上下限颠倒，导航条整体构建失败、图标消失）。
  testWidgets('宽横向导航条正常渲染（不因 clamp 上下限颠倒而崩溃）', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: SizedBox(
              width: 1280,
              child: LiquidPillNavBar(
                items: const [
                  LiquidPillNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: '首页',
                    activeColor: Colors.pinkAccent,
                  ),
                  LiquidPillNavItem(
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book,
                    label: '词库',
                    activeColor: Colors.pinkAccent,
                  ),
                  LiquidPillNavItem(
                    icon: Icons.auto_stories_outlined,
                    activeIcon: Icons.auto_stories,
                    label: '阅读',
                    activeColor: Colors.pinkAccent,
                  ),
                  LiquidPillNavItem(
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart,
                    label: '统计',
                    activeColor: Colors.pinkAccent,
                  ),
                  LiquidPillNavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: '设置',
                    activeColor: Colors.pinkAccent,
                  ),
                ],
                currentIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('纵向侧栏（cell 必然大于条宽）同样正常渲染', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                LiquidPillNavBar(
                  axis: Axis.vertical,
                  currentIndex: 0,
                  onChanged: (_) {},
                  items: [
                    LiquidPillNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: '首页',
                      activeColor: Colors.pinkAccent,
                    ),
                    LiquidPillNavItem(
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book,
                      label: '词库',
                      activeColor: Colors.pinkAccent,
                    ),
                    LiquidPillNavItem(
                      icon: Icons.auto_stories_outlined,
                      activeIcon: Icons.auto_stories,
                      label: '阅读',
                      activeColor: Colors.pinkAccent,
                    ),
                    LiquidPillNavItem(
                      icon: Icons.bar_chart_outlined,
                      activeIcon: Icons.bar_chart,
                      label: '统计',
                      activeColor: Colors.pinkAccent,
                    ),
                    LiquidPillNavItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings,
                      label: '设置',
                      activeColor: Colors.pinkAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  //回归：Windows 左/右侧栏通高面板形态（expand: true）。
  //五项应均分整条高度而不是挤在顶部 5×56dp 里。
  testWidgets('纵向展开模式：导航项均分通高空间', (tester) async {
    const items = [
      LiquidPillNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: '首页',
        activeColor: Colors.pinkAccent,
      ),
      LiquidPillNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: '设置',
        activeColor: Colors.pinkAccent,
      ),
    ];
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                LiquidPillNavBar(
                  axis: Axis.vertical,
                  expand: true,
                  items: items,
                  currentIndex: 0,
                  onChanged: (_) {},
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    //展开模式两项均分整高（600px 测试窗口下间距 ≈289）；
    //非展开时按 56dp 定高，间距只有 56。阈值取中间值区分两种形态。
    final homeY = tester.getCenter(find.byIcon(Icons.home)).dy;
    final settingsY = tester.getCenter(find.byIcon(Icons.settings_outlined)).dy;
    expect(settingsY - homeY, greaterThan(150));

    //回归：展开模式参照底部条几何——选中框几乎铺满该项整格（~88%），
    //边界与项对齐；截面与底部条同宽（≈49）。
    final pillFinder = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).shape is StadiumBorder,
    );
    final pillRect = tester.getRect(pillFinder);
    final cell = settingsY - homeY; //两项中心间距即一格高
    expect(pillRect.height, greaterThanOrEqualTo(cell * 0.8));
    expect(pillRect.height, lessThanOrEqualTo(cell));
    expect(pillRect.width, greaterThanOrEqualTo(40));
    expect(pillRect.width, lessThanOrEqualTo(60));
    expect((pillRect.center.dy - homeY).abs(), lessThan(10));

    //选中最后一项（用户反馈的错位场景）：胶囊居中于该项且不溢出条底。
    //重建实例以干净地设置 currentIndex（受控组件按住才改目标）。
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                LiquidPillNavBar(
                  axis: Axis.vertical,
                  expand: true,
                  items: items,
                  currentIndex: 1,
                  onChanged: (_) {},
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lastPillRect = tester.getRect(pillFinder);
    //选中项显示填充态图标
    final lastIconY = tester.getCenter(find.byIcon(Icons.settings)).dy;
    expect((lastPillRect.center.dy - lastIconY).abs(), lessThan(10));
    final stripRect = tester.getRect(find.byType(LiquidPillNavBar));
    expect(lastPillRect.bottom, lessThanOrEqualTo(stripRect.bottom));
    expect(tester.takeException(), isNull);
  });

  //诊断：与 home_screen 侧栏完全同构（header + 5 项 + 通高），
  //量胶囊中心与选中项内容中心的偏差。
  testWidgets('通高侧栏胶囊垂直居中于选中项（同构复现）', (tester) async {
    Widget build(int index) => ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 1000,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: SizedBox(
                    height: double.infinity,
                    child: LiquidPillNavBar(
                      axis: Axis.vertical,
                      expand: true,
                      header: const SizedBox(width: 40, height: 40),
                      items: const [
                        LiquidPillNavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home,
                          label: '首页',
                          activeColor: Colors.pinkAccent,
                        ),
                        LiquidPillNavItem(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book,
                          label: '词库',
                          activeColor: Colors.pinkAccent,
                        ),
                        LiquidPillNavItem(
                          icon: Icons.auto_stories_outlined,
                          activeIcon: Icons.auto_stories,
                          label: '阅读',
                          activeColor: Colors.pinkAccent,
                        ),
                        LiquidPillNavItem(
                          icon: Icons.bar_chart_outlined,
                          activeIcon: Icons.bar_chart,
                          label: '统计',
                          activeColor: Colors.pinkAccent,
                        ),
                        LiquidPillNavItem(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          label: '设置',
                          activeColor: Colors.pinkAccent,
                        ),
                      ],
                      currentIndex: index,
                      onChanged: (_) {},
                    ),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );

    final pillFinder = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).shape is StadiumBorder,
    );

    for (final index in [0, 4]) {
      await tester.pumpWidget(build(index));
      await tester.pumpAndSettle();
      final pillRect = tester.getRect(pillFinder);
      //选中项内容块 = 图标 + 间距 + 文字，取图标与标签的中点
      final activeIcon = const [
        Icons.home,
        Icons.menu_book,
        Icons.auto_stories,
        Icons.bar_chart,
        Icons.settings,
      ][index];
      final iconRect = tester.getRect(find.byIcon(activeIcon));
      final label = const ['首页', '词库', '阅读', '统计', '设置'][index];
      final labelRect = tester.getRect(find.text(label));
      final contentCenter = (iconRect.top + labelRect.bottom) / 2;
      expect(
        (pillRect.center.dy - contentCenter).abs(),
        lessThan(2),
        reason: '胶囊未居中于选中项内容',
      );
    }
    expect(tester.takeException(), isNull);
  });

  //回归：横向宽条胶囊必须居中于选中项。此前 _centerAt 的实测锚点在
  //横向误加条高一半（height/2）而非格宽一半，格宽远大于条高时
  //（Windows 宽窗口 cell≈210 vs 条高 56）胶囊整体明显偏左——
  //选中"首页"贴条左缘、"设置"落到"中文/English"区域上方。
  testWidgets('横向宽条胶囊居中于选中项', (tester) async {
    const labels = ['首页', '词库', '阅读', '统计', '设置'];
    final activeIcons = const [
      Icons.home,
      Icons.menu_book,
      Icons.auto_stories,
      Icons.bar_chart,
      Icons.settings,
    ];
    Widget build(int index) => ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: LiquidPillNavBar(
            items: [
              for (var i = 0; i < labels.length; i++)
                LiquidPillNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: activeIcons[i],
                  label: labels[i],
                  activeColor: Colors.pinkAccent,
                ),
            ],
            currentIndex: index,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final pillFinder = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).shape is StadiumBorder,
    );

    for (final index in [0, 4]) {
      await tester.pumpWidget(build(index));
      await tester.pumpAndSettle();
      final pillRect = tester.getRect(pillFinder);
      final iconRect = tester.getRect(find.byIcon(activeIcons[index]));
      expect(
        (pillRect.center.dx - iconRect.center.dx).abs(),
        lessThan(2),
        reason: '横向条胶囊未水平居中于选中项「${labels[index]}」',
      );
    }
    expect(tester.takeException(), isNull);
  });
}

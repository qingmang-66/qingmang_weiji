import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/screens/onboarding_screen.dart';
import 'package:qingmang_weiji/services/app_initialization_service.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';
import 'package:qingmang_weiji/widgets/fluid_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 每个用例都从"开屏还没结束"起跑（模拟首次冷启动）；
    // 需要放行保护窗的用例再显式 notifySplashCompleted()
    AppInitializationService.splashCompleted.value = false;
  });

  /// 引导页选项卡（显示模式 / 界面风格 / 语言）的布局回归。
  ///
  /// 卡片被包在 Stack 里，而 Stack 给非定位子节点的是宽松约束：卡片只写高度时
  /// 会收缩成"图标 + 文字"的宽度，选中的描边框（Positioned.fill）却按整个槽位
  /// 铺开，于是框比卡片宽出一大截、还盖住右边那张卡。这里锁住"卡片 = 槽位宽度"。
  testWidgets('选项卡占满槽位，同行卡片等宽', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    double cardWidth(String label, String second) {
      final first = tester.getSize(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final other = tester.getSize(
        find
            .ancestor(
              of: find.text(second),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (first.width - other.width).abs() < 1,
        isTrue,
        reason: '$label 与 $second 应等宽（同一行的 Expanded 槽位）',
      );
      return first.width;
    }

    // 三个显示模式选项：460 的可用宽度下每张卡约 146
    final modeWidth = cardWidth('浅色模式', '跟随系统');
    expect(modeWidth, greaterThan(120), reason: '卡片必须占满槽位，不能收缩成图标+文字的宽度');
  });

  /// 引导流程回归：Android 端反馈「显示第一页后立马跳到首页」。
  ///
  /// 静态审查找不到自动完成路径（只有跳过 / 完成 / 最后一页会调 onComplete），
  /// 这里把两条行为钉住：无人操作时不得自行完成、且「下一步」必须能把第一页
  /// 送到第二页——翻页一旦失效，用户就只能点右上角「跳过」离开，观感正是
  /// "引导只显示第一页就跳走了"。
  testWidgets('无操作时引导不自动完成', (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completeCount++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(completeCount, 0, reason: '未做任何操作就 onComplete，用户会直接落到首页');
  });

  testWidgets('下一步从第一页翻到语言页', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pump();
    // 保护窗 = max(进场 500ms, 开屏结束 + 300ms)，两条线都跑过再点
    await tester.pump(const Duration(milliseconds: 600));
    AppInitializationService.notifySplashCompleted();
    await tester.pump(const Duration(milliseconds: 300));
    // 第一页是外观页：底部只有「下一步」，右上角是「跳过」
    expect(find.text('1 / 5'), findsOne);
    await tester.tap(find.text('下一步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('2 / 5'), findsOne);
  });

  /// 回归：进场瞬间的残留点击（初始化确认弹窗的连点等）不得跳过引导。
  /// Android 端反馈过"5 页引导一闪而过"，其中一条诱因就是上一屏的
  /// 连点落在刚出现的跳过按钮上。
  testWidgets('进场 500ms 内的跳过点击被忽略', (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completeCount++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    //保护窗内整树被 IgnorePointer 屏蔽，按钮 hit test 会 miss（预期行为）
    await tester.tap(find.text('跳过'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(completeCount, 0, reason: '保护窗内的点击不应完成引导');
    expect(find.text('1 / 5'), findsOne);

    // 两条计时线都跑过（开屏结束 + 300ms）后跳过仍可用
    AppInitializationService.notifySplashCompleted();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('跳过'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(completeCount, 1);
  });

  /// 回归：开屏期间引导页挂在开屏层底下、看不见但可点，
  /// 保护窗只挡进场 500ms 挡不住开屏中后段的点击 —— 表现就是
  /// "5 页引导全被点完，开屏一结束直接落在首页弹功能巡览"。
  testWidgets('开屏结束前跳过一直无效，开屏结束 300ms 后才恢复', (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completeCount++),
        ),
      ),
    );
    await tester.pump();
    // 过了原来的 500ms 最短窗，但开屏还没结束
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('跳过'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(completeCount, 0, reason: '开屏期间的点击应继续被挡住');
    expect(find.text('1 / 5'), findsOne);

    // 开屏结束，但还要再等 300ms 缓冲
    AppInitializationService.notifySplashCompleted();
    await tester.pump(const Duration(milliseconds: 299));
    await tester.tap(find.text('跳过'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(completeCount, 0, reason: '开屏结束后的 300ms 仍在保护窗内');

    // 第三条线（连点去抖）：刚点过还需要 350ms 静默才放行
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.text('跳过'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 349));
    expect(completeCount, 0, reason: '最后一次按下后 350ms 静默未满，仍在保护窗内');

    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.text('跳过'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(completeCount, 1, reason: '静默期满后跳过恢复正常');
  });

  /// 回归（Android 真机"5 页引导一闪即逝"复发）：开屏结束后用户往往还在
  /// 惯性连点，固定 300ms 缓冲挡不住持续 1~2 秒的连点 —— 每一发都落在
  /// 满宽的「下一步」上，几下就把 5 页点完。这里钉住：连点期间保护窗
  /// 持续有效（每次按下续命 350ms），手停 350ms 后才放行。
  testWidgets('开屏结束后的惯性连点持续被挡，手停 350ms 后才放行', (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completeCount++),
        ),
      ),
    );
    await tester.pump();
    // 进场 500ms 最短窗已过
    await tester.pump(const Duration(milliseconds: 600));
    // 开屏缓冲还差 1ms，连点从这里开始（每 200ms 一发，间隔 < 350ms）
    AppInitializationService.notifySplashCompleted();
    await tester.pump(const Duration(milliseconds: 299));
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('跳过'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }
    // 连点总时长已越过"开屏 + 300ms"缓冲（599ms），但静默线一直被续命
    expect(completeCount, 0, reason: '惯性连点期间保护窗必须持续有效');
    expect(find.text('1 / 5'), findsOne, reason: '连点不得翻页/跳过');

    // 停手 350ms（再给 10ms 余量）→ 三条线齐备 → 放行
    await tester.pump(const Duration(milliseconds: 360));
    await tester.tap(find.text('跳过'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(completeCount, 1, reason: '手停 350ms 后跳过恢复正常');
  });

  /// 回归（Android 真机"选完液态玻璃后 5 页引导一闪即逝"）：
  /// 保护窗只管进场，解除后再不上锁；满宽的「下一步」在翻页动画期间不禁用、
  /// 页码又只在动画落定后才更新（陈旧读数），连点几下 `nextPage` 只是不断
  /// 重定向目标，几发就把 5 页点完。这里钉住：**一次按压只推进一页**，
  /// 且翻页忙锁期间按钮进入禁用态（给出可见反馈，用户不会以为按钮失灵）。
  testWidgets('连点「下一步」一次只推进一页', (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completeCount++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    AppInitializationService.notifySplashCompleted();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 / 5'), findsOne);

    // 第一发正常翻页，等忙锁期满（300ms 动画 + 180ms 落定）后再回到空闲态
    await tester.tap(find.text('下一步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2 / 5'), findsOne);

    // 从空闲态起连点 4 发（每发间隔 80ms，总跨度 240ms < 忙锁 480ms）：
    // 模拟真机上"刚看到第 2 页就接着往下点"。
    // 第 1 发合法推进到第 3 页，第 2~4 发都落在这一发的忙锁窗口内，必须被吞掉
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('下一步'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('3 / 5'), findsOne, reason: '4 发连点只应推进一页，忙锁窗口内的补点不得继续翻页');
    expect(completeCount, 0, reason: '连点不得把 5 页引导全部点完直接落到首页');

    // 忙锁期满后恢复正常：一次按压推进一页
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('下一步'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('4 / 5'), findsOne);
  });

  /// 回归（真机"只点一次下一步就跳过整段引导直达首页"）：
  /// 「是否已在末页」此前只看 _currentPage，而它唯一的写入点是 onPageChanged。
  /// 选液态玻璃时的整树重建/布局突变会让 PageView 报出异常页码，写进状态就把
  /// 计数顶到末页，下一次按压 target 越界 → 直接 _finishOnboarding 进首页。
  /// 这里钉住：越界上报只能被钳制，完成判定必须看视口真实页码。
  testWidgets('页码被越界值污染后，单击只前进一步不得直达首页', (tester) async {
    var completeCount = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => WordBookProvider()),
        ],
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completeCount++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    AppInitializationService.notifySplashCompleted();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 / 5'), findsOne);

    // 模拟布局突变时 PageView 报出的越界页码
    tester.widget<PageView>(find.byType(PageView)).onPageChanged!(99);
    await tester.pump();
    expect(find.text('5 / 5'), findsOne, reason: '越界值必须被钳制到合法范围');

    // 此刻计数已在末页、视口仍在第 1 页：单击必须只前进一步
    await tester.tap(find.byType(FluidButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(completeCount, 0, reason: '视口不在末页时不得完成引导');
    expect(find.text('2 / 5'), findsOne, reason: '单击只应推进到视口的下一页');
  });
}

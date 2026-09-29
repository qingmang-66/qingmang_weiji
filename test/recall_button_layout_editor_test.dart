import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/models/recall_button_layout.dart';
import 'package:qingmang_weiji/services/providers/study_settings_provider.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/widgets/recall_button_layout_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「自定义按键位置」编辑器的行为契约
///
/// 重构前的问题：三顆键除位置外全部共用一套 scale/opacity 滑杆，且预览区
/// 用的是与学习页不同的一套几何公式。重构后：
/// - 每顆键单独选中并调宽/高/透明度
/// - 预览直接复用学习页的题面卡 + RecallQualityButton（同一参考系）
/// - 保存一次性提交，退出后设置里能读回布局
///
/// 注意：不能用 pumpAndSettle —— FluidBackground 里有 `repeat()` 的常驻动画，
/// 永远收敛不了（这也是旧编辑器一直没有测试覆盖的原因）。统一用固定帧数推进。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StudySettingsProvider> pumpEditor(WidgetTester tester) async {
    // 不设 mock：SharedPreferences.getInstance() 会卡在未 mock 的平台通道上，
    // loadPreferences 永不返回，整个测试 10 分钟超时（表现为"假死"）
    SharedPreferences.setMockInitialValues({});
    final settings = StudySettingsProvider();
    addTearDown(settings.dispose);
    await settings.loadPreferences();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: RecallButtonLayoutEditor()),
      ),
    );
    await tester.pump();
    return settings;
  }

  /// 推进若干帧，让 AnimatedScale / AnimatedOpacity 之类有限动画跑完
  Future<void> advance(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// 展开顶部参数面板：选键/滑杆/微调都收在面板里，默认收起以让出整屏摆位区
  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(RecallLayoutKeys.panelToggle));
    await advance(tester);
  }

  testWidgets('预览区渲染真实题面与三颗评分键', (tester) async {
    await pumpEditor(tester);

    expect(find.byKey(RecallLayoutKeys.previewCard), findsOneWidget);
    expect(find.byKey(RecallLayoutKeys.button(1)), findsOneWidget);
    expect(find.byKey(RecallLayoutKeys.button(3)), findsOneWidget);
    expect(find.byKey(RecallLayoutKeys.button(4)), findsOneWidget);
  });

  testWidgets('选中某颗键后调宽度，只影响该键', (tester) async {
    final settings = await pumpEditor(tester);
    await openPanel(tester);

    await tester.tap(find.byKey(RecallLayoutKeys.selectButton(3)));
    await advance(tester);

    final slider = find.byKey(RecallLayoutKeys.widthSlider);
    expect(slider, findsOneWidget);
    // 把滑杆拖到最右端
    final sliderBox = tester.getRect(slider);
    await tester.drag(
      slider,
      Offset(sliderBox.width / 2 + 20, 0),
      touchSlopX: 0,
    );
    await advance(tester);
    await tester.tap(find.byKey(RecallLayoutKeys.saveButton));
    await advance(tester);

    final layout = settings.recallButtonLayout;
    expect(layout.specs[3]!.w, kRecallButtonMaxW);
    expect(layout.specs[1]!.w, kRecallButtonDefaultW);
    expect(layout.specs[4]!.w, kRecallButtonDefaultW);
  });

  testWidgets('拖动评分键改变其锚点，另外两颗键不动', (tester) async {
    final settings = await pumpEditor(tester);

    // 从当前选中键（默认"模糊"）的中心起手拖，否则落在空白处不触发拖拽
    final start = tester.getCenter(find.byKey(RecallLayoutKeys.button(3)));
    await tester.dragFrom(start, const Offset(0, -150));
    await advance(tester);
    await tester.tap(find.byKey(RecallLayoutKeys.saveButton));
    await advance(tester);

    final after = settings.recallButtonLayout;
    // 默认三颗键都贴底；从默认选中的"模糊"开始拖，它应改锚到别处
    expect(after.specs[3]!.v, isNot(RecallVAnchor.bottom));
    // 未拖动的两顆键保持原样
    expect(after.specs[1]!.v, RecallVAnchor.bottom);
    expect(after.specs[1]!.h, RecallHAnchor.left);
    expect(after.specs[4]!.v, RecallVAnchor.bottom);
    expect(after.specs[4]!.h, RecallHAnchor.right);
  });

  testWidgets('微调只移动当前选中的键', (tester) async {
    final settings = await pumpEditor(tester);
    await openPanel(tester);

    await tester.tap(find.byKey(RecallLayoutKeys.selectButton(1)));
    await advance(tester);
    await tester.tap(find.byKey(RecallLayoutKeys.nudgeDown));
    await advance(tester);
    await tester.tap(find.byKey(RecallLayoutKeys.saveButton));
    await advance(tester);

    final layout = settings.recallButtonLayout;
    expect(
      layout.specs[1]!.gapBottom,
      kRecallButtonDefaultGapBottom - kRecallSnapGrid,
    );
    expect(layout.specs[3]!.gapBottom, kRecallButtonDefaultGapBottom);
  });

  testWidgets('恢复默认把三颗键全部重置', (tester) async {
    final settings = await pumpEditor(tester);
    await openPanel(tester);

    // 先把选中键改宽（本地编辑态），再点恢复默认
    await tester.tap(find.byKey(RecallLayoutKeys.selectButton(1)));
    await advance(tester);
    final slider = find.byKey(RecallLayoutKeys.widthSlider);
    final sliderBox = tester.getRect(slider);
    await tester.drag(
      slider,
      Offset(sliderBox.width / 2 + 20, 0),
      touchSlopX: 0,
    );
    await advance(tester);

    await tester.tap(find.byKey(RecallLayoutKeys.resetButton));
    await advance(tester);

    expect(
      settings.recallButtonLayout.specs[1]!.gapBottom,
      kRecallButtonDefaultGapBottom,
    );
    expect(settings.recallButtonLayout.specs[1]!.w, kRecallButtonDefaultW);
  });
}

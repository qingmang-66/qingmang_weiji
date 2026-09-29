import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/services/app_initialization_service.dart';
import 'package:qingmang_weiji/services/guide_service.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/widgets/coach_mark_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 极简宿主：一个可被高亮的目标控件 + MaterialApp 自带的根 Overlay
Widget _host(GlobalKey targetKey) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(key: targetKey, width: 120, height: 40)),
      ),
    ),
  );
}

List<CoachMarkStep> _dictSteps(GlobalKey targetKey) => [
  CoachMarkStep(
    targetKey: targetKey,
    title: '长按单词查词典',
    message: '长按或右键任意单词，菜单里选「查词典」',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppInitializationService.splashCompleted.value = false;
  });

  tearDown(() {
    AppInitializationService.splashCompleted.value = false;
  });

  test('学习/阅读的查词典引导各自独立记录，并随「重看功能提示」一起重置', () async {
    expect(await GuideService.isSeen(GuideService.tipStudyActions), isFalse);
    expect(await GuideService.isSeen(GuideService.tipReaderFeatures), isFalse);

    await GuideService.markSeen(GuideService.tipStudyActions);
    expect(await GuideService.isSeen(GuideService.tipStudyActions), isTrue);
    //一条提示看过与否不影响另一条
    expect(await GuideService.isSeen(GuideService.tipReaderFeatures), isFalse);

    await GuideService.markSeen(GuideService.tipReaderFeatures);
    //「重看功能提示」后两条都要重新出现
    await GuideService.resetAll();
    expect(await GuideService.isSeen(GuideService.tipStudyActions), isFalse);
    expect(await GuideService.isSeen(GuideService.tipReaderFeatures), isFalse);
  });

  test('全部引导提示都能被「重看功能提示」重置', () async {
    //先在"已看过"状态下遍历一遍，确保每条都能被标记与读取
    for (final id in GuideService.allTipIds) {
      await GuideService.markSeen(id);
      expect(await GuideService.isSeen(id), isTrue, reason: '标记失败：$id');
    }

    await GuideService.resetAll();

    for (final id in GuideService.allTipIds) {
      expect(await GuideService.isSeen(id), isFalse, reason: '未重置：$id');
    }
  });

  testWidgets('开屏未结束时页面级引导不展示，也不标记已看过', (tester) async {
    final targetKey = GlobalKey();
    var prepared = false;
    await tester.pumpWidget(_host(targetKey));

    await CoachMarkOverlay.maybeShowAfterSplash(
      tester.element(find.byType(Scaffold)),
      guideId: GuideService.tipReaderFeatures,
      onBeforeShow: () => prepared = true,
      steps: () => _dictSteps(targetKey),
    );
    await tester.pump();
    await tester.pump();

    //没弹出就不该锁高亮锚点，也不该记成已看过
    expect(prepared, isFalse);
    expect(find.text('长按单词查词典'), findsNothing);
    expect(await GuideService.isSeen(GuideService.tipReaderFeatures), isFalse);
  });

  testWidgets('开屏结束后弹出一次，点「知道了」后记录为已看过', (tester) async {
    final targetKey = GlobalKey();
    var prepared = false;
    await tester.pumpWidget(_host(targetKey));
    AppInitializationService.splashCompleted.value = true;

    await CoachMarkOverlay.maybeShowAfterSplash(
      tester.element(find.byType(Scaffold)),
      guideId: GuideService.tipReaderFeatures,
      onBeforeShow: () => prepared = true,
      steps: () => _dictSteps(targetKey),
    );
    await tester.pump();
    await tester.pump();

    expect(prepared, isTrue);
    expect(find.text('长按单词查词典'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pump();
    await tester.pump();
    expect(find.text('长按单词查词典'), findsNothing);

    //markSeen 内部是异步写偏好，轮询几帧等它落盘
    var seen = false;
    for (var i = 0; i < 10 && !seen; i++) {
      seen = await GuideService.isSeen(GuideService.tipReaderFeatures);
      if (!seen) await tester.pump(const Duration(milliseconds: 20));
    }
    expect(seen, isTrue);
  });
}

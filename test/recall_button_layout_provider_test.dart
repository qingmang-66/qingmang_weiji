import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/recall_button_layout.dart';
import 'package:qingmang_weiji/services/providers/study_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回忆模式评分键布局的持久化契约
///
/// 旧实现把布局拆成 3 个键（positions / scale / opacity），每改一项就
/// notifyListeners 一次——编辑器点"保存"会让学习页重建 5 次。新实现是
/// 单个 JSON 键 + 一次批量写入 + 恰好一次通知。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RecallButtonLayout custom() => RecallButtonLayout({
    1: const RecallButtonSpec(
      h: RecallHAnchor.left,
      v: RecallVAnchor.top,
      gapLeft: 16,
      gapTop: 64,
      w: 100,
      hPx: 40,
      opacity: 0.6,
    ),
    3: const RecallButtonSpec(gapMidY: -24),
    4: const RecallButtonSpec(
      h: RecallHAnchor.right,
      gapRight: 48,
      opacity: 0.4,
    ),
  });

  StudySettingsProvider newProvider() => StudySettingsProvider();

  test('applyRecallButtonLayout 持久化后可被重新读出', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = newProvider();
    addTearDown(provider.dispose);

    await provider.applyRecallButtonLayout(custom());

    final reloaded = newProvider();
    addTearDown(reloaded.dispose);
    await reloaded.loadPreferences();

    expect(reloaded.recallButtonLayout.specs[1]!.h, RecallHAnchor.left);
    expect(reloaded.recallButtonLayout.specs[1]!.gapTop, 64);
    expect(reloaded.recallButtonLayout.specs[1]!.opacity, closeTo(0.6, 0.001));
    expect(reloaded.recallButtonLayout.specs[4]!.gapRight, 48);
  });

  test('保存一次布局只通知一次', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = newProvider();
    addTearDown(provider.dispose);

    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.applyRecallButtonLayout(custom());

    expect(notifications, 1);
  });

  test('没有存储记录时回落到默认布局', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = newProvider();
    addTearDown(provider.dispose);

    await provider.loadPreferences();

    expect(provider.recallButtonLayout.specs.keys.toSet(), {1, 3, 4});
    expect(provider.recallButtonLayout.specs[1]!.h, RecallHAnchor.left);
    expect(provider.recallButtonLayout.specs[4]!.h, RecallHAnchor.right);
  });

  test('旧版三键数据不做换算：直接回落默认布局并清掉旧键', () async {
    SharedPreferences.setMockInitialValues({
      'recallButtonPositions':
          '{"1":[0.16,0.94],"3":[0.5,0.94],"4":[0.83,0.94]}',
      'recallButtonScale': 1.2,
      'recallButtonOpacity': 0.5,
    });
    final provider = newProvider();
    addTearDown(provider.dispose);

    await provider.loadPreferences();

    // 默认布局而非旧坐标（旧坐标是"键中心比例"，没有运行时尺寸无法换算）
    expect(provider.recallButtonLayout.specs[3]!.h, RecallHAnchor.center);
    expect(provider.recallButtonLayout.specs[3]!.w, kRecallButtonDefaultW);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('recallButtonPositions'), isNull);
    expect(prefs.getDouble('recallButtonScale'), isNull);
    expect(prefs.getDouble('recallButtonOpacity'), isNull);
  });

  test('存储内容损坏时不抛异常，回落默认布局', () async {
    SharedPreferences.setMockInitialValues({
      'recallButtonLayout': '<not json>',
    });
    final provider = newProvider();
    addTearDown(provider.dispose);

    await provider.loadPreferences();

    expect(provider.recallButtonLayout.specs.keys.toSet(), {1, 3, 4});
  });

  test('resetRecallButtonLayout 恢复默认并落盘', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = newProvider();
    addTearDown(provider.dispose);

    await provider.applyRecallButtonLayout(custom());
    await provider.resetRecallButtonLayout();

    expect(provider.recallButtonLayout.specs[1]!.w, kRecallButtonDefaultW);
    expect(provider.recallButtonLayout.specs[1]!.v, RecallVAnchor.bottom);
    final reloaded = newProvider();
    addTearDown(reloaded.dispose);
    await reloaded.loadPreferences();
    expect(reloaded.recallButtonLayout.specs[1]!.w, kRecallButtonDefaultW);
  });
}

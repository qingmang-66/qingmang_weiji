import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/theme/fluid_theme.dart';
import 'package:qingmang_weiji/widgets/fluid_button.dart';
import 'package:qingmang_weiji/widgets/fluid_dialog.dart';
import 'package:qingmang_weiji/widgets/liquid_controls.dart';

Widget _host(ThemeProvider theme, Widget child) {
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: theme,
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// 推进若干帧让弹窗动画跑完（应用里存在常驻动画，不能用 pumpAndSettle）
Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 取分段控件里某个标签文字的颜色（选中项为主色、未选中为次级色）
Color _labelColor(WidgetTester tester, String label) {
  final element = tester.element(find.text(label));
  return DefaultTextStyle.of(element).style.color!;
}

void main() {
  group('弹窗回车键确认', () {
    testWidgets('回车触发 actions 里最后一个动作（确定）', (tester) async {
      final theme = ThemeProvider();
      var confirmed = 0;
      await tester.pumpWidget(
        _host(
          theme,
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFluidDialog<void>(
                context: context,
                title: '标题',
                content: const Text('内容'),
                actions: [
                  FluidTextButton(text: '取消', onPressed: () {}),
                  FluidButton(
                    text: '确定',
                    onPressed: () {
                      confirmed++;
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await _advance(tester);
      expect(find.text('确定'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _advance(tester);

      expect(confirmed, 1);
      expect(find.text('确定'), findsNothing);
    });

    testWidgets('回车触发显式 onConfirm（按钮写在内容里的弹窗）', (tester) async {
      final theme = ThemeProvider();
      var confirmed = 0;
      await tester.pumpWidget(
        _host(
          theme,
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFluidDialog<void>(
                context: context,
                title: '选择周期',
                content: const Text('滚轮'),
                onConfirm: () {
                  confirmed++;
                  Navigator.pop(context);
                },
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await _advance(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _advance(tester);

      expect(confirmed, 1);
    });

    testWidgets('多行输入框内的回车不触发确定', (tester) async {
      final theme = ThemeProvider();
      var confirmed = 0;
      await tester.pumpWidget(
        _host(
          theme,
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFluidDialog<void>(
                context: context,
                title: '标题',
                content: const TextField(maxLines: 3, autofocus: true),
                actions: [
                  FluidButton(text: '确定', onPressed: () => confirmed++),
                ],
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await _advance(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _advance(tester);

      expect(confirmed, 0);
      expect(find.text('确定'), findsOneWidget);
    });
  });

  group('分段控件高亮跟随选中值', () {
    testWidgets('ticker 被静音时高亮也不会滞留在原来那段', (tester) async {
      SharedPreferences.setMockInitialValues({'appStyle': 'liquidGlass'});
      final theme = ThemeProvider();
      await theme.loadPreferences();
      expect(theme.isLiquidGlass, isTrue);

      var period = 1;
      var tickerEnabled = false;
      late StateSetter setHost;
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setHost = setState;
                    return TickerMode(
                      enabled: tickerEnabled,
                      child: LiquidSegmented<int>(
                        value: period,
                        segments: const [
                          LiquidSegment(value: 0, label: '日'),
                          LiquidSegment(value: 1, label: '周'),
                          LiquidSegment(value: 2, label: '月'),
                        ],
                        onChanged: (v) => setState(() => period = v),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final active = FluidTheme.primaryAccessible(false);
      final inactive = FluidTheme.getTextSecondaryColor(false);
      expect(_labelColor(tester, '周'), active);
      expect(_labelColor(tester, '月'), inactive);

      // 数据切到「月」：高亮必须立刻跟上，不能被动画状态拖住
      setHost(() => period = 2);
      await tester.pump();
      expect(_labelColor(tester, '月'), active);
      expect(_labelColor(tester, '周'), inactive);

      // 恢复 ticker 后滑块动画补上，选中态保持正确
      tickerEnabled = true;
      setHost(() {});
      await _advance(tester);
      expect(_labelColor(tester, '月'), active);
    });
  });
}

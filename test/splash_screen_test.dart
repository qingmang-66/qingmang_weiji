import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/screens/splash_screen.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('启动页展示期间改变动画时长不会抛出FlutterError', (tester) async {
    final provider = ThemeProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SplashScreen(child: SizedBox.expand())),
      ),
    );
    expect(tester.takeException(), isNull);

    await provider.setSplashAnimationSpeed(SplashAnimationSpeed.slow);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  /// 回归：开屏层是纯装饰 box，不参与手势命中，点击会穿透到底下的
  /// 引导页/首页；而下层在开屏期间 opacity 为 0 看不见 —— 开屏时的
  /// 催促连点会落在引导页看不见的「下一步/跳过」上，5 页引导被点完。
  testWidgets('开屏期间点击被屏蔽，不会穿透到下层页面', (tester) async {
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    var taps = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: SplashScreen(
            child: Scaffold(
              body: Center(
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const Text('target'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('target'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0, reason: '开屏期间下层页面不应收到点击');

    // 播完开屏（默认 comfortable 2000ms + 50ms 收尾）再点
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    await tester.tap(find.text('target'));
    await tester.pump();
    expect(taps, 1, reason: '开屏结束后下层页面恢复正常交互');
  });
}

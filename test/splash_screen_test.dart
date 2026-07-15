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
}

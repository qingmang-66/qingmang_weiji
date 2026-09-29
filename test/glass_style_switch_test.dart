import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/theme/fluid_theme.dart';
import 'package:qingmang_weiji/widgets/fluid_background.dart';

/// 记录自身状态，用于验证切换风格时页面状态是否被保留
class _CounterProbe extends StatefulWidget {
  const _CounterProbe();

  @override
  State<_CounterProbe> createState() => _CounterProbeState();
}

class _CounterProbeState extends State<_CounterProbe> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('count: $_count'),
          TextButton(
            onPressed: () => setState(() => _count++),
            child: const Text('inc'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('切换界面风格不会重建 Navigator 之下的页面状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();

    // 复刻 main.dart 的实际层级：Selector → MaterialApp(theme) → builder → GlassAmbientScope
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: Selector<ThemeProvider, AppStyle>(
          selector: (_, p) => p.appStyle,
          builder: (context, style, _) {
            return MaterialApp(
              theme: style == AppStyle.liquidGlass
                  ? FluidTheme.glassThemeData(isDark: false)
                  : FluidTheme.lightThemeData,
              builder: (context, child) =>
                  GlassAmbientScope(child: child ?? const SizedBox.shrink()),
              home: const _CounterProbe(),
            );
          },
        ),
      ),
    );

    expect(find.text('count: 0'), findsOneWidget);
    await tester.tap(find.text('inc'));
    await tester.pump();
    expect(find.text('count: 1'), findsOneWidget);

    // 玻璃模式氛围光斑是常驻动画，这里不能用 pumpAndSettle
    await provider.setAppStyle(AppStyle.liquidGlass);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.text('count: 1'), findsOneWidget, reason: '切换风格后页面状态应保留');

    await provider.setAppStyle(AppStyle.fluid);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.text('count: 1'), findsOneWidget, reason: '切回风格后页面状态应保留');
  });
}

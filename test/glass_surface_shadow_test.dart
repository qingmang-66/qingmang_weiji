import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/theme/fluid_theme.dart';
import 'package:qingmang_weiji/widgets/liquid_glass.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGlassSurface(
    WidgetTester tester, {
    required bool isDark,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.setAppStyle(AppStyle.liquidGlass);
    if (isDark) await provider.setDarkMode(true);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: isDark
              ? FluidTheme.glassThemeData(isDark: true)
              : FluidTheme.glassThemeData(isDark: false),
          home: const Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: GlassSurface(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 取出 GlassSurface 最外层 Container 的阴影列表
  List<BoxShadow> surfaceShadows(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    return decoration.boxShadow ?? const <BoxShadow>[];
  }

  testWidgets('玻璃卡片只把白色受光边垫在内部，深色投影不进入卡片', (tester) async {
    await pumpGlassSurface(tester, isDark: false);

    // 深色投影改为裁到卡片外绘制。若它被挪回 BoxDecoration，
    // 会因为玻璃只有 ~7% 不透明度而从卡片内部透出来（底部一层灰）。
    expect(surfaceShadows(tester), LiquidGlass.edgeHighlight(false));
    expect(
      LiquidGlass.dropShadow(false).length,
      greaterThan(0),
      reason: '深色投影应由 _GlassDropShadowPainter 绘制',
    );
  });

  testWidgets('深色模式同样不把深色投影垫在卡片内部', (tester) async {
    await pumpGlassSurface(tester, isDark: true);

    expect(surfaceShadows(tester), LiquidGlass.edgeHighlight(true));
  });

  test('玻璃描边渐变方向为竖直', () {
    for (final isDark in [false, true]) {
      final gradient = LiquidGlass.edgeGradient(isDark) as LinearGradient;
      // 对角渐变会让宽卡片右侧整条边、以及下边的右半段偏向末端颜色，
      // 观感就是"有些框的某几段边框发灰"。竖直后上下边各自均匀、左右对称。
      expect(gradient.begin, Alignment.topCenter, reason: 'isDark=$isDark');
      expect(gradient.end, Alignment.bottomCenter, reason: 'isDark=$isDark');
    }
  });

  test('顶部受光边为白色，保证卡片内部是提亮而非压暗', () {
    for (final isDark in [false, true]) {
      final glow = LiquidGlass.edgeHighlight(isDark).single;
      expect(glow.color.r, 1.0, reason: 'isDark=$isDark');
      expect(glow.color.g, 1.0, reason: 'isDark=$isDark');
      expect(glow.color.b, 1.0, reason: 'isDark=$isDark');
    }
  });

  testWidgets('深色投影画在玻璃之后，不参与 BackdropFilter 的折射采样', (tester) async {
    await pumpGlassSurface(tester, isDark: false);

    //包住玻璃本体的那个 CustomPaint（最外层）必须把投影挂在 foregroundPainter 上。
    //挂在 painter 上时，投影会先画进同一 layer，成为 BackdropFilter 的采样源；
    //σ=28~34 的高斯模糊把卡片外侧那圈阴影整片拉回卡内，下半张卡被均匀压暗
    //（浅色下就是"卡片内部下沿横着一条灰带"）。
    final paints = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(CustomPaint),
          ),
        )
        .toList();
    expect(paints, isNotEmpty);
    expect(paints.first.painter, isNull, reason: '玻璃之前不能再画深色投影');
    expect(paints.first.foregroundPainter, isNotNull, reason: '投影应画在玻璃之后');
  });

  test('白色底光必须铺满整张卡片，不能内缩出未提亮的边缘', () {
    for (final isDark in [false, true]) {
      final base = LiquidGlass.edgeHighlight(isDark).single;
      //一旦内缩（spreadRadius < 0）或偏移，卡片四周会留出 3~4px 没有提亮的
      //边缘：玻璃只有 ~7% 不透明度，那圈会原样透出被卡片投影压暗的背景，
      //浅色下就是"卡片内部下沿横着一条灰带"。
      expect(base.spreadRadius, 0, reason: 'isDark=$isDark');
      expect(base.offset, Offset.zero, reason: 'isDark=$isDark');
      expect(base.blurRadius, 0, reason: 'isDark=$isDark');
    }
  });
}

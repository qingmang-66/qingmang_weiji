import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/theme/fluid_theme.dart';
import 'package:qingmang_weiji/widgets/liquid_glass.dart';

/// 渲一块玻璃到像素，取卡片竖直中线（去掉描边/圆角附近）的亮度序列。
///
/// 背景是纯色，所以卡片内部**必须**是一个常量：任何自上而下的起伏都说明
/// 有图层把阴影/灰调画进了卡片里。
Future<List<double>> _interiorColumn(
  WidgetTester tester, {
  required double height,
  bool isDark = false,
  Widget? background,
}) async {
  const width = 300.0;
  const surface = 600.0;
  final key = GlobalKey();

  SharedPreferences.setMockInitialValues({});
  final provider = ThemeProvider();
  await provider.setAppStyle(AppStyle.liquidGlass);
  if (isDark) await provider.setThemeMode(ThemeMode.dark);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: FluidTheme.glassThemeData(isDark: isDark),
        home: RepaintBoundary(
          key: key,
          child: Stack(
            fit: StackFit.expand,
            children: [
              background ??
                  ColoredBox(
                    color: isDark
                        ? const Color(0xFF14162A)
                        : const Color(0xFFBAD0EC),
                  ),
              Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  // 不开 grain：噪点本身会让单像素读数上下跳 ±3~5 级，
                  // 而这里要抓的是"整条横带"级别的均匀性问题
                  child: const GlassSurface(child: SizedBox.expand()),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  ui.Image? image;
  ByteData? raw;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    image = await boundary.toImage();
    raw = await image!.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  final bytes = raw!.buffer.asUint8List();
  final stride = image!.width;

  final top = (surface - height) / 2;
  // 每个采样点取 17x3 的小窗口平均，抹掉抗锯齿/颗粒带来的单像素抖动
  double lumAt(double dy) {
    final cx = (surface / 2).round();
    final cy = (top + dy).round();
    var sum = 0.0;
    var n = 0;
    for (var dx = -8; dx <= 8; dx++) {
      for (var ddy = -1; ddy <= 1; ddy++) {
        final i = ((cy + ddy) * stride + cx + dx) * 4;
        sum += 0.299 * bytes[i] + 0.587 * bytes[i + 1] + 0.114 * bytes[i + 2];
        n++;
      }
    }
    return sum / n;
  }

  final values = <double>[];
  // 跳过最外 8px：那里是渐变描边、色散边与圆角
  for (var dy = 8.0; dy <= height - 8; dy += 2) {
    values.add(lumAt(dy));
  }

  return values;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('玻璃卡片内部的亮度均匀性', () {
    for (final isDark in <bool>[false, true]) {
      for (final height in <double>[200, 90, 44]) {
        testWidgets(
          '${isDark ? "深色" : "浅色"}下高 ${height.toInt()} 的卡片内部不应出现横向压暗/提亮带',
          (tester) async {
            final values = await _interiorColumn(
              tester,
              height: height,
              isDark: isDark,
            );

            if (!isDark) {
              final maxL = values.reduce(math.max);
              final minL = values.reduce(math.min);
              // 历史 bug：上/下沿的"某色 → Colors.transparent"高光渐变，
              // 因为透明端是透明黑、插值又在非预乘空间，中段会插出灰色，
              // 在卡片上沿约 40px、下沿约 34px 各压出一条横带（实测压暗 11~14 级）。
              expect(
                maxL - minL,
                lessThan(5),
                reason:
                    '卡片内部亮度起伏 ${(maxL - minL).toStringAsFixed(1)} 级，'
                    '说明有图层把灰调/亮调画进了玻璃内部（min=$minL max=$maxL）',
              );
              return;
            }

            // 深色玻璃与背景的亮度差远大于浅色（合成亮度 46 vs 背景 22），
            // BackdropFilter 的高斯模糊会把卡片外侧更暗的背景混进边缘，在上下
            // 各约 2σ（≈36px）形成一圈对称的柔和过渡。那是玻璃边缘的折射，
            // 不是"横贯卡片内部的带"，所以对主体区域断言绝对均匀，
            // 再单独断言上下对称 —— 后者正是"只有上半张被点亮"这类退化的特征。
            const edge = 40;
            final bodyStart = ((edge - 8) / 2).ceil();
            final bodyEnd = values.length - bodyStart;
            if (bodyEnd - bodyStart >= 3) {
              final body = values.sublist(bodyStart, bodyEnd);
              final bodyMax = body.reduce(math.max);
              final bodyMin = body.reduce(math.min);
              // 历史 bug：深色分支曾保留 stops=[0, 0.45, 1] 的竖向白色渐变，
              // 加亮在 45% 高度处归零，于是"只有上半张被点亮"。
              expect(
                bodyMax - bodyMin,
                lessThan(5),
                reason:
                    '卡片主体亮度起伏 ${(bodyMax - bodyMin).toStringAsFixed(1)} 级，'
                    '说明有图层把灰调/亮调画进了玻璃内部'
                    '（min=$bodyMin max=$bodyMax）',
              );
            }

            final mirrored = values.reversed.toList(growable: false);
            var maxAsymmetry = 0.0;
            for (var i = 0; i < values.length; i++) {
              final diff = (values[i] - mirrored[i]).abs();
              if (diff > maxAsymmetry) maxAsymmetry = diff;
            }
            expect(
              maxAsymmetry,
              lessThan(6),
              reason:
                  '卡片上下亮度不对称 ${maxAsymmetry.toStringAsFixed(1)} 级，'
                  '说明顶/底有方向性的加亮或压暗',
            );
          },
        );
      }
    }
  });

  testWidgets('深色下透过"光斑背景"的明暗差应被玻璃压平', (tester) async {
    // 复现真实场景：页面背景有上亮下暗的大光斑（深色氛围光的常态），
    // 玻璃若太透，卡片内部就会复现同样的"上亮下暗"。
    // 背景差约 99 级（亮紫 122 vs 深底 24），断言卡片主体压到 15 级以内。
    const darkBase = Color(0xFF14162A);
    const glowPurple = Color(0xFF7C6BC7);
    final background = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glowPurple, darkBase],
        ),
      ),
    );

    final values = await _interiorColumn(
      tester,
      height: 200,
      isDark: true,
      background: background,
    );

    const edge = 40;
    final bodyStart = ((edge - 8) / 2).ceil();
    final bodyEnd = values.length - bodyStart;
    final body = values.sublist(bodyStart, bodyEnd);
    final bodyMax = body.reduce(math.max);
    final bodyMin = body.reduce(math.min);

    // ignore: avoid_print
    print(
      'transmission body min=${bodyMin.toStringAsFixed(1)} '
      'max=${bodyMax.toStringAsFixed(1)} diff=${(bodyMax - bodyMin).toStringAsFixed(1)}',
    );

    expect(
      bodyMax - bodyMin,
      lessThan(15),
      reason:
          '透过光斑背景后卡片主体仍有 ${(bodyMax - bodyMin).toStringAsFixed(1)} 级明暗差'
          '（min=$bodyMin max=$bodyMax），玻璃太透，卡片会显得"上亮下暗"',
    );
  });
}

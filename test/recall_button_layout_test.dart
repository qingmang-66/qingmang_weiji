import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/recall_button_layout.dart';

/// 回忆模式评分键「锚点 + dp 偏移」布局几何
///
/// 坐标系约定（与学习页/编辑器共享同一参考系）：
/// - 参考列宽 kRecallRefColumnWidth = 480，水平居中于内容区
/// - gapLeft/gapRight 是键边缘到参考列边缘的距离，gapTop/gapBottom 是键
///   边缘到内容区上/下边缘的距离，gapMidY 是键中心相对内容区垂直中线的偏移
/// - 内容区宽 < 480（竖屏手机）时，键宽与横向间距按 区域宽/480 等比缩放，
///   纵向不缩放（触控键高与手机屏宽无关）——这是两端默认布局都成立的关键
void main() {
  const ref = kRecallRefColumnWidth; // 480

  RecallButtonSpec spec({
    RecallHAnchor h = RecallHAnchor.center,
    RecallVAnchor v = RecallVAnchor.bottom,
    double gapLeft = 0,
    double gapRight = 0,
    double gapTop = 0,
    double gapBottom = 0,
    double gapMidY = 0,
    double w = kRecallButtonDefaultW,
    double hPx = kRecallButtonDefaultH,
    double opacity = 1.0,
  }) => RecallButtonSpec(
    h: h,
    v: v,
    gapLeft: gapLeft,
    gapRight: gapRight,
    gapTop: gapTop,
    gapBottom: gapBottom,
    gapMidY: gapMidY,
    w: w,
    hPx: hPx,
    opacity: opacity,
  );

  group('默认布局', () {
    test('桌面 480 列宽下解析为贴底等距一排（三键不重叠、间距由默认 gapX 决定）', () {
      final layout = RecallButtonLayout.defaults();
      final area = Size(ref, 900);
      final r1 = layout.resolve(1, area);
      final r3 = layout.resolve(3, area);
      final r4 = layout.resolve(4, area);

      expect(r1.left, closeTo(kRecallButtonDefaultGapX, 0.001));
      expect(r3.left, closeTo((ref - kRecallButtonDefaultW) / 2, 0.001));
      expect(r4.right, closeTo(ref - kRecallButtonDefaultGapX, 0.001));
      // 等距：1|3 与 3|4 的横向间距一致
      expect(r3.left - r1.right, closeTo(r4.left - r3.right, 0.001));
      // 贴底
      expect(r1.bottom, closeTo(900 - kRecallButtonDefaultGapBottom, 0.001));
    });

    test('竖屏手机下三键等比缩窄且仍贴合屏边', () {
      final layout = RecallButtonLayout.defaults();
      final r1 = layout.resolve(1, const Size(360, 780));
      final r4 = layout.resolve(4, const Size(360, 780));
      final k = 360 / ref;

      expect(r1.left, closeTo(360 * kRecallButtonDefaultGapX / ref, 0.001));
      expect(
        r4.right,
        closeTo(360 - 360 * kRecallButtonDefaultGapX / ref, 0.001),
      );
      expect(r1.width, closeTo(kRecallButtonDefaultW * k, 0.001));
      // 纵向不缩放：键高保持默认 dp
      expect(r1.height, closeTo(kRecallButtonDefaultH, 0.001));
    });

    test('桌面宽窗下键群落在 480 参考列内，不随窗口变宽而散开', () {
      final layout = RecallButtonLayout.defaults();
      final r1 = layout.resolve(1, const Size(1200, 900));
      final r4 = layout.resolve(4, const Size(1200, 900));

      expect(
        r1.left,
        closeTo((1200 - ref) / 2 + kRecallButtonDefaultGapX, 0.001),
      );
      expect(
        r4.right,
        closeTo((1200 + ref) / 2 - kRecallButtonDefaultGapX, 0.001),
      );
    });
  });

  group('resolve', () {
    test('右锚 + 中锚键按 dp 间距定位', () {
      final r = spec(
        h: RecallHAnchor.right,
        v: RecallVAnchor.middle,
        gapRight: 52,
        gapMidY: 30,
      ).resolve(const Size(1200, 900));

      expect(
        r.left,
        closeTo((1200 + ref) / 2 - kRecallButtonDefaultW - 52, 0.001),
      );
      expect(r.top, closeTo((900 - kRecallButtonDefaultH) / 2 + 30, 0.001));
    });

    test('超出内容区的键被夹回可视范围', () {
      final huge = spec(gapBottom: 5000, w: 400, hPx: 200);
      final r = huge.resolve(const Size(480, 600));

      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(480));
      expect(r.bottom, lessThanOrEqualTo(600));
    });

    test('同一 spec 在 360/480/1200 宽三种区域下均不越界', () {
      final s = spec(h: RecallHAnchor.right, gapRight: 10, w: 300);
      for (final area in [
        const Size(360, 800),
        const Size(480, 800),
        const Size(1200, 800),
      ]) {
        final r = s.resolve(area);
        expect(r.left, greaterThanOrEqualTo(0), reason: 'area=${area.width}');
        expect(r.top, greaterThanOrEqualTo(0), reason: 'area=${area.width}');
        // 键整体允许被夹取，但左上角必须落在区域内
        expect(
          r.left,
          lessThanOrEqualTo(area.width),
          reason: 'area=${area.width}',
        );
        expect(
          r.top,
          lessThanOrEqualTo(area.height),
          reason: 'area=${area.width}',
        );
      }
    });
  });

  group('fromRect（拖拽落点 → 最近锚点）', () {
    test('3x3 九个区域各自落在正确锚点档位', () {
      const area = Size(480, 800);
      final w = kRecallButtonDefaultW;
      final h = kRecallButtonDefaultH;
      // 列：左键贴左 / 中键居中 / 右键贴右；行：上键贴顶 / 中键居中 / 下键贴底
      final xs = <double>[24, (480 - w) / 2, 480 - w - 24];
      final ys = <double>[16, (800 - h) / 2, 800 - h - 24];
      final expected = <String, (RecallHAnchor, RecallVAnchor)>{
        'LT': (RecallHAnchor.left, RecallVAnchor.top),
        'CT': (RecallHAnchor.center, RecallVAnchor.top),
        'RT': (RecallHAnchor.right, RecallVAnchor.top),
        'LM': (RecallHAnchor.left, RecallVAnchor.middle),
        'CM': (RecallHAnchor.center, RecallVAnchor.middle),
        'RM': (RecallHAnchor.right, RecallVAnchor.middle),
        'LB': (RecallHAnchor.left, RecallVAnchor.bottom),
        'CB': (RecallHAnchor.center, RecallVAnchor.bottom),
        'RB': (RecallHAnchor.right, RecallVAnchor.bottom),
      };

      for (final key in expected.keys) {
        final col = 'LCR'.indexOf(key[0]);
        final row = 'TMB'.indexOf(key[1]);
        final rect = Rect.fromLTWH(xs[col], ys[row], w, h);
        final derived = RecallButtonSpec.fromRect(rect, area, w: w, hPx: h);
        expect(derived.h, expected[key]!.$1, reason: key);
        expect(derived.v, expected[key]!.$2, reason: key);
      }
    });

    test('往返解析的键中心不偏离超过 8dp', () {
      const area = Size(1200, 900);
      final rect = Rect.fromLTWH(300, 200, 160, 54);
      final derived = RecallButtonSpec.fromRect(rect, area, w: 160, hPx: 54);
      final back = derived.resolve(area);

      expect(back.center.dx - rect.center.dx, lessThan(8.0));
      expect(back.center.dy - rect.center.dy, lessThan(8.0));
    });
  });

  group('JSON 持久化', () {
    test('encode → decode 往返保留逐键字段', () {
      final layout = RecallButtonLayout({
        1: spec(
          h: RecallHAnchor.left,
          v: RecallVAnchor.top,
          gapLeft: 8,
          gapTop: 64,
          w: 100,
          hPx: 40,
          opacity: 0.5,
        ),
        3: spec(gapMidY: -12),
        4: spec(h: RecallHAnchor.right, gapRight: 24),
      });

      final decoded = RecallButtonLayout.decode(layout.encode());

      expect(decoded.specs[1]!.h, RecallHAnchor.left);
      expect(decoded.specs[1]!.gapTop, closeTo(64, 0.001));
      expect(decoded.specs[1]!.opacity, closeTo(0.5, 0.001));
      expect(decoded.specs[3]!.gapMidY, closeTo(-12, 0.001));
      expect(decoded.specs[4]!.h, RecallHAnchor.right);
      expect(decoded.specs[4]!.gapRight, closeTo(24, 0.001));
    });

    test('损坏 JSON 与缺字段回落到默认布局', () {
      expect(RecallButtonLayout.decode(null).specs.keys.toList()..sort(), [
        1,
        3,
        4,
      ]);
      expect(RecallButtonLayout.decode('not json').specs.keys.length, 3);
      expect(
        RecallButtonLayout.decode('{"v":1}').specs[1]!.h,
        RecallHAnchor.left,
      );
      // 默认布局的 1 号键是左锚
      expect(
        RecallButtonLayout.decode('{"v":999,"specs":{}}').specs[1]!.h,
        RecallHAnchor.left,
      );
    });
  });
}

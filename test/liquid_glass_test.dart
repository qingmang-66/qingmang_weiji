import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/providers/reader_settings_provider.dart';
import 'package:qingmang_weiji/widgets/liquid_glass.dart';

/// 按 Flutter ColorFilter.matrix 的语义套用矩阵（0..1 归一化通道，偏移项直接相加）
Color _apply(Float64List m, Color c) {
  double at(int row, int col) => m[row * 5 + col];
  double chan(int row) =>
      at(row, 0) * c.r * 255 +
      at(row, 1) * c.g * 255 +
      at(row, 2) * c.b * 255 +
      at(row, 3) * c.a * 255 +
      at(row, 4) * 255;
  return Color.fromARGB(
    255,
    chan(0).round().clamp(0, 255),
    chan(1).round().clamp(0, 255),
    chan(2).round().clamp(0, 255),
  );
}

void main() {
  group('GlassSurface.saturationMatrix', () {
    test('玻璃面板里的浅色不会被裁成纯白', () {
      //浅色模式下玻璃面板用的饱和度
      final m = GlassSurface.saturationMatrix(1.28);
      //只看本身有色相的浅色预设（纯白/黑灰没有色相可谈）
      final tinted = ReaderSettingsProvider.presetBgColors
          .map((v) => Color(v))
          .where((c) {
            final chans = [c.r, c.g, c.b];
            return chans.reduce((a, b) => a > b ? a : b) -
                    chans.reduce((a, b) => a < b ? a : b) >
                0.03;
          });
      expect(tinted, isNotEmpty);

      for (final c in tinted) {
        final chans = [
          _apply(m, c).r * 255,
          _apply(m, c).g * 255,
          _apply(m, c).b * 255,
        ];
        final spread =
            chans.reduce((a, b) => a > b ? a : b) -
            chans.reduce((a, b) => a < b ? a : b);
        //色相没了（所有通道被抬到 255 或压到同一值）就会被判成"纯白/灰"
        expect(
          spread,
          greaterThan(8),
          reason: '#${c.toARGB32().toRadixString(16)} 在玻璃里丢了色相',
        );
      }
    });

    test('变换只放大色度，亮度基本不变', () {
      final m = GlassSurface.saturationMatrix(1.28);
      for (final v in ReaderSettingsProvider.presetBgColors) {
        final c = Color(v);
        final diff = (_apply(m, c).computeLuminance() - c.computeLuminance())
            .abs();
        expect(
          diff,
          lessThan(0.05),
          reason:
              '#${v.toRadixString(16)} 亮度被改变了 '
              '${diff.toStringAsFixed(3)}',
        );
      }
    });
  });
}

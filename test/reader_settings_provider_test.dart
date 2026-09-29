import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qingmang_weiji/models/reader_bookmark.dart';
import 'package:qingmang_weiji/services/providers/reader_settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReaderSettingsProvider', () {
    test('默认值', () async {
      final p = ReaderSettingsProvider();
      await p.loadPreferences();
      expect(p.fontSize, 16);
      expect(p.fontWeightIndex, 0);
      expect(p.naming, ReaderBookmarkNaming.word);
      expect(p.bgColor.toARGB32(), 0xFFFFFFFF);
      expect(p.bgImagePath, isNull);
    });

    test('设置持久化并重新加载', () async {
      final p = ReaderSettingsProvider();
      await p.loadPreferences();
      await p.setFontSize(24);
      await p.setFontWeightIndex(2);
      await p.setNaming(ReaderBookmarkNaming.custom);
      await p.setBgColor(const Color.fromARGB(255, 10, 20, 30));
      await p.setBgImage('/tmp/bg.png');

      //新实例重新加载，验证持久化
      final p2 = ReaderSettingsProvider();
      await p2.loadPreferences();
      expect(p2.fontSize, 24);
      expect(p2.fontWeightIndex, 2);
      expect(p2.naming, ReaderBookmarkNaming.custom);
      expect(p2.bgColor.toARGB32(), 0xFF0A141E);
      expect(p2.bgImagePath, '/tmp/bg.png');

      //移除背景图
      await p2.setBgImage(null);
      final p3 = ReaderSettingsProvider();
      await p3.loadPreferences();
      expect(p3.bgImagePath, isNull);
    });

    test('fontSize 越界收敛', () async {
      final p = ReaderSettingsProvider();
      await p.setFontSize(99);
      expect(p.fontSize, ReaderSettingsProvider.maxFontSize);
      await p.setFontSize(1);
      expect(p.fontSize, ReaderSettingsProvider.minFontSize);
    });

    test('旧预设背景色迁移到新预设色板', () async {
      SharedPreferences.setMockInitialValues({
        'readerBgColor': 0xFFE8F5E9, //旧的极浅绿
      });
      final p = ReaderSettingsProvider();
      await p.loadPreferences();
      expect(p.bgColor.toARGB32(), 0xFFD9EEDA);
      //迁移后必须仍是色板里的成员，否则色点上不会出现选中态
      expect(
        ReaderSettingsProvider.presetBgColors.contains(p.bgColor.toARGB32()),
        isTrue,
      );
    });

    test('色板里的浅色都足够亮，保证自动取深色文字', () async {
      for (final v in ReaderSettingsProvider.presetBgColors) {
        final lum = Color(v).computeLuminance();
        //深色预设（深蓝灰/纯黑）走白字，浅色预设必须留在浅色区间
        if (lum > 0.6) continue;
        expect(v, anyOf(0xFF37474F, 0xFF212121));
      }
    });

    test('fontWeight 映射', () async {
      final p = ReaderSettingsProvider();
      await p.setFontWeightIndex(0);
      expect(p.fontWeight, FontWeight.w400);
      await p.setFontWeightIndex(1);
      expect(p.fontWeight, FontWeight.w500);
      await p.setFontWeightIndex(2);
      expect(p.fontWeight, FontWeight.w700);
    });

    test('文字颜色/翻页效果/翻页方式持久化', () async {
      final p = ReaderSettingsProvider();
      await p.loadPreferences();
      expect(p.textColor, isNull);
      expect(p.pageTransition, ReaderPageTransition.slide);
      expect(p.tapTurnEnabled, isTrue);
      expect(p.volumeTurnEnabled, isFalse);

      await p.setTextColor(const Color.fromARGB(255, 200, 30, 30));
      await p.setPageTransition(ReaderPageTransition.curl);
      await p.setTapTurnEnabled(false);
      await p.setVolumeTurnEnabled(true);

      final p2 = ReaderSettingsProvider();
      await p2.loadPreferences();
      expect(p2.textColor?.toARGB32(), 0xFFC81E1E);
      expect(p2.pageTransition, ReaderPageTransition.curl);
      expect(p2.tapTurnEnabled, isFalse);
      expect(p2.volumeTurnEnabled, isTrue);

      //恢复自动取色
      await p2.setTextColor(null);
      final p3 = ReaderSettingsProvider();
      await p3.loadPreferences();
      expect(p3.textColor, isNull);
    });

    test('preview 不触发 notifyListeners', () async {
      final p = ReaderSettingsProvider();
      await p.loadPreferences();
      var notified = 0;
      p.addListener(() => notified++);
      p.previewFontSize(20);
      p.previewBgColor(const Color(0xFF123456));
      expect(notified, 0);
      expect(p.fontSize, 20);
      expect(p.bgColor.toARGB32(), 0xFF123456);
      await p.setFontSize(22);
      expect(notified, 1);
    });
  });
}

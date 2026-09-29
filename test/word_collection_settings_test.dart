import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/word_favorite.dart';
import 'package:qingmang_weiji/services/providers/reader_settings_provider.dart';
import 'package:qingmang_weiji/services/providers/word_collection_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordCollectionSettingsProvider', () {
    test('默认值：两个词集入口都显示数量，错题集显示攻克进度', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = WordCollectionSettingsProvider();
      await provider.loadPreferences();

      expect(provider.showWrongWordsBadge, isTrue);
      expect(provider.showFavoritesBadge, isTrue);
      expect(provider.showMasteryProgress, isTrue);
    });

    test('开关持久化并可重新加载', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = WordCollectionSettingsProvider();
      await provider.loadPreferences();

      await provider.setShowWrongWordsBadge(false);
      await provider.setShowMasteryProgress(false);
      await provider.setShowFavoritesBadge(false);

      final reloaded = WordCollectionSettingsProvider();
      await reloaded.loadPreferences();
      expect(reloaded.showWrongWordsBadge, isFalse);
      expect(reloaded.showMasteryProgress, isFalse);
      expect(reloaded.showFavoritesBadge, isFalse);
    });

    test('收藏夹筛选默认是"全部"，排序默认最新在前', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = WordCollectionSettingsProvider();
      await provider.loadPreferences();

      expect(provider.favoriteSourceFilter, isNull);
      expect(provider.favoriteBookFilter, isNull);
      expect(provider.favoriteTimeRange, FavoriteTimeRange.all);
      expect(provider.favoriteSortAscending, isFalse);
    });

    test('记住上次的筛选与排序，重进页面即可恢复', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = WordCollectionSettingsProvider();
      await provider.loadPreferences();

      await provider.setFavoriteSourceFilter(FavoriteSource.reader);
      await provider.setFavoriteBookFilter(7);
      await provider.setFavoriteTimeRange(FavoriteTimeRange.last7Days);
      await provider.setFavoriteSortAscending(true);

      final reloaded = WordCollectionSettingsProvider();
      await reloaded.loadPreferences();
      expect(reloaded.favoriteSourceFilter, FavoriteSource.reader);
      expect(reloaded.favoriteBookFilter, 7);
      expect(reloaded.favoriteTimeRange, FavoriteTimeRange.last7Days);
      expect(reloaded.favoriteSortAscending, isTrue);
    });

    test('清除筛选清空来源/词库/时间，但保留排序方向', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = WordCollectionSettingsProvider();
      await provider.loadPreferences();

      await provider.setFavoriteSourceFilter(FavoriteSource.study);
      await provider.setFavoriteBookFilter(3);
      await provider.setFavoriteTimeRange(FavoriteTimeRange.today);
      await provider.setFavoriteSortAscending(true);

      await provider.clearFavoriteFilters();
      expect(provider.favoriteSourceFilter, isNull);
      expect(provider.favoriteBookFilter, isNull);
      expect(provider.favoriteTimeRange, FavoriteTimeRange.all);
      //排序不是"筛选"，没隐藏任何条目，不该被一起重置
      expect(provider.favoriteSortAscending, isTrue);

      final reloaded = WordCollectionSettingsProvider();
      await reloaded.loadPreferences();
      expect(reloaded.favoriteSourceFilter, isNull);
      expect(reloaded.favoriteBookFilter, isNull);
      expect(reloaded.favoriteTimeRange, FavoriteTimeRange.all);
      expect(reloaded.favoriteSortAscending, isTrue);
    });
  });

  group('FavoriteTimeRange', () {
    test('按自然日算起点，不是"过去 N×24 小时"', () {
      final now = DateTime(2026, 9, 16, 14, 33);
      expect(FavoriteTimeRange.all.since(now: now), isNull);
      expect(FavoriteTimeRange.today.since(now: now), DateTime(2026, 9, 16));
      //含今天在内共 7 个自然日
      expect(
        FavoriteTimeRange.last7Days.since(now: now),
        DateTime(2026, 9, 10),
      );
      expect(
        FavoriteTimeRange.last30Days.since(now: now),
        DateTime(2026, 8, 18),
      );
    });

    test('同一天的凌晨与深夜起点相同（不会随当前时刻漂移）', () {
      expect(
        FavoriteTimeRange.today.since(now: DateTime(2026, 9, 16, 0, 5)),
        FavoriteTimeRange.today.since(now: DateTime(2026, 9, 16, 23, 55)),
      );
    });

    test('tryParse 无法识别时回落到"全部"，不做激进降级', () {
      expect(
        FavoriteTimeRange.tryParse('last7Days'),
        FavoriteTimeRange.last7Days,
      );
      expect(FavoriteTimeRange.tryParse(null), FavoriteTimeRange.all);
      expect(FavoriteTimeRange.tryParse(''), FavoriteTimeRange.all);
      expect(FavoriteTimeRange.tryParse('unknown'), FavoriteTimeRange.all);
    });
  });

  group('ReaderSettingsProvider 标记设置', () {
    test('默认只开"记住了"的图标标记，收藏星标默认显示', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ReaderSettingsProvider();
      await provider.loadPreferences();

      expect(provider.rememberedMarkIcon, isTrue);
      expect(provider.rememberedMarkRow, isFalse);
      expect(provider.rememberedMarkWord, isFalse);
      expect(provider.showFavoriteStar, isTrue);
    });

    test('三种标记方式彼此独立，可只开一种也能全开', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ReaderSettingsProvider();
      await provider.loadPreferences();

      await provider.setRememberedMarkIcon(false);
      await provider.setRememberedMarkWord(true);
      expect(provider.rememberedMarkIcon, isFalse);
      expect(provider.rememberedMarkRow, isFalse);
      expect(provider.rememberedMarkWord, isTrue);

      await provider.setRememberedMarkRow(true);
      expect(provider.rememberedMarkRow, isTrue);
      expect(provider.rememberedMarkWord, isTrue);
    });

    test('标记设置会进入 renderSignature（否则改设置阅读器不重绘）', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ReaderSettingsProvider();
      await provider.loadPreferences();

      final before = provider.renderSignature;
      await provider.setRememberedMarkRow(true);
      expect(provider.renderSignature, isNot(before));

      final beforeColor = provider.renderSignature;
      await provider.setMarkColorIndex(2);
      expect(provider.renderSignature, isNot(beforeColor));
    });

    test('影响排版尺寸的开关会进入 markStyleSignature', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ReaderSettingsProvider();
      await provider.loadPreferences();

      final before = provider.markStyleSignature;
      //图标与星标占宽度、行底色加内边距，都必须触发重排
      await provider.setRememberedMarkIcon(false);
      expect(provider.markStyleSignature, isNot(before));

      final afterIcon = provider.markStyleSignature;
      await provider.setShowFavoriteStar(false);
      expect(provider.markStyleSignature, isNot(afterIcon));

      //纯颜色变化不影响尺寸，不该触发重排
      final afterStar = provider.markStyleSignature;
      await provider.setMarkColorIndex(1);
      expect(provider.markStyleSignature, afterStar);
    });

    test('markColor 在浅色背景用深色版、深色背景提亮', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ReaderSettingsProvider();
      await provider.loadPreferences();

      final onLight = provider.markColor(true);
      final onDark = provider.markColor(false);
      expect(
        onLight,
        ReaderSettingsProvider.markColors[provider.markColorIndex],
      );
      //深色背景上要往白里提，否则彩度被背景吃掉
      expect(
        onDark.computeLuminance(),
        greaterThan(onLight.computeLuminance()),
      );
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/word_favorite.dart';

/// 词集（错题集 / 收藏夹）的显示设置
///
/// 两个词集的开关各自归属**自己的**设置面板（错题集页 / 收藏夹页右上角），
/// 与阅读模式的做法一致 —— 设置跟着功能走，全局设置页保持精简。
/// 因此这里用一个 Provider 承载两组键，而不是塞进全局设置。
class WordCollectionSettingsProvider extends ChangeNotifier {
  final Future<SharedPreferences> Function() _preferencesLoader;

  /// dispose 标记：异步 loadPreferences 可能在 Provider 释放后才落地，
  /// 此时 notifyListeners 会触发 "used after being disposed" 断言
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (_disposed) return;
    super.notifyListeners();
  }

  WordCollectionSettingsProvider({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  bool _showWrongWordsBadge = true;
  bool _showMasteryProgress = true;
  bool _showFavoritesBadge = true;

  /// 错题列表是否显示"错因 · xx"标签
  bool _showWrongCause = true;

  /// 错题列表是否显示"×N"答错次数徽标
  bool _showWrongCount = true;

  FavoriteSource? _favoriteSourceFilter;
  int? _favoriteBookFilter;
  FavoriteTimeRange _favoriteTimeRange = FavoriteTimeRange.all;
  bool _favoriteSortAscending = false;

  /// 首页「错题集」入口是否显示数量徽标
  bool get showWrongWordsBadge => _showWrongWordsBadge;

  /// 错题列表是否显示"连续答对 x/3"的攻克进度
  bool get showMasteryProgress => _showMasteryProgress;

  /// 错题列表是否显示"错因 · xx"标签
  ///
  /// 老数据的错因事件可能缺失（卡片上有的显示有的不显示就是这个原因：
  /// 聚合不到事件的词没有错因可显示），这里提供整包关掉的开关。
  bool get showWrongCause => _showWrongCause;

  /// 错题列表是否显示"×N"答错次数徽标
  bool get showWrongCount => _showWrongCount;

  /// 首页「收藏夹」入口是否显示数量徽标
  bool get showFavoritesBadge => _showFavoritesBadge;

  /// 收藏夹上次用的来源筛选；null = 全部来源
  FavoriteSource? get favoriteSourceFilter => _favoriteSourceFilter;

  /// 收藏夹上次用的词库筛选；null = 全部词库
  int? get favoriteBookFilter => _favoriteBookFilter;

  /// 收藏夹上次用的时间范围筛选
  FavoriteTimeRange get favoriteTimeRange => _favoriteTimeRange;

  /// 收藏夹排序是否正序（最早在前）；false = 最新在前
  bool get favoriteSortAscending => _favoriteSortAscending;

  Future<void> loadPreferences() async {
    try {
      final prefs = await _preferencesLoader();
      _showWrongWordsBadge = prefs.getBool(_keyWrongWordsBadge) ?? true;
      _showMasteryProgress = prefs.getBool(_keyMasteryProgress) ?? true;
      _showFavoritesBadge = prefs.getBool(_keyFavoritesBadge) ?? true;
      _showWrongCause = prefs.getBool(_keyWrongCause) ?? true;
      _showWrongCount = prefs.getBool(_keyWrongCount) ?? true;
      //收藏夹筛选：记住上次的选择。词库可能已被删除，此时由收藏夹页在加载时
      //发现"该词库已无收藏"并自动回到全部，这里不做校验
      _favoriteSourceFilter = FavoriteSource.tryParse(
        prefs.getString(_keyFavoriteSource),
      );
      _favoriteBookFilter = prefs.getInt(_keyFavoriteBook);
      _favoriteTimeRange = FavoriteTimeRange.tryParse(
        prefs.getString(_keyFavoriteRange),
      );
      _favoriteSortAscending = prefs.getBool(_keyFavoriteSortAsc) ?? false;
      _safeNotify();
    } catch (e) {
      debugPrint('加载词集设置失败：$e');
    }
  }

  Future<void> setShowWrongWordsBadge(bool value) async {
    _showWrongWordsBadge = value;
    _safeNotify();
    await _save(_keyWrongWordsBadge, value);
  }

  Future<void> setShowMasteryProgress(bool value) async {
    _showMasteryProgress = value;
    _safeNotify();
    await _save(_keyMasteryProgress, value);
  }

  Future<void> setShowFavoritesBadge(bool value) async {
    _showFavoritesBadge = value;
    _safeNotify();
    await _save(_keyFavoritesBadge, value);
  }

  Future<void> setShowWrongCause(bool value) async {
    _showWrongCause = value;
    _safeNotify();
    await _save(_keyWrongCause, value);
  }

  Future<void> setShowWrongCount(bool value) async {
    _showWrongCount = value;
    _safeNotify();
    await _save(_keyWrongCount, value);
  }

  Future<void> setFavoriteSourceFilter(FavoriteSource? value) async {
    _favoriteSourceFilter = value;
    _safeNotify();
    await _saveFilter(_keyFavoriteSource, value?.name);
  }

  Future<void> setFavoriteBookFilter(int? value) async {
    _favoriteBookFilter = value;
    _safeNotify();
    await _saveFilter(_keyFavoriteBook, value);
  }

  Future<void> setFavoriteTimeRange(FavoriteTimeRange value) async {
    _favoriteTimeRange = value;
    _safeNotify();
    await _saveFilter(_keyFavoriteRange, value.name);
  }

  Future<void> setFavoriteSortAscending(bool value) async {
    _favoriteSortAscending = value;
    _safeNotify();
    await _save(_keyFavoriteSortAsc, value);
  }

  /// 清除收藏夹筛选（来源 / 词库 / 时间范围）
  ///
  /// 排序方向不算"筛选"（它不隐藏任何东西），保持用户的选择不动。
  Future<void> clearFavoriteFilters() async {
    _favoriteSourceFilter = null;
    _favoriteBookFilter = null;
    _favoriteTimeRange = FavoriteTimeRange.all;
    _safeNotify();
    await _saveFilter(_keyFavoriteSource, null);
    await _saveFilter(_keyFavoriteBook, null);
    await _saveFilter(_keyFavoriteRange, null);
  }

  static const String _keyWrongWordsBadge = 'collectionWrongWordsBadge';
  static const String _keyMasteryProgress = 'collectionMasteryProgress';
  static const String _keyFavoritesBadge = 'collectionFavoritesBadge';
  static const String _keyWrongCause = 'collectionShowWrongCause';
  static const String _keyWrongCount = 'collectionShowWrongCount';
  static const String _keyFavoriteSource = 'collectionFavoriteSource';
  static const String _keyFavoriteBook = 'collectionFavoriteBook';
  static const String _keyFavoriteRange = 'collectionFavoriteRange';
  static const String _keyFavoriteSortAsc = 'collectionFavoriteSortAsc';

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await _preferencesLoader();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('保存词集设置失败：$e');
    }
  }

  /// 写入筛选类设置；[value] 为 null 时删除键（回到"未设置/全部"）
  Future<void> _saveFilter(String key, Object? value) async {
    try {
      final prefs = await _preferencesLoader();
      if (value == null) {
        await prefs.remove(key);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('保存收藏夹筛选失败：$e');
    }
  }
}

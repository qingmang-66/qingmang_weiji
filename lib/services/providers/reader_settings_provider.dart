import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/reader_bookmark.dart';

/// 翻页效果
enum ReaderPageTransition { none, slide, curl }

/// 阅读模式设置：字体大小/粗细/颜色、书签命名方式、背景颜色/图片、翻页方式
class ReaderSettingsProvider extends ChangeNotifier {
  final Future<SharedPreferences> Function() _preferencesLoader;

  ReaderSettingsProvider({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  double _fontSize = 16;
  int _fontWeightIndex = 0; //0 正常 1 中等 2 加粗
  ReaderBookmarkNaming _naming = ReaderBookmarkNaming.word;
  int _bgColorValue = 0xFFFFFFFF;
  String? _bgImagePath;
  int? _textColorValue; //null 表示按背景亮度自动取色
  ReaderPageTransition _pageTransition = ReaderPageTransition.slide;
  bool _tapTurnEnabled = true; //点击屏幕左右区域翻页
  bool _volumeTurnEnabled = false; //音量键翻页（仅安卓）
  double _bgBlur = 0; //壁纸景深模糊 sigma
  double _bgOverlay = 0.3; //壁纸压暗蒙层透明度

  // 排版间距：行段间距倍率（同时缩放行高与词条间距）与页面左右边距。
  // 二者都影响每页能放多少词条，故纳入 renderSignature 与分页缓存键。
  double _spacingScale = 1.0;
  double _pageMargin = 20;

  /// 行段间距预设倍率：小 / 较小 / 适中 / 大（自定义走滑块）
  static const List<double> spacingPresets = [0.85, 1.0, 1.15, 1.35];

  /// 页面边距预设（逻辑像素）：小 / 适中 / 较大 / 大
  static const List<double> pageMarginPresets = [12, 20, 28, 36];

  /// 自定义区间
  static const double minSpacing = 0.8;
  static const double maxSpacing = 1.6;
  static const double minPageMargin = 8;
  static const double maxPageMargin = 48;

  // 「记住了」的三种标记方式，彼此独立，可只开一种也能全开
  bool _rememberedMarkIcon = true; //词条行首 ✓ 图标（原有行为）
  bool _rememberedMarkRow = false; //整行淡色底
  bool _rememberedMarkWord = false; //整行文字（单词+音标+释义）变色
  int _markColorIndex = 0; //标记颜色，见 markColors
  bool _showFavoriteStar = true; //已收藏词条行尾 ★

  /// 「记住了」/收藏标记可选颜色（浅色背景时用的深色版）
  static const List<Color> markColors = [
    Color(0xFF16A34A), //绿
    Color(0xFF2563EB), //蓝
    Color(0xFF9333EA), //紫
    Color(0xFFEA580C), //橙
  ];

  double get fontSize => _fontSize;
  int get fontWeightIndex => _fontWeightIndex;
  ReaderBookmarkNaming get naming => _naming;
  Color get bgColor => _safeArgb(_bgColorValue, 0xFFFFFFFF);
  String? get bgImagePath => _bgImagePath;
  Color? get textColor => _textColorValue == null
      ? null
      : _safeArgb(_textColorValue!, 0xFF000000);

  /// ARGB 收敛：prefs 里的整数可能被写坏（越界/负数），Color() 对越界值会
  /// 直接断言崩溃（阅读页白屏）；越界时回退默认色而不是让整页挂掉
  static Color _safeArgb(int value, int fallback) =>
      Color(value < 0 || value > 0xFFFFFFFF ? fallback : value);
  ReaderPageTransition get pageTransition => _pageTransition;
  bool get tapTurnEnabled => _tapTurnEnabled;
  bool get volumeTurnEnabled => _volumeTurnEnabled;
  double get bgBlur => _bgBlur;
  double get bgOverlay => _bgOverlay;
  double get spacingScale => _spacingScale;
  double get pageMargin => _pageMargin;

  bool get rememberedMarkIcon => _rememberedMarkIcon;
  bool get rememberedMarkRow => _rememberedMarkRow;
  bool get rememberedMarkWord => _rememberedMarkWord;
  bool get showFavoriteStar => _showFavoriteStar;
  int get markColorIndex => _markColorIndex.clamp(0, markColors.length - 1);

  /// 当前标记色。[lightBg] 为真（浅色阅读背景）时用深色版保证可读；
  /// 深色背景上把色相提亮，避免彩度被背景吃掉。
  Color markColor(bool lightBg) {
    final base = markColors[markColorIndex];
    return lightBg ? base : Color.lerp(base, Colors.white, 0.45)!;
  }

  /// 影响词条**排版尺寸**的标记设置签名。
  ///
  /// 图标和星标会占用单词行宽度、行底色会加内边距，所以这些开关一变，
  /// 阅读器必须让分页缓存失效重排，否则页尾会被裁掉。
  int get markStyleSignature =>
      Object.hash(_rememberedMarkIcon, _rememberedMarkRow, _showFavoriteStar);

  /// 阅读字号可选范围：设置面板滑块与取值收敛共用同一份定义
  static const double minFontSize = 10;
  static const double maxFontSize = 36;

  /// 阅读背景预设色。
  ///
  /// 选色标准是「铺满整页时读得出色相」：早先用的 #E8F5E9 / #FCE4EC 一类极浅色，
  /// 成片铺开是淡绿/淡粉，但缩成 38px 色点后和纯白几乎没区别，
  /// 于是出现「色点都是白的、可背景其实是黄/绿」的割裂感，这里统一加深一档。
  /// 亮度仍保持在浅色区间（computeLuminance > 0.6），保证自动取深色文字时可读。
  static const List<int> presetBgColors = <int>[
    0xFFFFFFFF, //纯白
    0xFFF6E7C8, //米黄
    0xFFD9EEDA, //浅绿
    0xFFD8E7F8, //浅蓝
    0xFFF8DEE5, //浅粉
    0xFFE9E4DD, //暖灰
    0xFF37474F, //深蓝灰
    0xFF212121, //纯黑
  ];

  /// 旧版预设色 → 新版预设色。
  /// 加载时做一次迁移，否则升级后色板上找不到当前值，会出现「一个都没选中」的错觉。
  static const Map<int, int> _legacyBgPresetRemap = <int, int>{
    0xFFFDF6E3: 0xFFF6E7C8,
    0xFFE8F5E9: 0xFFD9EEDA,
    0xFFE3F2FD: 0xFFD8E7F8,
    0xFFFCE4EC: 0xFFF8DEE5,
    0xFFEFEBE9: 0xFFE9E4DD,
  };

  static const List<FontWeight> _weights = [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w700,
  ];

  FontWeight get fontWeight => _weights[_fontWeightIndex.clamp(0, 2)];

  /// 影响阅读器外观的设置签名。
  ///
  /// 阅读器只订阅这个值：书签命名、音量键等与渲染无关的设置变化时
  /// 不会触发整页重建（书签命名切换原本会连带重建整个 PageView）。
  int get renderSignature => Object.hash(
    _fontSize,
    _fontWeightIndex,
    _bgColorValue,
    _textColorValue,
    _bgImagePath,
    _pageTransition.index,
    _tapTurnEnabled,
    _bgBlur,
    _bgOverlay,
    _spacingScale,
    _pageMargin,
    _rememberedMarkIcon,
    _rememberedMarkRow,
    _rememberedMarkWord,
    _markColorIndex,
    _showFavoriteStar,
  );

  Future<void> loadPreferences() async {
    try {
      final prefs = await _preferencesLoader();
      _fontSize = (prefs.getDouble('readerFontSize') ?? 16).clamp(
        minFontSize,
        maxFontSize,
      );
      final w = prefs.getInt('readerFontWeight') ?? 0;
      _fontWeightIndex = w.clamp(0, 2);
      final n = prefs.getInt('readerNamingMode') ?? 0;
      _naming = ReaderBookmarkNaming.values[n.clamp(0, 2)];
      final bg = prefs.getInt('readerBgColor') ?? 0xFFFFFFFF;
      _bgColorValue = _legacyBgPresetRemap[bg] ?? bg;
      _bgImagePath = prefs.getString('readerBgImage');
      _textColorValue = prefs.getInt('readerTextColor');
      final t = prefs.getInt('readerPageTransition') ?? 1;
      _pageTransition = ReaderPageTransition.values[t.clamp(0, 2)];
      _tapTurnEnabled = prefs.getBool('readerTapTurn') ?? true;
      _volumeTurnEnabled = prefs.getBool('readerVolumeTurn') ?? false;
      _bgBlur = (prefs.getDouble('readerBgBlur') ?? 0).clamp(0.0, 20.0);
      _bgOverlay = (prefs.getDouble('readerBgOverlay') ?? 0.3).clamp(0.0, 0.8);
      _rememberedMarkIcon = prefs.getBool('readerMarkIcon') ?? true;
      _rememberedMarkRow = prefs.getBool('readerMarkRow') ?? false;
      _rememberedMarkWord = prefs.getBool('readerMarkWord') ?? false;
      _markColorIndex = (prefs.getInt('readerMarkColor') ?? 0).clamp(
        0,
        markColors.length - 1,
      );
      _showFavoriteStar = prefs.getBool('readerFavoriteStar') ?? true;
      _spacingScale = (prefs.getDouble('readerSpacingScale') ?? 1.0).clamp(
        minSpacing,
        maxSpacing,
      );
      _pageMargin = (prefs.getDouble('readerPageMargin') ?? 20).clamp(
        minPageMargin,
        maxPageMargin,
      );
      _safeNotify();
    } catch (e) {
      debugPrint('加载阅读设置失败：$e');
    }
  }

  //以下 preview* 仅更新内存值不通知，供设置面板拖拽时实时预览，避免阅读器反复重排
  void previewFontSize(double v) =>
      _fontSize = v.clamp(minFontSize, maxFontSize);

  void previewFontWeightIndex(int v) => _fontWeightIndex = v.clamp(0, 2);

  void previewBgColor(Color c) => _bgColorValue = c.toARGB32();

  void previewTextColor(Color? c) => _textColorValue = c?.toARGB32();

  //颜色拖拽中：更新内存并通知重绘，但不写偏好设置（颜色不触发重排，开销小）
  void setBgColorLive(Color c) {
    previewBgColor(c);
    _safeNotify();
  }

  void setTextColorLive(Color? c) {
    previewTextColor(c);
    _safeNotify();
  }

  Future<void> setFontSize(double v) async {
    previewFontSize(v);
    //先通知 UI 再落盘，避免滑块/分段动画等待异步 IO
    _safeNotify();
    await _save('readerFontSize', _fontSize);
  }

  Future<void> setFontWeightIndex(int v) async {
    previewFontWeightIndex(v);
    _safeNotify();
    await _save('readerFontWeight', _fontWeightIndex);
  }

  //行段间距/页面边距：影响分页，与字号一致——拖拽中仅内存预览，松手一次性重排
  void previewSpacingScale(double v) =>
      _spacingScale = v.clamp(minSpacing, maxSpacing);

  void previewPageMargin(double v) =>
      _pageMargin = v.clamp(minPageMargin, maxPageMargin);

  Future<void> setSpacingScale(double v) async {
    previewSpacingScale(v);
    _safeNotify();
    await _save('readerSpacingScale', _spacingScale);
  }

  Future<void> setPageMargin(double v) async {
    previewPageMargin(v);
    _safeNotify();
    await _save('readerPageMargin', _pageMargin);
  }

  Future<void> setNaming(ReaderBookmarkNaming v) async {
    _naming = v;
    _safeNotify();
    await _save('readerNamingMode', v.index);
  }

  Future<void> setBgColor(Color c) async {
    previewBgColor(c);
    _safeNotify();
    await _save('readerBgColor', _bgColorValue);
  }

  /// null 表示按背景亮度自动取色
  Future<void> setTextColor(Color? c) async {
    previewTextColor(c);
    _safeNotify();
    // 与 _save 相同的兜底：插件/存储不可用时异常不应从 onChanged 抛给 UI
    try {
      final prefs = await _preferencesLoader();
      if (c == null) {
        await prefs.remove('readerTextColor');
      } else {
        await prefs.setInt('readerTextColor', _textColorValue!);
      }
    } catch (e) {
      debugPrint('保存阅读文字色失败：$e');
    }
  }

  Future<void> setPageTransition(ReaderPageTransition v) async {
    _pageTransition = v;
    _safeNotify();
    await _save('readerPageTransition', v.index);
  }

  Future<void> setTapTurnEnabled(bool v) async {
    _tapTurnEnabled = v;
    _safeNotify();
    await _save('readerTapTurn', v);
  }

  Future<void> setVolumeTurnEnabled(bool v) async {
    _volumeTurnEnabled = v;
    _safeNotify();
    await _save('readerVolumeTurn', v);
  }

  //壁纸景深/蒙层：拖拽中仅内存值，松手持久化
  void previewBgBlur(double v) => _bgBlur = v.clamp(0, 20);

  void previewBgOverlay(double v) => _bgOverlay = v.clamp(0, 0.8);

  //拖拽中实时刷新阅读器与面板显示，不写偏好设置
  void notifyBgLive() => _safeNotify();

  /// dispose 标记：颜色/间距拖拽的实时回调与异步 loadPreferences 可能在
  /// Provider 释放之后才落地，此时 notifyListeners 会触发
  /// "used after being disposed" 断言
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

  Future<void> setBgBlur(double v) async {
    previewBgBlur(v);
    _safeNotify();
    await _save('readerBgBlur', _bgBlur);
  }

  Future<void> setBgOverlay(double v) async {
    previewBgOverlay(v);
    _safeNotify();
    await _save('readerBgOverlay', _bgOverlay);
  }

  Future<void> setRememberedMarkIcon(bool v) async {
    _rememberedMarkIcon = v;
    _safeNotify();
    await _save('readerMarkIcon', v);
  }

  Future<void> setRememberedMarkRow(bool v) async {
    _rememberedMarkRow = v;
    _safeNotify();
    await _save('readerMarkRow', v);
  }

  Future<void> setRememberedMarkWord(bool v) async {
    _rememberedMarkWord = v;
    _safeNotify();
    await _save('readerMarkWord', v);
  }

  Future<void> setMarkColorIndex(int v) async {
    _markColorIndex = v.clamp(0, markColors.length - 1);
    _safeNotify();
    await _save('readerMarkColor', _markColorIndex);
  }

  Future<void> setShowFavoriteStar(bool v) async {
    _showFavoriteStar = v;
    _safeNotify();
    await _save('readerFavoriteStar', v);
  }

  Future<void> setBgImage(String? path) async {
    _bgImagePath = path;
    _safeNotify();
    // 与 _save 相同的兜底：存储不可用时异常不应从 onChanged 抛给 UI
    try {
      final prefs = await _preferencesLoader();
      if (path == null) {
        await prefs.remove('readerBgImage');
      } else {
        await prefs.setString('readerBgImage', path);
      }
    } catch (e) {
      debugPrint('保存阅读壁纸路径失败：$e');
    }
  }

  Future<void> _save(String key, dynamic value) async {
    try {
      final prefs = await _preferencesLoader();
      if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      }
    } catch (e) {
      debugPrint('保存阅读设置失败：$e');
    }
  }
}

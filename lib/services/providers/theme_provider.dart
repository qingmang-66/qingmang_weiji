import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/platform_info.dart';

/// 主题和语言状态管理
class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isEnglishLocale = false;
  SplashAnimationSpeed _splashAnimationSpeed = SplashAnimationSpeed.comfortable;
  NavPosition _navPosition = NavPosition.bottom;
  AppStyle _appStyle = AppStyle.fluid;

  /// 循环动效（背景光斑漂移、按钮/卡片 shimmer）开关。
  ///
  /// 默认值按平台区分：桌面端常插电，循环动效默认开；Android 由电池供电，
  /// 玻璃模式下光斑漂移会持续弄脏 backdrop 触发全屏重模糊，默认关更稳妥，
  /// 想要观感的用户仍可在「设置 → 外观 → 循环动效」里打开
  /// （系统「减弱动态效果」始终优先）。运行期真值在 loadPreferences 里取。
  bool _loopEffectsEnabled = !isMobilePlatform;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  ThemeMode get themeMode => _themeMode;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  bool get isEnglishLocale => _isEnglishLocale;
  SplashAnimationSpeed get splashAnimationSpeed => _splashAnimationSpeed;
  NavPosition get navPosition => _navPosition;
  AppStyle get appStyle => _appStyle;
  bool get isLiquidGlass => _appStyle == AppStyle.liquidGlass;
  bool get loopEffectsEnabled => _loopEffectsEnabled;

  /// 开启动画时长（毫秒）
  int get splashAnimationDurationMs {
    switch (_splashAnimationSpeed) {
      case SplashAnimationSpeed.fast:
        return 1000;
      case SplashAnimationSpeed.comfortable:
        return 2000;
      case SplashAnimationSpeed.slow:
        return 3000;
    }
  }

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString('themeMode');
      final legacyIsDarkMode = prefs.getBool('isDarkMode');
      _themeMode = _parseThemeMode(savedThemeMode, legacyIsDarkMode);
      _isEnglishLocale = prefs.getBool('isEnglishLocale') ?? false;
      final speedIndex = prefs.getInt('splashAnimationSpeed');
      if (speedIndex != null &&
          speedIndex >= 0 &&
          speedIndex < SplashAnimationSpeed.values.length) {
        _splashAnimationSpeed = SplashAnimationSpeed.values[speedIndex];
      }
      final navIndex = prefs.getInt('navPosition');
      if (navIndex != null &&
          navIndex >= 0 &&
          navIndex < NavPosition.values.length) {
        _navPosition = NavPosition.values[navIndex];
      }
      // 平台钳制：侧栏导航只在桌面（Windows）可用。跨端恢复备份/prefs 迁移
      // 后可能带着 right/left 落到 Android，表现为"移动端出现侧栏"，
      // 且设置页在移动端只渲染底部/侧栏两段中的底部，right 找不到对应段
      // 会让分段控件高亮错位且无法改回
      if (!isDesktopPlatform && _navPosition != NavPosition.bottom) {
        _navPosition = NavPosition.bottom;
      }
      _appStyle = _parseAppStyle(prefs.getString('appStyle'));
      //没存过时按平台取默认（桌面开/移动关），老用户已保存的偏好继续生效
      _loopEffectsEnabled = prefs.getBool('loopEffects') ?? !isMobilePlatform;
      _safeNotify();
    } catch (e) {
      debugPrint('加载主题偏好失败：$e');
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    //先通知 UI 再落盘：SharedPreferences 写盘是异步 IO，
    //若先 await 再 notify，主题切换/分段选中动画要等写盘完成才开始，手感明显迟滞
    _safeNotify();
    await _savePreference('themeMode', value.name);
  }

  Future<void> setDarkMode(bool value) async {
    await setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  /// 设置语言（true=英文，false=中文）
  Future<void> setEnglishLocale(bool value) async {
    if (_isEnglishLocale == value) return;
    _isEnglishLocale = value;
    _safeNotify();
    await _savePreference('isEnglishLocale', value);
  }

  /// 设置开启动画速度
  Future<void> setSplashAnimationSpeed(SplashAnimationSpeed value) async {
    if (_splashAnimationSpeed == value) return;
    _splashAnimationSpeed = value;
    _safeNotify();
    await _savePreference('splashAnimationSpeed', value.index);
  }

  Future<void> setNavPosition(NavPosition value) async {
    //非桌面端只允许底部导航：跨端备份恢复/外部调用兜底，避免移动端出现侧栏
    if (!isDesktopPlatform) value = NavPosition.bottom;
    if (_navPosition == value) return;
    _navPosition = value;
    _safeNotify();
    await _savePreference('navPosition', value.index);
  }

  /// 设置界面风格（流体渐变 / 液态玻璃）
  Future<void> setAppStyle(AppStyle value) async {
    if (_appStyle == value) return;
    _appStyle = value;
    _safeNotify();
    await _savePreference('appStyle', value.name);
  }

  /// 设置循环动效开关
  Future<void> setLoopEffectsEnabled(bool value) async {
    if (_loopEffectsEnabled == value) return;
    _loopEffectsEnabled = value;
    _safeNotify();
    await _savePreference('loopEffects', value);
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// dispose 标记：异步 loadPreferences 与拖拽实时回调可能在页面销毁后
  /// 才落地，此时 notifyListeners 会触发 "used after being disposed" 断言
  bool _disposed = false;

  void _safeNotify() {
    if (_disposed) return;
    super.notifyListeners();
  }

  ThemeMode _parseThemeMode(String? savedThemeMode, bool? legacyIsDarkMode) {
    switch (savedThemeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
    }
    return legacyIsDarkMode == true ? ThemeMode.dark : ThemeMode.light;
  }

  AppStyle _parseAppStyle(String? saved) {
    return AppStyle.values.firstWhere(
      (s) => s.name == saved,
      orElse: () => AppStyle.fluid,
    );
  }

  Future<void> _savePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      }
    } catch (e) {
      debugPrint('保存主题偏好失败：$e');
    }
  }
}

/// 开启动画速度
enum SplashAnimationSpeed { fast, comfortable, slow }

/// 导航栏位置
///
/// 按索引持久化，新增取值只能追加在末尾，避免打乱老用户的已存偏好。
enum NavPosition {
  bottom,
  left,

  /// 仅供 Windows 桌面端使用
  right,
}

/// 界面风格
enum AppStyle {
  /// 现有流体渐变风格
  fluid,

  /// 液态玻璃风格（参照 iOS 26 / 澎湃 OS 4 / ColorOS 16 / 鸿蒙 7）
  liquidGlass,
}

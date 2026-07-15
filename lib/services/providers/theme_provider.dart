import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题和语言状态管理
class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isEnglishLocale = false;
  SplashAnimationSpeed _splashAnimationSpeed = SplashAnimationSpeed.comfortable;
  NavPosition _navPosition = NavPosition.bottom;

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
      notifyListeners();
    } catch (e) {
      debugPrint('加载主题偏好失败：$e');
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    await _savePreference('themeMode', value.name);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    await setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  /// 设置语言（true=英文，false=中文）
  Future<void> setEnglishLocale(bool value) async {
    if (_isEnglishLocale == value) return;
    _isEnglishLocale = value;
    await _savePreference('isEnglishLocale', value);
    notifyListeners();
  }

  /// 设置开启动画速度
  Future<void> setSplashAnimationSpeed(SplashAnimationSpeed value) async {
    if (_splashAnimationSpeed == value) return;
    _splashAnimationSpeed = value;
    await _savePreference('splashAnimationSpeed', value.index);
    notifyListeners();
  }

  Future<void> setNavPosition(NavPosition value) async {
    if (_navPosition == value) return;
    _navPosition = value;
    await _savePreference('navPosition', value.index);
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
enum NavPosition { bottom, left }

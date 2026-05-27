import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题和语言状态管理
class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isEnglishLocale = false;

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

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString('themeMode');
      final legacyIsDarkMode = prefs.getBool('isDarkMode');
      _themeMode = _parseThemeMode(savedThemeMode, legacyIsDarkMode);
      _isEnglishLocale = prefs.getBool('isEnglishLocale') ?? false;
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
      }
    } catch (e) {
      debugPrint('保存主题偏好失败：$e');
    }
  }
}

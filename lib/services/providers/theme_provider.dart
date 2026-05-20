import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/translations.dart';

/// 主题和语言状态管理
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isEnglishLocale = false;

  bool get isDarkMode => _isDarkMode;
  bool get isEnglishLocale => _isEnglishLocale;

  /// 初始化加载偏好设置
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _isEnglishLocale = prefs.getBool('isEnglishLocale') ?? false;
      Translations.setLocale(_isEnglishLocale);
      notifyListeners();
    } catch (e) {
      debugPrint('加载主题偏好失败：$e');
    }
  }

  /// 设置深色模式
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    await _savePreference('isDarkMode', value);
    notifyListeners();
  }

  /// 设置语言
  Future<void> setEnglishLocale(bool value) async {
    if (_isEnglishLocale == value) return;
    _isEnglishLocale = value;
    Translations.setLocale(value);
    await _savePreference('isEnglishLocale', value);
    notifyListeners();
  }

  Future<void> _savePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      }
    } catch (e) {
      debugPrint('保存主题偏好失败：$e');
    }
  }
}

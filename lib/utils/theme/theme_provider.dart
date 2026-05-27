import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design_tokens.dart';

/// 主题提供者 - 管理玻璃拟态和圆角设置
class GlassThemeProvider extends ChangeNotifier {
  static const String _glassEffectKey = 'glassEffectEnabled';
  static const String _borderRadiusStyleKey = 'borderRadiusStyle';
  static const String _borderRadiusPercentKey = 'borderRadiusPercent';

  bool _glassEffectEnabled = true;
  String _borderRadiusStyle = 'rounded'; // 'rounded' or 'sharp'
  double _borderRadiusPercent = 1.0; // 0.0 to 1.0

  bool get glassEffectEnabled => _glassEffectEnabled;
  String get borderRadiusStyle => _borderRadiusStyle;
  double get borderRadiusPercent => _borderRadiusPercent;

  GlassThemeProvider() {
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _glassEffectEnabled = prefs.getBool(_glassEffectKey) ?? true;
    _borderRadiusStyle = prefs.getString(_borderRadiusStyleKey) ?? 'rounded';
    _borderRadiusPercent = prefs.getDouble(_borderRadiusPercentKey) ?? 1.0;
    notifyListeners();
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glassEffectKey, _glassEffectEnabled);
    await prefs.setString(_borderRadiusStyleKey, _borderRadiusStyle);
    await prefs.setDouble(_borderRadiusPercentKey, _borderRadiusPercent);
  }

  /// 设置玻璃效果开关
  Future<void> setGlassEffectEnabled(bool enabled) async {
    _glassEffectEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置圆角风格
  Future<void> setBorderRadiusStyle(String style) async {
    _borderRadiusStyle = style;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置圆角程度
  Future<void> setBorderRadiusPercent(double percent) async {
    _borderRadiusPercent = percent.clamp(0.0, 1.0);
    await _saveSettings();
    notifyListeners();
  }

  /// 获取当前圆角值
  double getCurrentBorderRadius(double maxRadius) {
    if (_borderRadiusStyle == 'sharp') {
      return 0.0;
    }
    return maxRadius * _borderRadiusPercent;
  }

  /// 获取卡片圆角
  double get cardBorderRadius =>
      getCurrentBorderRadius(DesignTokens.cardBorderRadius);

  /// 获取按钮圆角
  double get buttonBorderRadius =>
      getCurrentBorderRadius(DesignTokens.buttonBorderRadius);

  /// 获取图标圆角
  double get iconBorderRadius =>
      getCurrentBorderRadius(DesignTokens.iconBorderRadius);

  /// 获取对话框圆角
  double get dialogBorderRadius =>
      getCurrentBorderRadius(DesignTokens.dialogBorderRadius);

  /// 获取输入框圆角
  double get inputBorderRadius =>
      getCurrentBorderRadius(DesignTokens.inputBorderRadius);
}

import 'package:flutter/material.dart';

/// 设计令牌 - 定义全局设计常量
class DesignTokens {
  // 颜色
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color primaryPurple = Color(0xFF9B59B6);
  static const Color backgroundStart = Color(0xFFF5F7FF);
  static const Color backgroundEnd = Color(0xFFF0E6FF);
  static const Color cardBackground = Color(
    0xD9FFFFFF,
  ); // rgba(255, 255, 255, 0.85)
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF86868B);
  static const Color textTertiary = Color(0xFFAEAEB2);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color selectedBackground = Color(
    0x14007AFF,
  ); // rgba(0, 122, 255, 0.08)
  static const Color selectedBorder = Color(0xFF007AFF);
  static const Color selectedShadow = Color(
    0x26007AFF,
  ); // rgba(0, 122, 255, 0.15)

  // 圆角（最大值）
  static const double cardBorderRadius = 20.0;
  static const double buttonBorderRadius = 16.0;
  static const double iconBorderRadius = 14.0;
  static const double dialogBorderRadius = 28.0;
  static const double inputBorderRadius = 16.0;
  static const double chipBorderRadius = 12.0;

  // 阴影
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> selectedCardShadow = [
    BoxShadow(
      color: selectedShadow,
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primaryBlue.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> dialogShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  // 间距
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 6,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const double componentSpacing = 8;
  static const double sectionSpacing = 16;
  static const double largeSpacing = 24;

  // 毛玻璃效果
  static const double glassBlurSigma = 20.0;

  // 分隔线
  static const Color divider = Color(0xFFE5E7EB);
}

import 'package:flutter/material.dart';
import '../utils/theme/design_tokens.dart';

/// 统一 UI 主题配置
///
/// 特性：
/// - 克制、高级的配色方案
/// - 玻璃拟态效果支持
/// - 流体动画参数
/// - 响应式设计
class UITheme {
  // ==================== 颜色定义 ====================

  /// 主强调色 - 柔和蓝紫渐变
  static const List<Color> accentGradient = [
    Color(0xFF6366F1), // 靛蓝
    Color(0xFF8B5CF6), // 紫罗兰
    Color(0xFF6366F1), // 靛蓝（循环）
  ];

  /// 主渐变（别名）
  static const List<Color> primaryGradient = accentGradient;

  /// 次要强调色
  static const List<Color> secondaryGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
    Color(0xFF10B981),
  ];

  /// 卡片渐变
  static const List<Color> cardGradient = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF6366F1),
  ];

  /// 成功色
  static const Color success = Color(0xFF10B981);

  /// 警告色
  static const Color warning = Color(0xFFF59E0B);

  /// 错误色
  static const Color error = Color(0xFFEF4444);

  /// 文字颜色
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  /// 背景色
  static const Color background = Colors.white;
  static const Color surface = Color(0xFFF9FAFB);

  /// 边框色
  static const Color border = Color(0xFFE5E7EB);

  // ==================== 动画参数 ====================

  /// 流体动画持续时间
  static const Duration fluidAnimationDuration = Duration(seconds: 4);

  /// 按钮按压缩放
  static const double buttonPressedScale = 0.96;

  /// 卡片按压缩放
  static const double cardPressedScale = 0.98;

  /// 按压动画持续时间
  static const Duration pressAnimationDuration = Duration(milliseconds: 100);

  /// 水波纹动画持续时间
  static const Duration rippleDuration = Duration(milliseconds: 600);

  /// 水波纹最大半径
  static const double rippleMaxRadius = 60.0;

  /// 按钮弹簧参数
  static const double btnSpringMass = 1.0;
  static const double btnSpringStiffness = 300.0;
  static const double btnSpringDamping = 15.0;

  /// 卡片弹簧参数
  static const double cardSpringMass = 1.0;
  static const double cardSpringStiffness = 200.0;
  static const double cardSpringDamping = 20.0;

  /// 卡片圆角
  static const double cardBorderRadius = 16.0;
  static const double containerBorderRadius = 16.0;

  /// 按钮圆角
  static const double buttonBorderRadius = 12.0;

  // ==================== 阴影定义 ====================

  /// 卡片阴影
  static BoxShadow get cardShadow => BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 10,
    offset: const Offset(0, 2),
  );

  /// 按钮阴影
  static BoxShadow get buttonShadow => BoxShadow(
    color: accentGradient[0].withValues(alpha: 0.3),
    blurRadius: 8,
    offset: const Offset(0, 4),
  );

  /// 对话框阴影
  static List<BoxShadow> get dialogShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  // ==================== 玻璃效果参数 ====================

  /// 玻璃模糊强度
  static const double glassBlurSigma = 10.0;

  /// 玻璃背景透明度
  static const double glassBackgroundOpacity = 0.8;

  // ==================== 按钮样式 ====================

  /// 按钮文字样式
  static const TextStyle buttonStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ==================== 主题数据 ====================

  /// 获取统一主题数据
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: DesignTokens.primaryBlue,
      scaffoldBackgroundColor: DesignTokens.backgroundStart,
      colorScheme: ColorScheme.light(
        primary: DesignTokens.primaryBlue,
        secondary: DesignTokens.primaryPurple,
        surface: DesignTokens.cardBackground,
        error: DesignTokens.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: DesignTokens.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DesignTokens.cardBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: DesignTokens.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.cardBorderRadius),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: DesignTokens.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: DesignTokens.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      iconTheme: IconThemeData(color: DesignTokens.textPrimary, size: 24),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.inputBorderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.inputBorderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.inputBorderRadius),
          borderSide: BorderSide(color: DesignTokens.primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              DesignTokens.buttonBorderRadius,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.primaryBlue,
          side: BorderSide(color: DesignTokens.primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              DesignTokens.buttonBorderRadius,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: DesignTokens.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

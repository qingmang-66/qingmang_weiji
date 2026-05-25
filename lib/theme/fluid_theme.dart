import 'package:flutter/material.dart';

/// 流体渐变主题系统
///
/// 统一的设计令牌和主题配置，支持动态流体渐变效果
/// 基于 design-comparison.html 中的"动态流体渐变"方案
class FluidTheme {
  FluidTheme._();

  // ==================== 流体渐变色板 ====================

  /// 主流体渐变 - 紫蓝粉渐变
  static const List<Color> primaryFluidGradient = [
    Color(0xFFF093FB), // 粉紫
    Color(0xFFF5576C), // 珊瑚红
    Color(0xFF4FACFE), // 天蓝
  ];

  /// 次要流体渐变 - 蓝紫渐变
  static const List<Color> secondaryFluidGradient = [
    Color(0xFF667EEA), // 靛蓝
    Color(0xFF764BA2), // 紫罗兰
  ];

  /// 成功流体渐变 - 绿色渐变
  static const List<Color> successFluidGradient = [
    Color(0xFF10B981), // 翡翠绿
    Color(0xFF34D399), // 浅绿
  ];

  /// 警告流体渐变 - 橙色渐变
  static const List<Color> warningFluidGradient = [
    Color(0xFFF59E0B), // 琥珀
    Color(0xFFFBBF24), // 浅黄
  ];

  /// 错误流体渐变 - 红色渐变
  static const List<Color> errorFluidGradient = [
    Color(0xFFEF4444), // 红色
    Color(0xFFF87171), // 浅红
  ];

  /// 深色背景渐变 - 用于卡片背景
  static const List<Color> darkBackgroundGradient = [
    Color(0xFF0F0C29), // 深紫黑
    Color(0xFF302B63), // 深紫
    Color(0xFF24243E), // 深蓝灰
    Color(0xFF1A1A2E), // 深蓝
  ];

  /// 动态背景渐变 - 用于页面背景（深色主题）
  static const List<Color> dynamicBackgroundGradient = [
    Color(0xFF0a0a0f), // 近黑色
    Color(0xFF1a1a2e), // 深蓝
    Color(0xFF16213e), // 深蓝灰
    Color(0xFF0f3460), // 靛蓝
  ];

  /// 浅色背景渐变 - 用于页面背景（浅色主题）
  static const List<Color> lightBackgroundGradient = [
    Color(0xFFF5F7FF), // 浅紫白
    Color(0xFFE8EDFF), // 浅蓝白
    Color(0xFFF0E6FF), // 浅紫
    Color(0xFFE6F0FF), // 浅蓝
  ];

  // ==================== 静态颜色 ====================

  /// 主强调色
  static const Color accentPrimary = Color(0xFFF093FB);

  /// 次要强调色
  static const Color accentSecondary = Color(0xFF4FACFE);

  /// 深色主题文字颜色
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xB3FFFFFF); // 70% 白色
  static const Color textTertiaryDark = Color(0x80FFFFFF); // 50% 白色

  /// 浅色主题文字颜色
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xB31A1A2E); // 70% 深色
  static const Color textTertiaryLight = Color(0x801A1A2E); // 50% 深色

  /// 默认文字颜色（深色主题）
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x80FFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnLight = Color(0xFF1A1A2E);

  /// 背景色
  static const Color background = Color(0xFF0a0a0f);
  static const Color surface = Color(0x1AFFFFFF); // 10% 白色
  static const Color surfaceElevated = Color(0x33FFFFFF); // 20% 白色

  /// 边框色
  static const Color borderDark = Color(0x26FFFFFF); // 15% 白色
  static const Color borderLight = Color(0x1A000000); // 10% 黑色
  static const Color border = Color(0x26FFFFFF); // 默认深色主题

  /// 状态颜色
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ==================== 动画参数 ====================

  /// 流体渐变动画持续时间
  static const Duration fluidAnimationDuration = Duration(seconds: 15);

  /// 按钮流动动画持续时间
  static const Duration buttonFlowDuration = Duration(seconds: 6);

  /// 卡片Shimmer动画持续时间
  static const Duration shimmerDuration = Duration(seconds: 3);

  /// 标题流动动画持续时间
  static const Duration headerFlowDuration = Duration(seconds: 8);

  /// 文本流动动画持续时间
  static const Duration textFlowDuration = Duration(seconds: 5);

  /// 按压缩放动画持续时间
  static const Duration pressAnimationDuration = Duration(milliseconds: 100);

  /// 弹簧动画参数
  static const double buttonSpringMass = 1.0;
  static const double buttonSpringStiffness = 300.0;
  static const double buttonSpringDamping = 15.0;

  static const double cardSpringMass = 1.0;
  static const double cardSpringStiffness = 200.0;
  static const double cardSpringDamping = 20.0;

  /// 按压缩放比例
  static const double buttonPressedScale = 0.97;
  static const double cardPressedScale = 0.98;

  /// Hover缩放比例
  static const double buttonHoverScale = 1.03;
  static const double cardHoverScale = 1.02;

  // ==================== 圆角 ====================

  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 16.0;
  static const double iconBorderRadius = 14.0;
  static const double dialogBorderRadius = 28.0;
  static const double inputBorderRadius = 16.0;
  static const double chipBorderRadius = 12.0;
  static const double containerBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;

  // ==================== 间距 ====================

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // ==================== 阴影 ====================

  /// 卡片阴影
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// 按钮阴影 - 粉紫色
  static List<BoxShadow> buttonPrimaryShadow = [
    BoxShadow(
      color: const Color(0xFFF093FB).withValues(alpha: 0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// 按钮阴影 - 蓝色
  static List<BoxShadow> buttonSecondaryShadow = [
    BoxShadow(
      color: const Color(0xFF4FACFE).withValues(alpha: 0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// 对话框阴影
  static List<BoxShadow> dialogShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  /// 浮动按钮阴影
  static List<BoxShadow> fabShadow = [
    BoxShadow(
      color: const Color(0xFFF093FB).withValues(alpha: 0.4),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  // ==================== 渐变生成方法 ====================

  /// 生成流动渐变（用于动画背景）
  static LinearGradient createFluidGradient({
    required double animationValue,
    List<Color>? colors,
  }) {
    final gradientColors = colors ?? primaryFluidGradient;
    return LinearGradient(
      begin: Alignment(-1 + animationValue * 2, -1 + animationValue * 2),
      end: Alignment(1 - animationValue * 2, 1 - animationValue * 2),
      colors: gradientColors,
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// 生成按钮渐变
  static LinearGradient createButtonGradient({required double animationValue}) {
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: primaryFluidGradient,
      stops: [0.0, 0.5 + animationValue * 0.5, 1.0],
    );
  }

  /// 生成卡片边框渐变
  static LinearGradient createCardBorderGradient({
    required double animationValue,
  }) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryFluidGradient[0].withValues(alpha: 0.3),
        primaryFluidGradient[2].withValues(alpha: 0.1),
      ],
    );
  }

  // ==================== 动态颜色方法 ====================

  /// 根据深浅色模式返回主要文字颜色
  static Color getTextPrimaryColor(bool isDark) {
    return isDark ? textPrimaryDark : textPrimaryLight;
  }

  /// 根据深浅色模式返回次要文字颜色
  static Color getTextSecondaryColor(bool isDark) {
    return isDark ? textSecondaryDark : textSecondaryLight;
  }

  /// 根据深浅色模式返回第三级文字颜色
  static Color getTextTertiaryColor(bool isDark) {
    return isDark ? textTertiaryDark : textTertiaryLight;
  }

  /// 根据深浅色模式返回边框颜色
  static Color getBorderColor(bool isDark) {
    return isDark ? borderDark : borderLight;
  }

  /// 根据深浅色模式返回背景颜色
  static Color getBackgroundColor(bool isDark) {
    return isDark ? background : lightBackgroundGradient.first;
  }

  /// 根据深浅色模式返回表面颜色
  static Color getSurfaceColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.82);
  }

  static Color getElevatedSurfaceColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.94);
  }

  static Color getDialogSurfaceColor(bool isDark) {
    return isDark ? const Color(0xF21A1A2E) : const Color(0xF8FFFFFF);
  }

  static Color getInputFillColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.86);
  }

  static Color getMutedOverlayColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF667EEA).withValues(alpha: 0.08);
  }

  static Color getShimmerColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.05)
        : primaryFluidGradient[0].withValues(alpha: 0.08);
  }

  static List<Color> getSurfaceGradientColors(bool isDark) {
    return isDark
        ? [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.025),
          ]
        : [
            Colors.white.withValues(alpha: 0.96),
            const Color(0xFFF4F7FF).withValues(alpha: 0.82),
          ];
  }

  static List<Color> getBorderGradientColors(bool isDark, List<Color> colors) {
    return [
      colors.first.withValues(alpha: isDark ? 0.32 : 0.24),
      colors.last.withValues(alpha: isDark ? 0.12 : 0.16),
    ];
  }

  static TextStyle textStyle(
    bool isDark, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color ?? getTextPrimaryColor(isDark),
    );
  }

  // ==================== 样式方法 ====================

  /// 获取标题文本样式（深色主题）
  static TextStyle get headingLarge => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get headingMedium => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get headingSmall => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  /// 获取正文文本样式（深色主题）
  static TextStyle get bodyLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static TextStyle get bodySmall => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.5,
  );

  /// 获取标签文本样式
  static TextStyle get labelLarge => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get labelMedium => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  /// 获取数字文本样式
  static TextStyle get numberLarge => const TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -1,
  );

  static TextStyle get numberMedium => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get numberSmall => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // ==================== 装饰方法 ====================

  /// 创建流体卡片装饰
  static BoxDecoration fluidCardDecoration({
    List<Color>? borderColors,
    double borderRadius = cardBorderRadius,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      boxShadow: cardShadow,
    );
  }

  /// 创建深色卡片装饰
  static BoxDecoration darkCardDecoration({
    double borderRadius = cardBorderRadius,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.03),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
    );
  }

  /// 创建图标容器装饰
  static BoxDecoration iconContainerDecoration({
    required Color color,
    double borderRadius = smallBorderRadius,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  // ==================== 动画曲线 ====================

  /// 弹簧动画曲线
  static const Curve springCurve = Curves.easeOutBack;

  /// 平滑动画曲线
  static const Curve smoothCurve = Curves.easeOutCubic;

  /// 弹性动画曲线
  static const Curve elasticCurve = Curves.elasticOut;
}

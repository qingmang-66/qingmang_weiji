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

  /// 二级文字（深色）
  ///
  /// 原为 70% 白，在半透明玻璃上观感发灰，提到 80%（深色玻璃上约 11:1）。
  static const Color textSecondaryDark = Color(0xCCFFFFFF); // 80% 白色
  /// 三级文字（深色）
  ///
  /// 原为 50% 白，在半透明玻璃上小字号发灰、观感吃力。
  /// 提到 70% 后约 9:1，仍与二级文字（80% 白）保留层级差。
  static const Color textTertiaryDark = Color(0xB3FFFFFF); // 70% 白色

  /// 浅色主题文字颜色
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xB31A1A2E); // 70% 深色
  /// 三级文字（浅色）
  ///
  /// 原为 50% 深色，在 #F5F7FF 背景上仅 3.18:1，不满足 WCAG AA 4.5:1。
  /// 改为实色 #6B7280，对比度 4.52:1，层级感与二级文字仍可区分。
  static const Color textTertiaryLight = Color(0xFF6B7280);

  /// 默认文字颜色（深色主题，与 textXxxDark 保持同步）
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xCCFFFFFF);
  static const Color textTertiary = Color(0xB3FFFFFF);
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
  ///
  /// 用于填充、图标、图表等**图形**场景。作为文字前景请参考
  /// [FluidStatusColors] 中的 xxxText 变体，浅色下原色对比度不足 3:1。
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// 收藏星标色（图形场景：图标填充）
  ///
  /// 与 [warning] 同值但语义独立：收藏星标会同时出现在学习页顶栏、
  /// 阅读器词条行尾、首页「词集」入口三处，统一从这里取色，
  /// 避免各处各写一种金色。
  static const Color favorite = Color(0xFFF59E0B);

  // ==================== 可读性修正色 ====================
  //
  // 主色 #F093FB 相对亮度高达 0.46：
  //   · 作为背景时，白字对比度仅 2.04:1
  //   · 作为前景时，在 #F5F7FF 上对比度仅 1.91:1
  // 两者都不满足 WCAG AA 4.5:1。
  // 下面这些令牌在**不改变品牌色相、不改变渐变本身**的前提下修正用法。

  /// 亮渐变之上的前景色（按钮文字 / 图标）
  ///
  /// 用于 #F093FB→#4FACFE 这类高明度渐变之上，对比度 8.34:1。
  static const Color onGradientForeground = Color(0xFF1A1A2E);

  /// 亮渐变之上的禁用态前景色，对比度约 6.4:1
  static const Color onGradientForegroundMuted = Color(0xCC1A1A2E);

  /// 可读版主色（浅色）
  ///
  /// 供「主色作为文字/图标前景」的场景使用：文字按钮、链接、小面积强调。
  /// 在 #F5F7FF 上对比度 5.91:1，色相仍为粉紫，与主色同族。
  static const Color primaryAccessibleLight = Color(0xFFA21CAF);

  /// 可读版主色：深色下原主色对比度已达 9.25:1，直接沿用
  static Color primaryAccessible(bool isDark) =>
      isDark ? primaryFluidGradient[0] : primaryAccessibleLight;

  /// 可读版次色（浅色）：#4FACFE 在浅色背景上仅 2.40:1，压暗至 #0369A1（5.93:1）
  static const Color secondaryAccessibleLight = Color(0xFF0369A1);

  static Color secondaryAccessible(bool isDark) =>
      isDark ? primaryFluidGradient[2] : secondaryAccessibleLight;

  /// 标题/数字等「渐变文字」专用渐变
  ///
  /// 原渐变 #F093FB→#4FACFE 明度过高，作为**文字**时在浅色玻璃/背景上
  /// 仅约 1.9:1，小号字几乎不可读。浅色下改用同色相压暗变体（≥5.9:1）；
  /// 深色下对比度充足（≥9.2:1），沿用原渐变，观感保持不变。
  /// 图形填充（图标块、图表色块）请继续用 [primaryFluidGradient]。
  static List<Color> textGradient(bool isDark) => isDark
      ? primaryFluidGradient
      : const [primaryAccessibleLight, secondaryAccessibleLight];

  // ==================== 动画参数 ====================

  /// 流体渐变动画持续时间
  ///
  /// 原为 15s。视觉噪音偏高、且长时间占用合成器，放慢到 40s 后
  /// 仍保留"流动"感但不再抢注意力（移动端由 PlatformAdapt 直接关闭）。
  static const Duration fluidAnimationDuration = Duration(seconds: 40);

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

  /// 4dp 网格补充档：8 与 16 之间，代码中最常用的中间间距
  static const double spacing12 = 12.0;
  static const double spacingMd = 16.0;

  /// 4dp 网格补充档：16 与 24 之间
  static const double spacing20 = 20.0;
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

  /// 进度条轨道色
  ///
  /// 液态玻璃浅色下玻璃本体近透明白，黑色实色轨道（10% 黑）铺上去会
  /// 打断背景透射，呈一条横贯卡片的灰带；改用半透明白色亮槽，与玻璃
  /// 顶部高光同一语言。经典风格保留黑色凹槽观感。
  static Color getProgressTrackColor(bool isDark, bool isLiquidGlass) {
    if (isDark) return Colors.white.withValues(alpha: 0.10);
    return isLiquidGlass ? Colors.white.withValues(alpha: 0.45) : borderLight;
  }

  static Color getShimmerColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.05)
        : primaryFluidGradient[0].withValues(alpha: 0.08);
  }

  //卡片表面渐变：该 getter 在各类卡片的每帧构建路径上被调用，
  //缓存成静态实例避免重复分配（调用方只读，不会修改列表）
  static final List<Color> _surfaceGradientDark = [
    Colors.white.withValues(alpha: 0.1),
    Colors.white.withValues(alpha: 0.025),
  ];
  static final List<Color> _surfaceGradientLight = [
    Colors.white.withValues(alpha: 0.96),
    const Color(0xFFF4F7FF).withValues(alpha: 0.82),
  ];

  static List<Color> getSurfaceGradientColors(bool isDark) =>
      isDark ? _surfaceGradientDark : _surfaceGradientLight;

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
      // 正文中的数字也保持等宽圆滑风格
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // ==================== 样式方法 ====================

  /// 获取标题文本样式
  static TextStyle headingLarge(bool isDark) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: getTextPrimaryColor(isDark),
    letterSpacing: -0.5,
  );

  static TextStyle headingMedium(bool isDark) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: getTextPrimaryColor(isDark),
    letterSpacing: -0.3,
  );

  static TextStyle headingSmall(bool isDark) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: getTextPrimaryColor(isDark),
  );

  /// 获取正文文本样式
  static TextStyle bodyLarge(bool isDark) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: getTextPrimaryColor(isDark),
    height: 1.5,
  );

  static TextStyle bodyMedium(bool isDark) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: getTextSecondaryColor(isDark),
    height: 1.5,
  );

  static TextStyle bodySmall(bool isDark) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: getTextTertiaryColor(isDark),
    height: 1.5,
  );

  /// 获取标签文本样式
  static TextStyle labelLarge(bool isDark) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: getTextPrimaryColor(isDark),
  );

  static TextStyle labelMedium(bool isDark) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: getTextSecondaryColor(isDark),
  );

  /// 圆滑数字文本样式（全应用统一）
  ///
  /// 视觉目标：更柔和、更大、更圆润。
  static TextStyle numberStyle({
    required double fontSize,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
    double height = 1.05,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      // 更宽字距，视觉更圆润舒展
      letterSpacing:
          letterSpacing ??
          (fontSize >= 36
              ? 2.0
              : fontSize >= 24
              ? 1.3
              : 0.8),
      // 等宽数字，滚动/进度更稳
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// 获取数字文本样式
  static TextStyle numberLarge(bool isDark, {Color? color}) => numberStyle(
    fontSize: 48,
    fontWeight: FontWeight.w500,
    color: color ?? getTextPrimaryColor(isDark),
    letterSpacing: 2.2,
  );

  static TextStyle numberMedium(bool isDark, {Color? color}) => numberStyle(
    fontSize: 32,
    fontWeight: FontWeight.w500,
    color: color ?? getTextPrimaryColor(isDark),
    letterSpacing: 1.5,
  );

  static TextStyle numberSmall(bool isDark, {Color? color}) => numberStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: color ?? getTextPrimaryColor(isDark),
    letterSpacing: 1.0,
  );

  // ==================== 启动页专用色彩 ====================

  /// 启动页背景渐变起始色
  ///
  /// 原为浅绿系（#F8FBF7），与 App 主色（粉紫）断层，启动→主页有明显跳变。
  /// 改为主色的极浅变体后过渡连续，文字色也统一回 App 配色。
  static const Color splashBackgroundStart = Color(0xFFFDF8FF);

  /// 启动页背景渐变中间色
  static const Color splashBackgroundMiddle = Color(0xFFF8F2FE);

  /// 启动页背景渐变结束色
  static const Color splashBackgroundEnd = Color(0xFFF3EDFF);

  /// 启动页正文文字颜色
  static const Color splashTextColor = Color(0xFF1A1A2E);

  /// 启动页次要文字颜色
  static const Color splashMutedTextColor = Color(0xFF6B7280);

  // ==================== 动画曲线 ====================

  /// 弹簧动画曲线
  static const Curve springCurve = Curves.easeOutBack;

  /// 平滑动画曲线
  static const Curve smoothCurve = Curves.easeOutCubic;

  /// 弹性动画曲线
  static const Curve elasticCurve = Curves.elasticOut;

  // ==================== ThemeData ====================

  /// 浅色主题数据
  static final ThemeData lightThemeData = _buildThemeData(isDark: false);

  /// 深色主题数据
  static final ThemeData darkThemeData = _buildThemeData(isDark: true);

  /// 构建主题数据
  static ThemeData _buildThemeData({required bool isDark}) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final textPrimaryColor = getTextPrimaryColor(isDark);
    final textSecondaryColor = getTextSecondaryColor(isDark);
    final textTertiaryColor = getTextTertiaryColor(isDark);
    final borderColor = getBorderColor(isDark);
    final scaffoldBg = isDark
        ? const Color(0xFF0a0a0f)
        : const Color(0xFFF5F7FF);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.85);
    final inputFill = getInputFillColor(isDark);
    final primaryColor = primaryFluidGradient[0];

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme(
        primary: primaryColor,
        secondary: primaryFluidGradient[2],
        surface: cardBg,
        error: error,
        //主色 #F093FB / 次色 #4FACFE 均为高明度色，白色前景仅 2.04:1 / 2.40:1。
        //改用深色前景后达 8.34:1 / 9.11:1，渐变与色板本身不变。
        onPrimary: onGradientForeground,
        onSecondary: onGradientForeground,
        onSurface: textPrimaryColor,
        onError: Colors.white,
        brightness: brightness,
        onSurfaceVariant: textSecondaryColor,
        outline: borderColor,
        surfaceContainerHighest: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimaryColor),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: textSecondaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: textTertiaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      iconTheme: IconThemeData(color: textPrimaryColor, size: 24),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryAccessible(isDark), width: 2),
        ),
        hintStyle: TextStyle(color: textTertiaryColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onGradientForeground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccessible(isDark),
          side: BorderSide(color: primaryAccessible(isDark)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccessible(isDark),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      // 分段控件在 360dp 窄屏 + 中文下总宽会超出卡片（内容被 ClipRRect 裁掉）：
      // 去掉选中勾选图标、收紧内边距并降一档字号，保证各段文字完整可见
      segmentedButtonTheme: SegmentedButtonThemeData(
        selectedIcon: const SizedBox.shrink(),
        style: SegmentedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: getDialogSurfaceColor(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogBorderRadius),
        ),
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: textSecondaryColor, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return isDark
              ? Colors.white.withValues(alpha: 0.6)
              : const Color(0xFFE0E0E0);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.5);
          }
          return isDark
              ? Colors.white.withValues(alpha: 0.2)
              : const Color(0xFFE0E0E0);
        }),
      ),
      // Material 默认的 Checkbox 在按压/悬停时会在方框上盖一块蓝色
      // （overlay 是方形的，水波是圆的），勾选瞬间看起来像"蓝色方块闪一下"，
      // Windows 与 Android 都能复现，与流体/玻璃风格也不搭，这里统一关掉。
      checkboxTheme: const CheckboxThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashRadius: 0,
      ),
      // 图标按钮的 overlay 覆盖 hover/focus/pressed 三种状态：
      // 设备上只要接过鼠标（或系统判定为"传统输入"），任一图标按钮一旦获得焦点，
      // 就会永久挂着一圈 10% 灰底圆（用户反馈"某个按钮一直被聚焦"）。
      // 这里只保留按下时的品牌色水波，hover/focus 返回全透明。
      // 注意不能返回 null —— InkResponse 会退回到 ThemeData.highlightColor，
      // 灰底依旧会出现。
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primaryColor.withValues(alpha: isDark ? 0.20 : 0.14);
            }
            return Colors.transparent;
          }),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: getDialogSurfaceColor(isDark),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(dialogBorderRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : const Color(0xFF1A1A2E),
        contentTextStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        selectedColor: primaryColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: textPrimaryColor, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(chipBorderRadius),
        ),
        side: BorderSide.none,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: getDialogSurfaceColor(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
        ),
        textStyle: TextStyle(color: textPrimaryColor, fontSize: 14),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(smallBorderRadius),
        ),
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
      //状态色此前只能以 FluidTheme 静态常量散落调用，Material 原生组件取不到。
      //注入 ThemeExtension 后可通过 Theme.of(context).extension<FluidStatusColors>() 统一取用。
      extensions: [FluidStatusColors.of(isDark)],
    );
  }

  // ==================== 液态玻璃主题覆盖 ====================

  /// 液态玻璃主题：所有 Material 表面透明化，让全局氛围光斑透出，
  /// 组件玻璃质感由 GlassSurface 提供。经典主题经 copyWith 覆盖而来。
  static ThemeData glassThemeData({required bool isDark}) {
    final base = isDark ? darkThemeData : lightThemeData;
    final textPrimaryColor = getTextPrimaryColor(isDark);
    final textSecondaryColor = getTextSecondaryColor(isDark);
    final textTertiaryColor = getTextTertiaryColor(isDark);
    final primaryColor = primaryFluidGradient[0];
    //玻璃上的分隔线：极淡的中性描边
    final hairline = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);

    return base.copyWith(
      //所有页面透明：opaque 路由转场结束后下层不再渲染，
      //transparent 页面透出 builder 层 GlassAmbientScope 全局光斑供玻璃折射
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: textPrimaryColor),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        //裸 AlertDialog 用半透明磨砂底保证可读性；FluidDialog 显式传 transparent 走 GlassSurface
        backgroundColor: isDark
            ? const Color(0xE620202A)
            : const Color(0xF0FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: isDark
            ? const Color(0xEB20202A)
            : const Color(0xF2FFFFFF),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isDark
            ? const Color(0xEB20202A)
            : const Color(0xF2FFFFFF),
        modalBarrierColor: Colors.black.withValues(alpha: 0.25),
        elevation: 0,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        //玻璃上的输入框薄纱对齐导航栏量级（导航栏浅色仅 7% 白）：
        //原 35% 白是一块不透明奶片，与通透玻璃语言相悖；降到 15% 后
        //背景折射透上来，字段边界由 hairline 描边与焦点主色边框承担
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        //薄纱对齐导航栏量级：原 45% 白是不透明奶片；
        //降到 15% 后背景折射透上来，边界由 hairline 描边承担
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.15),
        selectedColor: primaryColor.withValues(alpha: 0.28),
        side: BorderSide(color: hairline),
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: null,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: isDark
            ? const Color(0xE620202A)
            : const Color(0xE6262636),
        actionTextColor: primaryColor,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        dividerColor: Colors.transparent,
        labelColor: textPrimaryColor,
        unselectedLabelColor: textTertiaryColor,
        indicatorColor: primaryColor,
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: primaryColor,
        linearTrackColor: hairline,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryColor.withValues(alpha: 0.22),
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        backgroundColor: Colors.transparent,
        indicatorColor: primaryColor.withValues(alpha: 0.22),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        elevation: 4,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textSecondaryColor,
        displayColor: textPrimaryColor,
      ),
    );
  }
}

/// 状态色主题扩展
///
/// Material 的 [ColorScheme] 只提供 error 槽位，success / warning / info 无处安放，
/// 此前只能以 [FluidTheme] 静态常量散落调用。这里通过 ThemeExtension 注入主题，
/// 原生组件与自定义组件都能用同一入口取到。
///
/// 每个状态提供两个变体：
/// * `success` 等 —— **图形**场景（填充、图标、图表色块），沿用品牌原色，观感不变；
/// * `successText` 等 —— **文字**场景，浅色下压暗至 WCAG AA 达标
///   （例如 success 原色 #10B981 在浅色背景上仅 2.39:1，压暗为 #15803D 后达 4.9:1）。
class FluidStatusColors extends ThemeExtension<FluidStatusColors> {
  const FluidStatusColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.successText,
    required this.warningText,
    required this.errorText,
    required this.infoText,
  });

  /// 图形场景：填充 / 图标 / 图表
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// 文字场景：已按深浅背景做过对比度校正
  final Color successText;
  final Color warningText;
  final Color errorText;
  final Color infoText;

  /// 按深浅模式构造状态色
  factory FluidStatusColors.of(bool isDark) => isDark
      ? const FluidStatusColors(
          success: FluidTheme.success,
          warning: FluidTheme.warning,
          error: FluidTheme.error,
          info: FluidTheme.info,
          //深色背景上原色偏暗，文字改用提亮变体
          successText: Color(0xFF4ADE80),
          warningText: Color(0xFFFBBF24),
          errorText: Color(0xFFF87171),
          infoText: Color(0xFF60A5FA),
        )
      : const FluidStatusColors(
          success: FluidTheme.success,
          warning: FluidTheme.warning,
          error: FluidTheme.error,
          info: FluidTheme.info,
          //浅色背景上原色对比度不足，文字改用压暗变体
          successText: Color(0xFF15803D),
          warningText: Color(0xFFB45309),
          errorText: Color(0xFFDC2626),
          infoText: Color(0xFF1D4ED8),
        );

  /// 从当前 Theme 取状态色；未注册 extension 时回退到浅色默认值
  static FluidStatusColors maybeOf(BuildContext context) =>
      Theme.of(context).extension<FluidStatusColors>() ??
      FluidStatusColors.of(false);

  @override
  FluidStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? successText,
    Color? warningText,
    Color? errorText,
    Color? infoText,
  }) {
    return FluidStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      successText: successText ?? this.successText,
      warningText: warningText ?? this.warningText,
      errorText: errorText ?? this.errorText,
      infoText: infoText ?? this.infoText,
    );
  }

  @override
  FluidStatusColors lerp(ThemeExtension<FluidStatusColors>? other, double t) {
    if (other is! FluidStatusColors) return this;
    return FluidStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
    );
  }
}

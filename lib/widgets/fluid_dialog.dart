import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';

/// 流体对话框组件
///
/// 特性：
/// - 支持深浅色主题
/// - 弹簧物理弹出动画
/// - 流体渐变边框
/// - Shimmer光泽效果
class FluidDialog extends StatefulWidget {
  final Widget content;
  final String? title;
  final List<Widget>? actions;
  final bool barrierDismissible;
  final double? width;
  final double? maxWidth;

  /// 内容区是否可滚动；滚轮选择器等嵌套滚动场景应关闭
  final bool scrollable;

  const FluidDialog({
    super.key,
    required this.content,
    this.title,
    this.actions,
    this.barrierDismissible = true,
    this.width,
    this.maxWidth,
    this.scrollable = true,
  });

  @override
  State<FluidDialog> createState() => _FluidDialogState();
}

class _FluidDialogState extends State<FluidDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _scaleController.forward();

    _shimmerController = AnimationController(
      duration: FluidTheme.shimmerDuration,
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_shimmerController);

    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isMobile = screenWidth < 600;
    final dialogMaxWidth =
        widget.maxWidth ??
        (widget.width ?? (isMobile ? screenWidth * 0.92 : 480.0));
    final maxContentHeight = screenHeight * (isMobile ? 0.68 : 0.74);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 16,
        vertical: isMobile ? 24 : 16,
      ),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                FluidTheme.dialogBorderRadius,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FluidTheme.primaryFluidGradient[0].withValues(
                    alpha: isDark ? 0.3 : 0.15,
                  ),
                  FluidTheme.primaryFluidGradient[2].withValues(
                    alpha: isDark ? 0.1 : 0.05,
                  ),
                ],
              ),
              boxShadow: FluidTheme.dialogShadow,
            ),
            child: Container(
              margin: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  FluidTheme.dialogBorderRadius - 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: FluidTheme.getSurfaceGradientColors(isDark),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  FluidTheme.dialogBorderRadius - 1.5,
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.title != null)
                          _buildTitle(widget.title!, isDark),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxContentHeight,
                            ),
                            child: widget.scrollable
                                ? SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      16,
                                      24,
                                      24,
                                    ),
                                    child: DefaultTextStyle(
                                      style: FluidTheme.textStyle(
                                        isDark,
                                        color: FluidTheme.getTextPrimaryColor(
                                          isDark,
                                        ),
                                      ),
                                      child: widget.content,
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      16,
                                      24,
                                      24,
                                    ),
                                    child: DefaultTextStyle(
                                      style: FluidTheme.textStyle(
                                        isDark,
                                        color: FluidTheme.getTextPrimaryColor(
                                          isDark,
                                        ),
                                      ),
                                      child: widget.content,
                                    ),
                                  ),
                          ),
                        ),
                        if (widget.actions != null &&
                            widget.actions!.isNotEmpty)
                          _buildActions(widget.actions!, isDark),
                      ],
                    ),
                    if (isDark) _buildShimmerEffect(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title, bool isDark) {
    final textColor = FluidTheme.getTextPrimaryColor(isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: isDark
          ? AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment(-1 + _shimmerAnimation.value * 2, 0),
                      end: Alignment(1 + _shimmerAnimation.value * 2, 0),
                      colors: FluidTheme.primaryFluidGradient,
                    ).createShader(bounds);
                  },
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            )
          : Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
    );
  }

  Widget _buildActions(List<Widget> actions, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        color: FluidTheme.getMutedOverlayColor(isDark),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(left: 12),
                child: action,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: Transform.translate(
            offset: Offset(
              MediaQuery.of(context).size.width *
                  (_shimmerAnimation.value - 0.5),
              0,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    FluidTheme.getShimmerColor(true),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 显示流体对话框的辅助函数
Future<T?> showFluidDialog<T>({
  required BuildContext context,
  required Widget content,
  String? title,
  List<Widget>? actions,
  bool barrierDismissible = true,
  double? width,
  double? maxWidth,
  bool scrollable = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => FluidDialog(
      content: content,
      title: title,
      actions: actions,
      barrierDismissible: barrierDismissible,
      width: width,
      maxWidth: maxWidth,
      scrollable: scrollable,
    ),
  );
}

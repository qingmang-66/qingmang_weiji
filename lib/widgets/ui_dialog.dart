import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme/theme_provider.dart';
import '../utils/theme/design_tokens.dart';

/// 统一对话框组件
///
/// 特性：
/// - 玻璃拟态效果（可选）
/// - 弹簧物理弹出动画
/// - 响应式设计
/// - 圆角设计
/// - 可配置 barrierDismissible
class UIDialog extends StatefulWidget {
  final Widget content;
  final String? title;
  final List<Widget>? actions;
  final bool barrierDismissible;
  final double? width;
  final double? maxWidth;
  final bool enableGlassEffect;
  final bool enableAnimation;

  const UIDialog({
    super.key,
    required this.content,
    this.title,
    this.actions,
    this.barrierDismissible = true,
    this.width,
    this.maxWidth,
    this.enableGlassEffect = true,
    this.enableAnimation = true,
  });

  @override
  State<UIDialog> createState() => _UIDialogState();
}

class _UIDialogState extends State<UIDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 弹簧缩放动画
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // 启动动画
    if (widget.enableAnimation) {
      _scaleController.forward();
    } else {
      _scaleController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final borderRadius = themeProvider.dialogBorderRadius;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final dialogMaxWidth = widget.maxWidth ??
        (widget.width ?? (isMobile ? screenWidth * 0.92 : 480.0));
    final shouldUseGlass =
        widget.enableGlassEffect && themeProvider.glassEffectEnabled;

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
              color: shouldUseGlass
                  ? DesignTokens.cardBackground.withValues(alpha: 0.9)
                  : DesignTokens.cardBackground,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: DesignTokens.dialogShadow,
            ),
            child: shouldUseGlass
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: DesignTokens.glassBlurSigma,
                        sigmaY: DesignTokens.glassBlurSigma,
                      ),
                      child: _buildDialogContent(context, borderRadius),
                    ),
                  )
                : _buildDialogContent(context, borderRadius),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogContent(BuildContext context, double borderRadius) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null)
          Container(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: widget.content,
        ),
        if (widget.actions != null && widget.actions!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: widget.actions!,
            ),
          ),
      ],
    );
  }
}

/// 显示统一对话框
Future<T?> showUIDialog<T>({
  required BuildContext context,
  String? title,
  required Widget content,
  List<Widget>? actions,
  Color? barrierColor,
  bool barrierDismissible = true,
  double? width,
  double? maxWidth,
  bool enableGlassEffect = true,
  bool enableAnimation = true,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.5),
    barrierDismissible: barrierDismissible,
    builder: (context) => UIDialog(
      title: title,
      content: content,
      actions: actions,
      width: width,
      maxWidth: maxWidth,
      enableGlassEffect: enableGlassEffect,
      enableAnimation: enableAnimation,
    ),
  );
}

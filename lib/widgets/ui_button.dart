import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme/theme_provider.dart';
import '../utils/theme/design_tokens.dart';

/// 统一按钮组件
///
/// 特性：
/// - 渐变背景
/// - 支持图标
/// - 支持禁用状态
/// - 响应式设计
/// - 点击动画
class UIButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double fontSize;
  final bool isEnabled;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;
  final double? height;
  final double? width;
  final bool expanded;
  final TextStyle? textStyle;

  const UIButton({
    super.key,
    required this.text,
    this.onPressed,
    this.colors,
    this.fontSize = 15,
    this.isEnabled = true,
    this.padding,
    this.icon,
    this.height,
    this.width,
    this.expanded = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final borderRadius = themeProvider.buttonBorderRadius;
    final buttonColors =
        colors ?? [DesignTokens.primaryBlue, DesignTokens.primaryPurple];

    final button = Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          width: width,
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: buttonColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: DesignTokens.buttonShadow,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style:
                    textStyle ??
                    TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

/// 图标按钮组件
class UIIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;
  final List<Color>? colors;

  const UIIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 24,
    this.tooltip,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = colors?.first ?? color ?? DesignTokens.textPrimary;
    final backgroundColor =
        (colors?.first ?? color ?? DesignTokens.textTertiary).withValues(
          alpha: 0.1,
        );

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: size),
        ),
      ),
    );
  }
}

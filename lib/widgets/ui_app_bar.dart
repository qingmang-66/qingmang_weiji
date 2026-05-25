import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme/theme_provider.dart';
import '../utils/theme/design_tokens.dart';

/// 统一导航栏组件
///
/// 特性：
/// - 玻璃拟态效果（可选）
/// - 响应式设计
/// - 圆角设计
/// - 支持自定义样式
class UIAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final double? height;
  final BorderRadius? borderRadius;
  final bool enableGlassEffect;

  const UIAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation = 0,
    this.height,
    this.borderRadius,
    this.enableGlassEffect = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height ?? kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(20);
    final shouldUseGlass =
        enableGlassEffect && themeProvider.glassEffectEnabled;

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: AppBar(
          leading: leading,
          title: title != null
              ? DefaultTextStyle(
                  style: TextStyle(
                    fontSize: isWideScreen ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimary,
                  ),
                  child: title!,
                )
              : null,
          actions: actions?.map((action) {
            if (action is IconButton) {
              return Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: DesignTokens.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: action.icon,
                  onPressed: action.onPressed,
                  tooltip: action.tooltip,
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              );
            }
            return action;
          }).toList(),
          centerTitle: centerTitle,
          elevation: elevation,
          backgroundColor: shouldUseGlass
              ? DesignTokens.cardBackground.withValues(alpha: 0.8)
              : DesignTokens.backgroundStart,
          flexibleSpace: shouldUseGlass
              ? ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: DesignTokens.glassBlurSigma,
                      sigmaY: DesignTokens.glassBlurSigma,
                    ),
                    child: Container(color: Colors.transparent),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

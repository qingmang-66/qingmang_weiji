import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme/theme_provider.dart';
import '../utils/theme/design_tokens.dart';

/// 统一卡片组件
///
/// 特性：
/// - 玻璃拟态效果（可选）
/// - 弹簧物理缩放动画（点击反馈）
/// - Hover 状态增强（桌面端）
/// - 选中边框效果
/// - 响应式设计
class UICard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool enableGlassEffect;
  final bool enableAnimation;

  const UICard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.isSelected = false,
    this.onTap,
    this.backgroundColor,
    this.enableGlassEffect = true,
    this.enableAnimation = true,
  });

  @override
  State<UICard> createState() => _UICardState();
}

class _UICardState extends State<UICard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // 弹簧缩放动画
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  /// 处理点击
  void _handleTap() {
    if (widget.onTap != null) {
      if (widget.enableAnimation) {
        _scaleController.forward().then((_) {
          _scaleController.reverse();
          widget.onTap!();
        });
      } else {
        widget.onTap!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final borderRadius = themeProvider.cardBorderRadius;
    final shouldUseGlass =
        widget.enableGlassEffect && themeProvider.glassEffectEnabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isHovered ? 1.01 : _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: widget.margin ?? DesignTokens.cardMargin,
            padding: widget.padding ?? DesignTokens.cardPadding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ??
                  (widget.isSelected
                      ? DesignTokens.selectedBackground
                      : shouldUseGlass
                          ? DesignTokens.cardBackground.withValues(alpha: 0.8)
                          : DesignTokens.cardBackground),
              borderRadius: BorderRadius.circular(borderRadius),
              border: widget.isSelected
                  ? Border.all(
                      color: DesignTokens.selectedBorder,
                      width: 2,
                    )
                  : null,
              boxShadow: widget.isSelected
                  ? DesignTokens.selectedCardShadow
                  : _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : DesignTokens.cardShadow,
            ),
            child: shouldUseGlass
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: DesignTokens.glassBlurSigma,
                        sigmaY: DesignTokens.glassBlurSigma,
                      ),
                      child: widget.child,
                    ),
                  )
                : widget.child,
          ),
        ),
      ),
    );
  }
}

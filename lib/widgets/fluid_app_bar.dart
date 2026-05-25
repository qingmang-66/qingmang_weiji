import 'package:flutter/material.dart';
import '../theme/fluid_theme.dart';

/// 流体导航栏组件
///
/// 特性：
/// - 深色玻璃质感
/// - 渐变标题文字
/// - 流体图标按钮
/// - 支持自定义操作
class FluidAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final double? height;
  final bool automaticallyImplyLeading;

  const FluidAppBar({
    super.key,
    this.title,
    this.titleText,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation = 0,
    this.height,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height ?? kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        child: AppBar(
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          title:
              title ??
              (titleText != null ? _FluidAppBarTitle(title: titleText!) : null),
          actions: actions?.map((action) {
            if (action is IconButton) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: action.icon,
                  onPressed: action.onPressed,
                  tooltip: action.tooltip,
                  iconSize: 22,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              );
            }
            return action;
          }).toList(),
          centerTitle: centerTitle,
          elevation: elevation,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

/// 流体导航栏标题组件
///
/// 带有渐变文字效果的标题
class _FluidAppBarTitle extends StatefulWidget {
  final String title;

  const _FluidAppBarTitle({required this.title});

  @override
  State<_FluidAppBarTitle> createState() => _FluidAppBarTitleState();
}

class _FluidAppBarTitleState extends State<_FluidAppBarTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluidTheme.textFlowDuration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + _animation.value * 2, 0),
              end: Alignment(1 + _animation.value * 2, 0),
              colors: FluidTheme.primaryFluidGradient,
            ).createShader(bounds);
          },
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

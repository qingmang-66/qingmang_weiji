import 'package:flutter/material.dart';

/// 带动画的列表项组件
///
/// 为列表项添加进入动画效果，支持多种动画类型
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final AnimationType animationType;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.animationType = AnimationType.slideUp,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedListItemWrapper(
      index: index,
      delay: delay,
      duration: duration,
      animationType: animationType,
      child: child,
    );
  }
}

/// 动画类型枚举
enum AnimationType { slideUp, slideRight, fade, scale, slideUpFade }

class _AnimatedListItemWrapper extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final AnimationType animationType;

  const _AnimatedListItemWrapper({
    required this.child,
    required this.index,
    required this.delay,
    required this.duration,
    required this.animationType,
  });

  @override
  State<_AnimatedListItemWrapper> createState() =>
      _AnimatedListItemWrapperState();
}

class _AnimatedListItemWrapperState extends State<_AnimatedListItemWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // 根据索引延迟启动动画，创建交错效果
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
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
        switch (widget.animationType) {
          case AnimationType.slideUp:
            return _buildSlideUp(child!);
          case AnimationType.slideRight:
            return _buildSlideRight(child!);
          case AnimationType.fade:
            return _buildFade(child!);
          case AnimationType.scale:
            return _buildScale(child!);
          case AnimationType.slideUpFade:
            return _buildSlideUpFade(child!);
        }
      },
      child: widget.child,
    );
  }

  Widget _buildSlideUp(Widget child) {
    final offset = (1.0 - _animation.value) * 30.0;
    return Transform.translate(
      offset: Offset(0, offset),
      child: Opacity(opacity: _animation.value, child: child),
    );
  }

  Widget _buildSlideRight(Widget child) {
    final offset = (1.0 - _animation.value) * -30.0;
    return Transform.translate(
      offset: Offset(offset, 0),
      child: Opacity(opacity: _animation.value, child: child),
    );
  }

  Widget _buildFade(Widget child) {
    return Opacity(opacity: _animation.value, child: child);
  }

  Widget _buildScale(Widget child) {
    final scale = 0.9 + (_animation.value * 0.1);
    return Transform.scale(
      scale: scale,
      child: Opacity(opacity: _animation.value, child: child),
    );
  }

  Widget _buildSlideUpFade(Widget child) {
    final offset = (1.0 - _animation.value) * 20.0;
    return Transform.translate(
      offset: Offset(0, offset),
      child: Opacity(opacity: _animation.value, child: child),
    );
  }
}

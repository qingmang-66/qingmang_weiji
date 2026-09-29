import 'package:flutter/material.dart';
import 'liquid_glass.dart' show LiquidMotion, SpringMotionCurve;

/// 答题卡换题过渡：新题「自下而上推入」，旧题「向上让位」
///
/// 供学习页 `AnimatedSwitcher.transitionBuilder` 使用，五个学习模式共用。
///
/// 相比早期版本的 Y 轴透视翻折 + 水波高光，这里只保留三件事：
/// **位移方向 + 淡入淡出 + 极轻微缩放**。原因是换题动画会在几十秒内被连续
/// 触发几十次，动作幅度越大越容易看出破绽（翻折时的文字变形、水波像闪屏）。
///
/// 手感细节：
/// - 方向语义＝「下一题」意味着内容整体向上推进，所以新题从下方进入、
///   旧题继续向上退出，而不是原地交叉淡入淡出；
/// - 透明度比位移先完成：入场 60% 时就完全不透明，避免文字长时间发虚；
/// - 位移由弹簧采样（[LiquidMotion.cardSwitch]），到位的瞬间有一次回弹，
///   像卡片被推进槽位。弹簧**默认对两种界面风格都生效** ——
///   之前只在液态玻璃下启用，流体渐变风格换题是纯缓动，同一台设备上
///   只因为风格不同就"不 Q 弹"，观感割裂。
class StudyCardTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  /// 位移是否带弹簧回弹（默认开启；置 false 退化为标准减速缓动）
  final bool elastic;

  /// 位移幅度，相对自身高度的比例
  final double distance;

  const StudyCardTransition({
    super.key,
    required this.child,
    required this.animation,
    this.elastic = true,
    this.distance = 0.12,
  });

  static final _spring = SpringMotionCurve(LiquidMotion.cardSwitch);

  @override
  Widget build(BuildContext context) {
    //AnimatedSwitcher：新内容动画 forward(0→1)，旧内容 reverse(1→0)
    final bool outgoing = animation.status == AnimationStatus.reverse;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final input = animation.value.clamp(0.0, 1.0);
        //AnimatedSwitcher 给新内容的动画是 forward(0→1)，给旧内容的 reverse(1→0)，
        //这里统一成「可见度 p」：p=1 完全显示，p=0 完全消失。
        //（此前对旧内容取了 1-raw，旧题透明度反而递增到 1，就成了残留重影。）
        //
        //退场用「加速」曲线：一开场透明度就掉下来。若用减速曲线，旧内容会在开头
        //几乎不动地停在原地，视觉上就是上一题残留。
        //入场用「减速」曲线（玻璃风格再用弹簧采样，到位时有一次很轻的回弹）。
        final double p = outgoing
            ? Curves.easeInCubic.transform(input)
            : elastic
            ? _spring.transform(input)
            : Curves.easeOutCubic.transform(input);

        //新题未就位时在下方（dy 为正），旧题退出时向上让位（dy 为负）
        final dy = outgoing ? (p - 1) * distance * 0.6 : (1 - p) * distance;
        final opacity = outgoing
            ? (p * 1.5).clamp(0.0, 1.0) //旧内容在动画前段就淡尽，避免与新题重影
            : (p * 1.6).clamp(0.0, 1.0); //新内容迅速变实，避免文字发虚
        final scale = (0.97 + 0.03 * p).clamp(0.97, 1.0);

        return FractionalTranslation(
          translation: Offset(0, dy),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

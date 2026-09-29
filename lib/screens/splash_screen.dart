import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_initialization_service.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoSlide;
  late Animation<double> _brandOpacity;
  late Animation<double> _brandSlide;
  late Animation<double> _progress;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentOffset;
  Timer? _finishTimer;
  bool _showSplash = true;
  int _appliedDurationMs = 2000;

  @override
  void initState() {
    super.initState();
    //首帧前取已持久化时长，避免先按默认时长播一帧再重启
    _appliedDurationMs = context
        .read<ThemeProvider>()
        .splashAnimationDurationMs;
    _setupAnimations(_appliedDurationMs);
    _controller.forward();
  }

  void _restartIfNeeded(int durationMs) {
    if (durationMs == _appliedDurationMs || !_showSplash) return;
    _appliedDurationMs = durationMs;
    _controller.dispose();
    _finishTimer?.cancel();
    _setupAnimations(durationMs);
    //必须重建：_setupAnimations 替换了所有 Animation 对象，
    //否则 Widget 树仍监听已 dispose 的旧动画，画面会停在末帧
    setState(() {});
    _controller.forward(from: 0);
  }

  void _setupAnimations(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    _controller = AnimationController(vsync: this, duration: duration);

    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 14),
      TweenSequenceItem(tween: ConstantTween(1), weight: 74),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 12),
    ]).animate(_controller);

    _logoScale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.78, end: 1.04), weight: 14),
        TweenSequenceItem(tween: Tween(begin: 1.04, end: 1), weight: 9),
        TweenSequenceItem(tween: Tween(begin: 1, end: 0.66), weight: 21),
        TweenSequenceItem(tween: ConstantTween(0.66), weight: 56),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _logoSlide = TweenSequence<double>(
      [
        TweenSequenceItem(tween: ConstantTween(82), weight: 23),
        TweenSequenceItem(tween: Tween(begin: 82, end: 0), weight: 21),
        TweenSequenceItem(tween: ConstantTween(0), weight: 56),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _brandOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 38),
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 12),
    ]).animate(_controller);

    _brandSlide = TweenSequence<double>(
      [
        TweenSequenceItem(tween: ConstantTween(8), weight: 38),
        TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 10),
        TweenSequenceItem(tween: ConstantTween(0), weight: 52),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _progress = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 36),
      TweenSequenceItem(tween: ConstantTween(1), weight: 14),
    ]).animate(_controller);

    _contentOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 90),
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 10),
    ]).animate(_controller);

    _contentOffset = TweenSequence<Offset>(
      [
        TweenSequenceItem(
          tween: ConstantTween(const Offset(0, 0.03)),
          weight: 90,
        ),
        TweenSequenceItem(
          tween: Tween(begin: const Offset(0, 0.03), end: Offset.zero),
          weight: 10,
        ),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _finishTimer = Timer(Duration(milliseconds: durationMs + 50), () {
      //开屏结束才允许上下文引导弹出，避免高亮落在被遮盖的位置
      AppInitializationService.notifySplashCompleted();
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = context.select<ThemeProvider, int>(
      (p) => p.splashAnimationDurationMs,
    );
    // Handle animation restart when duration changes (must be in build for context.select)
    if (durationMs != _appliedDurationMs && _showSplash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restartIfNeeded(durationMs);
      });
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        //开屏层是纯装饰 box（DecoratedBox/Positioned/Center），不参与手势
        //命中，点击会一路穿透到下层页面；而下层在开屏期间 opacity 为 0、
        //根本看不见 —— 用户开屏时的催促点击会落在引导页看不见的
        //「下一步/跳过」上，5 页引导被瞬间点完直接进首页。
        //开屏期间整体屏蔽下层，结束后再放行
        IgnorePointer(
          ignoring: _showSplash,
          child: SlideTransition(
            position: _contentOffset,
            child: FadeTransition(
              opacity: _contentOpacity,
              child: widget.child,
            ),
          ),
        ),
        if (_showSplash) const _SplashBackground(),
        if (_showSplash)
          _AnimatedSplashContent(
            logoOpacity: _logoOpacity,
            logoScale: _logoScale,
            logoSlide: _logoSlide,
            brandOpacity: _brandOpacity,
            brandSlide: _brandSlide,
            progress: _progress,
          ),
      ],
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FluidTheme.splashBackgroundStart,
            FluidTheme.splashBackgroundMiddle,
            FluidTheme.splashBackgroundEnd,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 88,
            right: -48,
            child: _SoftCircle(size: 120, opacity: 0.48),
          ),
          Positioned(
            left: -38,
            bottom: 130,
            child: _SoftCircle(size: 94, opacity: 0.45),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _SoftCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AnimatedSplashContent extends StatelessWidget {
  final Animation<double> logoOpacity;
  final Animation<double> logoScale;
  final Animation<double> logoSlide;
  final Animation<double> brandOpacity;
  final Animation<double> brandSlide;
  final Animation<double> progress;

  const _AnimatedSplashContent({
    required this.logoOpacity,
    required this.logoScale,
    required this.logoSlide,
    required this.brandOpacity,
    required this.brandSlide,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final groupScale = (shortestSide / 360).clamp(0.82, 1.08).toDouble();

    return Center(
      child: Transform.scale(
        scale: groupScale,
        child: SizedBox(
          width: 292,
          height: 128,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([
                  logoOpacity,
                  logoScale,
                  logoSlide,
                ]),
                builder: (context, child) {
                  return Positioned(
                    left: 0,
                    top: 0,
                    child: Opacity(
                      opacity: logoOpacity.value,
                      child: Transform.translate(
                        offset: Offset(logoSlide.value, 0),
                        child: Transform.scale(
                          scale: logoScale.value,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: const _SplashLogo(),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([
                  brandOpacity,
                  brandSlide,
                  progress,
                ]),
                // 品牌名 + 副标题是静态子树，作为 child 传入：
                // progress 是持续动画、builder 每帧执行，不提出去就会每帧
                // 重建两个 Text 与两个 SizedBox（动画结束前一次都不需要重建）
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.appName,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        color: FluidTheme.splashTextColor,
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'WORD MEMORY',
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: FluidTheme.splashMutedTextColor,
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                builder: (context, child) {
                  return Positioned(
                    left: 112,
                    top: 31,
                    child: Opacity(
                      opacity: brandOpacity.value,
                      child: Transform.translate(
                        offset: Offset(brandSlide.value, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            child!,
                            const SizedBox(height: 12),
                            _SplashProgress(progress: progress.value),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E467452),
            blurRadius: 54,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Image.asset(
          'assets/images/app_icon_source_760.png',
          // 128dp 显示位，按 3x 密度限制解码尺寸（原图 760px 属多余开销）
          cacheWidth: 384,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _SplashProgress extends StatelessWidget {
  final double progress;

  const _SplashProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      height: 7,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x387EBF8E),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [Color(0xFF3F8F58), Color(0xFF7EBF8E)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

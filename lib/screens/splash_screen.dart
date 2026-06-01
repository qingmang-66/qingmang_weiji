import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoSlide;
  late final Animation<double> _brandOpacity;
  late final Animation<double> _brandSlide;
  late final Animation<double> _progress;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentOffset;
  Timer? _finishTimer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

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

    _controller.forward();
    _finishTimer = Timer(const Duration(milliseconds: 2050), () {
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
    return Stack(
      fit: StackFit.expand,
      children: [
        SlideTransition(
          position: _contentOffset,
          child: FadeTransition(opacity: _contentOpacity, child: widget.child),
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

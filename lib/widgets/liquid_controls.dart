import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/platform_info.dart';
import 'liquid_glass.dart';

/// 液态玻璃通用控件库
///
/// 所有控件均为双风格：液态玻璃模式下水银/果冻/水滴质感 + 物理弹簧，
/// 经典模式下回退为原生 Material/Cupertino 控件，调用点无需自行判风格。

//============================================================================
// 水银勾选框（Gooey Checkbox）
//============================================================================

/// 勾选瞬间水银滴从边缘汇聚填满，带一次挤压超调；取消时水滴反向分离
class LiquidCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final double size;

  ///正圆形态（默认圆角方形）
  final bool circular;

  const LiquidCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.size = 22,
    this.circular = false,
  });

  @override
  State<LiquidCheckbox> createState() => _LiquidCheckboxState();
}

class _LiquidCheckboxState extends State<LiquidCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    //initState 中创建，避免经典模式下 dispose 才惰性触发构造
    _c = AnimationController(vsync: this, value: widget.value ? 1 : 0);
  }

  @override
  void didUpdateWidget(LiquidCheckbox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (widget.value) {
        _c.animateWith(
          SpringSimulation(
            LiquidMotion.press,
            _c.value,
            1,
            2 * (_c.value - 1),
          ),
        );
      } else {
        //取消勾选走无超调的快速淡出。
        //此前用弹簧从 1 回到 0：弹簧会越过 0（t<0），而绘制层把 t 钳在
        //[0,1] 后表现为「勾号消失 → 回弹又出现一点 → 再消失」的闪烁。
        _c.animateBack(
          0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      return Checkbox(
        value: widget.value,
        onChanged: widget.onChanged == null ? null : (v) => _tap(),
        activeColor: widget.activeColor,
      );
    }
    final color = widget.activeColor ?? FluidTheme.primaryFluidGradient[0];
    final enabled = widget.onChanged != null;
    // 深色标记在 build 里订阅一次即可：此前写在 AnimatedBuilder 的 builder 内，
    // 会被弹簧动画逐帧执行一次 select（每次都要查依赖并比较）
    final isDarkMode = context.select<ThemeProvider, bool>(
      (p) => p.isDarkMode,
    );
    return Semantics(
      checked: widget.value,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? _tap : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _MercuryCheckPainter(
                t: _c.value,
                color: color,
                circular: widget.circular,
                isDark: isDarkMode,
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 水银勾选绘制：玻璃凹槽 + 汇聚水银 + 对勾描边生长
class _MercuryCheckPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool circular;
  final bool isDark;
  final bool enabled;

  _MercuryCheckPainter({
    required this.t,
    required this.color,
    required this.circular,
    required this.isDark,
    required this.enabled,
  });

  //对勾 metric 按宽度缓存：尺寸离散，同尺寸复用即可
  static final Map<double, PathMetric> _metrics = {};

  static PathMetric _checkMetric(double w) {
    final cached = _metrics[w];
    if (cached != null) return cached;
    final check = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.34);
    return _metrics[w] = check.computeMetrics().first;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final radius = circular ? w / 2 : w * 0.30;
    final well = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    //玻璃凹槽：半透底 + 左上亮边/右下暗边
    final wellPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.03),
              ]
            : [
                Colors.white.withValues(alpha: 0.65),
                Colors.black.withValues(alpha: 0.05),
              ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(well, wellPaint);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.35),
              ]
            : [Colors.white, Colors.black.withValues(alpha: 0.18)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(well.deflate(0.5), rimPaint);

    final fill = t.clamp(0.0, 1.0);
    if (fill <= 0.01) return;

    //超调挤压：越过 1 时纵向微拉伸，呈现水银表面张力回弹
    final over = ((t - 1) / 0.25).clamp(-1.0, 1.0);
    final under = ((0 - t) / 0.25).clamp(0.0, 1.0);
    final sx = 1 - over * 0.07 + under * 0.05;
    final sy = 1 + over * 0.13 - under * 0.08;

    final inset = w * 0.13;
    final inner = Rect.fromLTWH(inset, inset, w - inset * 2, w - inset * 2);
    canvas.save();
    canvas.translate(w / 2, w / 2);
    canvas.scale(sx, sy);
    canvas.translate(-w / 2, -w / 2);

    //外发光
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.30 * fill)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(radius - inset)),
      glowPaint,
    );

    //汇聚的附属水滴（Gooey 融合感）：填充过程中从右下漂向中心并缩小
    final merge = ((fill - 0.12) / 0.55).clamp(0.0, 1.0);
    if (merge < 1) {
      final dropPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.6),
          colors: [Color.lerp(Colors.white, color, 0.35)!, color],
        ).createShader(inner);
      final dr = w * 0.16 * (1 - merge) + w * 0.03;
      final center = Offset(
        w * (0.78 - 0.28 * merge),
        w * (0.80 - 0.30 * merge),
      );
      canvas.drawCircle(center, dr, dropPaint);
    }

    //水银主体
    final mercury = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(Colors.white, color, 0.30)!,
          color,
          Color.lerp(Colors.black, color, 0.18)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(inner);
    final blob = RRect.fromRectAndRadius(
      inner,
      Radius.circular((radius - inset) * (0.6 + 0.4 * fill)),
    );
    canvas.drawRRect(blob, mercury);
    //顶部液面高光
    final sheen = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.55 * fill),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTWH(
              inner.left,
              inner.top,
              inner.width,
              inner.height * 0.6,
            ),
          );
    canvas.drawRRect(blob, sheen);
    canvas.restore();

    //对勾：沿路径生长
    final cp = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
    if (cp > 0) {
      //路径形状只随宽度线性缩放，metric 按宽度缓存，避免动画每帧 computeMetrics
      final metric = _checkMetric(w);
      final drawn = metric.extractPath(0, metric.length * cp);
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          //水银填充是亮主色，白色对勾仅约 2:1；浅色模式改用深色对勾
          ..color = (isDark ? Colors.white : FluidTheme.onGradientForeground)
              .withValues(alpha: enabled ? 0.96 : 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_MercuryCheckPainter old) =>
      old.t != t ||
      old.color != color ||
      old.circular != circular ||
      old.isDark != isDark ||
      old.enabled != enabled;
}

//============================================================================
// 水银开关（Liquid Switch）
//============================================================================

class LiquidSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const LiquidSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  State<LiquidSwitch> createState() => _LiquidSwitchState();
}

class _LiquidSwitchState extends State<LiquidSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, value: widget.value ? 1 : 0);
  }

  @override
  void didUpdateWidget(LiquidSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _c.animateWith(
        SpringSimulation(
          LiquidMotion.press,
          _c.value,
          widget.value ? 1 : 0,
          2 * (_c.value - (widget.value ? 1 : 0)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      return Switch(
        value: widget.value,
        onChanged: widget.onChanged,
        activeThumbColor: widget.activeColor,
      );
    }
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final color = widget.activeColor ?? FluidTheme.primaryFluidGradient[0];
    const w = 52.0, h = 30.0;
    final enabled = widget.onChanged != null;
    return Semantics(
      toggled: widget.value,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? _tap : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: const Size(w, h),
              painter: _MercurySwitchPainter(
                t: _c.value,
                color: color,
                isDark: isDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MercurySwitchPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool isDark;
  static const w = 52.0, h = 30.0, d = 24.0;

  _MercurySwitchPainter({
    required this.t,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & const Size(w, h),
      const Radius.circular(h / 2),
    );
    //玻璃轨道
    final trackPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(
            isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.7),
            color,
            t * 0.55,
          )!,
          Color.lerp(
            isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
            color,
            t * 0.55,
          )!,
        ],
      ).createShader(Offset.zero & const Size(w, h));
    canvas.drawRRect(track, trackPaint);
    //开启时轨道辉光
    if (t > 0.05) {
      canvas.drawRRect(
        track,
        Paint()
          ..color = color.withValues(alpha: 0.28 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawRRect(
      track.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.4),
                ]
              : [Colors.white, Colors.black.withValues(alpha: 0.15)],
        ).createShader(Offset.zero & const Size(w, h)),
    );

    //滑动中沿运动方向拉伸（水银惯性形变）
    final stretch = math.sin((t.clamp(0.0, 1.0)) * math.pi);
    final sx = 1 + stretch * 0.22;
    final sy = 1 - stretch * 0.10;
    final cx = d / 2 + 3 + (w - d - 6) * t.clamp(0.0, 1.0);
    final cy = h / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: d * sx,
      height: d * sy,
    );
    //水滴投影
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2)),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    //水银球
    final ball = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide / 2),
    );
    canvas.drawRRect(
      ball,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFFF2F4FF), const Color(0xFFB9C0D9)]
              : [Colors.white, const Color(0xFFDDE3F2)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      ball.deflate(rect.shortestSide * 0.18),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MercurySwitchPainter old) =>
      old.t != t || old.color != color || old.isDark != isDark;
}

//============================================================================
// 液态玻璃滑块（玻璃底盘 + 光影跟手）
//============================================================================

class LiquidSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;

  const LiquidSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChanged,
    this.onChangeEnd,
    this.activeColor,
  });

  @override
  State<LiquidSlider> createState() => _LiquidSliderState();
}

class _LiquidSliderState extends State<LiquidSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  double get _ratio => _ratioFor(widget.value);

  /// 把值换算为 0~1 比例；max==min（或被误传同值）时除零会得到 NaN，
  /// NaN 传入 drawCircle 会让整个滑块消失、并把 NaN 回调给业务层，这里返回 0
  double _ratioFor(double v) {
    final range = widget.max - widget.min;
    if (!range.isFinite || range <= 0) return 0;
    return ((v - widget.min) / range).clamp(0.0, 1.0);
  }

  double _snap(double v) {
    final divisions = widget.divisions;
    if (divisions == null || divisions <= 0) return v;
    final step = (widget.max - widget.min) / divisions;
    if (!step.isFinite || step <= 0) return v;
    //必须相对 min 取整：直接对绝对值取整会让 min≠0 的滑块越界
    //（如 min=12、max=30 时，拖到 24 会被算成 36，直接顶到最大值）
    return widget.min + ((v - widget.min) / step).round() * step;
  }

  void _update(Offset local, double trackW) {
    //父宽度为 0（首帧/被压缩）时无法换算比例，直接忽略本次更新
    if (!trackW.isFinite || trackW <= 0) return;
    final r = (local.dx / trackW).clamp(0.0, 1.0);
    final v = _snap(widget.min + r * (widget.max - widget.min));
    _dragValue = v;
    widget.onChanged?.call(v);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      return Slider(
        value: widget.value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        activeColor: widget.activeColor,
        onChanged: widget.onChanged,
        onChangeEnd: widget.onChangeEnd,
      );
    }
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final color = widget.activeColor ?? FluidTheme.primaryFluidGradient[0];
    const h = 28.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackW = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            _press.forward();
            _update(d.localPosition, trackW);
          },
          onTapUp: (_) {
            _press.reverse();
            widget.onChangeEnd?.call(_dragValue ?? widget.value);
            _dragValue = null;
          },
          onHorizontalDragStart: (d) {
            _press.forward();
            _update(d.localPosition, trackW);
          },
          onHorizontalDragUpdate: (d) => _update(d.localPosition, trackW),
          onHorizontalDragEnd: (_) {
            _press.reverse();
            widget.onChangeEnd?.call(_dragValue ?? widget.value);
            _dragValue = null;
          },
          //拖动被滚动视图抢走等取消场景：释放按下光晕并丢弃拖动中间值，
          //否则滑块会停在与外部 value 不一致的位置且 onChangeEnd 不触发
          onHorizontalDragCancel: () {
            _press.reverse();
            if (_dragValue != null) setState(() => _dragValue = null);
          },
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, _) => CustomPaint(
              size: Size(trackW, h),
              painter: _LiquidSliderPainter(
                ratio: _dragValue == null ? _ratio : _ratioFor(_dragValue!),
                color: color,
                isDark: isDark,
                pressT: _press.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiquidSliderPainter extends CustomPainter {
  final double ratio;
  final Color color;
  final bool isDark;
  final double pressT;
  static const trackH = 8.0;

  _LiquidSliderPainter({
    required this.ratio,
    required this.color,
    required this.isDark,
    required this.pressT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - trackH / 2, size.width, trackH),
      const Radius.circular(trackH / 2),
    );
    //玻璃底盘
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.black.withValues(alpha: 0.22),
                ]
              : [
                  Colors.white.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.07),
                ],
        ).createShader(track.outerRect),
    );
    canvas.drawRRect(
      track.deflate(0.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.4),
                ]
              : [Colors.white, Colors.black.withValues(alpha: 0.15)],
        ).createShader(track.outerRect),
    );

    //已滑过区段：品牌色液态注入 + 辉光
    final fillW = (size.width - 0) * ratio;
    if (fillW > 1) {
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - trackH / 2, fillW, trackH),
        const Radius.circular(trackH / 2),
      );
      canvas.drawRRect(
        fill,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(Colors.white, color, 0.35)!, color],
          ).createShader(fill.outerRect),
      );
    }

    //跟手光斑：拖动时光影在底盘上扩散
    final thumbX = size.width * ratio;
    if (pressT > 0.01) {
      final glowR = 26 + pressT * 12;
      canvas.drawCircle(
        Offset(thumbX, cy),
        glowR,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  color.withValues(alpha: 0.28 * pressT),
                  color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(thumbX, cy), radius: glowR),
              ),
      );
    }

    //玻璃拇指
    final thumbR = 10 + pressT * 2.5;
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbR + 2,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    final thumbRect = Rect.fromCircle(
      center: Offset(thumbX, cy),
      radius: thumbR,
    );
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFFF4F6FF), const Color(0xFFBEC6E0)]
              : [Colors.white, const Color(0xFFD9DFEF)],
        ).createShader(thumbRect),
    );
    canvas.drawCircle(
      Offset(thumbX - thumbR * 0.25, cy - thumbR * 0.3),
      thumbR * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_LiquidSliderPainter old) =>
      old.ratio != ratio ||
      old.color != color ||
      old.isDark != isDark ||
      old.pressT != pressT;
}

//============================================================================
// 液态单选圆点
//============================================================================

class LiquidRadio extends StatefulWidget {
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const LiquidRadio({
    super.key,
    required this.selected,
    this.onTap,
    this.color,
    this.size = 20,
  });

  @override
  State<LiquidRadio> createState() => _LiquidRadioState();
}

class _LiquidRadioState extends State<LiquidRadio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, value: widget.selected ? 1 : 0);
  }

  @override
  void didUpdateWidget(LiquidRadio old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _c.animateWith(
        SpringSimulation(
          LiquidMotion.press,
          _c.value,
          widget.selected ? 1 : 0,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? FluidTheme.primaryFluidGradient[0];
    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      return Icon(
        widget.selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: color,
        size: widget.size,
      );
    }
    // 与 LiquidCheckbox 同理：深色标记在 build 里订阅一次，
    // 不放在逐帧执行的 AnimatedBuilder builder 内
    final isDarkMode = context.select<ThemeProvider, bool>(
      (p) => p.isDarkMode,
    );
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _MercuryCheckPainter(
            t: _c.value,
            color: color,
            circular: true,
            isDark: isDarkMode,
            enabled: widget.onTap != null,
          ),
        ),
      ),
    );
  }
}

//============================================================================
// 颜料水滴色球：选中时色彩如颜料滴入水中扩散
//============================================================================

class LiquidColorDot extends StatefulWidget {
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final double size;

  /// 选中时是否在色块中央画对勾。
  /// 预设色板需要（浅色预设彼此过于接近，只靠描边分不出谁被选中）；
  /// 单纯显示"当前颜色"的地方不需要（对勾会误导成可点击项）。
  final bool showCheck;

  const LiquidColorDot({
    super.key,
    required this.color,
    required this.selected,
    this.onTap,
    this.size = 36,
    this.showCheck = false,
  });

  @override
  State<LiquidColorDot> createState() => _LiquidColorDotState();
}

class _LiquidColorDotState extends State<LiquidColorDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(LiquidColorDot old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    if (!isGlass) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.selected
                  ? FluidTheme.primaryFluidGradient[0]
                  : Colors.grey,
              width: widget.selected ? 3 : 1,
            ),
          ),
          child: widget.selected && widget.showCheck
              ? Icon(
                  Icons.check,
                  size: widget.size * 0.5,
                  //浅色底用深勾、深色底用白勾，保证任何预设色上都能看清
                  color: widget.color.computeLuminance() > 0.6
                      ? const Color(0xFF1A1A1A)
                      : Colors.white,
                )
              : null,
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _PaintDropPainter(
            color: widget.color,
            selected: widget.selected,
            spread: _c.value,
            showCheck: widget.showCheck,
          ),
        ),
      ),
    );
  }
}

class _PaintDropPainter extends CustomPainter {
  final Color color;
  final bool selected;
  final double spread;
  final bool showCheck;

  _PaintDropPainter({
    required this.color,
    required this.selected,
    required this.spread,
    this.showCheck = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - (selected ? 3.5 : 1);
    //浅色（白/米黄/浅绿…）在浅色玻璃面板上：白色高光会把它们冲成同一个白球，
    //既不显色也分不清，所以浅色走「平面色块 + 深色描边」的路线
    final isLight = color.computeLuminance() > 0.6;
    final accent = FluidTheme.primaryFluidGradient[0];

    //选中瞬间：颜料入水双层涟漪扩散
    if (spread > 0 && spread < 1) {
      for (var i = 0; i < 2; i++) {
        final p = (spread - i * 0.22).clamp(0.0, 1.0);
        if (p <= 0) continue;
        final rr = r + p * 16;
        final wave = isLight ? accent : color;
        canvas.drawCircle(
          c,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * (1 - p)
            ..color = wave.withValues(alpha: 0.55 * (1 - p)),
        );
        canvas.drawCircle(
          c,
          rr,
          Paint()..color = wave.withValues(alpha: 0.08 * (1 - p)),
        );
      }
    }
    //球体投影：固定中性黑，避免浅色球用自身颜色投影变成"发光"
    canvas.drawCircle(
      c.translate(0, selected ? 1.5 : 1),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: selected ? 0.22 : 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, selected ? 6 : 3),
    );
    //色块本体：平面填充，忠实还原颜色
    canvas.drawCircle(c, r, Paint()..color = color);
    //浅色块在浅色玻璃上缺边界：补一圈对比描边把每个色点的轮廓交代清楚
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = isLight
            ? Colors.black.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.32),
    );
    //玻璃高光：只给中深色补一点点湿润感，浅色加了只会整体泛白认不出颜色
    if (!isLight) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.45),
            colors: [
              Colors.white.withValues(alpha: 0.3),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.55],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    if (selected) {
      //选中玻璃环：改用主色，原来的纯白环在浅色面板上根本看不见
      canvas.drawCircle(
        c,
        r + 2.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, accent.withValues(alpha: 0.55)],
          ).createShader(Rect.fromCircle(center: c, radius: r + 3)),
      );
      //对勾：浅色预设（白/米黄/浅绿…）之间差得太少，描边不足以指出选中项
      if (showCheck) {
        final check = Path()
          ..moveTo(c.dx - r * 0.40, c.dy + r * 0.02)
          ..lineTo(c.dx - r * 0.12, c.dy + r * 0.30)
          ..lineTo(c.dx + r * 0.42, c.dy - r * 0.30);
        canvas.drawPath(
          check,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.17
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = isLight
                ? const Color(0xFF1A1A1A)
                : Colors.white.withValues(alpha: 0.92),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PaintDropPainter old) =>
      old.color != color ||
      old.selected != selected ||
      old.spread != spread ||
      old.showCheck != showCheck;
}

//============================================================================
// 水波手风琴展开（LiquidExpand）
//============================================================================

/// 弹簧驱动的高度展开，底边带正弦水波推挤，替代生硬的高度动画
class LiquidExpand extends StatefulWidget {
  final bool expanded;
  final Widget child;

  const LiquidExpand({super.key, required this.expanded, required this.child});

  @override
  State<LiquidExpand> createState() => _LiquidExpandState();
}

class _LiquidExpandState extends State<LiquidExpand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, value: widget.expanded ? 1 : 0);
  }

  @override
  void didUpdateWidget(LiquidExpand old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) {
      _c.animateWith(
        SpringSimulation(
          LiquidMotion.expand,
          _c.value,
          widget.expanded ? 1 : 0,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    if (!isGlass) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: widget.expanded ? widget.child : const SizedBox.shrink(),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (_c.value == 0) return const SizedBox.shrink();
        final hf = _c.value.clamp(0.0, 1.0);
        return ClipPath(
          clipper: _WaveEdgeClipper(t: _c.value),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: hf,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 底边正弦水波：展开/收起中段波幅最大，两端平直
class _WaveEdgeClipper extends CustomClipper<Path> {
  final double t;

  _WaveEdgeClipper({required this.t});

  @override
  Path getClip(Size size) {
    final amp = 5.0 * (1 - t) * t * 4; //sin 包络近似，端点为零
    final path = Path()..moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - amp);
    //两个波峰的水面边缘
    final segments = 4;
    for (var i = segments; i >= 0; i--) {
      final x = size.width * i / segments;
      final y = size.height - amp * math.sin(i * math.pi / segments);
      path.lineTo(x, y);
    }
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveEdgeClipper old) => (old.t - t).abs() > 0.003;
}

//============================================================================
// 液态分段选择器（替代 SegmentedButton）
//============================================================================

class LiquidSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const LiquidSegment({required this.value, required this.label, this.icon});
}

class LiquidSegmented<T> extends StatefulWidget {
  final List<LiquidSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;
  final Color? activeColor;

  const LiquidSegmented({
    super.key,
    required this.segments,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  @override
  State<LiquidSegmented<T>> createState() => _LiquidSegmentedState<T>();
}

class _LiquidSegmentedState<T> extends State<LiquidSegmented<T>> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.segments.indexWhere((s) => s.value == widget.value);
    if (_index < 0) _index = 0;
  }

  @override
  void didUpdateWidget(LiquidSegmented<T> old) {
    super.didUpdateWidget(old);
    _index = _indexOfValue();
  }

  /// 外部选中值对应的下标（找不到时保持原值）
  int _indexOfValue() {
    final i = widget.segments.indexWhere((s) => s.value == widget.value);
    return i < 0 ? _index : i;
  }

  /// 分段文字/图标颜色：视觉高亮段（按住时跟随手指）用可读版主色
  Color _segmentColor(int i, bool isDark) => _visualIndex == i
      //淡 tint 底上用可读版主色：浅色 5.27:1 / 深色 5.51:1
      ? FluidTheme.primaryAccessible(isDark)
      : FluidTheme.getTextSecondaryColor(isDark);

  @override
  Widget build(BuildContext context) {
    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      //经典（流体渐变）模式此前回退 Material SegmentedButton：它按内容收缩，
      //周/月/年只占卡片左侧一小段，与液态玻璃模式下"撑满整行"的观感不一致。
      //这里改成与玻璃分支同构的整行胶囊：淡底槽 + 滑动高亮块。
      return _buildFluidSegmented(context);
    }
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final color = widget.activeColor ?? FluidTheme.primaryFluidGradient[0];
    final n = widget.segments.length;
    //空分段列表直接不渲染：segW = 宽度/0 = NaN，会让 AnimatedPositioned
    //的 left 变成 NaN 触发布局异常
    if (n == 0) return const SizedBox.shrink();
    //每次构建都校准一次：外部选中值是唯一真相，
    //避免动画异常、热重载等导致「数据已切换、高亮还停在原来那段」
    _index = _indexOfValue();
    return GlassSurface(
      borderRadius: 14,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / n;
          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                //滑块位置由 _index（就是外部选中值）直接决定，隐式动画只负责过渡：
                //即使动画被打断/静音，也不会停留在一个与数据不一致的位置
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  left: segW * _visualIndex,
                  top: 0,
                  bottom: 0,
                  width: segW,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          //选中态统一为「淡主色 tint 底 + 高亮主色字」，
                          //与提醒时间滚轮保持一致。原「亮粉实底 + 白字」在
                          //浅色仅 2.04:1、深色仅 2.68:1，两种模式都不可读。
                          color.withValues(alpha: isDark ? 0.22 : 0.18),
                          color.withValues(alpha: isDark ? 0.30 : 0.26),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          //底色改淡后阴影相应收敛，避免彩色光晕压过文字
                          color: color.withValues(alpha: 0.20),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSegmentRow(isDark, n, constraints.maxWidth),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 经典（流体渐变）模式：整行胶囊 + 滑动高亮块。
  ///
  /// 与玻璃分支同构，只是把玻璃材质换成淡底槽 + 描边，
  /// 保证「周 / 月 / 年」在两种风格下都撑满整行、位置一致。
  Widget _buildFluidSegmented(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final color = widget.activeColor ?? FluidTheme.primaryFluidGradient[0];
    final n = widget.segments.length;
    //空分段列表直接不渲染：segW 除零会得到 NaN
    if (n == 0) return const SizedBox.shrink();
    _index = _indexOfValue();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FluidTheme.getMutedOverlayColor(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FluidTheme.getBorderColor(isDark)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / n;
          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  left: segW * _visualIndex,
                  top: 0,
                  bottom: 0,
                  width: segW,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: isDark ? 0.22 : 0.18),
                          color.withValues(alpha: isDark ? 0.30 : 0.26),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.20),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSegmentRow(isDark, n, constraints.maxWidth),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- 按住滑动切换（与底部导航栏同款交互）----
  //按下即高亮手指所在段（预览），滑动实时跟随，松手才提交 onChanged。
  //整条用原始指针事件（Listener）统一处理，不再逐段 onTap：
  //拖动跨段后松手若再触发 onTap 会造成二次切换，原始指针路径无此问题。
  bool _pressing = false;
  bool _cancelled = false;
  int? _previewIndex;

  /// 当前视觉高亮段：按住时跟随手指（预览），松手回到选中段
  int get _visualIndex =>
      _pressing && !_cancelled && _previewIndex != null
      ? _previewIndex!
      : _index;

  int _segmentFromDx(double dx, double totalW, int n) {
    //n=0 / 宽度为 0（首帧、被压缩）时除零会得到 NaN，.floor() 直接抛错
    if (n <= 0 || !totalW.isFinite || totalW <= 0) return 0;
    final idx = (dx / (totalW / n)).floor();
    if (!idx.isFinite) return 0;
    return idx.clamp(0, n - 1);
  }

  void _onPointerDown(Offset local, double totalW, int n) {
    _pressing = true;
    _cancelled = false;
    _previewIndex = _segmentFromDx(local.dx, totalW, n);
    if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
    setState(() {});
  }

  void _onPointerMove(Offset local, double totalW, int n) {
    if (!_pressing) return;
    //拖出控件过远（两侧各 0.6 个控件宽）：取消本次选择，松手不提交。
    //与底部导航栏一致——否则手指划到控件外松手仍会把主题/语言等关键设置改掉
    final outOfBounds =
        local.dx < -totalW * 0.6 || local.dx > totalW * 1.6;
    if (outOfBounds) {
      if (!_cancelled) {
        setState(() {
          _cancelled = true;
          _previewIndex = null; //高亮回到当前选中段
        });
      }
      return;
    }
    if (_cancelled) {
      _cancelled = false; //拖回来：恢复按压态
    }
    final seg = _segmentFromDx(local.dx, totalW, n);
    if (seg == _previewIndex) return;
    setState(() => _previewIndex = seg);
    if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
  }

  void _onPointerUp() {
    if (!_pressing) return;
    _pressing = false;
    final seg = _cancelled ? null : _previewIndex;
    _previewIndex = null;
    _cancelled = false;
    if (seg != null && seg != _index) {
      setState(() => _index = seg);
      widget.onChanged?.call(widget.segments[seg].value);
    } else {
      setState(() {});
    }
  }

  void _onPointerCancel() {
    if (!_pressing) return;
    _pressing = false;
    _cancelled = false;
    _previewIndex = null;
    setState(() {});
  }

  /// 无障碍/键盘激活某一段：与松手提交语义一致（不加按压预览）
  void _selectSegmentAt(int i) {
    if (i < 0 || i >= widget.segments.length || i == _index) return;
    setState(() => _index = i);
    widget.onChanged?.call(widget.segments[i].value);
  }

  /// 分段行：玻璃分支与经典分支共用（点击反馈、文字/图标排版完全一致）。
  /// [totalW] 为整行宽度，用于把指针横坐标换算成段下标。
  Widget _buildSegmentRow(bool isDark, int n, double totalW) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _onPointerDown(e.localPosition, totalW, n),
      onPointerMove: (e) => _onPointerMove(e.localPosition, totalW, n),
      onPointerUp: (_) => _onPointerUp(),
      onPointerCancel: (_) => _onPointerCancel(),
      child: Row(
        children: [
          for (var i = 0; i < n; i++)
            Expanded(
              // 语义动作：整条用裸 Listener 承载指针交互，不提供 onTap 时
              // 读屏/键盘完全无法感知与操作分段控件（关键设置项都在这里）
              child: Semantics(
                button: true,
                selected: _visualIndex == i,
                label: widget.segments[i].label,
                onTap: () => _selectSegmentAt(i),
                excludeSemantics: true,
                child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _segmentColor(i, isDark),
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: 16,
                      color: _segmentColor(i, isDark),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.segments[i].icon != null) ...[
                            Icon(widget.segments[i].icon),
                            const SizedBox(width: 4),
                          ],
                          Text(widget.segments[i].label),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
        ],
      ),
    );
  }
}

//============================================================================
// 液态筛选胶囊（替代 Material ChoiceChip）
//============================================================================

/// 筛选/选项胶囊
///
/// 玻璃模式下为「未选中＝普通玻璃胶囊，选中＝品牌色发光胶囊」，
/// 与搜索页、薄弱词库页一致；经典模式回退 Material [ChoiceChip]，
/// 避免玻璃界面里出现原生 Material 芯片而显得格格不入。
class LiquidChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accentColor;

  const LiquidChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final accent = accentColor ?? FluidTheme.primaryFluidGradient[0];

    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onTap == null ? null : (_) => onTap!(),
        selectedColor: accent.withValues(alpha: 0.22),
        backgroundColor: FluidTheme.getMutedOverlayColor(isDark),
        labelStyle: TextStyle(
          color: selected
              ? FluidTheme.primaryAccessible(isDark)
              : FluidTheme.getTextSecondaryColor(isDark),
        ),
      );
    }

    final content = Text(
      label,
      style: TextStyle(
        //选中态用可读版主色：发光胶囊在浅色下接近白底，主色原色仅 1.91:1
        color: selected
            ? FluidTheme.primaryAccessible(isDark)
            : FluidTheme.getTextSecondaryColor(isDark),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: selected
          ? GlowCapsule(color: accent, padding: padding, child: content)
          : GlassSurface(borderRadius: 999, padding: padding, child: content),
    );
  }
}

//============================================================================
// 液态水滴滚轮（替代 CupertinoPicker）
//============================================================================

/// 中央玻璃水珠承托选中项，两侧文字按距离压缩淡化，如水滴内滚动
class LiquidWheelPicker extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onSelectedItemChanged;
  final int initialItem;
  final double itemExtent;
  final double height;

  /// 打开时是否自动获得焦点（同行第一个滚轮建议设为 true，键盘可直接调节）
  final bool autofocus;

  const LiquidWheelPicker({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSelectedItemChanged,
    this.initialItem = 0,
    this.itemExtent = 36,
    this.height = 150,
    this.autofocus = false,
  });

  @override
  State<LiquidWheelPicker> createState() => _LiquidWheelPickerState();
}

class _LiquidWheelPickerState extends State<LiquidWheelPicker>
    with SingleTickerProviderStateMixin {
  late final FixedExtentScrollController _scroll = FixedExtentScrollController(
    initialItem: widget.initialItem,
  );
  late final AnimationController _repaint = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  final FocusNode _focusNode = FocusNode();
  int _lastSelected = 0;

  @override
  void initState() {
    super.initState();
    _lastSelected = widget.initialItem;
    //透明度/缩放只依赖 selectedItem，滚动中每 tick 翻转 repaint 会让所有
    //滚轮项无谓重建，只在选中项真正变化时才触发
    _scroll.addListener(() {
      if (_scroll.selectedItem != _lastSelected) {
        _lastSelected = _scroll.selectedItem;
        _repaint.value = 1 - _repaint.value;
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _repaint.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 键盘支持（Windows/macOS/Linux 桌面端）
  ///
  /// - 上下键：滚动"当前聚焦的"滚轮（焦点可用鼠标点击切换）
  /// - 左右键：在同一行的多个滚轮之间移动焦点
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _stepBy(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _stepBy(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _focusNode.previousFocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _focusNode.nextFocus();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(LiquidWheelPicker old) {
    super.didUpdateWidget(old);
    //外部数据变化（如切换月份后天数列表变短）时校正索引：
    //FixedExtentScrollController 不会自动跟随新的 itemCount，旧索引会越界
    if (widget.itemCount != old.itemCount && widget.itemCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final max = widget.itemCount - 1;
        if (_scroll.selectedItem > max) _scroll.jumpToItem(max);
      });
    }
  }

  void _stepBy(int delta) {
    //itemCount=0 时 clamp(0, -1) 上下限颠倒会直接抛错
    if (widget.itemCount <= 0) return;
    final target = (_scroll.selectedItem + delta).clamp(
      0,
      widget.itemCount - 1,
    );
    if (target == _scroll.selectedItem) return;
    _scroll.animateToItem(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget picker;
    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      picker = SizedBox(
        height: widget.height,
        child: CupertinoPicker(
          itemExtent: widget.itemExtent,
          scrollController: _scroll,
          onSelectedItemChanged: widget.onSelectedItemChanged,
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              Center(child: widget.itemBuilder(context, i)),
          ],
        ),
      );
    } else {
      final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
      picker = SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            //中央水滴承托改为白色半透明胶囊高亮选中项
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  height: widget.itemExtent + 6,
                  decoration: BoxDecoration(
                    //原为固定的「白色 70%」胶囊：深色模式下选中文字也是白色，
                    //白字压白胶囊几乎不可读。参照时间选择器（提醒时间）的范式——
                    //淡主色 tint 底 + 高亮字：深色改用主色淡 tint，
                    //浅色保留白胶囊（其上为深色文字，对比充足）。
                    color: isDark
                        ? FluidTheme.primaryFluidGradient[0].withValues(
                            alpha: 0.22,
                          )
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x00000000),
                        blurRadius: 0,
                        offset: Offset(0, 0),
                      ),
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            //上下渐隐：直接给滚轮内容本身做 alpha 淡出
            //（原实现是在玻璃面板上盖一层「实色 → Colors.transparent」渐变，
            //  透明端的 RGB 是黑色，插值途中会经过灰黑色，在半透明玻璃上
            //  就显出一条灰黑横杠；且实色块本身也不该盖在玻璃上）
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: [0, 0.2, 0.8, 1],
                ).createShader(rect),
                child: ListWheelScrollView.useDelegate(
                  controller: _scroll,
                  itemExtent: widget.itemExtent,
                  diameterRatio: 1.4,
                  perspective: 0.004,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: widget.onSelectedItemChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.itemCount,
                    builder: (context, i) {
                      return AnimatedBuilder(
                        animation: _repaint,
                        builder: (context, child) {
                          final dist = (_scroll.selectedItem - i)
                              .toDouble()
                              .abs()
                              .clamp(0.0, 3.0);
                          final opacity = (1 - dist * 0.32).clamp(0.0, 1.0);
                          final scale = 1 - dist * 0.08;
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(scale: scale, child: child),
                          );
                        },
                        child: Center(child: widget.itemBuilder(context, i)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    //桌面端：滚轮支持鼠标/触控板拖动，点击滚轮即可获得焦点再用上下键调节
    //键盘调节（autofocus + 方向键）只在桌面端挂载：移动端没有物理键盘，
    //聚焦了也没有任何用处，反而会抢走弹窗内其它控件的焦点
    return ScrollConfiguration(
      behavior: const _WheelDragScrollBehavior(),
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus && isDesktopPlatform,
        onKeyEvent: isDesktopPlatform ? _onKeyEvent : null,
        child: Listener(
          onPointerDown: (_) => _focusNode.requestFocus(),
          child: picker,
        ),
      ),
    );
  }
}

/// 桌面端滚轮允许鼠标/触控板拖动滚动（默认 ScrollBehavior 不含鼠标）
class _WheelDragScrollBehavior extends MaterialScrollBehavior {
  const _WheelDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

//============================================================================
// 液态底部弹窗（果冻升起的玻璃面板）
//============================================================================

Future<T?> showLiquidBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final glass = context.read<ThemeProvider>().isLiquidGlass;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    //玻璃模式用轻遮罩（与 FluidDialog 一致）：让玻璃片的模糊折射透出页面内容，
    //过重的黑遮罩会把玻璃压成一块灰板
    barrierColor: Colors.black.withValues(alpha: glass ? 0.25 : 0.5),
    builder: (ctx) => _LiquidSheet(child: Builder(builder: builder)),
  );
}

class _LiquidSheet extends StatefulWidget {
  final Widget child;
  const _LiquidSheet({required this.child});

  @override
  State<_LiquidSheet> createState() => _LiquidSheetState();
}

class _LiquidSheetState extends State<_LiquidSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    if (context.read<ThemeProvider>().isLiquidGlass) {
      _c = AnimationController.unbounded(vsync: this);
      LiquidMotion.run(_c, spring: LiquidMotion.jellyEntrance);
    } else {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 240),
      )..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    // 只要键盘高度就取 viewInsetsOf：of(context) 会把整份 MediaQueryData
    // （尺寸/字号/边距）都算作依赖，键盘弹起之外的变化也会重建这个弹窗
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (!context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      return Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Material(
          color: FluidTheme.getDialogSurfaceColor(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: widget.child,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final tc = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: (t * 2.2).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, (1 - tc) * 90, 0.0, 1.0)
              ..scaleByDouble(1.04 - 0.04 * t, 0.9 + 0.1 * t, 1.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        // 玻璃片本身不是 Material：面板内容里若用 InkWell / ListTile 这类
        // Material 系控件，会因缺少 Material 祖先直接抛错（经典模式的面板
        // 是 Material，所以只有玻璃模式会踩到）。这里补一层透明 Material，
        // 不改变任何外观，只让两种风格下能共用同一套交互控件。
        child: Material(
          type: MaterialType.transparency,
          child: GlassSurface(
            borderRadius: 28,
            margin: const EdgeInsets.all(8),
            emphasized: true,
            grain: true,
            //底部弹窗背后是较重的遮罩，用更厚的纱保证可读性
            tint: LiquidGlass.overlayTint(isDark),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                //顶部水滴抓手
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.4),
                              Colors.white.withValues(alpha: 0.15),
                            ]
                          : [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.08),
                            ],
                    ),
                  ),
                ),
                Flexible(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

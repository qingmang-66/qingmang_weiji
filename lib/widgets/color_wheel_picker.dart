import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'liquid_controls.dart';

/// 圆形 HSV 调色盘：色环角度=色相，半径=饱和度，下方滑条=明度
/// 拖拽中走 onPreview（实时看色），松手走 onCommit（持久化最终色）
class ColorWheelPicker extends StatefulWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onPreview;
  final ValueChanged<HSVColor> onCommit;
  final double size;

  const ColorWheelPicker({
    super.key,
    required this.hsv,
    required this.onPreview,
    required this.onCommit,
    this.size = 200,
  });

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker>
    with SingleTickerProviderStateMixin {
  //色环上 0→360 度的纯色序列
  static const _hueColors = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  //跟踪拖拽过程中的最新色，避免 onPanEnd 提交闭包捕获的起始色
  late HSVColor _cur;

  //提交瞬间的颜料入水涟漪
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    _cur = widget.hsv;
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ColorWheelPicker old) {
    super.didUpdateWidget(old);
    _cur = widget.hsv;
  }

  HSVColor _pick(Offset p) {
    final size = widget.size;
    final c = Offset(size / 2, size / 2);
    final d = p - c;
    final r = math.min(d.distance, size / 2);
    var hue = math.atan2(d.dy, d.dx) * 180 / math.pi;
    if (hue < 0) hue += 360;
    return HSVColor.fromAHSV(
      1,
      hue,
      (r / (size / 2)).clamp(0.0, 1.0),
      _cur.value,
    );
  }

  void _preview(HSVColor h) {
    setState(() => _cur = h);
    widget.onPreview(h);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final hsv = _cur;
    final color = hsv.toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _preview(_pick(d.localPosition)),
            onPanUpdate: (d) => _preview(_pick(d.localPosition)),
            onPanEnd: (_) {
              widget.onCommit(_cur);
              _ripple.forward(from: 0);
            },
            //嵌套在滚动视图里时，纵向分量可能让滚动抢走手势导致 onPanEnd 不触发；
            //此时已预览的颜色只存在内存里，这里补一次提交避免丢失
            onPanCancel: () => widget.onCommit(_cur),
            child: SizedBox(
              width: size,
              height: size,
              child: AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) => CustomPaint(
                  painter: _WheelPainter(
                    hsv: hsv,
                    hueColors: _hueColors,
                    ripple: _ripple.value,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        //明度滑条：黑→当前色
        Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black,
                          HSVColor.fromAHSV(
                            1,
                            hsv.hue,
                            hsv.saturation,
                            1,
                          ).toColor(),
                        ],
                      ),
                    ),
                  ),
                  LiquidSlider(
                    value: hsv.value,
                    min: 0,
                    max: 1,
                    activeColor: color,
                    onChanged: (v) => _preview(hsv.withValue(v)),
                    onChangeEnd: (v) {
                      _preview(hsv.withValue(v));
                      widget.onCommit(_cur);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            LiquidColorDot(color: color, selected: true, size: 28),
            const SizedBox(width: 10),
            Text(
              '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final HSVColor hsv;
  final List<Color> hueColors;

  //0→1：提交瞬间颜料入水涟漪进度
  final double ripple;

  const _WheelPainter({
    required this.hsv,
    required this.hueColors,
    this.ripple = 0,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromLTWH(0, 0, s.width, s.height);
    //色相环：角度映射色相
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = SweepGradient(colors: hueColors).createShader(rect),
    );
    //饱和度：圆心纯白向边缘衰减
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    //取色点
    final a = hsv.hue * math.pi / 180;
    final p = c + Offset(math.cos(a), math.sin(a)) * (hsv.saturation * r);
    final picked = hsv.toColor();

    //提交瞬间：颜料入水双层涟漪扩散
    if (ripple > 0 && ripple < 1) {
      for (var i = 0; i < 2; i++) {
        final t = (ripple - i * 0.22).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final rr = 9 + t * 22;
        canvas.drawCircle(
          p,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * (1 - t)
            ..color = picked.withValues(alpha: 0.55 * (1 - t)),
        );
        canvas.drawCircle(
          p,
          rr,
          Paint()..color = picked.withValues(alpha: 0.08 * (1 - t)),
        );
      }
    }

    //外圈 accent 辉光
    canvas.drawCircle(
      p,
      11,
      Paint()
        ..color = const Color(0xFF7A6BFF).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final ballRect = Rect.fromCircle(center: p, radius: 9);
    //水银球：中心偏左上白、边缘浅灰
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Colors.white, Color(0xFFDDE3F2)],
        ).createShader(ballRect),
    );
    //0.8px 玻璃描边
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0x2F000000)],
        ).createShader(ballRect),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.hsv != hsv || old.ripple != ripple;
}

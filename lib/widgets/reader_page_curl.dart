import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 仿真翻页。
///
/// 与旧版（竖直折线 + 矩形圆柱色带）相比，本版更接近真实纸张：
/// - 折痕是**带弧度的贝塞尔曲线**（翻动中段弯得最多，起收笔基本拉直）；
/// - 翻起的纸背以**镜像内容**呈现——旧页文字从纸背透出来（参考实体书卷页）；
/// - 卷边有「暗-亮-暗」受光渐变、折痕处投影、翻起边缘对下一页的接触阴影；
/// - 首尾淡入淡出，避免折痕越过页边时"啪"地出现/消失。
///
/// 布局约定（与 PageView 的遮挡关系一致：旧页盖在新页上方）：
/// - 旧页（v > 0）：画出折痕左侧的平坦部分 + 翻起的纸背（镜像内容）；
/// - 新页（v < 0）：只画出卷边右侧露出部分，并在卷边后画接触阴影。
class ReaderCurlPage extends StatelessWidget {
  final int index;
  final double page; //PageView 当前浮点页码
  final Color backColor; //卷起后的纸背颜色
  final Widget child;

  const ReaderCurlPage({
    super.key,
    required this.index,
    required this.page,
    required this.backColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final v = page - index;
    if (v <= -1 || v >= 1) return child;
    //停稳后 page == index（v == 0）：折痕压在页边，新页分支的可视区退化为 0，
    //整页会空白（表现是"选仿真翻页后阅读模式什么都不显示"）。此时直接返回原页
    if (v.abs() < 0.001) return child;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (v > 0) {
          //旧页：平坦部分（折痕左侧）+ 翻起的纸背（镜像内容 + 受光渐变）
          final t = _ease(v);
          final g = _CurlGeometry(width: w, height: h, t: t);
          return Transform.translate(
            offset: Offset(v * w, 0),
            child: Stack(
              children: [
                //平坦部分：折痕左侧，折痕处叠一道投影
                ClipPath(
                  clipper: _PathClipper(g.flatPath),
                  child: CustomPaint(
                    foregroundPainter: _CreaseShadowPainter(g),
                    size: c.biggest,
                    child: SizedBox(width: w, height: h, child: child),
                  ),
                ),
                //翻起的纸背：镜像旧页内容，再叠纸背色调与受光渐变
                if (g.fade > 0)
                  ClipPath(
                    clipper: _PathClipper(g.flapPath),
                    child: Stack(
                      children: [
                        Transform(
                          transform: Matrix4.identity()
                            ..translateByDouble(2 * g.cx, 0, 0, 1)
                            ..scaleByDouble(-1, 1, 1, 1),
                          child: SizedBox(width: w, height: h, child: child),
                        ),
                        CustomPaint(
                          foregroundPainter: _FlapShadePainter(g, backColor),
                          size: c.biggest,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }
        //新页：只露出卷边右侧，卷边后叠接触阴影
        //进度必须与旧页同源（page = index + v，旧页 t=_ease(v)）：
        //用 _ease(-v) 会让新页裁剪边界从左往右扫，与旧页折痕对向移动，
        //视觉上就是"两边向中间聚焦"
        final t = _ease(1 + v);
        final g = _CurlGeometry(width: w, height: h, t: t);
        return Transform.translate(
          offset: Offset(v * w, 0),
          child: ClipPath(
            clipper: _PathClipper(g.farSidePath),
            child: CustomPaint(
              foregroundPainter: _ContactShadowPainter(g),
              size: c.biggest,
              child: SizedBox(width: w, height: h, child: child),
            ),
          ),
        );
      },
    );
  }

  /// 翻动进度按余弦缓动：起翻/收翻慢、中段快，纸张运动更符合物理直觉
  static double _ease(double t) => 0.5 - 0.5 * math.cos(math.pi * t);
}

/// 单帧的翻页几何：由翻动进度 t ∈ [0,1] 推出折痕位置、弧度与各区域路径
class _CurlGeometry {
  final double width;
  final double height;
  final double t;

  _CurlGeometry({required this.width, required this.height, required this.t});

  static const double _margin = 48; //路径越界余量，避免斜边裁出锯齿

  /// 折痕基准线 x（随进度从右往左扫）
  double get cx => width * (1 - t);

  /// 折痕中段的弯曲量：起收笔为 0（折痕拉直），中段最弯
  double get bend => width * 0.05 * math.sin(math.pi * t);

  /// 卷边（纸背露出）宽度
  double get cyl => (width * 0.07).clamp(16.0, 40.0);

  /// 首尾淡入淡出系数：折痕贴近页边时卷边整体淡出，避免突现/突失
  double get fade => (math.min(cx, width - cx) / (cyl * 2.5)).clamp(0.0, 1.0);

  /// 折痕曲线（从上到下，中段向右弯 bend）
  Path _creaseCore() => Path()
    ..moveTo(cx, -_margin)
    ..quadraticBezierTo(cx + bend, height / 2, cx, height + _margin);

  /// 旧页平坦部分：折痕左侧
  Path get flatPath => Path()
    ..moveTo(-_margin, -_margin)
    ..lineTo(cx, -_margin)
    ..quadraticBezierTo(cx + bend, height / 2, cx, height + _margin)
    ..lineTo(-_margin, height + _margin)
    ..close();

  /// 翻起的纸背：折痕与翻起外缘之间的条带
  Path get flapPath => Path()
    ..moveTo(cx, -_margin)
    ..quadraticBezierTo(cx + bend, height / 2, cx, height + _margin)
    ..lineTo(cx + cyl, height + _margin)
    ..quadraticBezierTo(cx + cyl + bend, height / 2, cx + cyl, -_margin)
    ..close();

  /// 新页露出部分：翻起外缘右侧
  Path get farSidePath => Path()
    ..moveTo(cx + cyl, -_margin)
    ..quadraticBezierTo(cx + cyl + bend, height / 2, cx + cyl, height + _margin)
    ..lineTo(width + _margin, height + _margin)
    ..lineTo(width + _margin, -_margin)
    ..close();
}

class _PathClipper extends CustomClipper<Path> {
  final Path path;
  _PathClipper(this.path);

  @override
  Path getClip(Size s) => path;

  @override
  bool shouldReclip(_PathClipper old) => !identical(old.path, path);
}

/// 折痕投影：沿折痕曲线描一道模糊暗边，压在平坦页面上
class _CreaseShadowPainter extends CustomPainter {
  final _CurlGeometry g;
  _CreaseShadowPainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    if (g.fade <= 0) return;
    canvas.clipPath(g.flatPath);
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22 * g.fade)
      ..strokeWidth = g.cyl * 0.8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    //折痕略向左偏移半个线宽：让阴影主体落在平坦页一侧
    canvas.drawPath(g._creaseCore().shift(Offset(-g.cyl * 0.4, 0)), paint);
  }

  @override
  bool shouldRepaint(_CreaseShadowPainter old) =>
      old.g.cx != g.cx || old.g.bend != g.bend || old.g.fade != g.fade;
}

/// 纸背受光：先压纸背色调（让镜像文字呈"透出"效果），
/// 再叠「折痕暗 → 圆柱高光 → 纸背 → 外缘暗」的横向渐变
class _FlapShadePainter extends CustomPainter {
  final _CurlGeometry g;
  final Color backColor;
  _FlapShadePainter(this.g, this.backColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (g.fade <= 0) return;
    final h = size.height;
    final rect = Rect.fromLTRB(g.cx, 0, g.cx + g.cyl, h);
    final shaderRect = Rect.fromLTRB(g.cx, 0, g.cx + g.cyl * 1.4, h);

    //纸背色调：半透明纸色盖住镜像内容，文字呈隐约"透出"
    canvas.drawRect(
      rect,
      Paint()..color = backColor.withValues(alpha: 0.45 * g.fade),
    );
    //受光弧面：亮带偏折痕一侧（光源来自翻起方向）
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.42 * g.fade),
            Colors.white.withValues(alpha: 0.05 * g.fade),
            Colors.black.withValues(alpha: 0.05 * g.fade),
            Colors.black.withValues(alpha: 0.30 * g.fade),
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(shaderRect),
    );
    //翻起外缘：一道细暗线 + 渐弱暗边，给纸背厚度感
    canvas.drawPath(
      g._creaseCore().shift(Offset(g.cyl, 0)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20 * g.fade)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_FlapShadePainter old) =>
      old.g.cx != g.cx ||
      old.g.bend != g.bend ||
      old.g.fade != g.fade ||
      old.backColor != backColor;
}

/// 接触阴影：翻起的纸背在下一页露出的部分上投下的柔影
class _ContactShadowPainter extends CustomPainter {
  final _CurlGeometry g;
  _ContactShadowPainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    if (g.fade <= 0) return;
    final rect = Rect.fromLTRB(
      g.cx + g.cyl,
      0,
      g.cx + g.cyl + g.cyl * 2.2,
      size.height,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.26 * g.fade),
            Colors.black.withValues(alpha: 0.10 * g.fade),
            Colors.black.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ContactShadowPainter old) =>
      old.g.cx != g.cx || old.g.fade != g.fade;
}

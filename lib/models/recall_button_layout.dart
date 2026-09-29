/// 回忆模式评分键布局：「锚点 + dp 偏移」模型。
///
/// 取代旧的「键中心比例坐标（fx/fy）」方案。旧方案的两个致命问题：
/// 1. 比例坐标随区域尺寸线性放大——同一布局在手机上贴底、在大屏上会漂到
///    卡片中间；键宽又写死为「列宽/3」，用户无法单独调某一颗键。
/// 2. 键宽公式在两处（学习页 / 编辑器预览）各写一遍且口径不一致，
///    「所见即所得」是假的。
///
/// 新模型以 **锚点 + dp 间距** 描述每颗键：
/// - 横向锚在「参考列」（宽 [kRecallRefColumnWidth]，水平居中于内容区）的
///   左/中/右边缘，纵向锚在内容区的上/中/下边缘；
/// - 间距是 dp 常量，不随区域放大；内容区窄于参考列时（竖屏手机）横向
///   按 区域宽/480 等比缩放，纵向不缩放（触控键高与屏宽无关）。
/// 于是「贴底一排」「左右拇指位」这类语义在手机与桌面上都稳定成立。
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// 参考列宽（dp）：与学习页内容列的宽度口径一致。
/// 内容区比它窄时按比例缩键，比它宽时键群始终落在这条居中列内。
const double kRecallRefColumnWidth = 480;

/// 默认键宽 / 键高（dp）
const double kRecallButtonDefaultW = 140;
const double kRecallButtonDefaultH = 54;

/// 默认贴底间距（dp）：与旧默认布局（键中心 fy=0.94）视觉一致
const double kRecallButtonDefaultGapBottom = 26;

/// 默认横排时键与参考列边缘（及相邻键）的间距（dp）：
/// (480 - 3×140) / 2 = 30 —— 三键恰好在参考列内等距排开
const double kRecallButtonDefaultGapX = 30;

/// 逐键可调范围（dp / 透明度）
const double kRecallButtonMinW = 40;
const double kRecallButtonMaxW = 240;
const double kRecallButtonMinH = 28;
const double kRecallButtonMaxH = 96;
const double kRecallButtonMinOpacity = 0.3;
const double kRecallButtonMaxOpacity = 1.0;

/// 拖拽吸附网格（dp）
const double kRecallSnapGrid = 8;

/// 横向锚点：参考列的左边缘 / 中线 / 右边缘
enum RecallHAnchor { left, center, right }

/// 纵向锚点：内容区的上边缘 / 中线 / 下边缘。
/// 不锚卡片边缘——回忆模式的卡片高度会随「释义展开」动画变化，
/// 锚卡片会让键跟着漂移。
enum RecallVAnchor { top, middle, bottom }

/// 单颗评分键的完整描述（位置 + 尺寸 + 透明度），三颗键各持一份。
class RecallButtonSpec {
  const RecallButtonSpec({
    this.h = RecallHAnchor.center,
    this.v = RecallVAnchor.bottom,
    this.gapLeft = 0,
    this.gapRight = 0,
    this.gapTop = 0,
    this.gapBottom = kRecallButtonDefaultGapBottom,
    this.gapMidY = 0,
    this.w = kRecallButtonDefaultW,
    this.hPx = kRecallButtonDefaultH,
    this.opacity = 1.0,
  });

  final RecallHAnchor h;
  final RecallVAnchor v;

  /// h == left：键左边缘到参考列左边缘的距离
  final double gapLeft;

  /// h == right：键右边缘到参考列右边缘的距离
  final double gapRight;

  /// v == top：键上边缘到内容区上边缘的距离
  final double gapTop;

  /// v == bottom：键下边缘到内容区下边缘的距离
  final double gapBottom;

  /// v == middle：键中心相对内容区垂直中线的偏移（下正上负）
  final double gapMidY;

  /// 键宽（参考列坐标系下的 dp，内容区更窄时随 [RecallButtonSpec.resolve] 缩放）
  final double w;
  final double hPx;
  final double opacity;

  RecallButtonSpec copyWith({
    RecallHAnchor? h,
    RecallVAnchor? v,
    double? gapLeft,
    double? gapRight,
    double? gapTop,
    double? gapBottom,
    double? gapMidY,
    double? w,
    double? hPx,
    double? opacity,
  }) => RecallButtonSpec(
    h: h ?? this.h,
    v: v ?? this.v,
    gapLeft: gapLeft ?? this.gapLeft,
    gapRight: gapRight ?? this.gapRight,
    gapTop: gapTop ?? this.gapTop,
    gapBottom: gapBottom ?? this.gapBottom,
    gapMidY: gapMidY ?? this.gapMidY,
    w: w ?? this.w,
    hPx: hPx ?? this.hPx,
    opacity: opacity ?? this.opacity,
  );

  /// 解析成内容区坐标下的像素矩形。
  ///
  /// [areaSize] 是操作栏浮层的实际大小（学习页 = SafeArea 后的内容区，
  /// 编辑器预览 = 同一块区域），因此两端天然共用这一条公式。
  Rect resolve(Size areaSize) {
    final areaW = areaSize.width;
    final areaH = areaSize.height;
    // 窄屏（竖屏手机）横向等比缩放；宽屏下参考列恒定 480 且居中
    final k = math.min(areaW, kRecallRefColumnWidth) / kRecallRefColumnWidth;
    final colLeft = (areaW - kRecallRefColumnWidth * k) / 2;
    final btnW = w * k;
    final btnH = hPx;

    final double left;
    switch (h) {
      case RecallHAnchor.left:
        left = colLeft + gapLeft * k;
      case RecallHAnchor.center:
        left = areaW / 2 - btnW / 2 + (gapLeft - gapRight) * k;
      case RecallHAnchor.right:
        left = colLeft + kRecallRefColumnWidth * k - gapRight * k - btnW;
    }

    final double top;
    switch (v) {
      case RecallVAnchor.top:
        top = gapTop;
      case RecallVAnchor.middle:
        top = areaH / 2 - btnH / 2 + gapMidY;
      case RecallVAnchor.bottom:
        top = areaH - gapBottom - btnH;
    }

    // 收敛进内容区：极小窗口 / 超大键时不至于把键推出可视范围
    final maxLeft = math.max(0.0, areaW - btnW);
    final maxTop = math.max(0.0, areaH - btnH);
    return Rect.fromLTWH(
      left.clamp(0.0, maxLeft),
      top.clamp(0.0, maxTop),
      btnW,
      btnH,
    );
  }

  /// 拖拽落点 → 最近锚点 + 间隙。编辑器松手时调用，把「像素矩形」翻译成
  /// 可跨设备复用的锚点描述（保留拖拽结果的视觉位置，同时丢掉绝对坐标）。
  factory RecallButtonSpec.fromRect(
    Rect rect,
    Size areaSize, {
    required double w,
    required double hPx,
  }) {
    final areaW = areaSize.width;
    final areaH = areaSize.height;
    final k = math.min(areaW, kRecallRefColumnWidth) / kRecallRefColumnWidth;
    final colLeft = (areaW - kRecallRefColumnWidth * k) / 2;
    final btnW = w * k;

    // 横向：取「键边缘到三条候选基准线」间隙最小的一侧作为锚点
    // （三列基准线天然互斥，不需要额外的中心吸附惩罚）
    final gapsLeft = (rect.left - colLeft) / k;
    final gapsRight = (colLeft + kRecallRefColumnWidth * k - rect.right) / k;
    final gapCenter = (rect.left + btnW / 2 - areaW / 2) / k;
    final RecallHAnchor anchor;
    final double gap;
    if (gapCenter.abs() < gapsLeft.abs() && gapCenter.abs() < gapsRight.abs()) {
      anchor = RecallHAnchor.center;
      gap = _snap(gapCenter);
    } else if (gapsLeft.abs() <= gapsRight.abs()) {
      anchor = RecallHAnchor.left;
      gap = _snap(gapsLeft);
    } else {
      anchor = RecallHAnchor.right;
      gap = _snap(gapsRight);
    }
    // 中心锚定时偏移落在 gapLeft/gapRight 之差上，两半对半分即可
    final centerLeft = anchor == RecallHAnchor.center ? _snap(gap / 2) : 0.0;
    final centerRight = anchor == RecallHAnchor.center ? -centerLeft : 0.0;

    // 纵向：上/中/下三档同理
    final gapTop = rect.top;
    final gapBottom = areaH - rect.bottom;
    final gapMidY = rect.top + rect.height / 2 - areaH / 2;
    final RecallVAnchor vAnchor;
    double vGap = 0;
    double midY = 0;
    if (gapMidY.abs() < gapTop.abs() && gapMidY.abs() < gapBottom.abs()) {
      vAnchor = RecallVAnchor.middle;
      midY = _snap(gapMidY);
    } else if (gapTop.abs() <= gapBottom.abs()) {
      vAnchor = RecallVAnchor.top;
      vGap = _snap(gapTop);
    } else {
      vAnchor = RecallVAnchor.bottom;
      vGap = _snap(gapBottom);
    }

    return RecallButtonSpec(
      h: anchor,
      v: vAnchor,
      gapLeft: anchor == RecallHAnchor.left ? gap : centerLeft,
      gapRight: anchor == RecallHAnchor.right ? gap : centerRight,
      gapTop: vGap,
      gapBottom: vAnchor == RecallVAnchor.bottom
          ? vGap
          : kRecallButtonDefaultGapBottom,
      gapMidY: midY,
      w: w,
      hPx: hPx,
    );
  }

  static double _snap(double v) =>
      (v / kRecallSnapGrid).roundToDouble() * kRecallSnapGrid;

  Map<String, dynamic> toJson() => {
    'h': h.name,
    'v': v.name,
    'gl': gapLeft,
    'gr': gapRight,
    'gt': gapTop,
    'gb': gapBottom,
    'gm': gapMidY,
    'w': w,
    'hp': hPx,
    'op': opacity,
  };

  factory RecallButtonSpec.fromJson(Map<String, dynamic> json) {
    double num_(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    RecallHAnchor anchorH() => RecallHAnchor.values.firstWhere(
      (e) => e.name == json['h'],
      orElse: () => RecallHAnchor.center,
    );
    RecallVAnchor anchorV() => RecallVAnchor.values.firstWhere(
      (e) => e.name == json['v'],
      orElse: () => RecallVAnchor.bottom,
    );
    return RecallButtonSpec(
      h: anchorH(),
      v: anchorV(),
      gapLeft: num_('gl', 0),
      gapRight: num_('gr', 0),
      gapTop: num_('gt', 0),
      gapBottom: num_('gb', kRecallButtonDefaultGapBottom),
      gapMidY: num_('gm', 0),
      w: num_(
        'w',
        kRecallButtonDefaultW,
      ).clamp(kRecallButtonMinW, kRecallButtonMaxW),
      hPx: num_(
        'hp',
        kRecallButtonDefaultH,
      ).clamp(kRecallButtonMinH, kRecallButtonMaxH),
      opacity: num_(
        'op',
        1.0,
      ).clamp(kRecallButtonMinOpacity, kRecallButtonMaxOpacity),
    );
  }
}

/// 三颗评分键的整体布局。quality 编码：1=不认识 3=模糊 4=认识。
class RecallButtonLayout {
  const RecallButtonLayout(this.specs);

  final Map<int, RecallButtonSpec> specs;

  /// 默认布局：贴底等距一排（左锚 / 中锚 / 右锚 + 默认横向间隙）。
  static RecallButtonLayout defaults() => const RecallButtonLayout({
    1: RecallButtonSpec(
      h: RecallHAnchor.left,
      gapLeft: kRecallButtonDefaultGapX,
    ),
    3: RecallButtonSpec(h: RecallHAnchor.center),
    4: RecallButtonSpec(
      h: RecallHAnchor.right,
      gapRight: kRecallButtonDefaultGapX,
    ),
  });

  RecallButtonSpec specFor(int quality) =>
      specs[quality] ?? const RecallButtonSpec();

  Rect resolve(int quality, Size areaSize) =>
      specFor(quality).resolve(areaSize);

  RecallButtonLayout withSpec(int quality, RecallButtonSpec spec) =>
      RecallButtonLayout({...specs, quality: spec});

  String encode() => jsonEncode({
    'v': 1,
    'specs': {
      for (final e in specs.entries) e.key.toString(): e.value.toJson(),
    },
  });

  /// 解析持久化结果；任何异常/缺字段都回落到默认布局——
  /// 布局坏了最坏是回到默认一排，不能让学习页或设置页打不开。
  static RecallButtonLayout decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return defaults();
      final specsRaw = decoded['specs'];
      if (specsRaw is! Map) return defaults();
      final result = <int, RecallButtonSpec>{};
      specsRaw.forEach((key, value) {
        final quality = int.tryParse(key.toString());
        if (quality == null || value is! Map) return;
        result[quality] = RecallButtonSpec.fromJson(
          value.cast<String, dynamic>(),
        );
      });
      if (result.isEmpty) return defaults();
      // 缺失的键补默认值，保证三颗键都能解析
      for (final q in const [1, 3, 4]) {
        result.putIfAbsent(q, () => defaults().specFor(q));
      }
      return RecallButtonLayout(result);
    } catch (_) {
      return defaults();
    }
  }
}

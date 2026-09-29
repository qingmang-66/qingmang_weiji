import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_info.dart';

/// Android 原生窗口 insets 探针（摄像头挖孔 / 状态栏）。
///
/// Flutter 引擎在部分 ROM（MIUI/HyperOS、ColorOS 等）的沉浸式模式下，
/// 仍会把 `MediaQuery.padding.top` 报告成整条状态栏高度 —— Dart 侧拿到的
/// 这个值无法区分"状态栏"和"摄像头挖孔"：照搬会在隐藏状态栏后留一条空白，
/// 直接归零又会让首行内容顶进直板机的居中挖孔。
///
/// [MainActivity]（qingmang_weiji/insets 通道）用一个 0x0 的旁路 View
/// 读取原生 WindowInsets 并上报，这里据此换算出**真正需要的顶部避让**：
/// - 系统栏隐藏（沉浸式生效）：只避让挖孔高度，无挖孔机型为 0（完全铺满）；
/// - 系统栏可见（分屏、临时唤出通知栏）：避让状态栏高度，内容不被压住。
class InsetsProbe {
  InsetsProbe._();

  static final InsetsProbe instance = InsetsProbe._();

  static const MethodChannel _channel = MethodChannel('qingmang_weiji/insets');
  bool _bound = false;

  /// 计算后的顶部避让（逻辑像素）；null 表示尚未收到原生数据（沿用引擎值）。
  final ValueNotifier<double?> topInset = ValueNotifier<double?>(null);

  /// 在 main() 里调用一次；非 Android 平台是空操作。
  void bind() {
    if (_bound || !isAndroidPlatform) return;
    _bound = true;
    _channel.setMethodCallHandler(_onCall);
    // 主动拉一次兜底：原生在首帧前的 insets 分发若早于 handler 注册，
    // 推送会丢失，这里显式查询补上
    unawaited(
      _channel
          .invokeMethod<dynamic>('get')
          .then((payload) {
            if (payload is Map) _apply(payload);
          })
          .catchError((_) {}),
    );
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'onInsets' && call.arguments is Map) {
      _apply(call.arguments as Map);
    }
    return null;
  }

  void _apply(Map payload) {
    // 原生侧已按 displayMetrics.density 换算成逻辑像素
    final cutoutTop = (payload['cutoutTop'] as num?)?.toDouble() ?? 0;
    final statusBarTop = (payload['statusBarTop'] as num?)?.toDouble() ?? 0;
    final visible = payload['statusBarVisible'] == true;
    final value = visible
        ? (statusBarTop > cutoutTop ? statusBarTop : cutoutTop)
        : cutoutTop;
    if (topInset.value != value) topInset.value = value;
  }
}

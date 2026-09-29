import 'package:flutter/services.dart';

import 'platform_info.dart';

/// 跳转系统设置的平台通道封装。
///
/// Android 侧在 `MainActivity` 中实现具体跳转；其它平台返回 false，
/// 调用方据此决定是否展示对应入口（例如 Windows 没有 TTS 设置页）。
class PlatformSettings {
  PlatformSettings._();

  static const MethodChannel _channel = MethodChannel('qingmang_weiji/system');

  /// 打开本应用的"文字转语音（TTS）"设置页。
  ///
  /// 国产 ROM 常缺英文语音数据，用户需要在这里安装/切换语音引擎。
  /// 返回是否成功发起跳转（ROM 拦截时返回 false）。
  static Future<bool> openTtsSettings() async {
    // 只有 Android 原生侧实现了这些通道。用 isMobilePlatform 会把 iOS 也算进来，
    // iOS 走到通道只会拿到空实现返回 false，UI 却已经认定"这台设备支持该入口"，
    // 于是弹出误导性的"ROM 不支持"提示
    if (!isAndroidPlatform) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openTtsSettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 打开系统的"电池优化 / 后台运行"设置页。
  ///
  /// Android 12+ 的国产 ROM 会限制后台闹钟，导致每日提醒延迟或不来；
  /// 用户需要把本应用加入白名单。
  static Future<bool> openBatterySettings() async {
    // 同上：仅 Android 有原生实现
    if (!isAndroidPlatform) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openBatterySettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

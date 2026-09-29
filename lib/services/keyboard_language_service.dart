import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/platform_info.dart';

/// 拼写 / 听力输入时的输入法语言控制。
///
/// 界面语言是中文，但拼写和听力要求输入**英文单词**。中文输入法在键盘上
/// 会先吐拼音候选，用户必须手动把输入法切回英文，输入体验被打断。
/// 这里通过一条轻量的平台通道，在进入题目、切到下一题、点击输入框时
/// 把系统输入法切到英文：
///
/// - **Windows**：切换键盘布局到 en-US（`LoadKeyboardLayout` +
///   `WM_INPUTLANGCHANGEREQUEST`），中文输入法随之退出，按键直接落到英文；
/// - **Android**：把当前输入法的子类型切到英文子类型（不改动用户选择的
///   输入法应用）；同时 Dart 侧用 `TextInputType.visiblePassword` 让不支持
///   子类型切换的输入法（如部分国产输入法）也退化为英文键盘。
///
/// 两端都是**尽力而为**：通道不可用、系统拒绝、输入法没有英文子类型时
/// 静默失败，绝不阻断答题流程。
class KeyboardLanguageService {
  KeyboardLanguageService._();

  static const MethodChannel _channel = MethodChannel(
    'qingmang_weiji/keyboard',
  );

  /// 常规节流：切题之间不必反复打扰系统输入法。
  static const Duration _throttle = Duration(milliseconds: 1500);

  /// 硬下限：即使 [ensureEnglish] 传了 force，也不会比这更频繁地调用系统。
  ///
  /// 用户连点输入框时每次都真的去切一次输入法是没必要的，Android 上还会让
  /// 输入法面板闪一下；400ms 内的一次调用已经足够覆盖"点击即生效"的体感。
  static const Duration _minInterval = Duration(milliseconds: 400);

  static DateTime? _lastRequestAt;

  /// 该平台是否支持自动切换输入法语言
  static bool get isSupported =>
      !kIsWeb && (isWindowsPlatform || isAndroidPlatform);

  /// 让输入法切到英文。
  ///
  /// [force] 为 true 时忽略常规节流（例如用户主动点击输入框，应立刻生效）。
  static Future<void> ensureEnglish({bool force = false}) async {
    if (!isSupported) return;

    final now = DateTime.now();
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = now.difference(last);
      if (elapsed < _minInterval) return;
      if (!force && elapsed < _throttle) return;
    }
    _lastRequestAt = now;

    try {
      await _channel.invokeMethod<void>('switchToEnglish');
    } catch (e) {
      // 平台未实现 / 系统拒绝都走这里，不影响答题
      debugPrint('切换英文输入法失败：$e');
    }
  }

  /// 还原到切英文之前的输入法 / 键盘布局。
  ///
  /// 离开学习页时调用：拼写和听力需要英文键盘，但词库命名、笔记这类输入框
  /// 仍然要中文，把系统输入法一直留在英文会很难受。
  ///
  /// 平台侧没有记录过原始状态时是空操作，所以重复调用是安全的。
  static Future<void> restore() async {
    if (!isSupported) return;
    // 还原之后下次进入学习页要能立刻再切，这里把节流记录清掉
    _lastRequestAt = null;
    try {
      await _channel.invokeMethod<void>('restore');
    } catch (e) {
      debugPrint('还原输入法失败：$e');
    }
  }
}

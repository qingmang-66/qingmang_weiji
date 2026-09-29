import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/platform_info.dart';

/// 提醒提示音服务
///
/// Windows 端 local_notifier 无法自定义也无法关闭 Toast 提示音（只能沿用
/// 系统通知声音，而系统通知声音常被用户静音），因此提醒触发时由应用自身
/// 补播一次提示音（见 NotificationService._showWindowsNotification）：
/// 1. 优先播放 Windows 自带提示音（`C:\Windows\Media` 下的 wav）；
/// 2. 上述文件不可用时回退到系统提示音 [SystemSoundType.alert]。
///
/// 其他平台的通知已由系统通知自带提示音，这里不再处理，避免重复发声。
class ReminderSoundService {
  ReminderSoundService._();

  static final ReminderSoundService instance = ReminderSoundService._();

  /// Windows 自带提示音候选（按优先级尝试，取第一个可播放的）
  static const List<String> _windowsSoundCandidates = [
    r'C:\Windows\Media\Windows Notify System Generic.wav',
    r'C:\Windows\Media\Windows Notify.wav',
    r'C:\Windows\Media\Windows Notify Messaging.wav',
    r'C:\Windows\Media\notify.wav',
    r'C:\Windows\Media\Windows Ding.wav',
  ];

  AudioPlayer? _player;

  /// 已确认可播放的提示音路径；为 null 表示系统提示音均不可用
  String? _resolvedSoundPath;

  /// 是否已完成一次候选探测
  bool _probed = false;

  /// 设置页的「提醒声音」开关：关闭后提醒只弹通知不发声
  bool enabled = true;

  /// 播放提醒提示音（仅 Windows 桌面端生效；受 [enabled] 控制）
  Future<void> playReminderSound() async {
    if (!enabled) return;
    await _play();
  }

  /// 试听：忽略开关状态，直接播放一次
  Future<void> playPreview() => _play();

  Future<void> _play() async {
    if (!isWindowsPlatform) return;
    if (await _playWindowsWave()) return;
    await _playSystemAlert();
  }

  /// 播放 Windows 自带提示音，全部失败返回 false
  Future<bool> _playWindowsWave() async {
    if (_probed) {
      final cached = _resolvedSoundPath;
      return cached != null && await _playFile(cached);
    }
    _probed = true;
    for (final path in _windowsSoundCandidates) {
      if (await _playFile(path)) {
        _resolvedSoundPath = path;
        return true;
      }
    }
    return false;
  }

  Future<bool> _playFile(String path) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(DeviceFileSource(path));
      return true;
    } catch (e) {
      debugPrint('提醒提示音：播放 $path 失败 - $e');
      return false;
    }
  }

  /// 回退：播放系统提示音
  Future<void> _playSystemAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('提醒提示音：系统提示音播放失败 - $e');
    }
  }

  /// 释放音频播放器
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

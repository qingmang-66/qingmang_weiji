import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// TTS 服务 - 支持本地合成音和在线真人发音
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isOnline = false;
  String _accent = 'us'; // 'us' 或 'uk'

  /// 初始化服务
  /// [isOnline] 是否使用在线真人发音
  /// [accent] 口音：'us' (美音) 或 'uk' (英音)
  Future<void> init({bool isOnline = false, String accent = 'us'}) async {
    _isOnline = isOnline;
    _accent = accent;
    if (!isOnline) {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.45);
    }
  }

  /// 播放单词发音
  /// 如果在线模式失败，会自动降级到 TTS
  Future<void> playWord(String word) async {
    try {
      if (_isOnline) {
        await _playOnlineAudio(word);
      } else {
        await _playTtsAudio(word);
      }
    } catch (e) {
      debugPrint('发音播放失败：$e');
      // 如果在线失败，自动降级到 TTS
      if (_isOnline) {
        debugPrint('在线发音失败，降级为 TTS');
        _isOnline = false;
        await _playTtsAudio(word);
      }
    }
  }

  /// 播放在线真人发音 (有道 API)
  /// 有道 API: type=1 美音，type=2 英音
  /// 无需申请 Key，直接调用，免费额度极高
  Future<void> _playOnlineAudio(String word) async {
    final type = _accent == 'uk' ? '2' : '1';
    final url = Uri.parse('https://dict.youdao.com/dictvoice?audio=$word&type=$type');
    
    // 重试机制：最多 3 次
    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // 设置超时时间 5 秒
        await Future.any([
          _audioPlayer.play(UrlSource(url.toString())),
          Future.delayed(const Duration(seconds: 5), () => throw Exception('Timeout')),
        ]);
        return; // 成功则返回
      } catch (e) {
        debugPrint('在线发音尝试 $attempt/$maxRetries 失败：$e');
        if (attempt == maxRetries) {
          // 最后一次失败，抛出异常
          debugPrint('在线发音最终失败，将降级为 TTS');
          rethrow;
        }
        // 等待 300ms 后重试
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// 播放 TTS 发音
  Future<void> _playTtsAudio(String word) async {
    await _flutterTts.speak(word);
  }

  /// 停止发音
  Future<void> stop() async {
    await _flutterTts.stop();
    await _audioPlayer.stop();
  }

  /// 更新发音源设置
  Future<void> updateSettings({bool? isOnline, String? accent}) async {
    if (isOnline != null) _isOnline = isOnline;
    if (accent != null) _accent = accent;
    if (!_isOnline) {
      await _flutterTts.setLanguage("en-US");
    }
  }

  /// 清理资源
  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
  }
}

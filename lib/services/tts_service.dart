import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_info.dart';

typedef TtsWordAction = Future<void> Function(String word);
typedef TtsConfigAction = Future<void> Function(double speechRate);

/// TTS 错误事件类型
enum TtsErrorType { localFailed, onlineFailed, bothUnavailable }

/// TTS 错误事件
class TtsErrorEvent {
  final TtsErrorType type;
  final String word;
  final Object? error;

  const TtsErrorEvent(this.type, this.word, this.error);
}

/// TTS 服务 - 支持本地合成音和在线真人发音
class TtsService {
  // 私有构造函数
  TtsService._()
    : _flutterTts = FlutterTts(),
      _audioPlayer = AudioPlayer(),
      _playLocalOverride = null,
      _playOnlineOverride = null,
      _configureLocalOverride = null,
      _isWindows = isWindowsPlatform;

  TtsService.test({
    TtsWordAction? speakLocal,
    TtsWordAction? playOnline,
    TtsConfigAction? configureLocal,
    bool isWindows = false,
  }) : _flutterTts = null,
       _audioPlayer = null,
       _playLocalOverride = speakLocal,
       _playOnlineOverride = playOnline,
       _configureLocalOverride = configureLocal,
       _isWindows = isWindows;

  // 单例实例
  static final TtsService _instance = TtsService._();

  // 工厂构造函数
  factory TtsService() => _instance;

  final FlutterTts? _flutterTts;
  final AudioPlayer? _audioPlayer;
  final TtsWordAction? _playLocalOverride;
  final TtsWordAction? _playOnlineOverride;
  final TtsConfigAction? _configureLocalOverride;
  final bool _isWindows;
  bool _isOnline = false;
  bool _localAvailable = true;
  bool _onlineAvailable = true;
  double _speechRate = 0.45;
  String _accent = 'us'; // 'us' 或 'uk'
  bool _engineChecked = false;
  bool _hasEnglishEngine = true;
  String? _engineHint;

  final _errorController = StreamController<TtsErrorEvent>.broadcast();

  /// 错误事件流，UI 层监听并弹窗提示
  Stream<TtsErrorEvent> get errorStream => _errorController.stream;

  /// 当前是否使用在线发音
  bool get isOnline => _isOnline;

  /// 本地 TTS 是否可用
  bool get isLocalAvailable => _localAvailable;

  /// 在线发音是否可用
  bool get isOnlineAvailable => _onlineAvailable;

  /// 是否检测到英文语音引擎
  bool get hasEnglishEngine => _hasEnglishEngine;

  /// 引擎相关提示（无英文引擎时给 UI 展示）
  String? get engineHint => _engineHint;

  /// 初始化服务
  /// [isOnline] 是否使用在线真人发音
  /// [accent] 口音：'us' (美音) 或 'uk' (英音)
  /// [speechRate] 语速：0.0 - 1.0
  Future<void> init({
    bool isOnline = false,
    String accent = 'us',
    double speechRate = 0.45,
  }) async {
    _isOnline = isOnline;
    _accent = accent;
    _speechRate = speechRate;
    if (!isOnline) {
      await _configureLocalTts(speechRate: _speechRate);
    }
  }

  /// 播放单词发音
  /// 当前源失败时直接上报错误，不再自动回退，由 UI 层询问用户后切换
  Future<void> playWord(String word) async {
    if (_isOnline) {
      try {
        await _playOnlineAudio(word);
        return;
      } catch (e) {
        debugPrint('在线发音失败：$e');
        _reportError(TtsErrorType.onlineFailed, word, e);
        return;
      }
    } else {
      try {
        await _playTtsAudio(word);
        return;
      } catch (e) {
        debugPrint('本地 TTS 失败：$e');
        _reportError(TtsErrorType.localFailed, word, e);
        return;
      }
    }
  }

  /// 用户确认切换发音源后，使用新源重播当前单词
  /// 如果新源仍然失败，则上报 bothUnavailable
  Future<void> playWordAfterSwitch(String word) async {
    try {
      if (_isOnline) {
        await _playOnlineAudio(word);
      } else {
        await _playTtsAudio(word);
      }
    } catch (e) {
      debugPrint('切换发音源后重播失败：$e');
      _reportError(TtsErrorType.bothUnavailable, word, e);
    }
  }

  void _reportError(TtsErrorType type, String word, Object? error) {
    if (_errorController.isClosed) return;
    _errorController.add(TtsErrorEvent(type, word, error));
  }

  /// 切换到在线发音
  Future<void> switchToOnline() async {
    _isOnline = true;
    _onlineAvailable = true;
  }

  /// 切换到本地 TTS
  Future<void> switchToLocal() async {
    _isOnline = false;
    _localAvailable = true;
    await _configureLocalTts(speechRate: _speechRate);
  }

  /// 标记本地 TTS 不可用（通常由配置失败触发）
  void markLocalUnavailable() {
    _localAvailable = false;
  }

  /// 标记在线发音不可用
  void markOnlineUnavailable() {
    _onlineAvailable = false;
  }

  /// 播放在线真人发音 (有道 API)
  /// 有道 API: type=1 美音，type=2 英音
  Future<void> _playOnlineAudio(String word) async {
    final override = _playOnlineOverride;
    if (override != null) {
      await override(word);
      return;
    }

    final type = _accent == 'uk' ? '2' : '1';
    final url = Uri.parse(
      'https://dict.youdao.com/dictvoice?audio=$word&type=$type',
    );

    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final completer = Completer<void>();
        late StreamSubscription completeSub;
        late StreamSubscription stateSub;

        final audioPlayer = _audioPlayer!;
        completeSub = audioPlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });

        stateSub = audioPlayer.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.completed && !completer.isCompleted) {
            completer.complete();
          }
        });

        try {
          await audioPlayer.play(UrlSource(url.toString()));

          await Future.any([
            completer.future,
            Future.delayed(const Duration(seconds: 5)),
          ]);

          if (completer.isCompleted) {
            return;
          }

          await audioPlayer.stop();
          throw TimeoutException('在线发音超时');
        } finally {
          await completeSub.cancel();
          await stateSub.cancel();
        }
      } on TimeoutException catch (e) {
        debugPrint('在线发音尝试 $attempt/$maxRetries 超时：$e');
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('在线发音尝试 $attempt/$maxRetries 失败：$e');
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// 播放 TTS 发音
  Future<void> _playTtsAudio(String word) async {
    if (_isWindows) {
      throw Exception('Windows 平台不支持本地 TTS');
    }

    final override = _playLocalOverride;
    if (override != null) {
      await override(word);
      return;
    }

    if (!_localAvailable) {
      throw Exception('本地 TTS 不可用');
    }

    final flutterTts = _flutterTts!;
    await flutterTts.stop();
    await flutterTts.speak(word);
  }

  /// 配置本地 TTS，确保 Android 端使用已安装的英文语音引擎
  Future<void> _configureLocalTts({required double speechRate}) async {
    // Windows 本地 flutter_tts 会原生崩溃；Linux 也无可用引擎
    // 仅标记不可用，等用户实际播放时再上报，避免启动阶段弹窗
    if (_isWindows || isLinuxPlatform) {
      _localAvailable = false;
      _hasEnglishEngine = false;
      _engineHint = 'desktop_no_local_tts';
      return;
    }

    final override = _configureLocalOverride;
    if (override != null) {
      await override(speechRate);
      return;
    }

    try {
      final flutterTts = _flutterTts!;
      await flutterTts.awaitSpeakCompletion(true);
      await _detectEnglishEngine(flutterTts);
      if (!_hasEnglishEngine) {
        _localAvailable = false;
        _engineHint = 'missing_en_engine';
        debugPrint('本地 TTS：未检测到英文语音引擎，建议使用在线发音');
        return;
      }
      // 优先美音，失败再试英音
      final lang = _accent == 'uk' ? 'en-GB' : 'en-US';
      final langOk = await flutterTts.isLanguageAvailable(lang);
      if (langOk == true) {
        await flutterTts.setLanguage(lang);
      } else {
        await flutterTts.setLanguage('en-US');
      }
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(speechRate);
      _localAvailable = true;
    } catch (e) {
      debugPrint('本地 TTS 配置失败：$e');
      _localAvailable = false;
      _engineHint = 'config_failed';
      // 移动端配置失败时仅标记不可用，不在启动阶段弹窗
      return;
    }
  }

  /// 检测是否有英文 TTS 引擎/语言（国产 ROM 常缺 Google TTS）
  Future<void> _detectEnglishEngine(FlutterTts flutterTts) async {
    if (_engineChecked) return;
    _engineChecked = true;
    try {
      final languages = await flutterTts.getLanguages;
      if (languages is List && languages.isNotEmpty) {
        final hasEn = languages.any((lang) {
          final s = lang.toString().toLowerCase();
          return s.startsWith('en') ||
              s.contains('en-us') ||
              s.contains('en_us');
        });
        _hasEnglishEngine = hasEn;
        if (!hasEn) {
          debugPrint('本地 TTS：语言列表无英文 - $languages');
        }
        return;
      }
      // 部分机型 getLanguages 为空，尝试 isLanguageAvailable
      final us = await flutterTts.isLanguageAvailable('en-US');
      final gb = await flutterTts.isLanguageAvailable('en-GB');
      _hasEnglishEngine = us == true || gb == true;
    } catch (e) {
      // 检测失败不阻断，允许后续 speak 再失败上报
      debugPrint('本地 TTS 引擎检测失败：$e');
      _hasEnglishEngine = true;
    }
  }

  /// 停止发音（后台/来电时调用）
  Future<void> stop() async {
    try {
      if (kIsWeb || !isWindowsPlatform) {
        await _flutterTts?.stop();
      }
      await _audioPlayer?.stop();
    } catch (e) {
      debugPrint('停止 TTS 失败：$e');
    }
  }

  /// 更新发音源设置
  Future<void> updateSettings({
    bool? isOnline,
    String? accent,
    double? speechRate,
  }) async {
    if (isOnline != null) _isOnline = isOnline;
    if (accent != null) _accent = accent;
    if (speechRate != null) _speechRate = speechRate;
    if (!_isOnline) {
      await _configureLocalTts(speechRate: _speechRate);
    }
  }

  /// 清理资源
  void dispose() {
    if (kIsWeb || !isWindowsPlatform) {
      _flutterTts?.stop();
    }
    _audioPlayer?.dispose();
    if (!_errorController.isClosed) {
      _errorController.close();
    }
  }
}

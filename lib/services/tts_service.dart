import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_info.dart';
import 'dictionary_api_service.dart';

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

  // 共享 AudioPlayer 的并发保护：
  // 新的在线播放会作废上一轮等待，避免 A 的等待被 B 的播放完成事件提前结束
  int _playbackToken = 0;
  Completer<void>? _interruptPlayback;

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
    //先配好音频焦点，避免首次发音就把用户的后台音乐暂停且不恢复
    await _configureAudioContext();
    if (!isOnline) {
      await _configureLocalTts(speechRate: _speechRate);
    }
  }

  /// 播放单词发音
  ///
  /// 当前发音源失败时**先静默回退到另一路发音源**（在线 ⇄ 本地），
  /// 只有两路都失败才上报错误交给 UI 提示。
  /// 原因：Android 14-17 上两路失败的诱因完全不同 —— 在线依赖第三方 API 与
  /// 运营商网络，本地依赖厂商语音引擎是否带英文包；只坏一路时用户其实只想
  /// "听到发音"，弹窗要求手动切换反而打断学习节奏。
  Future<void> playWord(String word) async {
    // 与在线音频（DictionaryApiService 的另一个 AudioPlayer）互斥：
    // 不打断的话，上一题的在线真人发音还在响时本地 TTS 就起播了（叠音）
    try {
      await DictionaryApiService.stop();
    } catch (_) {
      // 停止失败不影响本次播放
    }
    if (_isOnline) {
      try {
        await _playOnlineAudio(word);
        return;
      } catch (e) {
        debugPrint('在线发音失败：$e');
        if (await _tryLocalFallback(word)) return;
        _reportError(TtsErrorType.onlineFailed, word, e);
        return;
      }
    } else {
      try {
        await _playTtsAudio(word);
        return;
      } catch (e) {
        debugPrint('本地 TTS 失败：$e');
        if (await _tryOnlineFallback(word)) return;
        _reportError(TtsErrorType.localFailed, word, e);
        return;
      }
    }
  }

  /// 回退到本地合成音；成功返回 true（不抛异常）
  Future<bool> _tryLocalFallback(String word) async {
    if (_isWindows || isLinuxPlatform) return false;
    try {
      // 引擎状态可能刚刚变化（用户照提示装好了语音包），重配一次再播
      _engineChecked = false;
      await _configureLocalTts(speechRate: _speechRate);
      await _playTtsAudio(word);
      return true;
    } catch (e) {
      debugPrint('回退本地 TTS 失败：$e');
      return false;
    }
  }

  /// 回退到在线真人发音；成功返回 true（不抛异常）
  Future<bool> _tryOnlineFallback(String word) async {
    try {
      await _playOnlineAudio(word);
      return true;
    } catch (e) {
      debugPrint('回退在线发音失败：$e');
      return false;
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

  /// 单次 TTS 插件调用的上界。
  ///
  /// 部分 ROM（尤其国产 ROM 未装语音引擎时）flutter_tts 的方法调用会**永久挂起**：
  /// 插件内部的 result 既不因 onError 也不因 onStop 完成，等待方永远醒不过来。
  static const Duration _ttsCallTimeout = Duration(seconds: 5);

  /// 播放前 stop 的上界。
  ///
  /// stop 只为清空朗读队列防叠读，正常返回是毫秒级；个别厂商引擎会挂起，
  /// 此前与通用调用共用 5 秒上界，表现为"每次点发音都要干等一小会儿才出声"。
  /// 收窄到 0.8 秒且失败不阻塞：即便 stop 没成，随后的 speak 也会接管声道，
  /// 最坏后果只是极短叠读，远好于出声前的固定等待。
  static const Duration _ttsStopTimeout = Duration(milliseconds: 800);

  /// 本地发音的上界。
  ///
  /// speak 只要求「成功开始朗读」、并不等朗读完成（见 [_playTtsAudio]），
  /// 正常返回只有毫秒级，超时覆盖的是厂商引擎懒初始化那一下。
  /// 此前给到 8 秒：引擎无响应时用户点一次发音要先干等 8 秒才回退到在线
  /// 真人音，观感就是"在线发音响应慢"。收窄到 2.5 秒。
  static const Duration _localSpeakTimeout = Duration(milliseconds: 2500);

  /// 音频焦点是否已配置（只需一次）
  bool _audioContextReady = false;

  /// 给插件调用加上界，超时/异常时返回 [fallback]
  static Future<T?> _guarded<T>(
    Future<T> future,
    Duration timeout, {
    T? fallback,
  }) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      debugPrint('TTS 调用超时（${timeout.inSeconds}s）');
      return fallback;
    } catch (e) {
      debugPrint('TTS 调用异常：$e');
      return fallback;
    }
  }

  /// 配置播放器的音频焦点策略。
  ///
  /// audioplayers 默认是 `AudioFocus.gain`（永久独占）：用户后台在放音乐/播客时，
  /// 点一次单词发音就会把它们暂停且不会自动恢复。单词发音属于"短暂播报"，
  /// 改用 gainTransientMayDuck —— 对方音量压低，播完自动回来。
  Future<void> _configureAudioContext() async {
    final player = _audioPlayer;
    if (player == null || _audioContextReady) return;
    _audioContextReady = true;
    try {
      // 设焦点也要有上界：个别 ROM 上 setAudioContext 会挂起，
      // 它挂在 stop()/play() 前面时表现为"点发音后按钮一直转圈"
      await _guarded(
        player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              contentType: AndroidContentType.speech,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        ),
        _ttsCallTimeout,
      );
    } catch (e) {
      debugPrint('配置音频焦点失败：$e');
    }
  }

  /// 切换到在线发音
  Future<void> switchToOnline() async {
    _isOnline = true;
    _onlineAvailable = true;
  }

  /// 切换到本地 TTS
  Future<void> switchToLocal() async {
    _isOnline = false;
    // 用户很可能是照着"打开语音设置"的引导刚装好/切换了语音引擎，
    // 这里重置检测标志重新检测一次，否则会一直沿用"无引擎"的旧结论
    _engineChecked = false;
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
    //word 可能是含空格/特殊字符的短语，必须编码后再拼 URL
    final url = Uri.parse(
      'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=$type',
    );

    const maxRetries = 3;
    //作废上一次仍在等待的播放，并给本轮打上令牌。
    //注意必须判 isCompleted：stop()（锁屏/切后台触发）可能已经完成过它，
    //对已完成的 Completer 再次 complete 会抛 StateError
    final previousInterrupt = _interruptPlayback;
    if (previousInterrupt != null && !previousInterrupt.isCompleted) {
      previousInterrupt.complete();
    }
    final interrupt = Completer<void>();
    _interruptPlayback = interrupt;
    final token = ++_playbackToken;

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        //被更新的播放请求取代：直接结束，不重试也不报错
        if (token != _playbackToken) return;
        final completer = Completer<void>();
        late StreamSubscription completeSub;
        late StreamSubscription stateSub;

        final audioPlayer = _audioPlayer!;
        //只有本轮令牌有效时才认领完成事件，否则会把并发的另一次播放误判为自己播完
        completeSub = audioPlayer.onPlayerComplete.listen((_) {
          if (token == _playbackToken && !completer.isCompleted) {
            completer.complete();
          }
        });

        // 起播事件：部分 ROM/播放器组合下 onPlayerComplete 永远不来，
        // 但 onPlayerStateChanged(playing) 是准的——用它把"等播完"拆成
        // 两段：先等起播，起播后只给完成事件一小段宽限期，超了也算成功
        // （单词音频最多两三秒，没必要为缺失的完成事件干等 5s×3 轮）。
        final started = Completer<void>();
        stateSub = audioPlayer.onPlayerStateChanged.listen((state) {
          if (token != _playbackToken) return;
          if (state == PlayerState.playing && !started.isCompleted) {
            started.complete();
          }
          if (state == PlayerState.completed && !completer.isCompleted) {
            completer.complete();
          }
        });

        try {
          await audioPlayer.play(UrlSource(url.toString()));

          //可取消的定时器：播完即取消，避免挂满 5 秒
          final timeout = Completer<void>();
          final timer = Timer(const Duration(seconds: 5), () {
            if (!timeout.isCompleted) timeout.complete();
          });
          try {
            await Future.any([
              completer.future,
              started.future,
              timeout.future,
              interrupt.future,
            ]);
          } finally {
            timer.cancel();
          }

          //被新的播放请求打断（或本轮已过期）：直接结束，不算失败
          if (token != _playbackToken || interrupt.isCompleted) {
            return;
          }

          if (completer.isCompleted) {
            return;
          }

          // 已起播：给完成事件 3 秒宽限（覆盖绝大多数单词音频时长），
          // 超了也按成功返回——音频在后台继续播/已播完，UI 不再空转
          if (started.isCompleted) {
            final grace = Completer<void>();
            final graceTimer = Timer(const Duration(seconds: 3), () {
              if (!grace.isCompleted) grace.complete();
            });
            try {
              await Future.any([
                completer.future,
                grace.future,
                interrupt.future,
              ]);
            } finally {
              graceTimer.cancel();
            }
            return;
          }

          await audioPlayer.stop();
          // stop 期间音频可能恰好自然播完（onPlayerComplete 完成了 completer），视为成功
          if (completer.isCompleted) {
            return;
          }
          throw TimeoutException('在线发音超时');
        } finally {
          await completeSub.cancel();
          await stateSub.cancel();
        }
      } on TimeoutException catch (e) {
        debugPrint('在线发音尝试 $attempt/$maxRetries 超时：$e');
        if (token != _playbackToken) return;
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('在线发音尝试 $attempt/$maxRetries 失败：$e');
        if (token != _playbackToken) return;
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
    //清队列防叠读：用短上界且失败不阻塞（见 _ttsStopTimeout 注释），
    //个别引擎 stop 挂起时不再拖慢每次出声
    await _guarded(flutterTts.stop(), _ttsStopTimeout);
    // speak 必须有上界：引擎无响应时它会永久挂起，UI 的"正在播放"状态随之卡死，
    // 之后所有发音点击都被 _isPlaying 拦掉（表现为"点了没反应"且不报错）。
    //
    // 同时这里**只要求「成功开始朗读」**，不再等 onDone：
    // Android 14-17 上大量厂商引擎（小爱/小艺/讯飞等）不会回调 onDone，
    // 一旦用 awaitSpeakCompletion(true) 等待，speak 就必然挂到超时，
    // 于是每次发音都误报「本地 TTS 异常」。改为按词长估算朗读时长来
    // 维持 UI 的播放态，超时不再算失败。
    final result = await _guarded(flutterTts.speak(word), _localSpeakTimeout);
    if (result == null) {
      await _guarded(flutterTts.stop(), _ttsStopTimeout);
      throw TimeoutException('语音引擎无响应（未安装可用的英文语音服务）');
    }
    // flutter_tts 用 1/0 表示成功/失败（失败通常是缺少对应语言的语音数据）
    if (result == 0) {
      throw Exception('语音引擎拒绝朗读（可能缺少英文语音包）');
    }
    // 用估算时长占住"正在播放"状态，避免连点多次叠读
    await Future.delayed(_estimatedSpeakDuration(word));
  }

  /// 按词长估算朗读时长：短词约 0.6s，长词上限 3s。
  /// 仅用于 UI 播放态与防叠读，不参与任何正确性判断。
  static Duration _estimatedSpeakDuration(String word) {
    final ms = word.trim().length.clamp(1, 24) * 90 + 520;
    return Duration(milliseconds: ms.clamp(600, 3000));
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
      // 故意不开 awaitSpeakCompletion(true)：Android 14-17 上大量厂商引擎
      // （小爱/小艺/讯飞等）不回调 onDone，等待完成会让 speak 永久挂起。
      // 播放逻辑见 _playTtsAudio，用估算时长维持播放态。
      await _guarded(flutterTts.awaitSpeakCompletion(false), _ttsCallTimeout);
      await _detectEnglishEngine(flutterTts);

      var applied = await _applyEnglishLanguage(flutterTts, speechRate);
      if (!applied) {
        // 当前引擎没有可用英文：尝试切到 Google 文字转语音再试一次
        final switched = await _selectGoogleEngine(flutterTts);
        if (switched) {
          _engineChecked = false;
          await _detectEnglishEngine(flutterTts);
          applied = await _applyEnglishLanguage(flutterTts, speechRate);
        }
      }

      if (!applied) {
        _localAvailable = false;
        _engineHint = 'missing_en_engine';
        debugPrint('本地 TTS：未检测到可用的英文语音，建议使用在线发音');
        return;
      }
      _hasEnglishEngine = true;
      _localAvailable = true;
      _engineHint = null;
    } catch (e) {
      debugPrint('本地 TTS 配置失败：$e');
      _localAvailable = false;
      _engineHint = 'config_failed';
      // 移动端配置失败时仅标记不可用，不在启动阶段弹窗
      return;
    }
  }

  /// 依次尝试美音/英音/通用 en，设置成功返回 true。
  ///
  /// - 只看 [FlutterTts.setLanguage] 的返回值，不再用 isLanguageInstalled 做硬门槛：
  ///   Android 14-17 上不少引擎对该 API 返回 null 或恒定 false，
  ///   但实际朗读完全正常，硬判会把可用机器误判成"没装语音包"。
  /// - 所有候选都拿不到明确答复（引擎未就绪/超时）时 fail-open，
  ///   交给 speak 去暴露真实问题。
  Future<bool> _applyEnglishLanguage(
    FlutterTts flutterTts,
    double speechRate,
  ) async {
    final candidates = _accent == 'uk'
        ? const ['en-GB', 'en-US', 'en']
        : const ['en-US', 'en-GB', 'en'];
    var gotAnswer = false;
    for (final lang in candidates) {
      final available = await _guarded(
        flutterTts.isLanguageAvailable(lang),
        _ttsCallTimeout,
      );
      if (available == null) continue;
      gotAnswer = true;
      if (available != true) continue;
      // setLanguage 失败时返回 0 而不是抛异常，必须看返回值
      final setResult = await _guarded(
        flutterTts.setLanguage(lang),
        _ttsCallTimeout,
      );
      if (setResult == 0) continue;
      await _guarded(flutterTts.setPitch(1.0), _ttsCallTimeout);
      await _guarded(flutterTts.setSpeechRate(speechRate), _ttsCallTimeout);
      return true;
    }
    return !gotAnswer;
  }

  /// 优先把系统 TTS 引擎切到 Google 文字转语音。
  ///
  /// 国产 ROM 的默认引擎（厂商语音服务）常缺英文语音数据；
  /// Google TTS（com.google.android.tts）存在时用它最稳。
  /// 未安装 / 被系统限制时返回 false，保持原引擎不动。
  Future<bool> _selectGoogleEngine(FlutterTts flutterTts) async {
    const googleEngine = 'com.google.android.tts';
    try {
      // getEngines 依赖 Manifest 里的 TTS_SERVICE queries 声明
      // （Android 11+ 包可见性），声明缺失时会抛异常，这里静默降级
      final engines = await _guarded(flutterTts.getEngines, _ttsCallTimeout);
      if (engines is! List || engines.isEmpty) return false;
      final names = engines.map((e) => e.toString()).toList();
      if (!names.contains(googleEngine)) return false;
      // flutter_tts 4.x 的 setEngine 没有返回值（内部 `await invokeMethod(...)`
      // 之后直接返回，结果恒为 null），所以判 `result == 1` 永远不成立 ——
      // 这正是"国产 ROM 缺英文数据时切 Google 引擎永远不生效"的原因。
      // 这里只负责发起切换；是否真的切过去由调用方重新检测语言、
      // 重新 setLanguage 来验证（见 _configureLocalTts）。
      await _guarded(flutterTts.setEngine(googleEngine), _ttsCallTimeout);
      debugPrint('本地 TTS：已请求切换到 Google 文字转语音');
      return true;
    } catch (e) {
      debugPrint('切换 TTS 引擎失败：$e');
    }
    return false;
  }

  /// 检测是否有英文 TTS 引擎/语言（国产 ROM 常缺 Google TTS）
  Future<void> _detectEnglishEngine(FlutterTts flutterTts) async {
    if (_engineChecked) return;
    _engineChecked = true;
    try {
      final languages = await _guarded(
        flutterTts.getLanguages,
        _ttsCallTimeout,
      );
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
      // 部分机型 getLanguages 为空或超时，退到 isLanguageAvailable
      final us = await _guarded(
        flutterTts.isLanguageAvailable('en-US'),
        _ttsCallTimeout,
      );
      final gb = await _guarded(
        flutterTts.isLanguageAvailable('en-GB'),
        _ttsCallTimeout,
      );
      if (us == null && gb == null) {
        //两个都拿不到结果（引擎未就绪/超时）：保持 fail-open，
        //让 speak 去暴露问题（speak 侧已有超时兜底，不会卡死 UI）
        _hasEnglishEngine = true;
        return;
      }
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
      // stop 也要有上界：个别厂商引擎的 stop 会永久挂起，而播放缓存音频/
      // 播放新词前都会先调 stop——它一挂，发音按钮的"正在播放"就永远转圈
      if (kIsWeb || !isWindowsPlatform) {
        final tts = _flutterTts;
        if (tts != null) await _guarded(tts.stop(), _ttsStopTimeout);
      }
      // 作废在途的在线播放：令牌 +1 让重试循环在 delay 结束后直接退出，
      // 否则 stop 期间正在等待重试的循环会重新 play()——音频已起播，
      // 随后的 interrupt 检查只是 return，没有任何代码再停它（后台异常发声）。
      _playbackToken++;
      // 同时唤醒等待方。
      // audioplayers 的 stop() 不会触发 onPlayerComplete，若不主动唤醒等待方，
      // 它会走到 5s 超时 → 重试 3 次 → 最终上报"在线发音异常"；
      // 于是用户锁屏/切后台/接完电话回来，就会看到一条无意义的错误弹窗。
      final pending = _interruptPlayback;
      if (pending != null && !pending.isCompleted) pending.complete();
      final player = _audioPlayer;
      if (player != null) await _guarded(player.stop(), _ttsStopTimeout);
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
    // 作废在途播放：否则该轮会在超时后继续对已释放的播放器 stop/重试，
    // 白白空转十几秒（错误最终也会因 errorController 已关闭而被吞掉）
    _playbackToken++;
    final pending = _interruptPlayback;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    if (kIsWeb || !isWindowsPlatform) {
      _flutterTts?.stop();
    }
    _audioPlayer?.dispose();
    if (!_errorController.isClosed) {
      _errorController.close();
    }
  }
}

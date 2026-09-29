import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'http_retry_client.dart';
import 'tts_service.dart';
import 'dictionary_cache_io.dart'
    if (dart.library.html) 'dictionary_cache_web.dart'
    as cache;

/// 词典 API 服务 - 获取在线真人发音音频
class DictionaryApiService {
  static const String _baseUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';
  static const int _maxAudioCacheFiles = 200;
  static const int _maxAudioCacheBytes = 50 * 1024 * 1024;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final HttpRetryClient _retryClient = HttpRetryClient();

  /// 释放静态资源（HTTP 客户端与播放器）
  static void shutdown() {
    _retryClient.dispose();
    _audioPlayer.dispose();
  }

  /// 同一单词的"在途请求"：只做并发去重，不缓存结果，
  /// 因此不会引入任何过期数据。
  ///
  /// 三个发音入口（词卡 / 词典弹窗 / 单词详情）在本地无音频缓存时都会先走这里，
  /// 短时间连点会并发请求同一个 URL —— 而每次请求内部还带 3 次重试，
  /// 去重后同一单词最多只有一次网络往返。
  static final Map<String, Future<DictionaryResult?>> _inflight = {};

  /// 从 Free Dictionary API 获取单词信息（音标+音频 URL）
  static Future<DictionaryResult?> fetchWord(String word) {
    final key = word.toLowerCase().trim();
    final existing = _inflight[key];
    if (existing != null) return existing;
    final future = _fetchWord(word).whenComplete(() {
      _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  static Future<DictionaryResult?> _fetchWord(String word) async {
    try {
      final encodedWord = Uri.encodeComponent(word.toLowerCase().trim());
      final response = await _retryClient.get(
        '$_baseUrl/$encodedWord',
        label: '词典API',
      );
      if (response.statusCode == 404) {
        debugPrint('⚠️ 单词未找到：$word');
        return null;
      }
      if (response.statusCode == 429) {
        debugPrint('⚠️ 请求频率限制：$word');
        return null;
      }
      if (response.statusCode != 200) {
        debugPrint('⚠️ API 返回错误状态码 ${response.statusCode}：$word');
        return null;
      }
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) return null;
      final entry = data[0] as Map<String, dynamic>;
      String? phonetic;
      String? audioUrl;
      String? definition;
      String? example;
      if (entry.containsKey('phonetics')) {
        final phonetics = entry['phonetics'] as List<dynamic>;
        for (var item in phonetics) {
          final pMap = item as Map<String, dynamic>;
          if (phonetic == null &&
              pMap['text'] != null &&
              (pMap['text'] as String).isNotEmpty) {
            phonetic = pMap['text'] as String;
          }
          if (audioUrl == null &&
              pMap['audio'] != null &&
              (pMap['audio'] as String).isNotEmpty) {
            audioUrl = pMap['audio'] as String;
          }
          if (phonetic != null && audioUrl != null) break;
        }
      }
      if (entry.containsKey('meanings')) {
        final meanings = entry['meanings'] as List<dynamic>;
        if (meanings.isNotEmpty) {
          final firstMeaning = meanings[0] as Map<String, dynamic>;
          if (firstMeaning.containsKey('definitions')) {
            final defs = firstMeaning['definitions'] as List<dynamic>;
            if (defs.isNotEmpty) {
              definition = defs[0]['definition'] as String?;
            }
          }
        }
      }
      if (entry.containsKey('meanings')) {
        final meanings = entry['meanings'] as List<dynamic>;
        for (var meaning in meanings) {
          final m = meaning as Map<String, dynamic>;
          if (m.containsKey('definitions')) {
            final defs = m['definitions'] as List<dynamic>;
            for (var def in defs) {
              final d = def as Map<String, dynamic>;
              if (d.containsKey('example') && d['example'] != null) {
                example = d['example'] as String;
                break;
              }
            }
            if (example != null) break;
          }
        }
      }
      return DictionaryResult(
        word: word,
        phonetic: phonetic,
        audioUrl: audioUrl,
        definition: definition,
        example: example,
      );
    } on TimeoutException catch (e) {
      debugPrint('❌ 查询超时：$word，${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ 查询失败：$word，$e');
      return null;
    }
  }

  /// 下载音频并缓存到本地（Web 直接返回 URL）
  static Future<String?> downloadAndCacheAudio(
    String audioUrl,
    String word,
  ) async {
    try {
      final normalizedUrl = _normalizeAudioUrl(audioUrl);
      if (kIsWeb) return normalizedUrl;
      //下载地址完全来自第三方响应：只接受 http(s)，其余协议（file:/data: 等）
      //直接拒绝，避免被投毒响应引导下载任意内容
      final uri = Uri.tryParse(normalizedUrl);
      if (uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty) {
        debugPrint('⚠️ 音频地址非法，已跳过：$normalizedUrl');
        return null;
      }
      final audioDir = await cache.audioCacheDir();
      final fileName = '${_safeFileName(word)}.mp3';
      final filePath = p.join(audioDir, fileName);
      if (await cache.fileExists(filePath)) return filePath;
      final response = await _retryClient.get(normalizedUrl, label: '音频下载');
      if (response.statusCode == 200) {
        // 内容类型校验：错误重定向/被投毒响应会返回 200 + HTML 错误页，
        // 落盘成 .mp3 后会被 fileExists 永久命中（播放失败也永不重下）
        final contentType = (response.headers['content-type'] ?? '')
            .toLowerCase();
        if (contentType.isNotEmpty &&
            !contentType.startsWith('audio/') &&
            !contentType.contains('octet-stream') &&
            !contentType.contains('mpeg')) {
          debugPrint('⚠️ 音频响应类型异常（$contentType），已跳过：$word');
          return null;
        }
        //响应体大小上限：单个发音通常 <200KB，超限说明响应异常
        //（错误重定向/被投毒），拒绝落盘避免内存与磁盘膨胀
        const maxAudioBytes = 5 * 1024 * 1024;
        if (response.bodyBytes.length > maxAudioBytes) {
          debugPrint('⚠️ 音频响应过大（${response.bodyBytes.length} 字节），已跳过：$word');
          return null;
        }
        await cache.writeBytes(filePath, response.bodyBytes);
        await cache.pruneAudioCache(
          audioDir,
          maxFiles: _maxAudioCacheFiles,
          maxBytes: _maxAudioCacheBytes,
        );
        return filePath;
      }
      debugPrint('⚠️ 音频下载失败：$word，状态码 ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ 音频下载异常：$word，$e');
      return null;
    }
  }

  /// 归一化音频地址，兼容三种历史情况：
  /// - 协议相对地址 `//ssl.gstatic.com/...`：dart:io 无法请求没有 scheme 的地址，
  ///   会直接抛异常并白跑 3 次重试，补上 `https:`；
  /// - 明文 `http://...`：一律升级为 `https://`（Android 端 HTTPS 更稳，
  ///   且能避开运营商透明代理改写音频流；Android 网络安全配置也已全局
  ///   禁止明文，不升级会直接请求失败）；
  /// - 其余原样返回。
  static String _normalizeAudioUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    if (trimmed.startsWith('http://')) {
      return 'https://${trimmed.substring('http://'.length)}';
    }
    return trimmed;
  }

  /// 生成音频缓存文件名。
  ///
  /// 早期实现把非 `[a-z0-9_-]` 字符统一折叠成 `_`，会让 `hello,` 与 `hello`、
  /// `don't` 与 `don t` 落到同一个缓存文件，可能播成别的单词。
  /// 这里改用 base64Url 编码（输出字符集天然适合做文件名）保证一一对应。
  static String _safeFileName(String word) {
    final normalized = word.toLowerCase().trim();
    if (normalized.isEmpty) return 'audio';
    return base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  }

  @visibleForTesting
  static Future<void> pruneAudioCacheForTesting(
    String audioDir, {
    int maxFiles = _maxAudioCacheFiles,
    int maxBytes = _maxAudioCacheBytes,
  }) {
    return cache.pruneAudioCache(
      audioDir,
      maxFiles: maxFiles,
      maxBytes: maxBytes,
    );
  }

  /// 音频焦点是否已配置（只需一次）
  static bool _audioContextReady = false;

  /// 与 TtsService 保持一致：单词发音用"短暂占用、可压低其他音频"的焦点策略，
  /// 避免点一次发音就把用户后台的音乐永久暂停
  static Future<void> _ensureAudioContext() async {
    if (_audioContextReady) return;
    try {
      // 加上界：个别 ROM 上 setAudioContext 会挂起，而它在播放链路前面，
      // 一挂就是"发音按钮一直转圈"
      await _audioPlayer
          .setAudioContext(
            AudioContext(
              android: AudioContextAndroid(
                contentType: AndroidContentType.speech,
                usageType: AndroidUsageType.media,
                audioFocus: AndroidAudioFocus.gainTransientMayDuck,
              ),
            ),
          )
          .timeout(const Duration(seconds: 5));
      //成功后才置位：此前先置位会把首次配置失败吞成"已就绪"，本会话不再重试
      _audioContextReady = true;
    } on TimeoutException {
      debugPrint('配置音频焦点超时');
    } catch (e) {
      debugPrint('配置音频焦点失败：$e');
    }
  }

  /// 播放本地缓存的音频，返回是否播放成功。
  ///
  /// 失败时调用方应回退到 TTS —— 此前异常被静默吞掉，
  /// 表现为"点了发音既不响也不报错"。
  static Future<bool> playCachedAudio(String filePath) async {
    try {
      // 与本地 TTS 的播放器互斥：两条链路各持一个 AudioPlayer，不打断的话
      // 上一题的 TTS 朗读还在响时新词的在线音频就起播了（叠音）
      try {
        await TtsService().stop();
      } catch (_) {
        // TTS 停止失败不影响本次播放
      }
      await _ensureAudioContext();
      if (kIsWeb || filePath.startsWith('http')) {
        await _audioPlayer.play(UrlSource(filePath));
      } else {
        await _audioPlayer.play(DeviceFileSource(filePath));
      }
      return true;
    } catch (e) {
      debugPrint('音频播放失败：$e');
      // 删掉这个坏缓存（半截文件 / 被投毒响应）：否则每次点发音都会命中
      // 同一个坏文件，永远"点了不响"
      if (!kIsWeb && !filePath.startsWith('http')) {
        unawaited(cache.deleteIfExists(filePath).catchError((_) {}));
      }
      return false;
    }
  }

  static Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// 清空发音缓存。
  ///
  /// 切换口音（美音/英音）或音频来源后必须调用：缓存文件名只含单词，
  /// 不清的话已缓存过的词会一直播旧口音，且不会再发请求。
  static Future<void> clearAudioCache() async {
    try {
      await cache.clearAudioCache();
    } catch (e) {
      debugPrint('清空发音缓存失败：$e');
    }
  }

  /// 正在后台预热的单词（同一单词只预热一次）
  static final Set<String> _prefetching = {};

  /// 后台预热真人发音：点开发音时不再串行等
  /// dictionaryapi.dev → gstatic 两段网络（大陆网络基本不可达，
  /// 表现为"延迟十几秒或干脆没声"），而是立即走学习页同款快路径出声，
  /// 这里异步把真人音缓存好，下次点同一单词直接命中秒播。
  static void prefetchAudio(String word) {
    if (kIsWeb) return;
    final key = word.toLowerCase().trim();
    if (key.isEmpty || !_prefetching.add(key)) return;
    unawaited(() async {
      try {
        final result = await fetchWord(word);
        final url = result?.audioUrl;
        if (url != null) await downloadAndCacheAudio(url, word);
      } catch (e) {
        debugPrint('预热发音缓存失败：$word，$e');
      } finally {
        _prefetching.remove(key);
      }
    }());
  }

  static Future<String?> getCachedAudioPath(String word) async {
    try {
      if (kIsWeb) return null;
      final audioDir = await cache.audioCacheDir();
      final filePath = p.join(audioDir, '${_safeFileName(word)}.mp3');
      if (await cache.fileExists(filePath)) return filePath;
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// 词典查询结果
class DictionaryResult {
  final String word;
  final String? phonetic;
  final String? audioUrl;
  final String? definition;
  final String? example;

  DictionaryResult({
    required this.word,
    this.phonetic,
    this.audioUrl,
    this.definition,
    this.example,
  });
}

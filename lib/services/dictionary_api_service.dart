import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'http_retry_client.dart';
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

  /// 从 Free Dictionary API 获取单词信息（音标+音频 URL）
  static Future<DictionaryResult?> fetchWord(String word) async {
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
      if (kIsWeb) return audioUrl;
      final audioDir = await cache.audioCacheDir();
      final fileName = '${_safeFileName(word)}.mp3';
      final filePath = p.join(audioDir, fileName);
      if (await cache.fileExists(filePath)) return filePath;
      final response = await _retryClient.get(audioUrl, label: '音频下载');
      if (response.statusCode == 200) {
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

  static String _safeFileName(String word) {
    final sanitized = word
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized.isEmpty ? 'audio' : sanitized;
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

  /// 播放本地缓存的音频
  static Future<void> playCachedAudio(String filePath) async {
    try {
      if (kIsWeb || filePath.startsWith('http')) {
        await _audioPlayer.play(UrlSource(filePath));
      } else {
        await _audioPlayer.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      // 播放失败则忽略
    }
  }

  static Future<void> stop() async {
    await _audioPlayer.stop();
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

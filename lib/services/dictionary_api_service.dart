import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

/// HTTP 客户端配置
class _HttpClientConfig {
  // 请求超时时间（秒）
  static const int connectTimeout = 10;
  
  // 重试配置
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 500);
  static const double retryBackoffMultiplier = 2.0; // 指数退避倍数
}

/// 词典 API 服务 - 获取在线真人发音音频
class DictionaryApiService {
  static const String _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 创建可复用的 HTTP 客户端（连接池优化）
  static final http.Client _httpClient = http.Client();

  /// 带重试机制的 HTTP GET 请求
  static Future<http.Response> _getWithRetry(String url, {int maxRetries = _HttpClientConfig.maxRetries}) async {
    Exception? lastException;
    Duration delay = _HttpClientConfig.retryDelay;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // 首次尝试不延迟，后续尝试使用指数退避
        if (attempt > 0) {
          debugPrint('🔄 请求重试（${attempt + 1}/$maxRetries）：$url，等待 ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
          delay = Duration(milliseconds: (delay.inMilliseconds * _HttpClientConfig.retryBackoffMultiplier).toInt());
        }
        
        final response = await _httpClient
            .get(Uri.parse(url))
            .timeout(
              Duration(seconds: _HttpClientConfig.connectTimeout),
              onTimeout: () => throw TimeoutException('请求超时（${_HttpClientConfig.connectTimeout}s）'),
            );
        
        return response;
      } on SocketException catch (e) {
        lastException = e;
        debugPrint('⚠️ 网络错误（尝试 ${attempt + 1}/$maxRetries）：${e.message}');
      } on TimeoutException catch (e) {
        lastException = e;
        debugPrint('⚠️ 请求超时（尝试 ${attempt + 1}/$maxRetries）：${e.message}');
      } on http.ClientException catch (e) {
        lastException = e;
        debugPrint('⚠️ HTTP 客户端错误（尝试 ${attempt + 1}/$maxRetries）：${e.message}');
      } catch (e) {
        lastException = e as Exception;
        debugPrint('⚠️ 未知错误（尝试 ${attempt + 1}/$maxRetries）：$e');
      }
    }
    
    // 所有重试都失败
    debugPrint('❌ 请求最终失败：$url，错误：$lastException');
    throw lastException!;
  }

  /// 从 Free Dictionary API 获取单词信息（音标+音频 URL）
  static Future<DictionaryResult?> fetchWord(String word) async {
    try {
      final response = await _getWithRetry('$_baseUrl/${word.toLowerCase()}');
      
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

      // 提取音标和音频
      if (entry.containsKey('phonetics')) {
        final phonetics = entry['phonetics'] as List<dynamic>;
        for (var p in phonetics) {
          final pMap = p as Map<String, dynamic>;
          if (phonetic == null && pMap['text'] != null && (pMap['text'] as String).isNotEmpty) {
            phonetic = pMap['text'] as String;
          }
          if (audioUrl == null && pMap['audio'] != null && (pMap['audio'] as String).isNotEmpty) {
            audioUrl = pMap['audio'] as String;
          }
          if (phonetic != null && audioUrl != null) break;
        }
      }

      // 提取释义
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

      // 提取例句
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
    } on SocketException catch (e) {
      debugPrint('❌ 网络连接失败：$word，${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ 查询失败：$word，$e');
      return null;
    }
  }

  /// 下载音频并缓存到本地（带重试机制）
  static Future<String?> downloadAndCacheAudio(String audioUrl, String word) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = p.join(dir.path, 'audio_cache');
      final audioDirFile = Directory(audioDir);
      if (!await audioDirFile.exists()) {
        await audioDirFile.create(recursive: true);
      }

      final fileName = '${word.toLowerCase()}.mp3';
      final filePath = p.join(audioDir, fileName);

      // 已缓存则直接返回
      if (await File(filePath).exists()) return filePath;

      // 下载（使用重试机制）
      final response = await _getWithRetry(audioUrl);
      if (response.statusCode == 200) {
        await File(filePath).writeAsBytes(response.bodyBytes);
        return filePath;
      }
      debugPrint('⚠️ 音频下载失败：$word，状态码 ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ 音频下载异常：$word，$e');
      return null;
    }
  }

  /// 播放本地缓存的音频
  static Future<void> playCachedAudio(String filePath) async {
    try {
      await _audioPlayer.play(DeviceFileSource(filePath));
    } catch (e) {
      // 播放失败则忽略
    }
  }

  /// 停止播放
  static Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// 检查本地是否有缓存音频
  static Future<String?> getCachedAudioPath(String word) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = p.join(dir.path, 'audio_cache', '${word.toLowerCase()}.mp3');
      if (await File(filePath).exists()) return filePath;
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP 客户端配置
class _HttpClientConfig {
  // 请求超时时间（秒）
  static const int connectTimeout = 10;
  
  // 重试配置
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 500);
  static const double retryBackoffMultiplier = 2.0;
}

/// 有道词典 API 服务
/// 提供中文释义、音标、例句等
class YoudaoService {
  static const String _baseUrl = 'https://dict.youdao.com/suggest';
  
  // 创建可复用的 HTTP 客户端（连接池优化）
  static final http.Client _httpClient = http.Client();

  /// 带重试机制的 HTTP GET 请求
  static Future<http.Response> _getWithRetry(Uri uri, {int maxRetries = _HttpClientConfig.maxRetries}) async {
    Exception? lastException;
    Duration delay = _HttpClientConfig.retryDelay;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint('🔄 有道请求重试（${attempt + 1}/$maxRetries）：${uri.queryParameters['q']}，等待 ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
          delay = Duration(milliseconds: (delay.inMilliseconds * _HttpClientConfig.retryBackoffMultiplier).toInt());
        }
        
        final response = await _httpClient
            .get(uri)
            .timeout(
              Duration(seconds: _HttpClientConfig.connectTimeout),
              onTimeout: () => throw TimeoutException('请求超时（${_HttpClientConfig.connectTimeout}s）'),
            );
        
        return response;
      } on SocketException catch (e) {
        lastException = e;
        debugPrint('⚠️ 有道网络错误（尝试 ${attempt + 1}/$maxRetries）：${e.message}');
      } on TimeoutException catch (e) {
        lastException = e;
        debugPrint('⚠️ 有道请求超时（尝试 ${attempt + 1}/$maxRetries）：${e.message}');
      } on http.ClientException catch (e) {
        lastException = e;
        debugPrint('⚠️ 有道 HTTP 客户端错误（尝试 ${attempt + 1}/$maxRetries）：${e.message}');
      } catch (e) {
        lastException = e as Exception;
        debugPrint('⚠️ 有道未知错误（尝试 ${attempt + 1}/$maxRetries）：$e');
      }
    }
    
    debugPrint('❌ 有道请求最终失败：${uri.queryParameters['q']}，错误：$lastException');
    throw lastException!;
  }

  /// 查询单词（建议接口）
  /// 返回：音标、中文释义、例句（如果有）
  static Future<YoudaoResult?> fetchWord(String word) async {
    try {
      final queryParameters = {
        'num': '5',
        'ver': '3.0',
        'doctype': 'json',
        'cache': 'false',
        'le': 'en',
        'q': word,
      };
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParameters);
      
      final response = await _getWithRetry(uri);

      if (response.statusCode == 404) {
        debugPrint('⚠️ 有道单词未找到：$word');
        return null;
      }
      
      if (response.statusCode == 429) {
        debugPrint('⚠️ 有道请求频率限制：$word');
        return null;
      }
      
      if (response.statusCode != 200) {
        debugPrint('⚠️ 有道返回错误状态码 ${response.statusCode}：$word');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['errorCode'] != '0') {
        debugPrint('⚠️ 有道 API 错误码：${data['errorCode']}，单词：$word');
        return null;
      }

      final entries = data['data']?['entries'] as List?;
      if (entries == null || entries.isEmpty) return null;

      final entry = entries[0] as Map<String, dynamic>;

      // 提取音标
      String? phonetic;
      if (entry.containsKey('phone')) {
        phonetic = entry['phone'] as String?;
      } else if (entry.containsKey('ukphone')) {
        phonetic = 'UK ${entry['ukphone']}';
      } else if (entry.containsKey('usphone')) {
        phonetic = 'US ${entry['usphone']}';
      }

      // 提取中文释义（explain 字段是 "释义; 释义" 格式）
      String? definition;
      if (entry.containsKey('explain')) {
        final explain = (entry['explain'] as String).trim();
        if (explain.isNotEmpty) {
          // 解析为数组
          definition = explain.split(';').map((e) => e.trim()).join('\n');
        }
      }

      // 提取例句（如果有）
      String? example;
      String? exampleTranslation;
      if (entry.containsKey('sentences')) {
        final sentences = entry['sentences'] as List?;
        if (sentences != null && sentences.isNotEmpty) {
          final firstSent = sentences[0] as Map<String, dynamic>;
          example = firstSent['sentence'] as String?;
          exampleTranslation = firstSent['sentenceTranslate'] as String?;
        }
      }

      return YoudaoResult(
        word: word,
        phonetic: phonetic,
        definition: definition,
        example: example,
        exampleTranslation: exampleTranslation,
      );
    } on TimeoutException catch (e) {
      debugPrint('❌ 有道查询超时：$word，${e.message}');
      return null;
    } on SocketException catch (e) {
      debugPrint('❌ 有道网络连接失败：$word，${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ 有道查询失败：$word，$e');
      return null;
    }
  }

  /// 批量查询（一次多个词）- 有道建议接口不支持批量，这个方法仅作框架
  static Future<Map<String, YoudaoResult?>> fetchWords(List<String> words) async {
    final results = <String, YoudaoResult?>{};
    for (final w in words) {
      results[w] = await fetchWord(w);
      await Future.delayed(const Duration(milliseconds: 200)); // 限流
    }
    return results;
  }
}

/// 有道查询结果
class YoudaoResult {
  final String word;
  final String? phonetic;
  final String? definition;
  final String? example;
  final String? exampleTranslation;

  YoudaoResult({
    required this.word,
    this.phonetic,
    this.definition,
    this.example,
    this.exampleTranslation,
  });
}

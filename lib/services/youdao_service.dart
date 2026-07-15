import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_retry_client.dart';

/// 有道词典 API 服务
/// 提供中文释义、音标、例句等
class YoudaoService {
  static const String _baseUrl = 'https://dict.youdao.com/suggest';

  // 使用公共 HTTP 重试客户端
  static final HttpRetryClient _retryClient = HttpRetryClient();

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

      final response = await _retryClient.getUri(uri, label: '有道');

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
    } catch (e) {
      debugPrint('❌ 有道查询失败：$word，$e');
      return null;
    }
  }

  /// 批量查询（一次多个词）- 有道建议接口不支持批量，这个方法仅作框架
  static Future<Map<String, YoudaoResult?>> fetchWords(
    List<String> words,
  ) async {
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_retry_client.dart';

/// 有道词典 API 服务
/// 提供中文释义、音标、例句等
class YoudaoService {
  static const String _jsonApiUrl = 'https://dict.youdao.com/jsonapi';
  static const String _suggestUrl = 'https://dict.youdao.com/suggest';

  //使用公共 HTTP 重试客户端
  static final HttpRetryClient _retryClient = HttpRetryClient();

  /// 释放静态 HTTP 客户端资源
  static void shutdown() {
    _retryClient.dispose();
  }

  //正则提升为静态实例：每次查询、每条例句都会用到，重复编译会增加无谓开销
  static final RegExp _trimNonAlnum = RegExp(
    r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$',
  );
  static final RegExp _htmlTag = RegExp(r'<[^>]*>');

  /// 查询单词（完整接口优先，获取音标、中文释义、英文例句及例句中文翻译）
  static Future<YoudaoResult?> fetchWord(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;

    // 清洗首尾非字母数字字符（去除标点/括号/引号等）
    final cleaned = trimmed.replaceAll(_trimNonAlnum, '');
    final targetWord = cleaned.isNotEmpty ? cleaned : trimmed;

    // 1. 优先请求完整 jsonapi 接口获取双语例句与详细释义
    var fullResult = await _fetchFromJsonApi(targetWord);

    // 若未查到例句且单词含大写，尝试全小写查询以获得更全例句
    if (fullResult?.example == null && targetWord != targetWord.toLowerCase()) {
      final lowerResult = await _fetchFromJsonApi(targetWord.toLowerCase());
      if (lowerResult?.example != null) {
        fullResult = YoudaoResult(
          word: targetWord,
          phonetic: fullResult?.phonetic ?? lowerResult?.phonetic,
          definition: fullResult?.definition ?? lowerResult?.definition,
          example: lowerResult?.example,
          exampleTranslation: lowerResult?.exampleTranslation,
        );
      }
    }

    if (fullResult != null &&
        (fullResult.example != null || fullResult.definition != null)) {
      return fullResult;
    }

    // 2. 降级尝试 suggest 接口
    final suggestResult = await _fetchFromSuggest(targetWord);
    if (suggestResult != null) {
      return YoudaoResult(
        word: targetWord,
        phonetic: fullResult?.phonetic ?? suggestResult.phonetic,
        definition: suggestResult.definition ?? fullResult?.definition,
        example: fullResult?.example,
        exampleTranslation: fullResult?.exampleTranslation,
      );
    }

    return fullResult;
  }

  /// 通过有道 jsonapi 接口查询
  static Future<YoudaoResult?> _fetchFromJsonApi(String word) async {
    try {
      final uri = Uri.parse('$_jsonApiUrl?q=${Uri.encodeComponent(word)}');
      final response = await _retryClient.getUri(uri, label: '有道词典');

      if (response.statusCode != 200) {
        debugPrint('⚠️ 有道 jsonapi 返回状态码 ${response.statusCode}：$word');
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      String? phonetic;
      String? definition;
      String? example;
      String? exampleTranslation;

      // 提取双语例句（blng_sents_part）
      if (decoded['blng_sents_part'] is Map) {
        final blng = decoded['blng_sents_part'] as Map<String, dynamic>;
        final pairs = blng['sentence-pair'] as List?;
        if (pairs != null && pairs.isNotEmpty) {
          for (final item in pairs) {
            if (item is Map) {
              final s = (item['sentence'] as String?)?.trim();
              final t = (item['sentence-translation'] as String?)?.trim();
              if (s != null && s.isNotEmpty) {
                example = s.replaceAll(_htmlTag, '').trim();
                exampleTranslation = t
                    ?.replaceAll(_htmlTag, '')
                    .trim();
                break;
              }
            }
          }
        }
      }

      // 若无双语例句，尝试原声媒体例句（media_sents_part）
      if (example == null && decoded['media_sents_part'] is Map) {
        final media = decoded['media_sents_part'] as Map<String, dynamic>;
        final sents = media['sent'] as List?;
        if (sents != null && sents.isNotEmpty) {
          for (final item in sents) {
            if (item is Map) {
              final eng = (item['eng'] as String?)
                  ?.replaceAll(_htmlTag, '')
                  .trim();
              final chn = (item['chn'] as String?)
                  ?.replaceAll(_htmlTag, '')
                  .trim();
              if (eng != null && eng.isNotEmpty) {
                example = eng;
                exampleTranslation = chn;
                break;
              }
            }
          }
        }
      }

      // 若仍无例句，尝试柯林斯例句（collins）
      if (example == null && decoded['collins'] is Map) {
        final collins = decoded['collins'] as Map<String, dynamic>;
        final collinsEntries = collins['collins_entries'] as List?;
        if (collinsEntries != null && collinsEntries.isNotEmpty) {
          for (final entry in collinsEntries) {
            if (entry is Map) {
              final transEntries = entry['entries'] as Map<String, dynamic>?;
              final entryList = transEntries?['entry'] as List?;
              if (entryList != null) {
                for (final item in entryList) {
                  if (item is Map) {
                    final tranEntry = item['tran_entry'] as List?;
                    if (tranEntry != null) {
                      for (final tran in tranEntry) {
                        if (tran is Map) {
                          final examSents =
                              tran['exam_sents'] as Map<String, dynamic>?;
                          final sentList = examSents?['sent'] as List?;
                          if (sentList != null &&
                              sentList.isNotEmpty &&
                              sentList[0] is Map) {
                            final s = (sentList[0]['eng_sent'] as String?)
                                ?.trim();
                            final t = (sentList[0]['chn_sent'] as String?)
                                ?.trim();
                            if (s != null && s.isNotEmpty) {
                              example = s
                                  .replaceAll(_htmlTag, '')
                                  .trim();
                              exampleTranslation = t
                                  ?.replaceAll(_htmlTag, '')
                                  .trim();
                              break;
                            }
                          }
                        }
                      }
                    }
                  }
                  if (example != null) break;
                }
              }
            }
            if (example != null) break;
          }
        }
      }

      // 提取英汉词典基础信息（ec）
      if (decoded['ec'] is Map) {
        final ec = decoded['ec'] as Map<String, dynamic>;
        final words = ec['word'] as List?;
        if (words != null && words.isNotEmpty && words[0] is Map) {
          final w = words[0] as Map<String, dynamic>;
          phonetic =
              (w['usphone'] as String?) ??
              (w['ukphone'] as String?) ??
              (w['phone'] as String?);

          final trs = w['trs'] as List?;
          if (trs != null && trs.isNotEmpty) {
            final List<String> defs = [];
            for (final trItem in trs) {
              if (trItem is Map) {
                final trList = trItem['tr'] as List?;
                if (trList != null) {
                  for (final subTr in trList) {
                    if (subTr is Map && subTr['l'] is Map) {
                      final iList = subTr['l']['i'] as List?;
                      if (iList != null) {
                        for (final val in iList) {
                          if (val is String && val.trim().isNotEmpty) {
                            defs.add(val.trim());
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            if (defs.isNotEmpty) {
              definition = defs.join('\n');
            }
          }
        }
      }

      // 提取 simple 信息作为音标或释义兜底
      if (phonetic == null && decoded['simple'] is Map) {
        final simple = decoded['simple'] as Map<String, dynamic>;
        final words = simple['word'] as List?;
        if (words != null && words.isNotEmpty && words[0] is Map) {
          final w = words[0] as Map<String, dynamic>;
          phonetic = (w['usphone'] as String?) ?? (w['ukphone'] as String?);
        }
      }

      if (phonetic == null &&
          definition == null &&
          example == null &&
          exampleTranslation == null) {
        return null;
      }

      return YoudaoResult(
        word: word,
        phonetic: phonetic,
        definition: definition,
        example: example,
        exampleTranslation: exampleTranslation,
      );
    } catch (e) {
      debugPrint('⚠️ 有道 jsonapi 查询异常：$word，$e');
      return null;
    }
  }

  /// 建议接口兜底（suggest）
  static Future<YoudaoResult?> _fetchFromSuggest(String word) async {
    try {
      final queryParameters = {
        'num': '5',
        'ver': '3.0',
        'doctype': 'json',
        'cache': 'false',
        'le': 'en',
        'q': word,
      };
      final uri = Uri.parse(
        _suggestUrl,
      ).replace(queryParameters: queryParameters);
      final response = await _retryClient.getUri(uri, label: '有道Suggest');

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final entries = data['data']?['entries'] as List?;
      if (entries == null || entries.isEmpty) return null;

      final entry = entries[0] as Map<String, dynamic>;

      String? phonetic;
      if (entry.containsKey('phone')) {
        phonetic = entry['phone'] as String?;
      } else if (entry.containsKey('ukphone')) {
        phonetic = 'UK ${entry['ukphone']}';
      } else if (entry.containsKey('usphone')) {
        phonetic = 'US ${entry['usphone']}';
      }

      String? definition;
      if (entry.containsKey('explain')) {
        final explain = (entry['explain'] as String).trim();
        if (explain.isNotEmpty) {
          definition = explain.split(';').map((e) => e.trim()).join('\n');
        }
      }

      return YoudaoResult(
        word: word,
        phonetic: phonetic,
        definition: definition,
      );
    } catch (e) {
      debugPrint('⚠️ 有道 Suggest 查询异常：$word，$e');
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

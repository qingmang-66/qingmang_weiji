import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP 重试客户端配置
class HttpRetryConfig {
  final int connectTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final double retryBackoffMultiplier;

  /// 整条链路（含所有重试与等待）的总时间预算。
  ///
  /// 此前只有"单次请求超时"，重试次数与退避叠起来最坏 ≈（10s×3 + 0.5+1s）≈31.5s，
  /// 期间调用方（查词/发音）没有任何反馈，用户只能以为卡死。超过预算就立刻放弃。
  final Duration totalBudget;

  const HttpRetryConfig({
    this.connectTimeout = 10,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
    this.retryBackoffMultiplier = 2.0,
    this.totalBudget = const Duration(seconds: 20),
  });
}

/// 通用 HTTP 重试客户端
class HttpRetryClient {
  final http.Client _httpClient;
  final HttpRetryConfig _config;

  HttpRetryClient({
    http.Client? httpClient,
    HttpRetryConfig config = const HttpRetryConfig(),
  }) : _httpClient = httpClient ?? http.Client(),
       _config = config;

  /// 解析 Retry-After（秒数或 HTTP 日期），上限 30s。
  ///
  /// 429 时按服务端给出的等待时间退避，而不是固定 500ms 立刻再打一次
  /// （那样只会加重限流，通常还会再吃一次 429）。
  static Duration? _parseRetryAfter(Map<String, String> headers) {
    final raw = headers['retry-after'];
    if (raw == null || raw.trim().isEmpty) return null;
    const cap = Duration(seconds: 30);
    final seconds = int.tryParse(raw.trim());
    if (seconds != null) {
      if (seconds <= 0) return Duration.zero;
      final value = Duration(seconds: seconds);
      return value > cap ? cap : value;
    }
    final date = DateTime.tryParse(raw.trim());
    if (date == null) return null;
    final delta = date.difference(DateTime.now());
    if (delta.isNegative) return Duration.zero;
    return delta > cap ? cap : delta;
  }

  /// 日志用地址：去掉 query/fragment/userinfo，只保留 scheme://host:port/path。
  ///
  /// 完整 URL 未来若拼入 token/查询参数会随日志泄露，且 debugPrint 在 release
  /// 下同样会输出。
  static String _redactUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || uri.host.isEmpty) return url;
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port${uri.path}';
    } catch (_) {
      return url;
    }
  }

  /// 带重试机制的 HTTP GET 请求
  Future<http.Response> get(String url, {String label = 'HTTP'}) async {
    Exception? lastException;
    Duration delay = _config.retryDelay;
    final deadline = DateTime.now().add(_config.totalBudget);

    for (int attempt = 0; attempt < _config.maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final remaining = deadline.difference(DateTime.now());
          if (remaining <= Duration.zero) {
            debugPrint(
              '⏹ $label 已超出总时间预算（${_config.totalBudget.inSeconds}s），停止重试',
            );
            break;
          }
          final wait = delay < remaining ? delay : remaining;
          debugPrint(
            '🔄 $label 重试（${attempt + 1}/${_config.maxRetries}）：${_redactUrl(url)}，等待 ${wait.inMilliseconds}ms',
          );
          await Future.delayed(wait);
          delay = Duration(
            milliseconds:
                (delay.inMilliseconds * _config.retryBackoffMultiplier).toInt(),
          );
        }

        final response = await _httpClient
            .get(Uri.parse(url))
            .timeout(
              Duration(seconds: _config.connectTimeout),
              onTimeout: () =>
                  throw TimeoutException('请求超时（${_config.connectTimeout}s）'),
            );

        //5xx / 429 属于可恢复的服务端错误，重试；其余状态码交给调用方处理
        if (response.statusCode >= 500 || response.statusCode == 429) {
          lastException = Exception('HTTP ${response.statusCode}');
          debugPrint(
            '⚠️ $label 服务端错误（尝试 ${attempt + 1}/${_config.maxRetries}）：${response.statusCode}',
          );
          if (attempt == _config.maxRetries - 1) return response;
          if (response.statusCode == 429) {
            final retryAfter = _parseRetryAfter(response.headers);
            if (retryAfter != null) delay = retryAfter;
          }
          continue;
        }

        return response;
      } on TimeoutException catch (e) {
        lastException = e;
        debugPrint(
          '⚠️ $label 请求超时（尝试 ${attempt + 1}/${_config.maxRetries}）：${e.message}',
        );
      } on http.ClientException catch (e) {
        lastException = e;
        debugPrint(
          '⚠️ $label HTTP 客户端错误（尝试 ${attempt + 1}/${_config.maxRetries}）：${e.message}',
        );
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint(
          '⚠️ $label 网络/未知错误（尝试 ${attempt + 1}/${_config.maxRetries}）：$e',
        );
      }
    }

    debugPrint('❌ $label 请求最终失败：${_redactUrl(url)}，错误：$lastException');
    //maxRetries <= 0 时循环一次都没跑，lastException 为 null，不能用 ! 断言
    throw lastException ??
        Exception(
          '$label 请求未执行（maxRetries=${_config.maxRetries}）：${_redactUrl(url)}',
        );
  }

  Future<http.Response> getUri(Uri uri, {String label = 'HTTP'}) async {
    return get(uri.toString(), label: label);
  }

  void dispose() {
    _httpClient.close();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP 重试客户端配置
class HttpRetryConfig {
  final int connectTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final double retryBackoffMultiplier;

  const HttpRetryConfig({
    this.connectTimeout = 10,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
    this.retryBackoffMultiplier = 2.0,
  });
}

/// 通用 HTTP 重试客户端
/// 封装了超时、指数退避重试逻辑，避免在多个服务中重复实现
class HttpRetryClient {
  final http.Client _httpClient;
  final HttpRetryConfig _config;

  HttpRetryClient({
    http.Client? httpClient,
    HttpRetryConfig config = const HttpRetryConfig(),
  })  : _httpClient = httpClient ?? http.Client(),
        _config = config;

  /// 带重试机制的 HTTP GET 请求
  /// [url] 请求地址
  /// [label] 日志标签，用于区分不同服务的请求
  Future<http.Response> get(String url, {String label = 'HTTP'}) async {
    Exception? lastException;
    Duration delay = _config.retryDelay;

    for (int attempt = 0; attempt < _config.maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint('🔄 $label 重试（${attempt + 1}/${_config.maxRetries}）：$url，等待 ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
          delay = Duration(milliseconds: (delay.inMilliseconds * _config.retryBackoffMultiplier).toInt());
        }

        final response = await _httpClient
            .get(Uri.parse(url))
            .timeout(
              Duration(seconds: _config.connectTimeout),
              onTimeout: () => throw TimeoutException('请求超时（${_config.connectTimeout}s）'),
            );

        return response;
      } on SocketException catch (e) {
        lastException = e;
        debugPrint('⚠️ $label 网络错误（尝试 ${attempt + 1}/${_config.maxRetries}）：${e.message}');
      } on TimeoutException catch (e) {
        lastException = e;
        debugPrint('⚠️ $label 请求超时（尝试 ${attempt + 1}/${_config.maxRetries}）：${e.message}');
      } on http.ClientException catch (e) {
        lastException = e;
        debugPrint('⚠️ $label HTTP 客户端错误（尝试 ${attempt + 1}/${_config.maxRetries}）：${e.message}');
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint('⚠️ $label 未知错误（尝试 ${attempt + 1}/${_config.maxRetries}）：$e');
      }
    }

    debugPrint('❌ $label 请求最终失败：$url，错误：$lastException');
    throw lastException!;
  }

  /// 带重试机制的 HTTP GET 请求（Uri 版本）
  Future<http.Response> getUri(Uri uri, {String label = 'HTTP'}) async {
    return get(uri.toString(), label: label);
  }

  /// 释放资源
  void dispose() {
    _httpClient.close();
  }
}

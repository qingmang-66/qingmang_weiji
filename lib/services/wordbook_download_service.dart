import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'wordbook_download_io.dart'
    if (dart.library.html) 'wordbook_download_web.dart' as io;

/// 词库下载服务 - 支持进度回调
class WordBookDownloadService {
  /// 下载词库文件（带进度回调）
  static Future<String?> download(
    String url,
    String wordBookName, {
    void Function(int progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0, '正在连接...');
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () => throw Exception('下载超时'),
          );
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
      onProgress?.call(30, '正在下载...');
      if (kIsWeb) {
        // Web 端返回内存内容路径标记，由调用方直接解析文本
        onProgress?.call(100, '完成！');
        return 'webmemory://${Uri.encodeComponent(response.body)}';
      }
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${wordBookName.replaceAll(' ', '_')}_$timestamp.txt';
      final filePath = p.join(appDir.path, 'wordbooks', fileName);
      await io.ensureParentDir(filePath);
      onProgress?.call(60, '正在保存...');
      await io.writeString(filePath, response.body);
      onProgress?.call(100, '完成！');
      debugPrint('词库已下载到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('下载词库失败: $e');
      onProgress?.call(0, '下载失败');
      return null;
    }
  }

  static List<Map<String, String>> getDownloadOptions() {
    final base = 'https://cdn.jsdelivr.net/gh';
    return [
      {
        'name': 'CET-4 词汇',
        'description': '大学英语四级词汇（约 2500 词）',
        'url': '$base/mahavivo/english-word-lists/master/cet4.txt',
        'category': 'CET',
      },
      {
        'name': 'CET-6 词汇',
        'description': '大学英语六级词汇（约 2500 词）',
        'url': '$base/mahavivo/english-word-lists/master/cet6.txt',
        'category': 'CET',
      },
      {
        'name': '考研英语词汇',
        'description': '考研英语大纲词汇',
        'url': '$base/mahavivo/english-word-lists/master/kaoyan.txt',
        'category': '考研',
      },
      {
        'name': '高考英语词汇',
        'description': '高考英语必背词汇（约 3500 词）',
        'url': '$base/mahavivo/english-word-lists/master/gaokao.txt',
        'category': '高考',
      },
      {
        'name': '雅思核心词汇',
        'description': '雅思考试核心词汇（约 3000 词）',
        'url': '$base/mahavivo/english-word-lists/master/ielts.txt',
        'category': '雅思',
      },
      {
        'name': '托福核心词汇',
        'description': '托福考试核心词汇（约 3500 词）',
        'url': '$base/mahavivo/english-word-lists/master/toefl.txt',
        'category': '托福',
      },
    ];
  }

  static Map<String, List<Map<String, String>>> getOptionsByCategory() {
    final options = getDownloadOptions();
    final result = <String, List<Map<String, String>>>{};
    for (final opt in options) {
      final category = opt['category'] ?? '其他';
      result.putIfAbsent(category, () => []).add(opt);
    }
    return result;
  }
}

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// 词库下载服务 - 支持进度回调
class WordBookDownloadService {
  /// 下载词库文件（带进度回调）
  /// [url] 下载地址
  /// [wordBookName] 词库名称
  /// [onProgress] 进度回调：参数为 (当前进度 0-100, 状态文本)
  static Future<String?> download(
    String url, 
    String wordBookName, {
    void Function(int progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0, '正在连接...');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw Exception('下载超时'),
      );

      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      onProgress?.call(30, '正在下载...');

      // 计算下载大小（如果服务器返回 Content-Length）
      
      // 保存到应用目录
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${wordBookName.replaceAll(' ', '_')}_$timestamp.txt';
      final filePath = p.join(appDir.path, 'wordbooks', fileName);

      // 确保目录存在
      final dir = Directory(p.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      onProgress?.call(60, '正在保存...');

      // 写入文件
      final file = File(filePath);
      await file.writeAsString(response.body);

      onProgress?.call(100, '完成！');
      debugPrint('词库已下载到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('下载词库失败: $e');
      onProgress?.call(0, '下载失败');
      return null;
    }
  }

  /// 获取预设的词库下载列表（从多个开源项目，使用国内镜像）
  static List<Map<String, String>> getDownloadOptions() {
    // 使用 jsDelivr 镜像加速 GitHub Raw 访问（国内可用）
    final base = 'https://cdn.jsdelivr.net/gh';
    
    return [
      // === CET 考试 ===
      {'name': 'CET-4 词汇', 'description': '大学英语四级词汇（约 2500 词）', 'url': '$base/mahavivo/english-word-lists/master/cet4.txt', 'category': 'CET'},
      {'name': 'CET-6 词汇', 'description': '大学英语六级词汇（约 2500 词）', 'url': '$base/mahavivo/english-word-lists/master/cet6.txt', 'category': 'CET'},
      {'name': '考研英语词汇', 'description': '考研英语大纲词汇', 'url': '$base/mahavivo/english-word-lists/master/kaoyan.txt', 'category': '考研'},
      
      // === 高考/留学 ===
      {'name': '高考英语词汇', 'description': '高考英语必背词汇（约 3500 词）', 'url': '$base/mahavivo/english-word-lists/master/gaokao.txt', 'category': '高考'},
      {'name': '雅思核心词汇', 'description': '雅思考试核心词汇（约 3000 词）', 'url': '$base/mahavivo/english-word-lists/master/ielts.txt', 'category': '雅思'},
      {'name': '托福核心词汇', 'description': '托福考试核心词汇（约 3500 词）', 'url': '$base/mahavivo/english-word-lists/master/toefl.txt', 'category': '托福'},
      
      // === 日常/专业 ===
      {'name': '日常口语 1000 词', 'description': '日常交流必备基础词汇', 'url': '$base/mahavivo/english-word-lists/master/daily.txt', 'category': '日常'},
      {'name': '商务英语词汇', 'description': '商务场合常用词汇', 'url': '$base/mahavivo/english-word-lists/master/business.txt', 'category': '商务'},
      {'name': 'IT 行业词汇', 'description': '计算机/软件行业常用英语', 'url': '$base/mahavivo/english-word-lists/master/tech.txt', 'category': '专业'},
      {'name': '医学英语词汇', 'description': '医学领域专业英语', 'url': '$base/mahavivo/english-word-lists/master/medical.txt', 'category': '专业'},
      
      // === 更多来源 ===
      {'name': 'GRE 核心词汇', 'description': 'GRE 考试核心词汇（约 1000 词）', 'url': '$base/liu6733/oxford-word/main/gre.txt', 'category': 'GRE'},
      {'name': '高频单词 2000', 'description': '英语使用频率最高的 2000 词', 'url': '$base/liu6733/oxford-word/main/top2000.txt', 'category': '基础'},
      {'name': '初中英语词汇', 'description': '初中英语必背词汇（约 1600 词）', 'url': '$base/liu6733/oxford-word/main/middle.txt', 'category': '基础'},
      {'name': '高中英语词汇', 'description': '高中英语必背词汇（约 3500 词）', 'url': '$base/liu6733/oxford-word/main/high.txt', 'category': '基础'},
      {'name': '专四核心词汇', 'description': '英语专业四级核心词汇', 'url': '$base/mahavivo/english-word-lists/master/tem4.txt', 'category': '专业'},
      {'name': '专八核心词汇', 'description': '英语专业八级核心词汇', 'url': '$base/mahavivo/english-word-lists/master/tem8.txt', 'category': '专业'},
    ];
  }

  /// 按分类获取词库
  static Map<String, List<Map<String, String>>> getOptionsByCategory() {
    final options = getDownloadOptions();
    final result = <String, List<Map<String, String>>>{};
    
    for (final opt in options) {
      final category = opt['category'] ?? '其他';
      final list = result.putIfAbsent(category, () => []);
      list.add(opt);
    }
    
    return result;
  }
}

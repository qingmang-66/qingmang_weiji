import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// 数据备份服务
/// 支持一键导出所有数据（词库、单词、复习记录）为 JSON 文件
/// 支持从 JSON 文件恢复数据
class BackupService {
  /// 备份所有数据到指定文件
  /// [filePath] 可选，如果不传则保存到应用文档目录
  /// 返回保存的文件路径
  static Future<String> backupData({String? filePath}) async {
    try {
      // 获取所有数据
      final wordBooks = await DatabaseService.getAllWordBooks();
      final words = await DatabaseService.getAllWords();
      final records = await DatabaseService.getAllReviewRecords();
      final data = {
        'version': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'wordBooks': wordBooks.map((b) => b.toMap()).toList(),
        'words': words.map((w) => w.toMap()).toList(),
        'reviewRecords': records.map((r) => r.toMap()).toList(),
      };
      final jsonString = jsonEncode(data);

      // 确定保存路径
      final targetPath = filePath ?? await _getDefaultBackupPath();
      final file = File(targetPath);
      await file.writeAsString(jsonString);
      debugPrint('数据备份成功：$targetPath');
      return targetPath;
    } catch (e) {
      debugPrint('备份失败：$e');
      rethrow;
    }
  }

  /// 从文件恢复数据
  /// [filePath] JSON 文件路径
  /// 返回恢复的统计信息
  static Future<Map<String, int>> restoreData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('备份文件不存在');
      }
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // 验证版本兼容性
      final version = data['version'] as String?;
      if (version == null) {
        throw Exception('备份文件格式错误：缺少版本号');
      }
      if (!_isCompatibleVersion(version)) {
        throw Exception('不支持的备份版本：$version (当前仅支持 1.x.x)');
      }

      // 使用 DatabaseService.importAll 恢复所有数据
      await DatabaseService.importAll(data);

      final wordBooksList = data['word_books'] as List;
      final wordsList = data['words'] as List;
      final recordsList = data['review_records'] as List;
      final result = {
        'wordBooks': wordBooksList.length,
        'words': wordsList.length,
        'records': recordsList.length,
      };
      debugPrint('数据恢复成功：$result');
      return result;
    } catch (e) {
      debugPrint('恢复失败：$e');
      rethrow;
    }
  }

  /// 检查版本是否兼容
  static bool _isCompatibleVersion(String version) {
    try {
      final parts = version.split('.');
      if (parts.isEmpty) return false;
      final major = int.tryParse(parts[0]);
      return major == 1; // 支持 1.x.x 系列
    } catch (e) {
      return false;
    }
  }

  /// 获取默认备份文件路径
  static Future<String> _getDefaultBackupPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/qingmang_backup_$timestamp.json';
  }

  /// 获取所有备份文件列表
  static Future<List<File>> getBackupFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/qingmang_backups');
      if (!await backupDir.exists()) {
        return [];
      }
      final files = backupDir.listSync().whereType<File>().toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (e) {
      debugPrint('获取备份文件列表失败：$e');
      return [];
    }
  }
}

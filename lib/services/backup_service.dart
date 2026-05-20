import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// 数据备份服务
/// 支持一键导出所有数据（词库、单词、复习记录）为 JSON 文件
/// 支持从 JSON 文件恢复数据
class BackupService {
  static Future<Directory> getBackupDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(directory.path, 'qingmang_backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 备份所有数据到指定文件
  /// [filePath] 可选，如果不传则保存到应用文档目录
  /// 返回保存的文件路径
  static Future<String> backupData({String? filePath}) async {
    try {
      final data = await DatabaseService.exportAll();
      final jsonString = const JsonEncoder.withIndent(' ').convert(data);
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
        throw Exception('不支持的备份版本：$version');
      }

      await DatabaseService.importAll(data);

      final result = {
        'wordBooks': ((data['word_books'] as List?) ?? []).length,
        'words': ((data['words'] as List?) ?? []).length,
        'records': ((data['review_records'] as List?) ?? []).length,
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
      return major == 1 || major == 2;
    } catch (e) {
      return false;
    }
  }

  /// 获取默认备份文件路径
  static Future<String> _getDefaultBackupPath() async {
    final backupDir = await getBackupDirectory();
    final now = DateTime.now();
    final filename = 'qingmang_backup_'
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}.json';
    return p.join(backupDir.path, filename);
  }

  /// 获取所有备份文件列表
  static Future<List<File>> getBackupFiles() async {
    try {
      final backupDir = await getBackupDirectory();
      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (e) {
      debugPrint('获取备份文件列表失败：$e');
      return [];
    }
  }

  static Future<void> clearAllData() => DatabaseService.clearAllData();
}

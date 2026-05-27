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
  static const int _maxBackupBytes = 20 * 1024 * 1024;
  static const int _maxBackupRows = 200000;

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
      final size = await file.length();
      if (size > _maxBackupBytes) {
        throw Exception('备份文件过大，请选择小于 20MB 的备份文件');
      }

      final jsonString = await file.readAsString();
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('备份文件格式错误：根节点必须是对象');
      }
      final data = decoded;
      _validateBackupData(data);

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

  static void _validateBackupData(Map<String, dynamic> data) {
    const listKeys = [
      'word_books',
      'words',
      'review_records',
      'study_sessions',
      'achievements',
      'wrong_words',
      'study_progress',
    ];

    var totalRows = 0;
    for (final key in listKeys) {
      final value = data[key];
      if (value == null) continue;
      if (value is! List) {
        throw Exception('备份文件格式错误：$key 必须是数组');
      }
      totalRows += value.length;
      if (totalRows > _maxBackupRows) {
        throw Exception('备份数据过大，超过 $_maxBackupRows 条记录限制');
      }
      if (value.any((item) => item is! Map)) {
        throw Exception('备份文件格式错误：$key 中包含无效记录');
      }
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
      final fileStats = await Future.wait(
      files.map((f) async => MapEntry(f, await f.stat())),
    );
    fileStats.sort((a, b) => b.value.modified.compareTo(a.value.modified));
    return fileStats.map((e) => e.key).toList();
    } catch (e) {
      debugPrint('获取备份文件列表失败：$e');
      return [];
    }
  }

  static Future<void> clearAllData() => DatabaseService.clearAllData();
}

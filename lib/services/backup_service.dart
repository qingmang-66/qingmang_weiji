import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/file_compat.dart';
import 'backup_io.dart' if (dart.library.html) 'backup_web.dart' as io;
import 'database_service.dart';

typedef BackupFileReplacer =
    Future<void> Function({required AppFile temp, required AppFile target});

class BackupService {
  static const int _maxBackupBytes = 20 * 1024 * 1024;
  static const int _maxBackupRows = 200000;
  static Future<String> Function() _directoryLoader = _defaultDirectory;
  static Future<Map<String, dynamic>> Function() _exportLoader =
      DatabaseService.exportAll;
  static Future<void> Function(Map<String, dynamic>) _importLoader =
      DatabaseService.importAll;
  static BackupFileReplacer _fileReplacer = atomicReplaceTarget;

  static void configureForTesting({
    required Future<String> Function() backupDirectoryLoader,
    required Future<Map<String, dynamic>> Function() exportLoader,
    required Future<void> Function(Map<String, dynamic>) importLoader,
    BackupFileReplacer? fileReplacer,
  }) {
    _directoryLoader = backupDirectoryLoader;
    _exportLoader = exportLoader;
    _importLoader = importLoader;
    _fileReplacer = fileReplacer ?? atomicReplaceTarget;
  }

  static Future<String> _defaultDirectory() async {
    if (kIsWeb) return 'web_backups';
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'qingmang_backups');
  }

  static Future<String> getBackupDirectory() async {
    final directory = await _directoryLoader();
    await io.ensureDir(directory);
    return directory;
  }

  static Future<String> backupData({String? filePath}) async {
    final data = await _exportLoader();
    final targetPath = filePath ?? await _getDefaultBackupPath();
    final json = await compute(_encodeBackupJson, data);
    if (kIsWeb) {
      await io.downloadText(
        p.basename(targetPath),
        json,
        mimeType: 'application/json',
      );
      debugPrint('数据备份成功（Web下载）：$targetPath');
      return targetPath;
    }
    await io.ensureParentDir(targetPath);
    final tempPath = '$targetPath.tmp';
    try {
      await io.writeString(tempPath, json);
      await _fileReplacer(
        temp: AppFile(tempPath),
        target: AppFile(targetPath),
      );
      debugPrint('数据备份成功：$targetPath');
      return targetPath;
    } catch (e) {
      await io.deleteIfExists(tempPath);
      rethrow;
    }
  }

  static Future<String> backupAndShare({String? subject}) async {
    final path = await backupData();
    if (!kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/json')],
          subject: subject ?? '清茫微记备份',
        ),
      );
    }
    return path;
  }

  static Future<Map<String, int>> restoreFromFile(AppFile file) async {
    final raw = await io.readString(file.path);
    return restoreFromRaw(raw);
  }

  static Future<Map<String, int>> restoreFromBytes(List<int> bytes) async {
    if (bytes.length > _maxBackupBytes) {
      throw Exception('备份文件过大，请选择小于20MB的备份文件');
    }
    return restoreFromRaw(utf8.decode(bytes));
  }

  static Future<Map<String, int>> restoreFromRaw(String raw) async {
    final decoded = await compute(_decodeBackupJson, raw);
    if (decoded is! Map) {
      throw Exception('备份文件格式错误：根节点必须是对象');
    }
    final root = Map<String, dynamic>.from(decoded);
    final tables = _validateBackupData(root);
    await _importLoader(tables);
    return {
      'wordBooks': (tables['word_books'] as List?)?.length ?? 0,
      'words': (tables['words'] as List?)?.length ?? 0,
      'records': (tables['review_records'] as List?)?.length ?? 0,
      'studyPlans': (tables['study_plans'] as List?)?.length ?? 0,
      'favorites': (tables['favorites'] as List?)?.length ?? 0,
      'customWordSets': (tables['custom_word_sets'] as List?)?.length ?? 0,
    };
  }

  @visibleForTesting
  static Future<void> atomicReplaceTarget({
    required AppFile temp,
    required AppFile target,
  }) async {
    await io.atomicReplace(temp.path, target.path);
  }

  static Future<Map<String, int>> restoreData(String filePath) async {
    final raw = await io.readString(filePath);
    return restoreFromRaw(raw);
  }

  static Map<String, dynamic> _validateBackupData(Map<String, dynamic> data) {
    if (data['appVersion'] is! String) throw Exception('备份文件格式错误：缺少appVersion');
    if (data['schemaVersion'] is! int) {
      throw Exception('备份文件格式错误：缺少schemaVersion');
    }
    if (data['schemaVersion'] != DatabaseService.schemaVersion) {
      throw Exception('不支持的schemaVersion：${data['schemaVersion']}');
    }
    final rawTables = data['tables'];
    if (rawTables is! Map) throw Exception('备份文件格式错误：tables必须是对象');
    final tables = Map<String, dynamic>.from(rawTables);
    var totalRows = 0;
    for (final table in DatabaseService.backupTables) {
      final rows = tables[table];
      if (rows == null) continue;
      if (rows is! List) throw Exception('备份文件格式错误：$table必须是数组');
      totalRows += rows.length;
      if (totalRows > _maxBackupRows) {
        throw Exception('备份数据过大，超过$_maxBackupRows条记录限制');
      }
      if (rows.any((row) => row is! Map)) {
        throw Exception('备份文件格式错误：$table中包含无效记录');
      }
    }
    return tables;
  }

  static Future<String> _getDefaultBackupPath() async {
    final directory = await getBackupDirectory();
    final now = DateTime.now();
    final filename =
        'qingmang_backup_'
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.json';
    return p.join(directory, filename);
  }

  static Future<List<AppFile>> getBackupFiles() async {
    final directory = await getBackupDirectory();
    final paths = await io.listJsonFiles(directory);
    return paths.map(AppFile.new).toList();
  }

  static Future<void> deleteBackupFile(String filePath) async {
    await io.deleteIfExists(filePath);
  }

  static Future<void> clearAllData() => DatabaseService.clearAllData();
}

String _encodeBackupJson(Map<String, dynamic> data) => jsonEncode(data);
dynamic _decodeBackupJson(String raw) => jsonDecode(raw);

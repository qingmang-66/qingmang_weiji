import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/file_compat.dart';
import '../utils/json_guard.dart';
import 'backup_crypto.dart';
import 'backup_io.dart' if (dart.library.html) 'backup_web.dart' as io;
import 'database_service.dart';

export 'backup_crypto.dart'
    show
        BackupPasswordException,
        BackupPasswordRequiredException,
        BackupFormatException;

typedef BackupFileReplacer =
    Future<void> Function({required AppFile temp, required AppFile target});

class BackupService {
  /// 与 backup_io.maxBackupBytes 保持一致：恢复时峰值内存约为文件体积的
  /// 3~4 倍（String + isolate 拷贝 + 解析结果），不宜放大到 100MB
  static const int _maxBackupBytes = 50 * 1024 * 1024;
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

  /// 导出备份。
  ///
  /// [password] 非空时输出**加密备份**（PBKDF2-HMAC-SHA256 派生密钥 +
  /// AES-256-GCM 认证加密，见 [BackupCrypto]）；否则保持历史明文 JSON 格式。
  /// 两种格式的恢复路径都能自动识别，历史备份不受影响。
  /// 加密整体放 isolate：12 万次 PBKDF2 迭代在 UI 线程会明显卡顿。
  static Future<String> backupData({String? filePath, String? password}) async {
    final data = await _exportLoader();
    //设置（SharedPreferences）一并进备份：换机/重装后按键位置、发音偏好、
    //主题这些不用重配。值带类型标签，避免 double 经 JSON 退化成 int 后
    //prefs.getDouble 读不回
    data['settings'] = await _collectSettings();
    final targetPath = filePath ?? await _getDefaultBackupPath();
    var json = await compute(_encodeBackupJson, data);
    if (password != null && password.isNotEmpty) {
      json = await compute(_encryptBackupJson, (
        json: json,
        password: password,
      ));
    }
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
      await _fileReplacer(temp: AppFile(tempPath), target: AppFile(targetPath));
      debugPrint('数据备份成功：$targetPath');
      return targetPath;
    } catch (e) {
      await io.deleteIfExists(tempPath);
      rethrow;
    }
  }

  static Future<String> backupAndShare({
    String? subject,
    String? password,
  }) async {
    final path = await backupData(password: password);
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

  static Future<Map<String, int>> restoreFromFile(
    AppFile file, {
    String? password,
  }) async {
    final raw = await io.readString(file.path);
    return restoreFromRaw(raw, password: password);
  }

  static Future<Map<String, int>> restoreFromBytes(
    List<int> bytes, {
    String? password,
  }) async {
    if (bytes.length > _maxBackupBytes) {
      throw Exception('备份文件过大，请选择小于${_maxBackupBytes ~/ 1024 ~/ 1024}MB的备份文件');
    }
    //allowMalformed：截断/非 UTF-8 的备份文件不让 utf8.decode 直接抛
    //FormatException（对用户是不可读错误），交给 JSON 校验给出明确提示
    return restoreFromRaw(
      utf8.decode(bytes, allowMalformed: true),
      password: password,
    );
  }

  /// 从原始文本恢复。[password] 用于加密备份——加密文件未提供口令时抛
  /// [BackupPasswordRequiredException]（UI 弹口令框后重试），口令错误抛
  /// [BackupPasswordException]。历史明文备份不传口令也能正常恢复。
  static Future<Map<String, int>> restoreFromRaw(
    String raw, {
    String? password,
  }) async {
    final decoded = await compute(_decodeBackupJson, raw);
    if (decoded is! Map) {
      throw Exception('备份文件格式错误：根节点必须是对象');
    }
    var root = Map<String, dynamic>.from(decoded);
    if (BackupCrypto.isEncryptedEnvelope(root)) {
      if (password == null || password.isEmpty) {
        throw const BackupPasswordRequiredException();
      }
      // 解密整体放 isolate：PBKDF2 派生与 GCM 校验同样不适合 UI 线程
      final plain = await compute(_decryptBackupJson, (
        envelope: root,
        password: password,
      ));
      final inner = await compute(_decodeBackupJson, plain);
      if (inner is! Map) {
        throw Exception('备份文件格式错误：根节点必须是对象');
      }
      root = Map<String, dynamic>.from(inner);
    }
    final tables = _validateBackupData(root);
    await _importLoader(tables);
    //设置随整库一起替换：先清掉本机全部偏好再写回备份内容，
    //语义与"初始化应用"的 prefs.clear() 一致；旧备份无 settings 字段则跳过
    await _applySettings(root['settings']);
    return {
      'wordBooks': (tables['word_books'] as List?)?.length ?? 0,
      'words': (tables['words'] as List?)?.length ?? 0,
      'records': (tables['review_records'] as List?)?.length ?? 0,
      'studyPlans': (tables['study_plans'] as List?)?.length ?? 0,
    };
  }

  @visibleForTesting
  static Future<void> atomicReplaceTarget({
    required AppFile temp,
    required AppFile target,
  }) async {
    await io.atomicReplace(temp.path, target.path);
  }

  static Future<Map<String, int>> restoreData(
    String filePath, {
    String? password,
  }) async {
    final raw = await io.readString(filePath);
    return restoreFromRaw(raw, password: password);
  }

  static Map<String, dynamic> _validateBackupData(Map<String, dynamic> data) {
    if (data['appVersion'] is! String) throw Exception('备份文件格式错误：缺少appVersion');
    if (data['schemaVersion'] is! int) {
      throw Exception('备份文件格式错误：缺少schemaVersion');
    }
    final schemaVersion = data['schemaVersion'] as int;
    // 只拒绝"来自更新版本"的备份（可能有本版本读不懂的表结构）；
    // 旧版本备份（schemaVersion < 当前）按列名白名单导入，允许恢复。
    // 此前要求强相等：schemaVersion 恒为 1 时看似无害，但一旦版本演进，
    // 所有历史备份都会突然无法恢复。
    if (schemaVersion > DatabaseService.schemaVersion) {
      throw Exception('不支持的schemaVersion：$schemaVersion（高于当前版本）');
    }
    // schemaVersion 恒为 1，单看它拦不住任何东西（v2~v23 的建表变更都没提升过
    // 该常量）。这里用导出时写入的 databaseVersion 做真正的版本闸门：
    // 只拒绝"来自更新版本"的备份，旧备份仍按列白名单裁剪导入。
    final backupDbVersion = data['databaseVersion'];
    if (backupDbVersion is int &&
        backupDbVersion > DatabaseService.databaseVersion) {
      throw Exception(
        '备份来自更新版本的应用（数据库 v$backupDbVersion > 当前 v${DatabaseService.databaseVersion}），'
        '请先升级应用再恢复',
      );
    }
    final rawTables = data['tables'];
    if (rawTables is! Map) throw Exception('备份文件格式错误：tables必须是对象');
    final tables = Map<String, dynamic>.from(rawTables);
    var totalRows = 0;
    var presentTables = 0;
    for (final table in DatabaseService.backupTables) {
      final rows = tables[table];
      if (rows == null) continue;
      if (rows is! List) throw Exception('备份文件格式错误：$table必须是数组');
      presentTables++;
      totalRows += rows.length;
      if (totalRows > _maxBackupRows) {
        throw Exception('备份数据过大，超过$_maxBackupRows条记录限制');
      }
      if (rows.any((row) => row is! Map)) {
        throw Exception('备份文件格式错误：$table中包含无效记录');
      }
    }
    // 空备份/缺表的"备份"必须拒绝：导入实现会先无条件清空全部业务表，
    // 一个 {"schemaVersion":1,"tables":{}} 就能清光用户全部学习数据
    if (presentTables == 0 || totalRows == 0) {
      throw Exception('备份文件不包含任何数据，已拒绝恢复以保护现有数据');
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
    // 顺带清理中断残留（.tmp/.bak）：崩溃/强杀留下的明文副本不再有用，
    // 只占空间并扩大泄露面
    await io.cleanupStaleBackupTemps(directory);
    final paths = await io.listJsonFiles(directory);
    return paths.map(AppFile.new).toList();
  }

  static Future<void> deleteBackupFile(String filePath) async {
    await io.deleteIfExists(filePath);
  }

  static Future<void> clearAllData() => DatabaseService.clearAllData();

  /// 设备/会话态的键：跨机恢复没有意义甚至有害（提醒已触发日期、
  /// 埋点计数），导出时剔除。
  static const List<String> _settingsExcludeKeys = [
    'windowsReminderLastFiredDate',
  ];
  static const List<String> _settingsExcludePrefixes = ['guide_event_'];

  static bool _isExcludedSettingKey(String key) =>
      _settingsExcludeKeys.contains(key) ||
      _settingsExcludePrefixes.any(key.startsWith);

  /// 收集全部 SharedPreferences 设置，值带类型标签
  /// （JSON 数字不区分 int/double，裸存会让 speechRate 这类 double
  /// 在恢复后变成 int 而读不回来）
  static Future<Map<String, dynamic>> _collectSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (_isExcludedSettingKey(key)) continue;
        final value = prefs.get(key);
        final tag = value is bool
            ? 'b'
            : value is int
            ? 'i'
            : value is double
            ? 'd'
            : value is String
            ? 's'
            : value is List<String>
            ? 'l'
            : null;
        if (tag != null) result[key] = [tag, value];
      }
      return result;
    } catch (e) {
      //收集失败不阻断备份：数据表才是备份的主体
      debugPrint('收集设置失败：$e');
      return {};
    }
  }

  /// 恢复设置：整库替换语义，先清空再写入。
  /// 单个键写失败只跳过该键，不让整次恢复报错。
  static Future<void> _applySettings(Object? raw) async {
    if (raw is! Map) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        if (_isExcludedSettingKey(key)) continue;
        final pair = entry.value;
        if (pair is! List || pair.length != 2) continue;
        final tag = pair[0];
        final value = pair[1];
        try {
          switch (tag) {
            case 'b':
              if (value is bool) await prefs.setBool(key, value);
            case 'i':
              if (value is int) await prefs.setInt(key, value);
            case 'd':
              //int 字面量（如 0.0 被 JSON 编码成 0）也要能落成 double
              if (value is num) await prefs.setDouble(key, value.toDouble());
            case 's':
              if (value is String) await prefs.setString(key, value);
            case 'l':
              if (value is List) {
                await prefs.setStringList(
                  key,
                  value.map((e) => e.toString()).toList(),
                );
              }
          }
        } catch (e) {
          debugPrint('恢复设置键 $key 失败：$e');
        }
      }
    } catch (e) {
      debugPrint('恢复设置失败：$e');
    }
  }
}

String _encodeBackupJson(Map<String, dynamic> data) => jsonEncode(data);

/// 走 [JsonGuard]：深嵌套的恶意/损坏备份不会以 StackOverflowError
/// 杀死 compute isolate
dynamic _decodeBackupJson(String raw) => JsonGuard.decode(raw);

/// isolate 入口：加密明文备份 JSON
Future<String> _encryptBackupJson(({String json, String password}) args) =>
    BackupCrypto.encrypt(args.json, args.password);

/// isolate 入口：解密备份信封
Future<String> _decryptBackupJson(
  ({Map<String, dynamic> envelope, String password}) args,
) => BackupCrypto.decrypt(args.envelope, args.password);

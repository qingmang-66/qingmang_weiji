import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/fs_helper.dart';
import 'local_dictionary_io.dart'
    if (dart.library.html) 'local_dictionary_web.dart'
    as platform;

/// 本地离线词典服务 - 基于 ECDICT 数据库
/// 包含 340 万 + 词条，完全离线，无需网络
/// 首次查询时再拷贝 assets，避免启动阶段卡顿
class LocalDictionaryService {
  static Database? _db;
  static bool _initialized = false;
  static Future<void>? _initFuture;
  static bool _copying = false;

  /// 是否已完成初始化（含拷贝失败后的降级）
  static bool get isReady => _initialized;

  /// 是否正在拷贝大库（UI 可展示进度）
  static bool get isCopying => _copying;

  /// 初始化数据库（复制 assets 到本地）。可安全并发调用。
  static Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _doInit();
    await _initFuture;
  }

  static Future<void> _doInit() async {
    if (kIsWeb) {
      // Web端不支持拷贝大文件到本地存储
      _initialized = true;
      return;
    }
    try {
      platform.initDesktopFfi();
      final appDir = await getApplicationDocumentsDirectory();
      final dbDirPath = join(appDir.path, 'dictionary');
      await ensureDirectoryExists(join(dbDirPath, 'placeholder'));
      final dbPath = join(dbDirPath, 'ecdict.db');
      final exists = await platform.fileExists(dbPath);
      if (!exists) {
        _copying = true;
        debugPrint('正在初始化本地词典数据库...');
        final tempPath = '$dbPath.tmp';
        try {
          final assetData = await rootBundle.load('assets/db/ecdict.db');
          final total = assetData.lengthInBytes;
          await platform.writeBytesInChunks(
            tempPath,
            assetData.buffer.asUint8List(0, total),
          );
          await platform.renameFile(tempPath, dbPath);
          debugPrint('✓ 数据库文件复制完成: $total bytes');
        } catch (e) {
          debugPrint('❌ 复制数据库文件失败: $e');
          await platform.deleteIfExists(tempPath);
        } finally {
          _copying = false;
        }
      }
      if (await platform.fileExists(dbPath)) {
        _db = await openDatabase(dbPath, readOnly: true);
      }
      _initialized = true;
      debugPrint('✓ 本地词典数据库初始化完成');
    } catch (e) {
      debugPrint('❌ 本地词典初始化失败：$e');
      _initialized = true;
      _copying = false;
    }
  }

  /// 后台预热（不阻塞 UI；失败静默）
  static void warmUpInBackground() {
    if (_initialized || _initFuture != null) return;
    unawaited(init());
  }

  /// 查询单词
  static Future<Map<String, dynamic>?> lookup(String word) async {
    if (_db == null) await init();
    final db = _db;
    if (db == null) return null;
    try {
      final result = await db.query(
        'stardict',
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [word],
        limit: 1,
      );
      if (result.isEmpty) return null;
      final row = result.first;
      return {
        'word': row['word'] as String,
        'phonetic': row['phonetic'] as String?,
        'definition': row['definition'] as String?,
        'translation': row['translation'] as String?,
        'pos': row['pos'] as String?,
        'collins': row['collins'] as int?,
        'oxford': row['oxford'] as int?,
        'tag': row['tag'] as String?,
        'exchange': row['exchange'] as String?,
        'detail': row['detail'] as String?,
      };
    } catch (e) {
      debugPrint('查询失败：$e');
      return null;
    }
  }

  /// 模糊搜索（支持前缀匹配）
  static Future<List<Map<String, dynamic>>> search(
    String prefix, {
    int limit = 10,
  }) async {
    if (_db == null) await init();
    final db = _db;
    if (db == null) return [];
    try {
      final result = await db.query(
        'stardict',
        where: 'word LIKE ? COLLATE NOCASE',
        whereArgs: ['$prefix%'],
        limit: limit,
        orderBy: 'LENGTH(word)',
      );
      return result
          .map(
            (row) => {
              'word': row['word'] as String,
              'phonetic': row['phonetic'] as String?,
              'translation': row['translation'] as String?,
              'pos': row['pos'] as String?,
            },
          )
          .toList();
    } catch (e) {
      debugPrint('搜索失败：$e');
      return [];
    }
  }

  /// 获取 Collins 星级描述
  static String? getCollinsDescription(int? stars) {
    if (stars == null) return null;
    switch (stars) {
      case 5:
        return 'Collins 5 星（最高频）';
      case 4:
        return 'Collins 4 星';
      case 3:
        return 'Collins 3 星';
      case 2:
        return 'Collins 2 星';
      case 1:
        return 'Collins 1 星';
      default:
        return null;
    }
  }

  /// 获取词性描述
  static String? getPosDescription(String? pos) {
    if (pos == null) return null;
    final map = {
      'n': '名词',
      'v': '动词',
      'adj': '形容词',
      'a': '形容词',
      'adv': '副词',
      'ad': '副词',
      'prep': '介词',
      'prep.': '介词',
      'conj': '连词',
      'pron': '代词',
      'num': '数词',
      'art': '冠词',
      'int': '感叹词',
      'interj': '感叹词',
    };
    return map[pos] ?? pos;
  }

  /// 获取随机单词列表，用于测验模式生成干扰项
  static Future<List<Map<String, dynamic>>> getRandomWords({
    int count = 3,
    List<String> excludeWords = const [],
  }) async {
    if (_db == null) await init();
    final db = _db;
    if (db == null) return [];
    try {
      final result = await db.query(
        'stardict',
        where: excludeWords.isNotEmpty
            ? 'word NOT IN (${List.filled(excludeWords.length, '?').join(',')})'
            : null,
        whereArgs: excludeWords.isNotEmpty ? excludeWords : null,
        limit: count * 3,
        orderBy: 'RANDOM()',
      );
      final seen = <String>{};
      final filtered = <Map<String, dynamic>>[];
      for (final row in result) {
        final word = row['word'] as String;
        final translation = row['translation'] as String?;
        if (seen.contains(word)) continue;
        if (translation == null || translation.isEmpty) continue;
        if (excludeWords.contains(word)) continue;
        seen.add(word);
        filtered.add({
          'word': word,
          'translation': translation,
          'phonetic': row['phonetic'] as String?,
          'definition': row['definition'] as String?,
        });
        if (filtered.length >= count) break;
      }
      return filtered;
    } catch (e) {
      debugPrint('获取随机单词失败：$e');
      return [];
    }
  }
}

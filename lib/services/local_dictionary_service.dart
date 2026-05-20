import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 本地离线词典服务 - 基于 ECDICT 数据库
/// 包含 340 万 + 词条，完全离线，无需网络
class LocalDictionaryService {
  static Database? _db;
  static bool _initialized = false;

  /// 初始化数据库（复制 assets 到本地）
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // Windows/Linux 需要 FFI
      if (Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(join(appDir.path, 'dictionary'));
      
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      final dbPath = join(dbDir.path, 'ecdict.db');
      final dbFile = File(dbPath);

      // 如果本地数据库不存在，从 assets 复制
      if (!await dbFile.exists()) {
        debugPrint('正在初始化本地词典数据库...');
        try {
          // 从 assets 复制数据库文件
          final assetData = await rootBundle.load('assets/db/ecdict.db');
          final bytes = assetData.buffer.asUint8List();
          await dbFile.writeAsBytes(bytes);
          debugPrint('✓ 数据库文件复制完成: ${bytes.length} bytes');
        } catch (e) {
          debugPrint('❌ 复制数据库文件失败: $e');
          // 如果复制失败，创建空数据库（后续查询会返回空结果）
        }
      }

      _db = await openDatabase(
        dbPath,
        readOnly: true,
      );

      _initialized = true;
      debugPrint('✓ 本地词典数据库初始化完成');
    } catch (e) {
      debugPrint('❌ 本地词典初始化失败：$e');
    }
  }

  /// 查询单词
  /// 返回包含释义、音标、词性、Collins 星级的完整信息
  static Future<Map<String, dynamic>?> lookup(String word) async {
    if (_db == null) {
      await init();
    }

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
  static Future<List<Map<String, dynamic>>> search(String prefix, {int limit = 10}) async {
    if (_db == null) {
      await init();
    }

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

      return result.map((row) => {
        'word': row['word'] as String,
        'phonetic': row['phonetic'] as String?,
        'translation': row['translation'] as String?,
        'pos': row['pos'] as String?,
      }).toList();
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
    // ECDICT 词性编码转换
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
  /// [count] 需要的单词数量
  /// [excludeWords] 需要排除的单词（避免和正确答案重复）
  static Future<List<Map<String, dynamic>>> getRandomWords({
    int count = 3,
    List<String> excludeWords = const [],
  }) async {
    if (_db == null) {
      await init();
    }

    final db = _db;
    if (db == null) return [];

    try {
      // 使用随机排序获取不重复的单词
      final result = await db.query(
        'stardict',
        where: excludeWords.isNotEmpty
            ? 'word NOT IN (${List.filled(excludeWords.length, '?').join(',')})'
            : null,
        whereArgs: excludeWords.isNotEmpty ? excludeWords : null,
        limit: count * 3, // 多取一些，后面过滤
        orderBy: 'RANDOM()',
      );

      // 过滤掉没有释义的单词，并确保单词不重复
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

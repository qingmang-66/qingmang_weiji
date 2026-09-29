import 'dart:async';
import 'dart:math';

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

  /// 上次初始化是否失败（磁盘满/文件被占用等临时故障）
  ///
  /// 失败时不能置 [_initialized]，否则 `init()` 开头的短路会让本进程内所有
  /// 重试直接返回，[_db] 永远为 null、查询静默返回空。置本标记后 `init()`
  /// 会允许再跑一遍（见 [init]）。
  static bool _failed = false;

  /// 初始化流程是否已跑完（包含拷贝失败后的降级）
  static bool get isReady => _initialized;

  /// 词典数据库是否真正可用。
  /// 初始化失败（asset 缺失、拷贝失败等）时为 false——此时所有查询都会静默返回
  /// 空结果，调用方可用本属性区分「没查到这个词」和「本地词典根本没起来」。
  static bool get isAvailable => _db != null;

  /// 是否正在拷贝大库（UI 可展示进度）
  static bool get isCopying => _copying;

  /// 初始化数据库（复制 assets 到本地）。可安全并发调用。
  /// 分片资产数量：与 scripts/split_dict_asset.ps1 的默认切分数一致
  static const int dictionaryPartCount = 6;

  /// 逐片拷贝词典到 [tempPath]。
  ///
  /// - 成功（所有分片都存在并写入完毕）返回 true；
  /// - 任一分片缺失视为"未生成分片资产"，清理半成品并返回 false，
  ///   由调用方回退整包 ecdict.db 路径；
  /// - 每片之间主动让出事件循环（Duration.zero），避免连续大块写入
  ///   把 UI 线程的微任务队列长时间占满。
  static Future<bool> _copyDictionaryFromParts(String tempPath) async {
    for (var i = 1; i <= dictionaryPartCount; i++) {
      final name = 'assets/db/ecdict.db.part${i.toString().padLeft(2, '0')}';
      ByteData data;
      try {
        data = await rootBundle.load(name);
      } catch (_) {
        // 缺少分片：删除已写入的半成品，回退整包
        if (i > 1) await platform.deleteIfExists(tempPath);
        return false;
      }
      await platform.appendBytes(
        tempPath,
        data.buffer.asUint8List(0, data.lengthInBytes),
      );
      await Future<void>.delayed(Duration.zero);
    }
    return true;
  }

  static Future<void> init() async {
    if (_initialized) return;
    //失败后允许重试：清掉失败标记，让下方闸门重新发起一次初始化
    if (_failed) _failed = false;
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
          // 分片优先：assets/db/ecdict.db.partNN（由
          // scripts/split_dict_asset.ps1 生成）逐片加载并追加写入——内存峰值
          // 从"整包词典"（数十 MB 一次分配）降到"单片"；未生成分片时回退
          // 整包 ecdict.db，行为与历史一致
          final copiedFromParts = await _copyDictionaryFromParts(tempPath);
          if (!copiedFromParts) {
            final assetData = await rootBundle.load('assets/db/ecdict.db');
            final total = assetData.lengthInBytes;
            await platform.writeBytesInChunks(
              tempPath,
              assetData.buffer.asUint8List(0, total),
            );
          }
          await platform.renameFile(tempPath, dbPath);
          debugPrint('✓ 数据库文件复制完成（分片模式：$copiedFromParts）');
        } catch (e) {
          debugPrint('❌ 复制数据库文件失败: $e');
          await platform.deleteIfExists(tempPath);
          //向上抛：由外层 catch 标记为失败态，下次 init() 仍可重试
          rethrow;
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
      //失败态：不置 _initialized，清掉在途闸门，允许下次 init() 重试
      _failed = true;
      _initFuture = null;
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

  /// 随机候选池：`ORDER BY RANDOM()` 需要对 340 万行的 stardict 做全表扫描
  /// 并排序，而干扰项每次测验都要取。改为批量补充候选池后从池中随机抽取，
  /// 昂贵的随机排序从「每次调用」降到「每池一次」。
  static const int _randomPoolTarget = 120;
  static final List<Map<String, dynamic>> _randomPool = [];
  static final Random _random = Random();

  /// 补充随机候选池（只保留释义非空的词条）
  static Future<void> _refillRandomPool(Database db) async {
    try {
      final rows = await db.query(
        'stardict',
        columns: ['word', 'translation', 'phonetic', 'definition'],
        limit: _randomPoolTarget,
        orderBy: 'RANDOM()',
      );
      _randomPool
        ..clear()
        ..addAll(
          rows.where((row) {
            final word = row['word'] as String?;
            final translation = row['translation'] as String?;
            return word != null &&
                word.isNotEmpty &&
                translation != null &&
                translation.isNotEmpty;
          }),
        );
    } catch (e) {
      debugPrint('补充随机词池失败：$e');
    }
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
      final excluded = excludeWords.map((w) => w.toLowerCase()).toSet();
      if (_randomPool.length < count * 4) {
        await _refillRandomPool(db);
      }
      final result = <Map<String, dynamic>>[];
      final usedIndexes = <int>{};
      //池内可能命中排除词，重试上限防止极端情况下死循环
      var guard = 0;
      while (result.length < count && guard < _randomPool.length * 2) {
        guard++;
        if (_randomPool.isEmpty) break;
        final index = _random.nextInt(_randomPool.length);
        if (!usedIndexes.add(index)) continue;
        final row = _randomPool[index];
        final word = (row['word'] as String?) ?? '';
        if (word.isEmpty || excluded.contains(word.toLowerCase())) continue;
        result.add({
          'word': word,
          'translation': row['translation'] as String?,
          'phonetic': row['phonetic'] as String?,
          'definition': row['definition'] as String?,
        });
      }
      return result;
    } catch (e) {
      debugPrint('获取随机单词失败：$e');
      return [];
    }
  }
}

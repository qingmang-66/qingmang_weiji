import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';

import '../../models/word_favorite.dart';

/// 收藏夹数据访问对象（表 `word_favorites`）
///
/// 收藏是**单词级、跨词库全局唯一**的：`word_id` 上有 UNIQUE 约束，
/// 同一个词在学习模式和阅读模式里收藏的是同一条记录
/// （与 `reader_marks` 的建模方式一致）。
///
/// 注意与另外两个"看起来像收藏"的概念区分：
/// - `reader_marks`：阅读模式的「记住了」，语义是**已掌握**，与本表相反
/// - `reader_bookmarks`：按「词书 + 词序号」的**位置**书签，用于"回到这里"
class FavoriteDao {
  final Future<Database> Function() _dbFuture;

  FavoriteDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  static const String _table = 'word_favorites';

  /// 批量删除时分块，避免 SQLite 变量数上限
  static const int _chunkSize = 500;

  /// 切换收藏，返回切换后是否已收藏。
  ///
  /// delete + insert 必须在同一事务内：学习页与阅读页都有收藏入口，快速连点
  /// 时两次调用可能都读到"删除 0 行" → 各自插入（第二次被 UNIQUE ignore 吞掉），
  /// 两个调用都返回 true，UI 与库里的状态相反。
  /// 返回值必须以"真正插入成功"为准（ignore 命中时 insert 返回 0）。
  Future<bool> toggle(int wordId, {String? source}) async {
    final db = await _dbFuture();
    return db.transaction((txn) async {
      final deleted = await txn.delete(
        _table,
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      if (deleted > 0) return false;
      final rowId = await txn.insert(_table, {
        'word_id': wordId,
        'source': source,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return rowId > 0;
    });
  }

  /// 收藏（已存在则忽略，不改动原有来源与时间）
  Future<void> add(int wordId, {String? source}) async {
    final db = await _dbFuture();
    await db.insert(_table, {
      'word_id': wordId,
      'source': source,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 批量收藏，返回真正新增的条数
  Future<int> addMany(List<int> wordIds, {String? source}) async {
    if (wordIds.isEmpty) return 0;
    final db = await _dbFuture();
    final now = DateTime.now().toIso8601String();
    var inserted = 0;
    await db.transaction((txn) async {
      for (final id in wordIds.toSet()) {
        final rowId = await txn.insert(_table, {
          'word_id': id,
          'source': source,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (rowId > 0) inserted++;
      }
    });
    return inserted;
  }

  Future<void> remove(int wordId) async {
    final db = await _dbFuture();
    await db.delete(_table, where: 'word_id = ?', whereArgs: [wordId]);
  }

  Future<void> removeMany(List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture();
    final ids = wordIds.toSet().toList(growable: false);
    await db.transaction((txn) async {
      for (var i = 0; i < ids.length; i += _chunkSize) {
        final chunk = ids.sublist(i, (i + _chunkSize).clamp(0, ids.length));
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.delete(
          _table,
          where: 'word_id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
  }

  Future<void> clear() async {
    final db = await _dbFuture();
    await db.delete(_table);
  }

  Future<bool> contains(int wordId) async {
    final db = await _dbFuture();
    final rows = await db.query(
      _table,
      columns: ['word_id'],
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 全部已收藏的单词 id
  Future<Set<int>> getFavoriteWordIds() async {
    final db = await _dbFuture();
    final rows = await db.query(_table, columns: ['word_id']);
    return rows.map((row) => row['word_id'] as int).toSet();
  }

  /// 某词书内已收藏的单词 id 集合（阅读器整本书一次取回）
  Future<Set<int>> getFavoriteWordIdsInBook(int wordBookId) async {
    final db = await _dbFuture();
    final rows = await db.rawQuery(
      '''
      SELECT f.word_id FROM $_table f
      INNER JOIN words w ON w.id = f.word_id
      WHERE w.word_book_id = ?
    ''',
      [wordBookId],
    );
    return rows.map((row) => row['word_id'] as int).toSet();
  }

  /// 这批单词里哪些已被收藏
  ///
  /// 阅读器 / 学习页需要一次性拿到整屏词的收藏状态，避免逐个查询。
  Future<Set<int>> filterFavorited(Iterable<int> wordIds) async {
    final ids = wordIds.toSet().toList(growable: false);
    if (ids.isEmpty) return <int>{};
    final db = await _dbFuture();
    final result = <int>{};
    for (var i = 0; i < ids.length; i += _chunkSize) {
      final chunk = ids.sublist(i, (i + _chunkSize).clamp(0, ids.length));
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        _table,
        columns: ['word_id'],
        where: 'word_id IN ($placeholders)',
        whereArgs: chunk,
      );
      result.addAll(rows.map((row) => row['word_id'] as int));
    }
    return result;
  }

  Future<int> getCount() async {
    final db = await _dbFuture();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return rows.first['c'] as int? ?? 0;
  }

  /// 有收藏的词库汇总（按收藏条数降序），用于收藏夹的「按词库筛选」
  ///
  /// 只返回**确实有收藏**的词库：收藏横跨多个词库时，把没有收藏的词库也列进
  /// 筛选栏只会让它变长，点进去还必然是空的。
  Future<List<FavoriteBookSummary>> getBookSummaries() async {
    final db = await _dbFuture();
    final rows = await db.rawQuery('''
      SELECT w.word_book_id AS book_id, b.name AS book_name, COUNT(*) AS c
      FROM $_table f
      INNER JOIN words w ON w.id = f.word_id
      LEFT JOIN word_books b ON b.id = w.word_book_id
      GROUP BY w.word_book_id
      ORDER BY c DESC, w.word_book_id ASC
    ''');
    return rows.map((row) => FavoriteBookSummary.fromMap(row)).toList();
  }

  /// 收藏夹列表
  ///
  /// [keyword] 非空时按单词或释义模糊匹配；
  /// [source] 按收藏来源筛选（`study` / `reader`）；
  /// [wordBookId] 按词库筛选；
  /// [since] 只取此时间点（含）之后收藏的；
  /// [ascending] 为 true 时按收藏时间正序（最早在前），默认倒序（最新在前）。
  ///
  /// 时间比较直接用 ISO8601 字符串：`created_at` 一直是
  /// `DateTime.toIso8601String()` 写入的本地时间，格式同源可比
  /// （本方法原本的 ORDER BY 也依赖这一点），且只精确到"当天 00:00"，
  /// 不存在时区歧义。
  Future<List<WordFavorite>> getAll({
    String? keyword,
    String? source,
    int? wordBookId,
    DateTime? since,
    bool ascending = false,
    int? limit,
    int? offset,
  }) async {
    final db = await _dbFuture();
    final trimmed = keyword?.trim() ?? '';
    final where = <String>[];
    final args = <Object>[];

    if (trimmed.isNotEmpty) {
      //转义 LIKE 通配符，避免用户输入的 % 和 _ 变成通配符
      final escaped = trimmed
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      where.add(
        "(w.word LIKE ? ESCAPE '\\' OR w.definition LIKE ? ESCAPE '\\')",
      );
      final like = '%$escaped%';
      args
        ..add(like)
        ..add(like);
    }
    if (source != null && source.isNotEmpty) {
      where.add('f.source = ?');
      args.add(source);
    }
    if (wordBookId != null) {
      where.add('w.word_book_id = ?');
      args.add(wordBookId);
    }
    if (since != null) {
      where.add('f.created_at >= ?');
      args.add(since.toIso8601String());
    }

    final direction = ascending ? 'ASC' : 'DESC';
    final buffer = StringBuffer('''
      SELECT w.*, f.source AS source, f.note AS note, f.created_at AS created_at
      FROM $_table f
      INNER JOIN words w ON w.id = f.word_id
    ''');
    if (where.isNotEmpty) buffer.write(' WHERE ${where.join(' AND ')}');
    //id 作为次级排序键：批量收藏（addMany）会用同一个时间戳写入多条，
    //这时靠自增 id 才能给出稳定的先后
    buffer.write(' ORDER BY f.created_at $direction, f.id $direction');
    if (limit != null && limit > 0) {
      buffer.write(' LIMIT ?');
      args.add(limit);
      if (offset != null && offset > 0) {
        buffer.write(' OFFSET ?');
        args.add(offset);
      }
    } else if (offset != null && offset > 0) {
      //只传 offset 不传 limit：offset 必须独立生效，否则分页被静默忽略；
      //SQLite 用 LIMIT -1 表示不限行数，仅保留 OFFSET
      buffer.write(' LIMIT -1 OFFSET ?');
      args.add(offset);
    }

    final rows = await db.rawQuery(buffer.toString(), args);
    return rows.map((row) => WordFavorite.fromMap(row)).toList();
  }

  /// 按 id 批量取收藏条目（专项复习结束后回写用）
  Future<List<WordFavorite>> getByIds(List<int> wordIds) async {
    if (wordIds.isEmpty) return const [];
    final db = await _dbFuture();
    //IN 子句分块：老版本 SQLite 变量上限 999，超限抛错且整批丢失
    final result = <WordFavorite>[];
    for (var i = 0; i < wordIds.length; i += _chunkSize) {
      final end = i + _chunkSize < wordIds.length
          ? i + _chunkSize
          : wordIds.length;
      final chunk = wordIds.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery('''
        SELECT w.*, f.source AS source, f.note AS note, f.created_at AS created_at
        FROM $_table f
        INNER JOIN words w ON w.id = f.word_id
        WHERE f.word_id IN ($placeholders)
      ''', chunk);
      result.addAll(rows.map((row) => WordFavorite.fromMap(row)));
    }
    return result;
  }
}

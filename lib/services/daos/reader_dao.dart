import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';
import '../../models/reader_bookmark.dart';

/// 阅读模式数据访问对象
/// 管理勾记（reader_marks）、书签（reader_bookmarks）、进度（reader_progress）
class ReaderDao {
  final Future<Database> Function() _dbFuture;

  ReaderDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  // ========== 勾记 ==========

  /// 切换勾记，返回切换后是否已勾记。
  ///
  /// delete + insert 必须原子：并发双击时两次都可能读到"删除 0 行"、
  /// 各自插入（第二次撞 UNIQUE 被 ignore），两个调用都返回 true。
  Future<bool> toggleMark(int wordId) async {
    final db = await _dbFuture();
    return db.transaction((txn) async {
      final deleted = await txn.delete(
        'reader_marks',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      if (deleted > 0) return false;
      //ignore 兜底并发双 toggle 时第二个 insert 撞 word_id UNIQUE
      final rowId = await txn.insert('reader_marks', {
        'word_id': wordId,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return rowId > 0;
    });
  }

  /// 获取某词书内已勾记的单词ID集合
  Future<Set<int>> getMarkedWordIds(int bookId) async {
    final db = await _dbFuture();
    final rows = await db.rawQuery(
      '''
      SELECT m.word_id FROM reader_marks m
      INNER JOIN words w ON w.id = m.word_id
      WHERE w.word_book_id = ?
    ''',
      [bookId],
    );
    return rows.map((r) => r['word_id'] as int).toSet();
  }

  /// 勾记数量：总数 + 指定区间内新增数
  Future<({int total, int range})> getMarkCounts({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbFuture();
    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN created_at >= ? AND created_at < ? THEN 1 ELSE 0 END) as range_c
      FROM reader_marks
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final r = rows.first;
    return (total: r['total'] as int? ?? 0, range: r['range_c'] as int? ?? 0);
  }

  // ========== 书签 ==========

  Future<int> addBookmark({
    required int bookId,
    required int wordIndex,
    String? wordText,
    String? customName,
  }) async {
    final db = await _dbFuture();
    return await db.insert('reader_bookmarks', {
      'word_book_id': bookId,
      'word_index': wordIndex,
      // 记录创建时的词文本：词库重新导入后用于识别"序号已失效"
      'word_text': wordText,
      'custom_name': customName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// 按创建顺序返回书签
  Future<List<ReaderBookmark>> getBookmarks(int bookId) async {
    final db = await _dbFuture();
    final rows = await db.query(
      'reader_bookmarks',
      where: 'word_book_id = ?',
      whereArgs: [bookId],
      orderBy: 'id ASC',
    );
    return rows.map((r) => ReaderBookmark.fromMap(r)).toList();
  }

  /// 是否已存在同位置书签
  Future<bool> hasBookmarkAt(int bookId, int wordIndex) async {
    final db = await _dbFuture();
    final rows = await db.query(
      'reader_bookmarks',
      where: 'word_book_id = ? AND word_index = ?',
      whereArgs: [bookId, wordIndex],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> deleteBookmark(int id) async {
    final db = await _dbFuture();
    await db.delete('reader_bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameBookmark(int id, String name) async {
    final db = await _dbFuture();
    await db.update(
      'reader_bookmarks',
      {'custom_name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 为旧书签补录 `word_text` 快照（老数据该列为 null）。
  ///
  /// 词库重新导入/排序变化后，仅凭 `word_index` 无法判断书签是否还指向原词。
  /// 如果当前词列表长度足够，用当前索引位置的词回填快照，让这些旧书签也能
  /// 参与「词序已变化」检测；无法回填的保持 null，按未知处理。
  Future<void> backfillBookmarkWordTexts(
    int bookId,
    List<String> words,
  ) async {
    final db = await _dbFuture();
    final rows = await db.query(
      'reader_bookmarks',
      columns: ['id', 'word_index'],
      where: 'word_book_id = ? AND word_text IS NULL',
      whereArgs: [bookId],
    );
    for (final row in rows) {
      final id = row['id'] as int?;
      final idx = row['word_index'] as int?;
      if (id == null || idx == null) continue;
      if (idx < 0 || idx >= words.length) continue;
      await db.update(
        'reader_bookmarks',
        {'word_text': words[idx]},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ========== 进度 ==========

  /// 保存阅读进度（按词序号，与分页无关）
  Future<void> saveProgress({
    required int bookId,
    required int wordIndex,
  }) async {
    final db = await _dbFuture();
    final now = DateTime.now().toIso8601String();
    //replace 原子处理插入/更新，避免读-判-写并发撞 word_book_id UNIQUE
    await db.insert('reader_progress', {
      'word_book_id': bookId,
      'word_index': wordIndex,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> getProgress(int bookId) async {
    final db = await _dbFuture();
    final rows = await db.query(
      'reader_progress',
      columns: ['word_index'],
      where: 'word_book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['word_index'] as int;
  }

  /// 批量获取多本词书的阅读进度：bookId -> wordIndex
  Future<Map<int, int>> getProgressMap(Iterable<int> bookIds) async {
    final db = await _dbFuture();
    final ids = bookIds.toList();
    if (ids.isEmpty) return {};
    //IN 子句分块：老版本 SQLite 变量上限 999，超限抛错且整批丢失
    const chunkSize = 400;
    final result = <int, int>{};
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize < ids.length ? i + chunkSize : ids.length;
      final chunk = ids.sublist(i, end);
      final rows = await db.query(
        'reader_progress',
        columns: ['word_book_id', 'word_index'],
        where: 'word_book_id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      for (final r in rows) {
        result[r['word_book_id'] as int] = r['word_index'] as int;
      }
    }
    return result;
  }
}

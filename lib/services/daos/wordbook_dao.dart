import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';
import '../../models/models.dart';

/// 词库数据访问对象
class WordBookDao {
  final Future<Database> Function() _dbFuture;

  WordBookDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  Future<int> insertWordBook(WordBook book) async {
    final db = await _dbFuture();
    return await db.insert('word_books', book.toMap());
  }

  Future<List<WordBook>> getAllWordBooks() async {
    final db = await _dbFuture();
    final maps = await db.query(
      'word_books',
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map((m) => WordBook.fromMap(m)).toList();
  }

  /// 更新词库排序顺序
  Future<void> updateSortOrder(int bookId, int sortOrder) async {
    final db = await _dbFuture();
    await db.update(
      'word_books',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// 批量更新排序顺序
  Future<void> updateSortOrders(Map<int, int> sortOrderMap) async {
    if (sortOrderMap.isEmpty) return;
    final db = await _dbFuture();
    await db.transaction((txn) async {
      for (final entry in sortOrderMap.entries) {
        await txn.update(
          'word_books',
          {'sort_order': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });
  }

  Future<WordBook?> getWordBook(int id) async {
    final db = await _dbFuture();
    final maps = await db.query('word_books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WordBook.fromMap(maps.first);
  }

  Future<void> updateWordBookTotalWords(int bookId) async {
    final db = await _dbFuture();
    final count = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    final total = (count.first['c'] as int?) ?? 0;
    await db.update(
      'word_books',
      {'total_words': total},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteWordBook(int id) async {
    final db = await _dbFuture();
    await db.transaction((txn) async {
      await _deleteWordReferencesForBooks(txn, '?', [id]);
      await txn.delete('words', where: 'word_book_id = ?', whereArgs: [id]);
      await txn.delete('word_books', where: 'id = ?', whereArgs: [id]);
      // study_plans.word_book_ids 是逗号串无外键，删词库后必须剔除悬空 id
      await _pruneStudyPlans(txn, [id]);
    });
  }

  Future<void> deleteWordBooksBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbFuture();
    //IN 子句分块：老版本 SQLite 变量上限 999，超限抛错并回滚整批删除
    const chunkSize = 400;
    await db.transaction((txn) async {
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = i + chunkSize < ids.length ? i + chunkSize : ids.length;
        final chunk = ids.sublist(i, end);
        final placeholders = List.filled(chunk.length, '?').join(',');
        await _deleteWordReferencesForBooks(txn, placeholders, chunk);
        await txn.delete(
          'words',
          where: 'word_book_id IN ($placeholders)',
          whereArgs: chunk,
        );
        await txn.delete(
          'word_books',
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
        await _pruneStudyPlans(txn, chunk);
      }
    });
  }

  /// 从所有学习计划的词库列表里剔除已删除的词库。
  ///
  /// `study_plans.word_book_ids` 是逗号串（无外键），不清理就会留下悬空 id：
  /// 今日任务的目标复习量按"幽灵词库"计算、计划进度永远到不了 100%。
  /// 剔除后计划若已无任何词库，则标记为已完成。
  Future<void> _pruneStudyPlans(
    Transaction txn,
    List<int> removedBookIds,
  ) async {
    final existing = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'study_plans'",
    );
    if (existing.isEmpty) return;
    final removedSet = removedBookIds.toSet();
    final rows = await txn.query('study_plans');
    for (final row in rows) {
      final plan = StudyPlan.fromMap(row);
      if (plan.id == null) continue;
      final remaining =
          plan.wordBookIds.where((id) => !removedSet.contains(id)).toList();
      if (remaining.length == plan.wordBookIds.length) continue;
      final updated = plan.copyWith(
        wordBookIds: remaining,
        status: remaining.isEmpty ? StudyPlanStatus.completed : plan.status,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'study_plans',
        updated.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [plan.id],
      );
    }
  }

  Future<void> _deleteWordReferencesForBooks(
    Transaction txn,
    String bookPlaceholders,
    List<int> bookIds,
  ) async {
    // 先取出库里实际存在的表：测试夹具与极老的库可能缺表，
    // 一条 "no such table" 会让整个删除事务回滚（连词库都删不掉）
    final existing = (await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name'] as String).toSet();
    bool has(String table) => existing.contains(table);

    final wordSubquery =
        'SELECT id FROM words WHERE word_book_id IN ($bookPlaceholders)';
    // 单词级引用：新库靠 ON DELETE CASCADE，但老库（v3→v4 升级路径建的
    // study_sessions 等）没有外键约束，只依赖级联会留下孤儿行 → 这里显式清理。
    for (final table in [
      'wrong_words',
      'review_records',
      'wrong_words_strength',
      'session_mastery_records',
      'reader_marks',
      'word_favorites',
    ]) {
      if (!has(table)) continue;
      await txn.rawDelete(
        'DELETE FROM $table WHERE word_id IN ($wordSubquery)',
        bookIds,
      );
    }
    // 词库级引用：同样显式删，不依赖外键
    for (final table in [
      'study_sessions',
      'study_progress',
      'reader_bookmarks',
      'reader_progress',
    ]) {
      if (!has(table)) continue;
      await txn.rawDelete(
        'DELETE FROM $table WHERE word_book_id IN ($bookPlaceholders)',
        bookIds,
      );
    }
  }

  /// 重置单个词库的学习进度：只清进度，保留单词本身。
  /// 清理清单与 [_deleteWordReferencesForBooks] 一致（去掉 word_favorites、
  /// reader_marks 这两个跨词库全局收藏/标记，及 word_books/words 两表）。
  Future<void> resetBookProgress(int bookId) async {
    final db = await _dbFuture();
    await db.transaction((txn) async {
      final existing = (await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      )).map((row) => row['name'] as String).toSet();
      final wordSubquery =
          'SELECT id FROM words WHERE word_book_id = ?';
      for (final table in [
        'wrong_words',
        'review_records',
        'wrong_words_strength',
        'session_mastery_records',
      ]) {
        if (!existing.contains(table)) continue;
        await txn.rawDelete(
          'DELETE FROM $table WHERE word_id IN ($wordSubquery)',
          [bookId],
        );
      }
      for (final table in [
        'study_sessions',
        'study_progress',
        'reader_bookmarks',
        'reader_progress',
      ]) {
        if (!existing.contains(table)) continue;
        await txn.delete(table, where: 'word_book_id = ?', whereArgs: [bookId]);
      }
    });
  }

  Future<bool> hasWordsInBook(int bookId) async {
    final db = await _dbFuture();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    return ((result.first['c'] as int?) ?? 0) > 0;
  }
}

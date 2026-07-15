import 'package:sqflite/sqflite.dart';
import '../../models/custom_word_set.dart';
import '../../models/custom_word_set_item_sort_mode.dart';
import '../../models/custom_word_set_sort_mode.dart';
import '../../models/word.dart';

/// 自定义单词集 DAO
///
/// 负责 custom_word_sets 和 custom_word_set_items 两张表的增删改查。
class CustomWordSetDao {
  final Future<Database> _dbFuture;

  CustomWordSetDao(this._dbFuture);

  // ========== 单词集 ==========

  /// 创建单词集
  Future<int> createSet(CustomWordSet set) async {
    final db = await _dbFuture;
    final map = set.toMap()..remove('id');
    return await db.insert('custom_word_sets', map);
  }

  /// 更新单词集
  Future<void> updateSet(CustomWordSet set) async {
    if (set.id == null) return;
    final db = await _dbFuture;
    await db.update(
      'custom_word_sets',
      set.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [set.id],
    );
  }

  /// 删除单词集（条目通过外键级联删除）
  Future<void> deleteSet(int setId) async {
    final db = await _dbFuture;
    await db.delete('custom_word_sets', where: 'id = ?', whereArgs: [setId]);
  }

  /// 获取全部单词集（支持搜索 + 排序）
  Future<List<CustomWordSet>> getAllSets({
    String? query,
    CustomWordSetSortMode orderBy = CustomWordSetSortMode.updatedDesc,
  }) async {
    final db = await _dbFuture;
    final trimmed = query?.trim();
    final hasQuery = trimmed != null && trimmed.isNotEmpty;
    final like = hasQuery ? '%$trimmed%' : null;

    String sql;
    final args = <Object?>[];
    if (orderBy == CustomWordSetSortMode.wordCountDesc) {
      // 词数排序需要 GROUP BY + COUNT
      sql =
          '''
        SELECT s.* FROM custom_word_sets s
        LEFT JOIN custom_word_set_items i ON i.set_id = s.id
        ${hasQuery ? 'WHERE s.name LIKE ? OR IFNULL(s.description, \'\') LIKE ?' : ''}
        GROUP BY s.id
        ORDER BY COUNT(i.id) DESC, s.updated_at DESC
      ''';
      if (hasQuery) {
        args.add(like);
        args.add(like);
      }
    } else {
      sql = 'SELECT * FROM custom_word_sets';
      if (hasQuery) {
        sql += ' WHERE name LIKE ? OR IFNULL(description, \'\') LIKE ?';
        args.add(like);
        args.add(like);
      }
      switch (orderBy) {
        case CustomWordSetSortMode.nameAsc:
          sql += ' ORDER BY name COLLATE NOCASE ASC';
          break;
        case CustomWordSetSortMode.updatedDesc:
          sql += ' ORDER BY updated_at DESC';
          break;
        case CustomWordSetSortMode.wordCountDesc:
          break; // 不会到这里
      }
    }

    final result = await db.rawQuery(sql, args);
    return result.map((row) => CustomWordSet.fromMap(row)).toList();
  }

  /// 按 ID 获取单词集
  Future<CustomWordSet?> getSet(int setId) async {
    final db = await _dbFuture;
    final result = await db.query(
      'custom_word_sets',
      where: 'id = ?',
      whereArgs: [setId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return CustomWordSet.fromMap(result.first);
  }

  // ========== 单词集条目 ==========

  /// 向单词集添加单词（已存在则忽略）
  Future<void> addWord(int setId, int wordId) async {
    final db = await _dbFuture;
    final existing = await db.query(
      'custom_word_set_items',
      where: 'set_id = ? AND word_id = ?',
      whereArgs: [setId, wordId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final maxOrderResult = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) as m FROM custom_word_set_items WHERE set_id = ?',
      [setId],
    );
    final nextOrder = ((maxOrderResult.first['m'] as int?) ?? 0) + 1;
    await db.insert('custom_word_set_items', {
      'set_id': setId,
      'word_id': wordId,
      'sort_order': nextOrder,
      'added_at': DateTime.now().toIso8601String(),
    });
    await _touchSet(setId);
  }

  /// 批量加入单词
  Future<void> addWords(int setId, List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture;
    await db.transaction((txn) async {
      // 查询已存在的，避免重复
      final placeholders = List.filled(wordIds.length, '?').join(',');
      final existed = await txn.query(
        'custom_word_set_items',
        columns: ['word_id'],
        where: 'set_id = ? AND word_id IN ($placeholders)',
        whereArgs: [setId, ...wordIds],
      );
      final existedIds = existed.map((row) => row['word_id'] as int).toSet();
      final maxOrderResult = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), 0) as m FROM custom_word_set_items WHERE set_id = ?',
        [setId],
      );
      var nextOrder = ((maxOrderResult.first['m'] as int?) ?? 0) + 1;
      final batch = txn.batch();
      for (final wid in wordIds) {
        if (existedIds.contains(wid)) continue;
        batch.insert('custom_word_set_items', {
          'set_id': setId,
          'word_id': wid,
          'sort_order': nextOrder++,
          'added_at': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
    });
    await _touchSet(setId);
  }

  /// 原子移动单词到其他词集
  Future<void> moveWords(
    int sourceSetId,
    int targetSetId,
    List<int> wordIds,
  ) async {
    if (wordIds.isEmpty || sourceSetId == targetSetId) return;
    final db = await _dbFuture;
    final placeholders = List.filled(wordIds.length, '?').join(',');
    await db.transaction((txn) async {
      final existed = await txn.query(
        'custom_word_set_items',
        columns: ['word_id'],
        where: 'set_id = ? AND word_id IN ($placeholders)',
        whereArgs: [targetSetId, ...wordIds],
      );
      final existedIds = existed.map((row) => row['word_id'] as int).toSet();
      final maxOrderResult = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), 0) as m FROM custom_word_set_items WHERE set_id = ?',
        [targetSetId],
      );
      var nextOrder = ((maxOrderResult.first['m'] as int?) ?? 0) + 1;
      final now = DateTime.now().toIso8601String();
      for (final wordId in wordIds) {
        if (existedIds.contains(wordId)) continue;
        await txn.insert('custom_word_set_items', {
          'set_id': targetSetId,
          'word_id': wordId,
          'sort_order': nextOrder++,
          'added_at': now,
        });
      }
      await txn.delete(
        'custom_word_set_items',
        where: 'set_id = ? AND word_id IN ($placeholders)',
        whereArgs: [sourceSetId, ...wordIds],
      );
      await txn.update(
        'custom_word_sets',
        {'updated_at': now},
        where: 'id IN (?, ?)',
        whereArgs: [sourceSetId, targetSetId],
      );
    });
  }

  /// 从单词集移除单词
  Future<void> removeWord(int setId, int wordId) async {
    final db = await _dbFuture;
    await db.delete(
      'custom_word_set_items',
      where: 'set_id = ? AND word_id = ?',
      whereArgs: [setId, wordId],
    );
    await _touchSet(setId);
  }

  /// 批量移除单词
  Future<void> removeWords(int setId, List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture;
    final placeholders = List.filled(wordIds.length, '?').join(',');
    await db.delete(
      'custom_word_set_items',
      where: 'set_id = ? AND word_id IN ($placeholders)',
      whereArgs: [setId, ...wordIds],
    );
    await _touchSet(setId);
  }

  /// 获取单词集内的单词列表（支持排序）
  Future<List<Word>> getWordsInSet(
    int setId, {
    CustomWordSetItemSortMode orderBy = CustomWordSetItemSortMode.addedAsc,
  }) async {
    final db = await _dbFuture;
    final orderByClause = orderBy == CustomWordSetItemSortMode.wordAsc
        ? 'w.word COLLATE NOCASE ASC'
        : 'i.sort_order ASC, i.added_at ASC';
    final result = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      INNER JOIN custom_word_set_items i ON w.id = i.word_id
      WHERE i.set_id = ?
      ORDER BY $orderByClause
      ''',
      [setId],
    );
    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// 获取条目数量
  Future<int> getWordCount(int setId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM custom_word_set_items WHERE set_id = ?',
      [setId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// 批量获取多个集合的词数
  Future<Map<int, int>> getWordCounts(List<int> setIds) async {
    if (setIds.isEmpty) return {};
    final db = await _dbFuture;
    final placeholders = List.filled(setIds.length, '?').join(',');
    final result = await db.rawQuery('''
      SELECT set_id, COUNT(*) as c FROM custom_word_set_items
      WHERE set_id IN ($placeholders)
      GROUP BY set_id
      ''', setIds);
    final map = <int, int>{for (final id in setIds) id: 0};
    for (final row in result) {
      map[row['set_id'] as int] = (row['c'] as int?) ?? 0;
    }
    return map;
  }

  /// 更新单词集的更新时间
  Future<void> _touchSet(int setId) async {
    final db = await _dbFuture;
    await db.update(
      'custom_word_sets',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// 判断某个单词是否已在指定词集中
  Future<bool> isWordInSet(int setId, int wordId) async {
    final db = await _dbFuture;
    final result = await db.query(
      'custom_word_set_items',
      where: 'set_id = ? AND word_id = ?',
      whereArgs: [setId, wordId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 更新词集的上次学习时间
  Future<void> updateLastStudiedAt(int setId, DateTime when) async {
    final db = await _dbFuture;
    await db.update(
      'custom_word_sets',
      {'last_studied_at': when.toIso8601String()},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// 阶段四：统计自定义词集总数
  Future<int> getSetCount() async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM custom_word_sets',
    );
    return (result.first['c'] as int?) ?? 0;
  }
}

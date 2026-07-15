import 'package:sqflite/sqflite.dart';
import '../../models/favorite_sort_mode.dart';
import '../../models/favorite_word.dart';
import '../../models/word.dart';

/// 收藏夹数据访问对象
///
/// 负责 favorites 表的增删改查。表结构由 [DatabaseService] 在
/// 数据库版本 10 升级时创建。
class FavoriteDao {
  final Future<Database> _dbFuture;

  FavoriteDao(this._dbFuture);

  /// 添加收藏（同一单词重复添加将覆盖分组与备注）
  Future<int> addFavorite({
    required int wordId,
    String groupName = FavoriteWord.defaultGroup,
    String? note,
  }) async {
    final db = await _dbFuture;
    final existing = await db.query(
      'favorites',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      // 已存在则更新分组与备注
      await db.update(
        'favorites',
        {'group_name': groupName, 'note': note},
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      return existing.first['id'] as int;
    }
    return await db.insert('favorites', {
      'word_id': wordId,
      'group_name': groupName,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
      'last_studied_at': null,
    });
  }

  /// 移除收藏
  Future<void> removeFavorite(int wordId) async {
    final db = await _dbFuture;
    await db.delete('favorites', where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// 批量移除收藏
  Future<void> removeFavorites(List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture;
    final placeholders = List.filled(wordIds.length, '?').join(',');
    await db.delete(
      'favorites',
      where: 'word_id IN ($placeholders)',
      whereArgs: wordIds,
    );
  }

  /// 判断单词是否已收藏
  Future<bool> isFavorite(int wordId) async {
    final db = await _dbFuture;
    final result = await db.query(
      'favorites',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 获取所有收藏记录
  Future<List<FavoriteWord>> getAllFavorites({String? groupName}) async {
    final db = await _dbFuture;
    final result = await db.query(
      'favorites',
      where: groupName != null ? 'group_name = ?' : null,
      whereArgs: groupName != null ? [groupName] : null,
      orderBy: 'created_at DESC',
    );
    return result.map((row) => FavoriteWord.fromMap(row)).toList();
  }

  /// 获取收藏的单词详情（联表查询）
  Future<List<Word>> getFavoriteWords({
    String? groupName,
    FavoriteSortMode orderBy = FavoriteSortMode.createdDesc,
  }) async {
    final db = await _dbFuture;
    final args = <Object>[];
    var sql = '''
      SELECT w.* FROM words w
      INNER JOIN favorites f ON w.id = f.word_id
    ''';
    if (groupName != null) {
      sql += ' WHERE f.group_name = ?';
      args.add(groupName);
    }
    sql += _orderByClause(orderBy);
    final result = await db.rawQuery(sql, args);
    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// 根据排序方式生成 ORDER BY 子句
  String _orderByClause(FavoriteSortMode mode) {
    switch (mode) {
      case FavoriteSortMode.createdDesc:
        return ' ORDER BY f.created_at DESC';
      case FavoriteSortMode.wordAsc:
        return ' ORDER BY w.word COLLATE NOCASE ASC';
      case FavoriteSortMode.lastStudiedDesc:
        // 未复习（NULL）置底，再按复习时间倒序，最后回退到收藏时间
        return ' ORDER BY '
            'CASE WHEN f.last_studied_at IS NULL THEN 1 ELSE 0 END, '
            'f.last_studied_at DESC, '
            'f.created_at DESC';
    }
  }

  /// 根据 wordId 获取收藏记录
  Future<FavoriteWord?> getByWordId(int wordId) async {
    final db = await _dbFuture;
    final result = await db.query(
      'favorites',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return FavoriteWord.fromMap(result.first);
  }

  /// 批量更新收藏分组
  Future<void> updateGroupBatch(List<int> wordIds, String groupName) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture;
    final placeholders = List.filled(wordIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE favorites SET group_name = ? WHERE word_id IN ($placeholders)',
      [groupName, ...wordIds],
    );
  }

  /// 获取收藏数量
  Future<int> getFavoriteCount() async {
    final db = await _dbFuture;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM favorites');
    return (result.first['c'] as int?) ?? 0;
  }

  /// 阶段四：获取收藏分组数（去重后的非空 group_name 数量）
  Future<int> getFavoriteGroupCount() async {
    final db = await _dbFuture;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT group_name) as c
      FROM favorites
      WHERE group_name IS NOT NULL AND TRIM(group_name) <> ''
    ''');
    return (result.first['c'] as int?) ?? 0;
  }

  /// 获取所有分组名称（去重 + 计数）
  Future<List<MapEntry<String, int>>> getGroups() async {
    final db = await _dbFuture;
    final result = await db.rawQuery('''
      SELECT group_name, COUNT(*) as c FROM favorites
      GROUP BY group_name
      ORDER BY group_name ASC
    ''');
    return result
        .map(
          (row) => MapEntry(
            (row['group_name'] as String?) ?? FavoriteWord.defaultGroup,
            (row['c'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  /// 更新分组
  Future<void> updateGroup(int wordId, String groupName) async {
    final db = await _dbFuture;
    await db.update(
      'favorites',
      {'group_name': groupName},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 更新备注
  Future<void> updateNote(int wordId, String? note) async {
    final db = await _dbFuture;
    await db.update(
      'favorites',
      {'note': note},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 更新最近学习时间
  Future<void> updateLastStudiedAt(List<int> wordIds, DateTime when) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture;
    final placeholders = List.filled(wordIds.length, '?').join(',');
    await db.update(
      'favorites',
      {'last_studied_at': when.toIso8601String()},
      where: 'word_id IN ($placeholders)',
      whereArgs: wordIds,
    );
  }
}

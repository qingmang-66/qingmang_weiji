import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';
import '../../models/models.dart';

/// 复习记录数据访问对象
class ReviewDao {
  final Future<Database> Function() _dbFuture;

  ReviewDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  Future<int> saveReviewRecord(ReviewRecord record) async {
    final db = await _dbFuture();
    final map = record.toMap();
    // first_learned_at 保留策略：
    // 1. 内存记录已有值则沿用；2. 库中已有值（含历史 NULL 回填）则沿用；
    // 3. 全新单词首次落库时写当前时间。
    // 查-组装-插入必须在同一事务内：并发保存同一词时两步交错会互相覆盖
    return await db.transaction((txn) async {
      if (record.firstLearnedAt != null) {
        map['first_learned_at'] = record.firstLearnedAt!.toIso8601String();
      } else {
        final existing = await txn.query(
          'review_records',
          columns: ['first_learned_at', 'last_review'],
          where: 'word_id = ?',
          whereArgs: [record.wordId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final raw = existing.first['first_learned_at'];
          final fallback = existing.first['last_review'];
          // 历史数据 NULL 时用上次复习时间近似回填，保证早于"今日"不计为新学；
          // 两个字段都可能是 NULL（脏数据），再兜底当前时间避免 null as String 崩溃
          map['first_learned_at'] = raw is String && raw.isNotEmpty
              ? raw
              : (fallback is String && fallback.isNotEmpty
                    ? fallback
                    : DateTime.now().toIso8601String());
        } else {
          map['first_learned_at'] = DateTime.now().toIso8601String();
        }
      }
      await txn.insert(
        'review_records',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final saved = await txn.query(
        'review_records',
        columns: ['id'],
        where: 'word_id = ?',
        whereArgs: [record.wordId],
        limit: 1,
      );
      // 理论上插入后必然能查到；极端竞态下为空时返回 0 而不是抛 No element
      return (saved.isEmpty ? null : saved.first['id'] as int?) ?? 0;
    });
  }

  Future<ReviewRecord?> getReviewRecord(int wordId) async {
    final db = await _dbFuture();
    final maps = await db.query(
      'review_records',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ReviewRecord.fromMap(maps.first);
  }

  /// 批量获取复习记录，避免 N+1
  Future<Map<int, ReviewRecord?>> getReviewRecordsByWordIds(
    List<int> wordIds,
  ) async {
    if (wordIds.isEmpty) return {};
    final db = await _dbFuture();
    final result = <int, ReviewRecord?>{for (final id in wordIds) id: null};
    const chunkSize = 400;
    for (var i = 0; i < wordIds.length; i += chunkSize) {
      final chunk = wordIds.skip(i).take(chunkSize).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM review_records WHERE word_id IN ($placeholders)',
        chunk,
      );
      for (final map in maps) {
        final record = ReviewRecord.fromMap(map);
        result[record.wordId] = record;
      }
    }
    return result;
  }

  Future<List<ReviewRecord>> getAllReviewRecords() async {
    final db = await _dbFuture();
    final maps = await db.query('review_records');
    return maps.map((m) => ReviewRecord.fromMap(m)).toList();
  }
}

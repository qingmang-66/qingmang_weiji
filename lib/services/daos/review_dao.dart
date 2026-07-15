import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// 复习记录数据访问对象
class ReviewDao {
  final Future<Database> _dbFuture;

  ReviewDao(this._dbFuture);

  Future<int> saveReviewRecord(ReviewRecord record) async {
    final db = await _dbFuture;
    await db.insert(
      'review_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final saved = await db.query(
      'review_records',
      columns: ['id'],
      where: 'word_id = ?',
      whereArgs: [record.wordId],
      limit: 1,
    );
    return saved.first['id'] as int;
  }

  Future<ReviewRecord?> getReviewRecord(int wordId) async {
    final db = await _dbFuture;
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
    final db = await _dbFuture;
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
    final db = await _dbFuture;
    final maps = await db.query('review_records');
    return maps.map((m) => ReviewRecord.fromMap(m)).toList();
  }
}

import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// 复习记录数据访问对象
class ReviewDao {
  final Future<Database> _dbFuture;

  ReviewDao(this._dbFuture);

  Future<int> saveReviewRecord(ReviewRecord record) async {
    final db = await _dbFuture;
    // 先按 word_id 查询是否已存在记录，避免重复插入
    final existing = await db.query(
      'review_records',
      where: 'word_id = ?',
      whereArgs: [record.wordId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      final updatedRecord = record.copyWith(id: existingId);
      await db.update(
        'review_records',
        updatedRecord.toMap(),
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    } else {
      return await db.insert('review_records', record.toMap());
    }
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

  Future<List<ReviewRecord>> getAllReviewRecords() async {
    final db = await _dbFuture;
    final maps = await db.query('review_records');
    return maps.map((m) => ReviewRecord.fromMap(m)).toList();
  }
}

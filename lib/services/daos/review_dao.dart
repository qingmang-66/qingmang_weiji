import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// 复习记录数据访问对象
class ReviewDao {
  final Future<Database> _dbFuture;

  ReviewDao(this._dbFuture);

  Future<int> saveReviewRecord(ReviewRecord record) async {
    final db = await _dbFuture;
    if (record.id != null) {
      await db.update(
        'review_records',
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      return record.id!;
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

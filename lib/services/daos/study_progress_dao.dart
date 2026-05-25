import 'package:sqflite/sqflite.dart';

/// 学习进度数据访问对象
class StudyProgressDao {
  final Future<Database> _dbFuture;

  StudyProgressDao(this._dbFuture);

  Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
  }) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final wordIdsStr = wordIds.join(',');

    await db.delete('study_progress');

    await db.insert('study_progress', {
      'word_book_id': wordBookId,
      'study_mode': studyMode,
      'is_review': isReview ? 1 : 0,
      'current_index': currentIndex,
      'word_ids': wordIdsStr,
      'updated_at': now,
    });
  }

  Future<Map<String, dynamic>?> getStudyProgress() async {
    final db = await _dbFuture;
    final result = await db.query(
      'study_progress',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final wordIdsStr = row['word_ids'] as String;
    final wordIds = wordIdsStr.split(',').map((s) => int.parse(s)).toList();

    return {
      'wordBookId': row['word_book_id'] as int,
      'studyMode': row['study_mode'] as int,
      'isReview': (row['is_review'] as int) == 1,
      'currentIndex': row['current_index'] as int,
      'wordIds': wordIds,
      'updatedAt': DateTime.parse(row['updated_at'] as String),
    };
  }

  Future<void> clearStudyProgress() async {
    final db = await _dbFuture;
    await db.delete('study_progress');
  }

  Future<bool> hasStudyProgress() async {
    final db = await _dbFuture;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM study_progress');
    return (result.first['count'] as int? ?? 0) > 0;
  }
}

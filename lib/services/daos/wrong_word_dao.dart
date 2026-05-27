import 'package:sqflite/sqflite.dart';
import '../../models/word.dart';

/// 错词本数据访问对象
class WrongWordDao {
  final Future<Database> _dbFuture;

  WrongWordDao(this._dbFuture);

  /// 添加错词（已存在则增加错误次数）
  Future<void> addWrongWord(int wordId, {String? note}) async {
    final db = await _dbFuture;
    final existing = await db.query(
      'wrong_words',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'wrong_words',
        {
          'wrong_count': (existing[0]['wrong_count'] as int) + 1,
          'last_wrong_time': DateTime.now().toIso8601String(),
          'note': note ?? existing[0]['note'],
        },
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
    } else {
      await db.insert('wrong_words', {
        'word_id': wordId,
        'wrong_count': 1,
        'first_wrong_time': DateTime.now().toIso8601String(),
        'last_wrong_time': DateTime.now().toIso8601String(),
        'note': note,
      });
    }
  }

  /// 获取所有错词
  Future<List<Word>> getWrongWords({int? limit}) async {
    final db = await _dbFuture;
    final safeLimit = (limit != null && limit > 0) ? limit : null;

    String query = '''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
    ''';

    final List<Object> args = [];
    if (safeLimit != null) {
      query += ' LIMIT ?';
      args.add(safeLimit);
    }

    final result = await db.rawQuery(query, args);
    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// 获取错词数量
  Future<int> getWrongWordCount() async {
    final db = await _dbFuture;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM wrong_words');
    return (result[0]['count'] as int? ?? 0);
  }

  /// 获取指定单词的错误次数
  Future<int> getWrongCount(int wordId) async {
    final db = await _dbFuture;
    final result = await db.query(
      'wrong_words',
      columns: ['wrong_count'],
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    if (result.isNotEmpty) {
      return result[0]['wrong_count'] as int;
    }
    return 0;
  }

  /// 从错词本移除
  Future<void> removeWrongWord(int wordId) async {
    final db = await _dbFuture;
    await db.delete('wrong_words', where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// 批量移除错词
  Future<void> removeWrongWords(List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture;
    final placeholders = wordIds.map((_) => '?').join(',');
    await db.delete(
      'wrong_words',
      where: 'word_id IN ($placeholders)',
      whereArgs: wordIds,
    );
  }

  /// 更新错词备注
  Future<void> updateNote(int wordId, String note) async {
    final db = await _dbFuture;
    await db.update(
      'wrong_words',
      {'note': note},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 获取错词统计
  Future<Map<String, dynamic>> getWrongWordStats() async {
    final db = await _dbFuture;
    final totalCount = await db.rawQuery('SELECT COUNT(*) as count FROM wrong_words');
    final totalWrongCount = await db.rawQuery('SELECT SUM(wrong_count) as sum FROM wrong_words');
    final highWrongWords = await db.rawQuery(
      'SELECT COUNT(*) as count FROM wrong_words WHERE wrong_count >= 5',
    );

    return {
      'totalWrongWords': totalCount.first['count'] as int? ?? 0,
      'totalWrongTimes': totalWrongCount.first['sum'] as int? ?? 0,
      'highWrongWords': highWrongWords.first['count'] as int? ?? 0,
    };
  }

  /// 获取今日新增错词
  Future<List<Word>> getTodayWrongWords() async {
    final db = await _dbFuture;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final result = await db.rawQuery('''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      WHERE DATE(ww.last_wrong_time) = DATE(?)
      ORDER BY ww.last_wrong_time DESC
    ''', [startOfDay.toIso8601String()]);

    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }
}

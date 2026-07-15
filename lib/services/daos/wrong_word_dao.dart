import 'package:sqflite/sqflite.dart';
import '../../models/word.dart';

/// 错词本数据访问对象
class WrongWordDao {
  final Future<Database> _dbFuture;

  WrongWordDao(this._dbFuture);

  /// 添加错词（已存在则增加错误次数）
  Future<void> addWrongWord(int wordId, {String? note}) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        '''
        UPDATE wrong_words
        SET wrong_count = wrong_count + 1,
            last_wrong_time = ?,
            note = COALESCE(?, note)
        WHERE word_id = ?
        ''',
        [now, note, wordId],
      );
      if (updated > 0) return;
      await txn.insert('wrong_words', {
        'word_id': wordId,
        'wrong_count': 1,
        'first_wrong_time': now,
        'last_wrong_time': now,
        'note': note,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
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
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM wrong_words',
    );
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
    final totalCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM wrong_words',
    );
    final totalWrongCount = await db.rawQuery(
      'SELECT SUM(wrong_count) as sum FROM wrong_words',
    );
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

    final result = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      WHERE DATE(ww.last_wrong_time) = DATE(?)
      ORDER BY ww.last_wrong_time DESC
    ''',
      [startOfDay.toIso8601String()],
    );

    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Word>> getWrongWordsByIds(List<int> wordIds) async {
    if (wordIds.isEmpty) return [];
    final db = await _dbFuture;
    final placeholders = wordIds.map((_) => '?').join(',');
    final result = await db.rawQuery('''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      WHERE w.id IN ($placeholders)
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
    ''', wordIds);

    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> reduceWrongCount(int wordId) async {
    final db = await _dbFuture;
    await db.rawUpdate(
      '''
      UPDATE wrong_words
      SET wrong_count = wrong_count - 1
      WHERE word_id = ? AND wrong_count > 1
      ''',
      [wordId],
    );
  }

  Future<void> addStrengthEvent({
    required int wordId,
    required bool isWrong,
    bool viewedAnswer = false,
    String? reviewMode,
  }) async {
    final db = await _dbFuture;
    await db.insert('wrong_words_strength', {
      'word_id': wordId,
      'is_wrong': isWrong ? 1 : 0,
      'viewed_answer': viewedAnswer ? 1 : 0,
      'review_mode': reviewMode,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateStrength(int wordId, double strength) async {
    final db = await _dbFuture;
    await db.update(
      'wrong_words',
      {'strength': strength},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  Future<void> batchUpdateStrength(Map<int, double> values) async {
    if (values.isEmpty) return;
    final db = await _dbFuture;
    final batch = db.batch();
    for (final entry in values.entries) {
      batch.update(
        'wrong_words',
        {'strength': entry.value},
        where: 'word_id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
  }

  // ========== 阶段四：高频错词排行 - 新增方法 ==========

  /// 拉取全部错词 + 关联 word 详情（带元数据）
  ///
  /// 返回结构：[{word, wrongCount, lastWrongTime, firstWrongTime}]
  /// 排序：按 wrong_count DESC, last_wrong_time DESC
  Future<List<WrongWordMetaRow>> getAllWithMeta() async {
    final db = await _dbFuture;
    final result = await db.rawQuery('''
      SELECT
        w.id AS id,
        w.word,
        w.definition,
        w.word_book_id,
        ww.wrong_count,
        ww.last_wrong_time,
        ww.first_wrong_time,
        ww.strength
      FROM wrong_words ww
      INNER JOIN words w ON w.id = ww.word_id
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
    ''');
    return result.map((row) => WrongWordMetaRow.fromMap(row)).toList();
  }

  /// 聚合 strength 表的查看答案次数与最近复习是否再错
  ///
  /// 返回 `Map<wordId, {viewedAnswerCount, latestReviewWrong}>`
  Future<Map<int, WrongWordStrengthAggregate>> getStrengthAggregates(
    List<int> wordIds,
  ) async {
    if (wordIds.isEmpty) return {};
    final db = await _dbFuture;
    final placeholders = wordIds.map((_) => '?').join(',');

    // viewed_answer_count：累计 viewed_answer = 1 的次数
    final viewedResult = await db.rawQuery('''
      SELECT word_id, COUNT(*) AS viewed_count
      FROM wrong_words_strength
      WHERE word_id IN ($placeholders) AND viewed_answer = 1
      GROUP BY word_id
    ''', wordIds);

    // latest_review_wrong：取每个 word_id 最新一条 strength 记录
    final latestResult = await db.rawQuery('''
      SELECT word_id, is_wrong
      FROM wrong_words_strength wws1
      WHERE word_id IN ($placeholders)
        AND id = (
          SELECT MAX(id) FROM wrong_words_strength wws2
          WHERE wws2.word_id = wws1.word_id
        )
    ''', wordIds);

    final viewedMap = <int, int>{};
    for (final row in viewedResult) {
      viewedMap[row['word_id'] as int] = (row['viewed_count'] as int?) ?? 0;
    }
    final latestMap = <int, bool>{};
    for (final row in latestResult) {
      latestMap[row['word_id'] as int] = (row['is_wrong'] as int? ?? 0) == 1;
    }

    final aggregate = <int, WrongWordStrengthAggregate>{};
    for (final id in wordIds) {
      aggregate[id] = WrongWordStrengthAggregate(
        viewedAnswerCount: viewedMap[id] ?? 0,
        latestReviewWrong: latestMap[id] ?? false,
      );
    }
    return aggregate;
  }
}

/// DAO 拉取错词元数据时的中间行
class WrongWordMetaRow {
  final Word word;
  final int wrongCount;
  final DateTime lastWrongTime;
  final DateTime? firstWrongTime;

  const WrongWordMetaRow({
    required this.word,
    required this.wrongCount,
    required this.lastWrongTime,
    this.firstWrongTime,
  });

  factory WrongWordMetaRow.fromMap(Map<String, dynamic> row) {
    // 解析时间字段，对 null / 非法值做容错，避免崩溃
    final lastWrongRaw = row['last_wrong_time'];
    final firstWrongRaw = row['first_wrong_time'];
    return WrongWordMetaRow(
      word: Word.fromMap(Map<String, dynamic>.from(row)),
      wrongCount: row['wrong_count'] as int? ?? 0,
      lastWrongTime: lastWrongRaw == null
          ? DateTime.now()
          : (DateTime.tryParse(lastWrongRaw.toString()) ?? DateTime.now()),
      firstWrongTime: firstWrongRaw == null
          ? null
          : DateTime.tryParse(firstWrongRaw.toString()),
    );
  }
}

/// strength 表聚合结果
class WrongWordStrengthAggregate {
  final int viewedAnswerCount;
  final bool latestReviewWrong;

  const WrongWordStrengthAggregate({
    required this.viewedAnswerCount,
    required this.latestReviewWrong,
  });
}

/// 阶段四：错词统计扩展查询
extension WrongWordStatsExt on WrongWordDao {
  /// 错词本最高"连续答对"次数
  ///
  /// 计算每条错词最近 strength 记录流中 is_wrong=0 的最长连击，
  /// 再取所有错词中的最大值。无数据时返回 0。
  Future<int> getMaxCorrectStreakInWrongWords() async {
    final db = await _dbFuture;
    final rows = await db.rawQuery('''
      SELECT word_id, is_wrong
      FROM wrong_words_strength
      ORDER BY word_id ASC, id ASC
    ''');
    if (rows.isEmpty) return 0;
    final grouped = <int, List<int>>{};
    for (final r in rows) {
      final wid = r['word_id'] as int;
      grouped.putIfAbsent(wid, () => []).add((r['is_wrong'] as int? ?? 0));
    }
    int best = 0;
    for (final list in grouped.values) {
      int cur = 0;
      for (final w in list) {
        if (w == 0) {
          cur += 1;
          if (cur > best) best = cur;
        } else {
          cur = 0;
        }
      }
    }
    return best;
  }
}

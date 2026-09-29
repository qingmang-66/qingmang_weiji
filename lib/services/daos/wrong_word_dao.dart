import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';
import '../../models/word.dart';

/// 错词本数据访问对象
class WrongWordDao {
  /// IN 子句分块大小（与 word_dao / review_dao 保持一致）：
  /// 老版本 SQLite 的变量上限为 999，超限会直接抛错
  static const int _inChunkSize = 400;

  final Future<Database> Function() _dbFuture;

  WrongWordDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  /// 添加错词（已存在则增加错误次数）
  ///
  /// 答错/看答案都会走这里，因此顺手把 [correctStreak] 清零 —— 连续答对进度
  /// 对应的就是"连续答对 3 次移出错词本"这条规则。
  Future<void> addWrongWord(int wordId, {String? note}) async {
    final db = await _dbFuture();
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        '''
        UPDATE wrong_words
        SET wrong_count = wrong_count + 1,
            correct_streak = 0,
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
        'correct_streak': 0,
        'first_wrong_time': now,
        'last_wrong_time': now,
        'note': note,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  /// 获取所有错词
  Future<List<Word>> getWrongWords({int? limit}) async {
    final db = await _dbFuture();
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
    final db = await _dbFuture();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM wrong_words',
    );
    return (result[0]['count'] as int? ?? 0);
  }

  /// 获取指定单词的错误次数
  Future<int> getWrongCount(int wordId) async {
    final db = await _dbFuture();
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
    final db = await _dbFuture();
    await db.delete('wrong_words', where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// 批量移除错词
  Future<void> removeWrongWords(List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture();
    //IN 子句分块：老版本 SQLite 变量上限 999，超限抛错且整批丢失
    for (var i = 0; i < wordIds.length; i += _inChunkSize) {
      final end = i + _inChunkSize < wordIds.length
          ? i + _inChunkSize
          : wordIds.length;
      final chunk = wordIds.sublist(i, end);
      final placeholders = chunk.map((_) => '?').join(',');
      await db.delete(
        'wrong_words',
        where: 'word_id IN ($placeholders)',
        whereArgs: chunk,
      );
    }
  }

  /// 恢复被移除的错词（撤销"标记已掌握"）
  ///
  /// 用显式值回插，保留原来的错误次数 / 时间 / 连续答对进度，
  /// 而不是按"新错词"重新计数。
  Future<void> restoreWrongWords(List<WrongWordSnapshot> snapshots) async {
    if (snapshots.isEmpty) return;
    final db = await _dbFuture();
    await db.transaction((txn) async {
      for (final snapshot in snapshots) {
        await txn.insert('wrong_words', {
          'word_id': snapshot.wordId,
          'wrong_count': snapshot.wrongCount,
          'correct_streak': snapshot.correctStreak,
          'first_wrong_time': snapshot.firstWrongTime.toIso8601String(),
          'last_wrong_time': snapshot.lastWrongTime.toIso8601String(),
          'note': snapshot.note,
          'strength': snapshot.strength,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// 更新错词备注
  Future<void> updateNote(int wordId, String note) async {
    final db = await _dbFuture();
    await db.update(
      'wrong_words',
      {'note': note},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 获取错词统计
  Future<Map<String, dynamic>> getWrongWordStats() async {
    final db = await _dbFuture();
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
  ///
  /// 用"范围比较"而不是 `DATE(列) = DATE(?)`：后者在列上套函数，无法命中
  /// `idx_wrong_last_time`，每次进错词页/首页都要全表扫描。
  /// 范围端点与本 DAO 的写入格式（本地 ISO8601）同源，字符串比较即为时间序。
  Future<List<Word>> getTodayWrongWords() async {
    final db = await _dbFuture();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfNextDay = DateTime(today.year, today.month, today.day + 1);

    final result = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      WHERE ww.last_wrong_time >= ? AND ww.last_wrong_time < ?
      ORDER BY ww.last_wrong_time DESC
    ''',
      [
        startOfDay.toIso8601String(),
        startOfNextDay.toIso8601String(),
      ],
    );

    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Word>> getWrongWordsByIds(List<int> wordIds) async {
    if (wordIds.isEmpty) return [];
    final db = await _dbFuture();
    final result = <Map<String, Object?>>[];
    //IN 子句分块（同一排序在每块内应用，最后再整体排一次）
    for (var i = 0; i < wordIds.length; i += _inChunkSize) {
      final end = i + _inChunkSize < wordIds.length
          ? i + _inChunkSize
          : wordIds.length;
      final chunk = wordIds.sublist(i, end);
      final placeholders = chunk.map((_) => '?').join(',');
      result.addAll(
        await db.rawQuery('''
          SELECT w.*, ww.wrong_count AS _sort_wrong_count,
                 ww.last_wrong_time AS _sort_last_wrong
          FROM words w
          INNER JOIN wrong_words ww ON w.id = ww.word_id
          WHERE w.id IN ($placeholders)
        ''', chunk),
      );
    }
    result.sort((a, b) {
      final c1 = (b['_sort_wrong_count'] as int? ?? 0)
          .compareTo(a['_sort_wrong_count'] as int? ?? 0);
      if (c1 != 0) return c1;
      return (b['_sort_last_wrong'] as String? ?? '')
          .compareTo(a['_sort_last_wrong'] as String? ?? '');
    });

    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> reduceWrongCount(int wordId) async {
    final db = await _dbFuture();
    await db.rawUpdate(
      '''
      UPDATE wrong_words
      SET wrong_count = wrong_count - 1
      WHERE word_id = ? AND wrong_count > 1
      ''',
      [wordId],
    );
  }

  /// 记一次"答对"：错误次数 -1（下限 1），连续答对次数 +1；
  /// 传入 [correctStreak] 时改为写入该绝对值。
  ///
  /// 绝对值用于学习页结算场景：内存里的 [WrongWordReviewResult.nextCorrectStreak]
  /// 是"以入库基准起算、答错清零"的绝对语义，一次会话每词只应用最后一条结果，
  /// 若落库仍在旧库值上 +1，"先答错再答对"会把 streak 虚增到库值+1（应为 1）。
  ///
  /// 连续答对次数与"答对"必须原子更新：它是 [WrongWordReviewResult] 判断
  /// 「连续答对 3 次 → 移出错词本」的依据，此前只存在学习页的内存里，
  /// 中途退出就归零。
  Future<void> applyCorrectReview(int wordId, {int? correctStreak}) async {
    final db = await _dbFuture();
    if (correctStreak != null) {
      await db.rawUpdate(
        '''
        UPDATE wrong_words
        SET correct_streak = ?,
            wrong_count = CASE WHEN wrong_count > 1 THEN wrong_count - 1 ELSE wrong_count END
        WHERE word_id = ?
        ''',
        [correctStreak, wordId],
      );
      return;
    }
    await db.rawUpdate(
      '''
      UPDATE wrong_words
      SET correct_streak = correct_streak + 1,
          wrong_count = CASE WHEN wrong_count > 1 THEN wrong_count - 1 ELSE wrong_count END
      WHERE word_id = ?
      ''',
      [wordId],
    );
  }

  /// 批量应用错词复习结果（单事务）。
  ///
  /// 逐词调用时每个词都要独立事务（各自的 fsync），一场复习几十个词会明显变慢；
  /// 语义与 [removeWrongWord] / [addWrongWord] / [applyCorrectReview] 保持一致。
  Future<void> applyReviewResultsBatch({
    required List<int> removeIds,
    required List<int> strengthenIds,
    // wordId → 连续答对次数的绝对值（WrongWordReviewResult.nextCorrectStreak）。
    // 不能在旧库值上 +1：一次会话每词只应用最后一条结果，"先答错再答对"
    // 时 +1 会把库值虚增（如库值 2 → 3，而内存语义应为 1），
    // 导致错词提前达到"连续答对 3 次"被移出错词本。
    required Map<int, int> correctStreaks,
  }) async {
    if (removeIds.isEmpty && strengthenIds.isEmpty && correctStreaks.isEmpty) {
      return;
    }
    final db = await _dbFuture();
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      //IN 子句分块：老版本 SQLite 的变量上限为 999，超限会抛错并使整批结果丢失
      for (var i = 0; i < removeIds.length; i += _inChunkSize) {
        final end = i + _inChunkSize < removeIds.length
            ? i + _inChunkSize
            : removeIds.length;
        final chunk = removeIds.sublist(i, end);
        final placeholders = chunk.map((_) => '?').join(',');
        await txn.delete(
          'wrong_words',
          where: 'word_id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
      for (final wordId in strengthenIds) {
        final updated = await txn.rawUpdate(
          '''
          UPDATE wrong_words
          SET wrong_count = wrong_count + 1,
              correct_streak = 0,
              last_wrong_time = ?
          WHERE word_id = ?
          ''',
          [now, wordId],
        );
        if (updated > 0) continue;
        await txn.insert('wrong_words', {
          'word_id': wordId,
          'wrong_count': 1,
          'correct_streak': 0,
          'first_wrong_time': now,
          'last_wrong_time': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      //streak 是逐词绝对值，无法合并成 IN 批写；一场复习的词量（几十个）
      //在同一事务内逐条 UPDATE 开销可接受
      for (final entry in correctStreaks.entries) {
        await txn.rawUpdate(
          '''
          UPDATE wrong_words
          SET correct_streak = ?,
              wrong_count = CASE WHEN wrong_count > 1 THEN wrong_count - 1 ELSE wrong_count END
          WHERE word_id = ?
          ''',
          [entry.value, entry.key],
        );
      }
    });
  }

  /// 全部错词的连续答对次数（进入错词专项复习前一次性载入）
  Future<Map<int, int>> getCorrectStreaks() async {
    final db = await _dbFuture();
    final rows = await db.query(
      'wrong_words',
      columns: ['word_id', 'correct_streak'],
    );
    return {
      for (final row in rows)
        row['word_id'] as int: (row['correct_streak'] as int?) ?? 0,
    };
  }

  /// 清理过期的作答事件，避免 `wrong_words_strength` 无限增长。
  ///
  /// 每次作答都会往这张表追加一行、且此前**全库没有任何清理语句**：
  /// 长期使用后行数线性增长，备份体积、错因聚合与"最长连击"扫描的
  /// 内存占用都会随之膨胀。错因/薄弱度只关心近期表现，保留 [days] 天足够。
  Future<int> pruneStrengthEvents({int days = 180}) async {
    final db = await _dbFuture();
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    return db.delete(
      'wrong_words_strength',
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> addStrengthEvent({
    required int wordId,
    required bool isWrong,
    bool viewedAnswer = false,
    String? reviewMode,
  }) async {
    final db = await _dbFuture();
    await db.insert('wrong_words_strength', {
      'word_id': wordId,
      'is_wrong': isWrong ? 1 : 0,
      'viewed_answer': viewedAnswer ? 1 : 0,
      'review_mode': reviewMode,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateStrength(int wordId, double strength) async {
    final db = await _dbFuture();
    await db.update(
      'wrong_words',
      {'strength': strength},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  Future<void> batchUpdateStrength(Map<int, double> values) async {
    if (values.isEmpty) return;
    final db = await _dbFuture();
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
    final db = await _dbFuture();
    final result = await db.rawQuery('''
      SELECT
        w.id AS id,
        w.word,
        w.phonetic,
        w.definition,
        w.word_book_id,
        ww.wrong_count,
        ww.correct_streak,
        ww.last_wrong_time,
        ww.first_wrong_time,
        ww.strength
      FROM wrong_words ww
      INNER JOIN words w ON w.id = ww.word_id
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
    ''');
    return result.map((row) => WrongWordMetaRow.fromMap(row)).toList();
  }

  /// 错因聚合（错题集标签 + 按错因筛选）
  ///
  /// 只统计 `is_wrong = 1` 的事件：答对的事件不该算作错因。
  /// 老库里 `wrong_words_strength` 没有数据时返回空 Map，
  /// 调用方应据此显示"暂无错因数据"而不是瞎猜。
  Future<Map<int, WrongWordCauseAggregate>> getCauseAggregates(
    List<int> wordIds,
  ) async {
    if (wordIds.isEmpty) return {};
    final db = await _dbFuture();
    final result = <int, WrongWordCauseAggregate>{};
    //IN 子句分块：错题集可能上千词，不分块会撞 SQLite 变量上限
    for (var i = 0; i < wordIds.length; i += _inChunkSize) {
      final end = i + _inChunkSize < wordIds.length
          ? i + _inChunkSize
          : wordIds.length;
      final chunk = wordIds.sublist(i, end);
      final placeholders = chunk.map((_) => '?').join(',');
      final rows = await db.rawQuery('''
        SELECT
          word_id,
          COUNT(*) AS wrong_events,
          SUM(CASE WHEN viewed_answer = 1 THEN 1 ELSE 0 END) AS revealed_events,
          SUM(CASE WHEN review_mode = 'spelling' THEN 1 ELSE 0 END) AS spelling_events,
          SUM(CASE WHEN review_mode = 'listening' THEN 1 ELSE 0 END) AS listening_events,
          SUM(CASE WHEN review_mode IN ('quizEnCn', 'quizCnEn') THEN 1 ELSE 0 END) AS quiz_events,
          SUM(CASE WHEN review_mode = 'recall' THEN 1 ELSE 0 END) AS recall_events
        FROM wrong_words_strength
        WHERE word_id IN ($placeholders) AND is_wrong = 1
        GROUP BY word_id
      ''', chunk);

      for (final row in rows) {
        int at(String key) => (row[key] as int?) ?? 0;
        result[row['word_id'] as int] = WrongWordCauseAggregate(
          wrongEvents: at('wrong_events'),
          revealedEvents: at('revealed_events'),
          spellingEvents: at('spelling_events'),
          listeningEvents: at('listening_events'),
          quizEvents: at('quiz_events'),
          recallEvents: at('recall_events'),
        );
      }
    }
    return result;
  }

  /// 聚合 strength 表的查看答案次数与最近复习是否再错
  ///
  /// 返回 `Map<wordId, {viewedAnswerCount, latestReviewWrong}>`
  Future<Map<int, WrongWordStrengthAggregate>> getStrengthAggregates(
    List<int> wordIds,
  ) async {
    if (wordIds.isEmpty) return {};
    final db = await _dbFuture();
    final viewedMap = <int, int>{};
    final latestMap = <int, bool>{};

    // IN 子句分块：调用方（错词排行）会传入全部错词 id，不分块会撞变量上限
    for (var i = 0; i < wordIds.length; i += _inChunkSize) {
      final end = i + _inChunkSize < wordIds.length
          ? i + _inChunkSize
          : wordIds.length;
      final chunk = wordIds.sublist(i, end);
      final placeholders = chunk.map((_) => '?').join(',');

      // viewed_answer_count：累计 viewed_answer = 1 的次数
      final viewedResult = await db.rawQuery('''
        SELECT word_id, COUNT(*) AS viewed_count
        FROM wrong_words_strength
        WHERE word_id IN ($placeholders) AND viewed_answer = 1
        GROUP BY word_id
      ''', chunk);
      for (final row in viewedResult) {
        viewedMap[row['word_id'] as int] = (row['viewed_count'] as int?) ?? 0;
      }

      // latest_review_wrong：每个 word_id 最新一条 strength 记录。
      // 不能用窗口函数 ROW_NUMBER()（SQLite >= 3.25 才支持，Android 老机型与
      // 老版 winsqlite3 上直接语法错误导致首页错词排行崩溃）；
      // 改用相关子查询按「时间优先、id 兜底」取最新一条，与 WeakVocabularyDao
      // 口径一致（MAX(id) 在 created_at 乱序/导入数据下会取到错误的"最近一次"）。
      final latestResult = await db.rawQuery('''
        SELECT s.word_id, s.is_wrong
        FROM wrong_words_strength s
        WHERE s.word_id IN ($placeholders)
          AND s.id = (
            SELECT t.id FROM wrong_words_strength t
            WHERE t.word_id = s.word_id
            ORDER BY datetime(t.created_at) DESC, t.id DESC
            LIMIT 1
          )
      ''', chunk);
      for (final row in latestResult) {
        latestMap[row['word_id'] as int] = (row['is_wrong'] as int? ?? 0) == 1;
      }
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

  /// 连续答对次数（达到 3 次即建议移出错词本）
  final int correctStreak;

  const WrongWordMetaRow({
    required this.word,
    required this.wrongCount,
    required this.lastWrongTime,
    this.firstWrongTime,
    this.correctStreak = 0,
  });

  factory WrongWordMetaRow.fromMap(Map<String, dynamic> row) {
    // 解析时间字段，对 null / 非法值做容错，避免崩溃
    final lastWrongRaw = row['last_wrong_time'];
    final firstWrongRaw = row['first_wrong_time'];
    return WrongWordMetaRow(
      word: Word.fromMap(Map<String, dynamic>.from(row)),
      wrongCount: row['wrong_count'] as int? ?? 0,
      correctStreak: (row['correct_streak'] as int?) ?? 0,
      lastWrongTime: lastWrongRaw == null
          ? DateTime.now()
          : (DateTime.tryParse(lastWrongRaw.toString()) ?? DateTime.now()),
      firstWrongTime: firstWrongRaw == null
          ? null
          : DateTime.tryParse(firstWrongRaw.toString()),
    );
  }
}

/// 被移除错词的快照，用于"撤销标记已掌握"
class WrongWordSnapshot {
  final int wordId;
  final int wrongCount;
  final int correctStreak;
  final DateTime firstWrongTime;
  final DateTime lastWrongTime;
  final String? note;
  final double strength;

  const WrongWordSnapshot({
    required this.wordId,
    required this.wrongCount,
    required this.firstWrongTime,
    required this.lastWrongTime,
    this.correctStreak = 0,
    this.note,
    this.strength = 0,
  });
}

/// 错词主要错因
enum WrongWordCause {
  /// 明确点开过答案（半数以上错次都是看答案）
  revealed,

  /// 拼写模式写错
  spelling,

  /// 听写模式写错
  listening,

  /// 测验模式选错
  quiz,

  /// 回忆模式想不起来
  recall,

  /// 没有可用的错因事件（老数据）
  unknown,
}

/// 错因聚合结果
class WrongWordCauseAggregate {
  final int wrongEvents;
  final int revealedEvents;
  final int spellingEvents;
  final int listeningEvents;
  final int quizEvents;
  final int recallEvents;

  const WrongWordCauseAggregate({
    this.wrongEvents = 0,
    this.revealedEvents = 0,
    this.spellingEvents = 0,
    this.listeningEvents = 0,
    this.quizEvents = 0,
    this.recallEvents = 0,
  });

  bool get hasData => wrongEvents > 0;

  /// 主导错因：看答案过半则优先归为"看答案"，否则取出现最多的模式；
  /// 全为 recall 或事件过少时归为"回忆不出"。
  WrongWordCause get dominant {
    if (wrongEvents <= 0) return WrongWordCause.unknown;
    if (revealedEvents * 2 >= wrongEvents) return WrongWordCause.revealed;
    final byMode = <WrongWordCause, int>{
      WrongWordCause.spelling: spellingEvents,
      WrongWordCause.listening: listeningEvents,
      WrongWordCause.quiz: quizEvents,
      WrongWordCause.recall: recallEvents,
    };
    var best = WrongWordCause.unknown;
    var bestCount = 0;
    for (final entry in byMode.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        best = entry.key;
      }
    }
    return best;
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
    final db = await _dbFuture();
    //不能再用窗口函数 ROW_NUMBER 做 gaps-and-islands（SQLite < 3.25 语法错误）。
    //改为按 word_id 分块拉取 (word_id, is_wrong) 序列，在 Dart 侧扫描最长连续
    //is_wrong=0 段：每块最多 _inChunkSize（WrongWordDao 内常量 400）个词的事件
    //行，内存可控，且结果与旧窗口函数实现等价。
    final wordIds = (await db.rawQuery(
      'SELECT DISTINCT word_id FROM wrong_words_strength',
    )).map((row) => row['word_id'] as int).toList(growable: false);
    if (wordIds.isEmpty) return 0;

    var best = 0;
    const chunkSize = 400;
    for (var i = 0; i < wordIds.length; i += chunkSize) {
      final end = i + chunkSize < wordIds.length
          ? i + chunkSize
          : wordIds.length;
      final chunk = wordIds.sublist(i, end);
      final placeholders = chunk.map((_) => '?').join(',');
      final rows = await db.rawQuery('''
        SELECT word_id, is_wrong
        FROM wrong_words_strength
        WHERE word_id IN ($placeholders)
        ORDER BY word_id, id
      ''', chunk);

      int? currentWordId;
      var run = 0;
      for (final row in rows) {
        final wordId = row['word_id'] as int;
        if (wordId != currentWordId) {
          currentWordId = wordId;
          run = 0;
        }
        if ((row['is_wrong'] as int? ?? 0) == 0) {
          run++;
          if (run > best) best = run;
        } else {
          run = 0;
        }
      }
    }
    return best;
  }
}

import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';

import '../../models/word.dart';

class WeakVocabularyDao {
  final Future<Database> Function() _dbFuture;

  WeakVocabularyDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  Future<List<WeakVocabularyRawRow>> getWeakVocabularyRows({
    DateTime? since,
    int? limit,
  }) async {
    final db = await _dbFuture();
    //last_wrong_time 与参数同为本地 ISO 字符串，直接比较即可命中索引；
    //包一层 datetime() 会让 idx 失效
    final where = since == null
        ? ''
        : 'WHERE ww.last_wrong_time >= ?';
    final args = <Object?>[];
    if (since != null) args.add(since.toIso8601String());
    final limitClause = limit != null && limit > 0 ? 'LIMIT ?' : '';
    if (limit != null && limit > 0) args.add(limit);

    final baseRows = await db.rawQuery('''
      SELECT
        w.id,
        w.word,
        w.definition,
        w.word_book_id,
        ww.wrong_count,
        ww.first_wrong_time,
        ww.last_wrong_time,
        COALESCE(ww.strength, 0) AS strength
      FROM wrong_words ww
      INNER JOIN words w ON w.id = ww.word_id
      $where
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
      $limitClause
    ''', args);
    if (baseRows.isEmpty) return const [];

    final ids = baseRows
        .map((row) => row['id'])
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const [];
    final strengthMap = await _loadStrengthAggregates(db, ids);
    final masteryMap = await _loadMasteryAggregates(db, ids);
    final reviewMap = await _loadReviewAggregates(db, ids);

    return baseRows
        .map((row) {
          final word = Word.fromMap(Map<String, dynamic>.from(row));
          final id = word.id;
          if (id == null) return null;
          final strength = strengthMap[id] ?? const _StrengthAggregate();
          final mastery = masteryMap[id] ?? const _MasteryAggregate();
          final review = reviewMap[id] ?? const _ReviewAggregate();
          return WeakVocabularyRawRow(
            word: word,
            wrongCount: row['wrong_count'] as int? ?? 0,
            lastWrongTime: _parseDate(row['last_wrong_time']) ?? DateTime.now(),
            firstWrongTime: _parseDate(row['first_wrong_time']),
            storedStrength: (row['strength'] as num?)?.toDouble() ?? 0,
            viewedAnswerCount: strength.viewedAnswerCount,
            latestReviewWrong: strength.latestReviewWrong,
            avgSessionScore: mastery.avgSessionScore,
            consecutiveCorrect: mastery.consecutiveCorrect,
            easeFactor: review.easeFactor,
          );
        })
        .whereType<WeakVocabularyRawRow>()
        .toList(growable: false);
  }

  /// IN 子句分块大小：老版本 SQLite 的变量上限为 999，超限会直接抛错
  static const int _inChunkSize = 400;

  /// 按分块执行 IN 查询并合并结果。
  /// 每个 id 只会落在一个分块里，因此分组聚合结果可直接拼接。
  Future<List<Map<String, Object?>>> _queryInChunks(
    Database db,
    List<int> ids,
    String Function(String placeholders) buildSql,
    List<Object?> tailArgs,
  ) async {
    if (ids.length <= _inChunkSize) {
      return db.rawQuery(buildSql(ids.map((_) => '?').join(',')), [
        ...ids,
        ...tailArgs,
      ]);
    }
    final rows = <Map<String, Object?>>[];
    for (var i = 0; i < ids.length; i += _inChunkSize) {
      final end = i + _inChunkSize < ids.length ? i + _inChunkSize : ids.length;
      final chunk = ids.sublist(i, end);
      rows.addAll(
        await db.rawQuery(buildSql(chunk.map((_) => '?').join(',')), [
          ...chunk,
          ...tailArgs,
        ]),
      );
    }
    return rows;
  }

  Future<Map<int, _StrengthAggregate>> _loadStrengthAggregates(
    Database db,
    List<int> wordIds,
  ) async {
    final rows = await _queryInChunks(
      db,
      wordIds,
      (placeholders) => '''
      SELECT
        s.word_id,
        SUM(CASE WHEN s.viewed_answer = 1 THEN 1 ELSE 0 END) AS viewed_answer_count,
        (
          SELECT latest.is_wrong
          FROM wrong_words_strength latest
          WHERE latest.word_id = s.word_id
          ORDER BY datetime(latest.created_at) DESC, latest.id DESC
          LIMIT 1
        ) AS latest_review_wrong
      FROM wrong_words_strength s
      WHERE s.word_id IN ($placeholders)
      GROUP BY s.word_id
    ''',
      const [],
    );
    return {
      for (final row in rows)
        row['word_id'] as int: _StrengthAggregate(
          viewedAnswerCount: row['viewed_answer_count'] as int? ?? 0,
          latestReviewWrong: (row['latest_review_wrong'] as int? ?? 0) == 1,
        ),
    };
  }

  Future<Map<int, _MasteryAggregate>> _loadMasteryAggregates(
    Database db,
    List<int> wordIds,
  ) async {
    final start = DateTime.now().subtract(const Duration(days: 14));
    //date 列存的是 yyyy-MM-dd，直接字符串比较即可命中 idx_session_mastery_date；
    //包一层 datetime() 会让该索引失效
    final startDate =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final rows = await _queryInChunks(
      db,
      wordIds,
      (placeholders) => '''
      SELECT
        word_id,
        AVG(session_score) AS avg_session_score
      FROM session_mastery_records
      WHERE word_id IN ($placeholders)
        AND date >= ?
      GROUP BY word_id
    ''',
      [startDate],
    );
    // 连续答对取"最近一条记录"的值：MAX(correct_streak) 是历史最大值，
    // 会把"曾经连对若干次、此后反复答错"的词误判成掌握良好。
    // 用 MAX(id) 分组 + JOIN 实现"每组最新一行"，全版本 SQLite 兼容。
    final latestRows = await _queryInChunks(
      db,
      wordIds,
      (placeholders) => '''
      SELECT r.word_id, r.correct_streak
      FROM session_mastery_records r
      INNER JOIN (
        SELECT word_id, MAX(id) AS max_id
        FROM session_mastery_records
        WHERE word_id IN ($placeholders)
          AND date >= ?
        GROUP BY word_id
      ) t ON r.word_id = t.word_id AND r.id = t.max_id
    ''',
      [startDate],
    );
    final latestStreak = {
      for (final row in latestRows)
        row['word_id'] as int: (row['correct_streak'] as int?) ?? 0,
    };
    return {
      for (final row in rows)
        row['word_id'] as int: _MasteryAggregate(
          // 无掌握度数据时按 0 分（未掌握）处理：分数是 0~100 制，
          // 旧实现用 1.0 当"无数据"哨兵，与分制单位冲突
          avgSessionScore:
              (row['avg_session_score'] as num?)?.toDouble() ?? 0.0,
          consecutiveCorrect: latestStreak[row['word_id'] as int] ?? 0,
        ),
    };
  }

  Future<Map<int, _ReviewAggregate>> _loadReviewAggregates(
    Database db,
    List<int> wordIds,
  ) async {
    final rows = await _queryInChunks(
      db,
      wordIds,
      //review_records.word_id 有 UNIQUE 约束：每个词只有一条记录，
      //直接按 word_id 取即可，无需 MAX(id) 子查询选"最新"那条
      (placeholders) => '''
      SELECT word_id, ease_factor
      FROM review_records
      WHERE word_id IN ($placeholders)
    ''',
      const [],
    );
    return {
      for (final row in rows)
        row['word_id'] as int: _ReviewAggregate(
          easeFactor: (row['ease_factor'] as num?)?.toDouble() ?? 2.5,
        ),
    };
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class WeakVocabularyRawRow {
  final Word word;
  final int wrongCount;
  final DateTime lastWrongTime;
  final DateTime? firstWrongTime;
  final double storedStrength;
  final int viewedAnswerCount;
  final bool latestReviewWrong;
  final double avgSessionScore;
  final int consecutiveCorrect;
  final double easeFactor;

  const WeakVocabularyRawRow({
    required this.word,
    required this.wrongCount,
    required this.lastWrongTime,
    this.firstWrongTime,
    required this.storedStrength,
    required this.viewedAnswerCount,
    required this.latestReviewWrong,
    required this.avgSessionScore,
    required this.consecutiveCorrect,
    required this.easeFactor,
  });
}

class _StrengthAggregate {
  final int viewedAnswerCount;
  final bool latestReviewWrong;

  const _StrengthAggregate({
    this.viewedAnswerCount = 0,
    this.latestReviewWrong = false,
  });
}

class _MasteryAggregate {
  final double avgSessionScore;
  final int consecutiveCorrect;

  // 无 session_mastery 记录时按"未掌握（0 分）"处理：分数是 0~100 制，
  // 旧默认值 1.0 是按 0~1 分制写的，与分制单位冲突
  const _MasteryAggregate({
    this.avgSessionScore = 0.0,
    this.consecutiveCorrect = 0,
  });
}

class _ReviewAggregate {
  final double easeFactor;

  const _ReviewAggregate({this.easeFactor = 2.5});
}

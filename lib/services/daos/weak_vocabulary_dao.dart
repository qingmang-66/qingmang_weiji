import 'package:sqflite/sqflite.dart';

import '../../models/word.dart';

class WeakVocabularyDao {
  final Future<Database> _dbFuture;

  WeakVocabularyDao(this._dbFuture);

  Future<List<WeakVocabularyRawRow>> getWeakVocabularyRows({
    DateTime? since,
    int? limit,
  }) async {
    final db = await _dbFuture;
    final where = since == null
        ? ''
        : 'WHERE datetime(ww.last_wrong_time) >= datetime(?)';
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

  Future<Map<int, _StrengthAggregate>> _loadStrengthAggregates(
    Database db,
    List<int> wordIds,
  ) async {
    final placeholders = wordIds.map((_) => '?').join(',');
    final rows = await db.rawQuery('''
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
    ''', wordIds);
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
    final placeholders = wordIds.map((_) => '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT
        word_id,
        AVG(session_score) AS avg_session_score,
        MAX(correct_streak) AS consecutive_correct
      FROM session_mastery_records
      WHERE word_id IN ($placeholders)
        AND datetime(date) >= datetime(?)
      GROUP BY word_id
    ''',
      [...wordIds, start.toIso8601String()],
    );
    return {
      for (final row in rows)
        row['word_id'] as int: _MasteryAggregate(
          avgSessionScore:
              (row['avg_session_score'] as num?)?.toDouble() ?? 1.0,
          consecutiveCorrect: row['consecutive_correct'] as int? ?? 0,
        ),
    };
  }

  Future<Map<int, _ReviewAggregate>> _loadReviewAggregates(
    Database db,
    List<int> wordIds,
  ) async {
    final placeholders = wordIds.map((_) => '?').join(',');
    final rows = await db.rawQuery('''
      SELECT word_id, ease_factor
      FROM review_records r1
      WHERE word_id IN ($placeholders)
        AND id = (
          SELECT MAX(id)
          FROM review_records r2
          WHERE r2.word_id = r1.word_id
        )
    ''', wordIds);
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

  const _MasteryAggregate({
    this.avgSessionScore = 1.0,
    this.consecutiveCorrect = 0,
  });
}

class _ReviewAggregate {
  final double easeFactor;

  const _ReviewAggregate({this.easeFactor = 2.5});
}

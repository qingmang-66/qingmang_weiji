import 'dart:async';
import 'dart:math';

import '../models/weak_word_entry.dart';
import '../models/weakness_level.dart';
import '../models/weakness_overview.dart';
import 'daos/weak_vocabulary_dao.dart';
import 'daos/wrong_word_dao.dart';

class WeakVocabularyService {
  final WeakVocabularyDao _dao;
  final WrongWordDao? _wrongWordDao;
  final Duration cacheTtl;
  WeaknessOverview? _cache;
  DateTime? _cacheTime;
  Future<WeaknessOverview>? _refreshing;
  final _eventController = StreamController<WeakVocabularyEvent>.broadcast();

  WeakVocabularyService({
    required WeakVocabularyDao dao,
    WrongWordDao? wrongWordDao,
    this.cacheTtl = const Duration(seconds: 60),
  }) : _dao = dao,
       _wrongWordDao = wrongWordDao;

  Stream<WeakVocabularyEvent> get events => _eventController.stream;

  Future<WeaknessOverview> getOverview({
    bool forceRefresh = false,
    DateTime? since,
  }) async {
    if (!forceRefresh &&
        since == null &&
        _cache != null &&
        _cacheTime != null) {
      final fresh = DateTime.now().difference(_cacheTime!) < cacheTtl;
      if (fresh) return _cache!;
    }
    if (_refreshing != null) return _refreshing!;
    _refreshing = _loadOverview(since: since);
    try {
      final overview = await _refreshing!;
      if (since == null) {
        _cache = overview;
        _cacheTime = DateTime.now();
      }
      return overview;
    } finally {
      _refreshing = null;
    }
  }

  Future<List<WeakWordEntry>> getWeakWords({
    WeaknessLevel minLevel = WeaknessLevel.shaky,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final overview = await getOverview(forceRefresh: forceRefresh);
    final entries = overview.entries
        .where((entry) => entry.level.priority >= minLevel.priority)
        .take(limit ?? overview.entries.length)
        .toList(growable: false);
    return entries;
  }

  Future<List<WeakWordEntry>> getCriticalWords({int limit = 10}) async {
    return getWeakWords(minLevel: WeaknessLevel.critical, limit: limit);
  }

  void invalidate({int? wordId}) {
    _cache = null;
    _cacheTime = null;
    _eventController.add(
      WeakVocabularyEvent(
        type: WeakVocabularyEventType.invalidated,
        wordId: wordId,
      ),
    );
  }

  void dispose() {
    _eventController.close();
  }

  Future<WeaknessOverview> _loadOverview({DateTime? since}) async {
    final rows = await _dao.getWeakVocabularyRows(since: since);
    final entries = rows.map(_toEntry).toList(growable: false)
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        if (score != 0) return score;
        return b.lastWrongTime.compareTo(a.lastWrongTime);
      });
    if (_wrongWordDao != null) {
      await _wrongWordDao.batchUpdateStrength({
        for (final entry in entries)
          if (entry.word.id != null) entry.word.id!: entry.score,
      });
    }
    return WeaknessOverview.fromEntries(entries);
  }

  WeakWordEntry _toEntry(WeakVocabularyRawRow row) {
    final breakdown = _buildBreakdown(row);
    final score = min(100.0, breakdown.total);
    return WeakWordEntry(
      word: row.word,
      wrongCount: row.wrongCount,
      consecutiveCorrect: row.consecutiveCorrect,
      avgSessionScore: row.avgSessionScore,
      easeFactor: row.easeFactor,
      viewedAnswerCount: row.viewedAnswerCount,
      latestReviewWrong: row.latestReviewWrong,
      lastWrongTime: row.lastWrongTime,
      firstWrongTime: row.firstWrongTime,
      level: _levelOf(score),
      score: score,
      breakdown: breakdown,
    );
  }

  WeaknessBreakdown _buildBreakdown(WeakVocabularyRawRow row) {
    final wrongFreqScore = min(row.wrongCount * 6.0, 30.0);
    final masteryScore = (1 - row.avgSessionScore).clamp(0.0, 1.0) * 25.0;
    final memoryScore = _memoryScore(row.easeFactor);
    final recencyScore = _recencyScore(row.lastWrongTime);
    final behaviorScore =
        (row.viewedAnswerCount >= 3 ? 5.0 : 0.0) +
        (row.latestReviewWrong ? 5.0 : 0.0);
    return WeaknessBreakdown(
      wrongFreqScore: wrongFreqScore,
      masteryScore: masteryScore,
      memoryScore: memoryScore,
      recencyScore: recencyScore,
      behaviorScore: behaviorScore,
    );
  }

  double _memoryScore(double easeFactor) {
    if (easeFactor < 1.5) return 20.0;
    if (easeFactor < 2.0) return 10.0;
    return 2.0;
  }

  double _recencyScore(DateTime lastWrongTime) {
    final days = DateTime.now().difference(lastWrongTime).inDays;
    if (days <= 1) return 15.0;
    if (days <= 3) return 12.0;
    if (days <= 7) return 8.0;
    if (days <= 30) return 4.0;
    return 1.0;
  }

  WeaknessLevel _levelOf(double score) {
    if (score >= 80) return WeaknessLevel.critical;
    if (score >= 60) return WeaknessLevel.weak;
    if (score >= 35) return WeaknessLevel.shaky;
    if (score >= 15) return WeaknessLevel.normal;
    return WeaknessLevel.solid;
  }
}

enum WeakVocabularyEventType { invalidated }

class WeakVocabularyEvent {
  final WeakVocabularyEventType type;
  final int? wordId;

  const WeakVocabularyEvent({required this.type, this.wordId});
}

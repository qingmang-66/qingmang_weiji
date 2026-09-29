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
  //in-flight 请求的 since 参数，去重键需包含它，否则带区间的查询会误用全量结果
  static const Object _sentinel = Object();
  Object? _refreshingSince = _sentinel;
  //缓存代际：invalidate 时自增，在途请求据此判断结果是否已被失效
  int _generation = 0;
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
    if (_refreshing != null && _refreshingSince == since) return _refreshing!;
    final generation = _generation;
    final request = _loadOverview(since: since);
    _refreshing = request;
    _refreshingSince = since;
    try {
      final overview = await request;
      //invalidate 发生在本次请求在途期间时不再回写：否则会把失效前的陈旧
      //数据写回缓存，令 invalidate 形同无效
      if (since == null && generation == _generation) {
        _cache = overview;
        _cacheTime = DateTime.now();
      }
      return overview;
    } finally {
      //只清理自己的在途标记：若期间已发起更新的请求，旧的 finally 不能把它清掉，
      //否则去重会失效，导致重复全量查询 + 重复批量写库
      if (identical(_refreshing, request)) {
        _refreshing = null;
        _refreshingSince = _sentinel;
      }
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
    _generation++;
    _cache = null;
    _cacheTime = null;
    //丢弃在途刷新标记：其结果属于失效前的陈旧数据，不能再写回缓存
    _refreshing = null;
    _refreshingSince = _sentinel;
    //dispose 之后仍可能被上层调用，向已关闭的 controller 添加事件会抛 StateError
    if (_eventController.isClosed) return;
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
      //只回写分数确有变化的行：此前每次加载都会把整张错词表逐条 UPDATE 一遍，
      //首页每次刷新都会触发一次全量写放大
      final storedById = <int, double>{
        for (final row in rows)
          if (row.word.id != null) row.word.id!: row.storedStrength,
      };
      final updates = <int, double>{};
      for (final entry in entries) {
        final id = entry.word.id;
        if (id == null) continue;
        final stored = storedById[id] ?? 0;
        if ((stored - entry.score).abs() < 0.5) continue;
        updates[id] = entry.score;
      }
      if (updates.isNotEmpty) {
        await _wrongWordDao.batchUpdateStrength(updates);
      }
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
    // avgSessionScore 是 0~100 分制（S-MARS 的 sessionScore / DAO 的
    // AVG(session_score)），必须归一化后才能当作"掌握度比例"使用。
    // 旧实现按 0~1 处理：任何实际分数（≥1）都被 clamp 成 1，该项恒为 0，
    // 总分上限从 100 掉到 75，WeaknessLevel.critical（>=80）永远不可达。
    final masteryRatio = (row.avgSessionScore / 100.0).clamp(0.0, 1.0);
    final masteryScore = (1 - masteryRatio) * 25.0;
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

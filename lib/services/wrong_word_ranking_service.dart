import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'daos/wrong_word_dao.dart';
import 'wrong_word_service.dart';

/// 阶段四：高频错词排行服务
///
/// 综合评分公式（5 维加权）：
///   wrongCount     * 10.0  +   // 主权重：错误次数
///   recencyWeight  (1~20)  +   // 越近越高
///   viewedAnswerScore (0/5) +   // 查看答案 >= 3 次
///   reviewWrongScore (0/15) +  // 专项复习再错
///   persistentScore (days * 0.5) // 长期顽固
class WrongWordRankingService {
  WrongWordRankingService._();
  static final WrongWordRankingService _instance = WrongWordRankingService._();
  factory WrongWordRankingService() => _instance;

  final WrongWordService _wrongWordService = WrongWordService();

  /// 获取 Top N 高频错词
  ///
  /// [limit] 限制返回条数，传 null 返回全部排序结果
  /// [since] 仅考虑 last_wrong_time >= since 的错词（null = 不限）
  Future<List<WrongWordRankingItem>> getTopWrongWords({
    int? limit = 10,
    DateTime? since,
  }) async {
    try {
      // 1. 拉取错词 + word 详情
      final metas = await _wrongWordService.getAllWrongWordsWithMeta();
      if (metas.isEmpty) return const [];

      // 2. 过滤时间窗口
      final filtered = since == null
          ? metas
          : metas.where((m) => !m.lastWrongTime.isBefore(since)).toList();
      if (filtered.isEmpty) return const [];

      // 3. 聚合 strength
      final ids = filtered
          .map((m) => m.word.id)
          .whereType<int>()
          .toList(growable: false);
      final aggregates = await _wrongWordService.getStrengthAggregates(ids);

      // 4. 算分
      final now = DateTime.now();
      final items = <WrongWordRankingItem>[];
      for (final meta in filtered) {
        final id = meta.word.id!;
        final agg =
            aggregates[id] ??
            const WrongWordStrengthAggregate(
              viewedAnswerCount: 0,
              latestReviewWrong: false,
            );
        final breakdown = _computeBreakdown(
          meta: meta,
          aggregate: agg,
          now: now,
        );
        items.add(
          WrongWordRankingItem(
            word: meta.word,
            wrongCount: meta.wrongCount,
            lastWrongTime: meta.lastWrongTime,
            firstWrongTime: meta.firstWrongTime,
            viewedAnswerCount: agg.viewedAnswerCount,
            latestReviewWrong: agg.latestReviewWrong,
            score: breakdown.total,
            breakdown: breakdown,
          ),
        );
      }

      // 5. 排序：score DESC, last_wrong_time DESC
      items.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.lastWrongTime.compareTo(a.lastWrongTime);
      });

      // 6. limit
      if (limit == null) return items;
      return items.take(limit).toList(growable: false);
    } catch (e) {
      debugPrint('WrongWordRankingService.getTopWrongWords error: $e');
      rethrow;
    }
  }

  /// 获取最近专项复习中再错的错词
  Future<List<WrongWordRankingItem>> getRepeatWrongWords({
    int limit = 5,
  }) async {
    final all = await getTopWrongWords(limit: null);
    return all
        .where((i) => i.latestReviewWrong)
        .take(limit)
        .toList(growable: false);
  }

  /// 评分计算（内部方法）
  WrongWordScoreBreakdown _computeBreakdown({
    required WrongWordMetaRow meta,
    required WrongWordStrengthAggregate aggregate,
    required DateTime now,
  }) {
    // 1. wrongCount * 10
    final wrongCountScore = meta.wrongCount * 10.0;

    // 2. recency：基于 last_wrong_time 距 now 的天数
    final daysSince = now.difference(meta.lastWrongTime).inDays;
    double recencyScore;
    if (daysSince <= 1) {
      recencyScore = 20;
    } else if (daysSince <= 3) {
      recencyScore = 15;
    } else if (daysSince <= 7) {
      recencyScore = 10;
    } else if (daysSince <= 30) {
      recencyScore = 5;
    } else {
      recencyScore = 1;
    }

    // 3. viewed answer >= 3
    final viewedAnswerScore = aggregate.viewedAnswerCount >= 3 ? 5.0 : 0.0;

    // 4. review wrong
    final reviewWrongScore = aggregate.latestReviewWrong ? 15.0 : 0.0;

    // 5. persistent：首次错误距 now 的天数 * 0.5
    final daysSinceFirst = meta.firstWrongTime == null
        ? 0
        : now.difference(meta.firstWrongTime!).inDays;
    final persistentScore = daysSinceFirst * 0.5;

    return WrongWordScoreBreakdown(
      wrongCountScore: wrongCountScore,
      recencyScore: recencyScore,
      viewedAnswerScore: viewedAnswerScore,
      reviewWrongScore: reviewWrongScore,
      persistentScore: persistentScore,
    );
  }
}

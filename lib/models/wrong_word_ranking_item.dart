import 'word.dart';

/// 阶段四：高频错词排行项
///
/// 综合评分后的单条错词记录，用于排行展示、报告、建议生成。
class WrongWordRankingItem {
  /// 关联的单词详情
  final Word word;

  /// 错误次数（来自 wrong_words.wrong_count）
  final int wrongCount;

  /// 最近错误时间
  final DateTime lastWrongTime;

  /// 首次错误时间（用于"长期顽固"加分）
  final DateTime? firstWrongTime;

  /// 累计查看答案次数（来自 wrong_words_strength）
  final int viewedAnswerCount;

  /// 最近一次专项复习是否答错
  final bool latestReviewWrong;

  /// 综合评分（越高越需要关注）
  final double score;

  /// 评分明细（用于 UI 展示"为什么这个错词排前面"）
  final WrongWordScoreBreakdown breakdown;

  const WrongWordRankingItem({
    required this.word,
    required this.wrongCount,
    required this.lastWrongTime,
    this.firstWrongTime,
    required this.viewedAnswerCount,
    required this.latestReviewWrong,
    required this.score,
    required this.breakdown,
  });
}

/// 评分明细
class WrongWordScoreBreakdown {
  /// 错误次数得分：wrongCount * 10
  final double wrongCountScore;

  /// 近期错误得分：1~20
  final double recencyScore;

  /// 多次查看答案得分：0 或 5
  final double viewedAnswerScore;

  /// 专项复习再错得分：0 或 15
  final double reviewWrongScore;

  /// 长期顽固得分：首次错误距今天数 * 0.5
  final double persistentScore;

  const WrongWordScoreBreakdown({
    required this.wrongCountScore,
    required this.recencyScore,
    required this.viewedAnswerScore,
    required this.reviewWrongScore,
    required this.persistentScore,
  });

  double get total =>
      wrongCountScore +
      recencyScore +
      viewedAnswerScore +
      reviewWrongScore +
      persistentScore;
}

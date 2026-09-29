enum TodayAdviceType { reviewFirst, learnNewWords, waitForReview }

/// 今日建议：基于词库事实（到期词/未学词）给出行动建议，不涉及每日额度
class TodayAdvice {
  final TodayAdviceType type;
  final int dueWords;
  final int todayNewWords;
  final int unlearnedWords;

  const TodayAdvice({
    required this.type,
    required this.dueWords,
    required this.todayNewWords,
    required this.unlearnedWords,
  });

  factory TodayAdvice.fromCounts({
    required int dueWords,
    required int todayNewWords,
    required int unlearnedWords,
  }) {
    final type = dueWords > 0
        ? TodayAdviceType.reviewFirst
        : unlearnedWords > 0
        ? TodayAdviceType.learnNewWords
        : TodayAdviceType.waitForReview;

    return TodayAdvice(
      type: type,
      dueWords: dueWords,
      todayNewWords: todayNewWords,
      unlearnedWords: unlearnedWords,
    );
  }
}

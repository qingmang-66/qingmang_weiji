enum TodayAdviceType { reviewFirst, learnNewWords, doneToday, waitForReview }

class TodayAdvice {
  final TodayAdviceType type;
  final int dueWords;
  final int todayNewWords;
  final int dailyNewLimit;
  final int unlearnedWords;

  const TodayAdvice({
    required this.type,
    required this.dueWords,
    required this.todayNewWords,
    required this.dailyNewLimit,
    required this.unlearnedWords,
  });

  factory TodayAdvice.fromCounts({
    required int dueWords,
    required int todayNewWords,
    required int dailyNewLimit,
    required int unlearnedWords,
  }) {
    final remainingNewWords = _remaining(dailyNewLimit, todayNewWords);
    final type = dueWords > 0
        ? TodayAdviceType.reviewFirst
        : unlearnedWords <= 0
        ? TodayAdviceType.waitForReview
        : remainingNewWords > 0
        ? TodayAdviceType.learnNewWords
        : TodayAdviceType.doneToday;

    return TodayAdvice(
      type: type,
      dueWords: dueWords,
      todayNewWords: todayNewWords,
      dailyNewLimit: dailyNewLimit,
      unlearnedWords: unlearnedWords,
    );
  }

  int get remainingNewWords => _remaining(dailyNewLimit, todayNewWords);

  static int _remaining(int limit, int used) {
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }
}

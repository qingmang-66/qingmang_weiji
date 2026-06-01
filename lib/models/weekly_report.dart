/// 每周学习报告
class WeeklyReport {
  final int newWords;
  final int reviewWords;
  final int studyDays;
  final double averageQuality;
  final int planCompletedDays;
  final List<FrequentWrongWord> frequentWrongWords;

  const WeeklyReport({
    required this.newWords,
    required this.reviewWords,
    required this.studyDays,
    required this.averageQuality,
    required this.planCompletedDays,
    required this.frequentWrongWords,
  });

  int get totalWords => newWords + reviewWords;
  int get qualityPercent => (averageQuality / 5 * 100).round().clamp(0, 100);
}

/// 高频错词排行条目
class FrequentWrongWord {
  final int wordId;
  final String word;
  final String definition;
  final int wrongCount;
  final DateTime? lastWrongTime;

  const FrequentWrongWord({
    required this.wordId,
    required this.word,
    required this.definition,
    required this.wrongCount,
    required this.lastWrongTime,
  });
}

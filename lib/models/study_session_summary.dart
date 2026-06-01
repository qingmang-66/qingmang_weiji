class StudySessionSummary {
  final int totalWords;
  final int weakWords;
  final int revealedWords;
  final int skippedWords;

  const StudySessionSummary({
    required this.totalWords,
    required this.weakWords,
    required this.revealedWords,
    required this.skippedWords,
  });

  int get masteredWords {
    final mastered = totalWords - weakWords;
    return mastered < 0 ? 0 : mastered;
  }

  double get masteryRatio {
    if (totalWords <= 0) return 0;
    return (masteredWords / totalWords).clamp(0, 1).toDouble();
  }

  int get masteryPercent => (masteryRatio * 100).round();
}

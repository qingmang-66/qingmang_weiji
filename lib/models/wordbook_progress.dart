class WordBookProgress {
  final int bookId;
  final int totalWords;
  final int unlearnedWords;
  final int dueWords;

  const WordBookProgress({
    required this.bookId,
    required this.totalWords,
    required this.unlearnedWords,
    required this.dueWords,
  });

  int get learnedWords {
    final learned = totalWords - unlearnedWords;
    return learned < 0 ? 0 : learned;
  }

  double get learnedRatio {
    if (totalWords <= 0) return 0;
    return (learnedWords / totalWords).clamp(0, 1).toDouble();
  }

  int get learnedPercent => (learnedRatio * 100).round();
}

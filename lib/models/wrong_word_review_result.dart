class WrongWordReviewResult {
  static const int masteredStreakThreshold = 3;

  final int wordId;
  final bool wasCorrect;
  final bool revealedAnswer;
  final int previousCorrectStreak;

  const WrongWordReviewResult({
    required this.wordId,
    required this.wasCorrect,
    required this.revealedAnswer,
    required this.previousCorrectStreak,
  });

  bool get shouldStrengthen => !wasCorrect || revealedAnswer;

  int get nextCorrectStreak {
    if (shouldStrengthen) return 0;
    return previousCorrectStreak + 1;
  }

  bool get shouldSuggestMastered {
    return nextCorrectStreak >= masteredStreakThreshold;
  }
}

class WrongWordStrength {
  const WrongWordStrength._();

  static int nextWrongCountAfterCorrect(int currentWrongCount) {
    if (currentWrongCount <= 1) return 1;
    return currentWrongCount - 1;
  }
}

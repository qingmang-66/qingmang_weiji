import 'weakness_level.dart';
import 'word.dart';

class WeaknessBreakdown {
  final double wrongFreqScore;
  final double masteryScore;
  final double memoryScore;
  final double recencyScore;
  final double behaviorScore;

  const WeaknessBreakdown({
    required this.wrongFreqScore,
    required this.masteryScore,
    required this.memoryScore,
    required this.recencyScore,
    required this.behaviorScore,
  });

  double get total =>
      wrongFreqScore +
      masteryScore +
      memoryScore +
      recencyScore +
      behaviorScore;
}

class WeakWordEntry {
  final Word word;
  final int wrongCount;
  final int consecutiveCorrect;
  final double avgSessionScore;
  final double easeFactor;
  final int viewedAnswerCount;
  final bool latestReviewWrong;
  final DateTime lastWrongTime;
  final DateTime? firstWrongTime;
  final WeaknessLevel level;
  final double score;
  final WeaknessBreakdown breakdown;

  const WeakWordEntry({
    required this.word,
    required this.wrongCount,
    required this.consecutiveCorrect,
    required this.avgSessionScore,
    required this.easeFactor,
    required this.viewedAnswerCount,
    required this.latestReviewWrong,
    required this.lastWrongTime,
    this.firstWrongTime,
    required this.level,
    required this.score,
    required this.breakdown,
  });
}

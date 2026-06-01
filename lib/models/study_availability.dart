enum StudyAvailabilityStatus {
  available,
  emptyBook,
  dailyNewCompleted,
  allNewWordsLearned,
  noDueReviews,
  dailyReviewCompleted,
}

class StudyAvailability {
  final StudyAvailabilityStatus status;
  final int totalWords;
  final int unlearnedWords;
  final int dueWords;
  final int todayNewWords;
  final int todayReviewedWords;
  final int dailyNewLimit;
  final int dailyReviewLimit;
  final bool isReview;

  const StudyAvailability({
    required this.status,
    required this.totalWords,
    required this.unlearnedWords,
    required this.dueWords,
    required this.todayNewWords,
    required this.todayReviewedWords,
    required this.dailyNewLimit,
    required this.dailyReviewLimit,
    required this.isReview,
  });

  factory StudyAvailability.forNewWords({
    required int totalWords,
    required int unlearnedWords,
    required int dueWords,
    required int todayNewWords,
    required int todayReviewedWords,
    required int dailyNewLimit,
    required int dailyReviewLimit,
  }) {
    final remainingNewWords = _remaining(dailyNewLimit, todayNewWords);
    final status = totalWords == 0
        ? StudyAvailabilityStatus.emptyBook
        : unlearnedWords == 0
        ? StudyAvailabilityStatus.allNewWordsLearned
        : remainingNewWords == 0
        ? StudyAvailabilityStatus.dailyNewCompleted
        : StudyAvailabilityStatus.available;

    return StudyAvailability(
      status: status,
      totalWords: totalWords,
      unlearnedWords: unlearnedWords,
      dueWords: dueWords,
      todayNewWords: todayNewWords,
      todayReviewedWords: todayReviewedWords,
      dailyNewLimit: dailyNewLimit,
      dailyReviewLimit: dailyReviewLimit,
      isReview: false,
    );
  }

  factory StudyAvailability.forReview({
    required int totalWords,
    required int unlearnedWords,
    required int dueWords,
    required int todayNewWords,
    required int todayReviewedWords,
    required int dailyNewLimit,
    required int dailyReviewLimit,
  }) {
    final remainingReviewWords = _remaining(
      dailyReviewLimit,
      todayReviewedWords,
    );
    final status = totalWords == 0
        ? StudyAvailabilityStatus.emptyBook
        : dueWords == 0
        ? StudyAvailabilityStatus.noDueReviews
        : remainingReviewWords == 0
        ? StudyAvailabilityStatus.dailyReviewCompleted
        : StudyAvailabilityStatus.available;

    return StudyAvailability(
      status: status,
      totalWords: totalWords,
      unlearnedWords: unlearnedWords,
      dueWords: dueWords,
      todayNewWords: todayNewWords,
      todayReviewedWords: todayReviewedWords,
      dailyNewLimit: dailyNewLimit,
      dailyReviewLimit: dailyReviewLimit,
      isReview: true,
    );
  }

  bool get canStart => status == StudyAvailabilityStatus.available;

  int get remainingNewWords => _remaining(dailyNewLimit, todayNewWords);

  int get remainingReviewWords =>
      _remaining(dailyReviewLimit, todayReviewedWords);

  static int _remaining(int limit, int used) {
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }
}

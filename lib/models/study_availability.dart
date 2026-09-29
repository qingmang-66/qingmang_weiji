enum StudyAvailabilityStatus {
  available,
  emptyBook,
  allNewWordsLearned,
  noDueReviews,
}

/// 学习可用性：只描述事实（词库空/无新词/无到期词），不再做每日额度判断
class StudyAvailability {
  final StudyAvailabilityStatus status;
  final int totalWords;
  final int unlearnedWords;
  final int dueWords;
  final int todayNewWords;
  final int todayReviewedWords;
  final bool isReview;

  const StudyAvailability({
    required this.status,
    required this.totalWords,
    required this.unlearnedWords,
    required this.dueWords,
    required this.todayNewWords,
    required this.todayReviewedWords,
    required this.isReview,
  });

  factory StudyAvailability.forNewWords({
    required int totalWords,
    required int unlearnedWords,
    required int dueWords,
    required int todayNewWords,
    required int todayReviewedWords,
  }) {
    final status = totalWords == 0
        ? StudyAvailabilityStatus.emptyBook
        : unlearnedWords == 0
        ? StudyAvailabilityStatus.allNewWordsLearned
        : StudyAvailabilityStatus.available;

    return StudyAvailability(
      status: status,
      totalWords: totalWords,
      unlearnedWords: unlearnedWords,
      dueWords: dueWords,
      todayNewWords: todayNewWords,
      todayReviewedWords: todayReviewedWords,
      isReview: false,
    );
  }

  factory StudyAvailability.forReview({
    required int totalWords,
    required int unlearnedWords,
    required int dueWords,
    required int todayNewWords,
    required int todayReviewedWords,
  }) {
    final status = totalWords == 0
        ? StudyAvailabilityStatus.emptyBook
        : dueWords == 0
        ? StudyAvailabilityStatus.noDueReviews
        : StudyAvailabilityStatus.available;

    return StudyAvailability(
      status: status,
      totalWords: totalWords,
      unlearnedWords: unlearnedWords,
      dueWords: dueWords,
      todayNewWords: todayNewWords,
      todayReviewedWords: todayReviewedWords,
      isReview: true,
    );
  }

  bool get canStart => status == StudyAvailabilityStatus.available;
}

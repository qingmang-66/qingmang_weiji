import 'package:qingmang_weiji/models/study_availability.dart';
import 'package:test/test.dart';

int remainingDailyNewWords({
  required int dailyLimit,
  required int todayNewLearned,
}) {
  final remaining = dailyLimit - todayNewLearned;
  return remaining < 0 ? 0 : remaining;
}

int remainingDailyReviews({
  required int dailyLimit,
  required int todayReviewed,
}) {
  final remaining = dailyLimit - todayReviewed;
  return remaining < 0 ? 0 : remaining;
}

void main() {
  group('每日学习额度', () {
    test('学完每日新词上限后，当天不再加载下一批新词', () {
      expect(remainingDailyNewWords(dailyLimit: 20, todayNewLearned: 20), 0);
    });

    test('只学完部分新词时，只加载今天剩余额度', () {
      expect(remainingDailyNewWords(dailyLimit: 20, todayNewLearned: 12), 8);
    });

    test('复习达到每日上限后，当天不再加载更多待复习词', () {
      expect(remainingDailyReviews(dailyLimit: 50, todayReviewed: 50), 0);
    });
  });

  group('学习可用性状态', () {
    test('新词模式在词库没有单词时返回空词库状态', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 0,
        unlearnedWords: 0,
        dueWords: 0,
        todayNewWords: 0,
        todayReviewedWords: 0,
        dailyNewLimit: 20,
        dailyReviewLimit: 50,
      );

      expect(availability.status, StudyAvailabilityStatus.emptyBook);
      expect(availability.canStart, isFalse);
    });

    test('新词模式在今日额度用完但仍有未学词时返回今日完成状态', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 0,
        todayNewWords: 20,
        todayReviewedWords: 0,
        dailyNewLimit: 20,
        dailyReviewLimit: 50,
      );

      expect(availability.status, StudyAvailabilityStatus.dailyNewCompleted);
      expect(availability.remainingNewWords, 0);
      expect(availability.canStart, isFalse);
    });

    test('新词模式在当前词库全部学完时返回全部学完状态', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 100,
        unlearnedWords: 0,
        dueWords: 0,
        todayNewWords: 12,
        todayReviewedWords: 0,
        dailyNewLimit: 20,
        dailyReviewLimit: 50,
      );

      expect(availability.status, StudyAvailabilityStatus.allNewWordsLearned);
      expect(availability.canStart, isFalse);
    });

    test('新词模式在还有额度和未学词时可以开始学习', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 0,
        todayNewWords: 12,
        todayReviewedWords: 0,
        dailyNewLimit: 20,
        dailyReviewLimit: 50,
      );

      expect(availability.status, StudyAvailabilityStatus.available);
      expect(availability.remainingNewWords, 8);
      expect(availability.canStart, isTrue);
    });

    test('复习模式在没有待复习时返回无复习状态', () {
      final availability = StudyAvailability.forReview(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 0,
        todayNewWords: 20,
        todayReviewedWords: 0,
        dailyNewLimit: 20,
        dailyReviewLimit: 50,
      );

      expect(availability.status, StudyAvailabilityStatus.noDueReviews);
      expect(availability.canStart, isFalse);
    });

    test('复习模式在今日复习额度用完但仍有待复习时返回今日复习完成状态', () {
      final availability = StudyAvailability.forReview(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 12,
        todayNewWords: 20,
        todayReviewedWords: 50,
        dailyNewLimit: 20,
        dailyReviewLimit: 50,
      );

      expect(availability.status, StudyAvailabilityStatus.dailyReviewCompleted);
      expect(availability.remainingReviewWords, 0);
      expect(availability.canStart, isFalse);
    });
  });
}

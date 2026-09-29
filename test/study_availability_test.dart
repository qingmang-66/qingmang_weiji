import 'package:qingmang_weiji/models/study_availability.dart';
import 'package:test/test.dart';

void main() {
  group('学习可用性状态', () {
    test('新词模式在词库没有单词时返回空词库状态', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 0,
        unlearnedWords: 0,
        dueWords: 0,
        todayNewWords: 0,
        todayReviewedWords: 0,
      );

      expect(availability.status, StudyAvailabilityStatus.emptyBook);
      expect(availability.canStart, isFalse);
    });

    test('新词模式在当前词库全部学完时返回全部学完状态', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 100,
        unlearnedWords: 0,
        dueWords: 0,
        todayNewWords: 12,
        todayReviewedWords: 0,
      );

      expect(availability.status, StudyAvailabilityStatus.allNewWordsLearned);
      expect(availability.canStart, isFalse);
    });

    test('新词模式在还有未学词时可以开始学习，学多少由用户决定', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 0,
        todayNewWords: 12,
        todayReviewedWords: 0,
      );

      expect(availability.status, StudyAvailabilityStatus.available);
      expect(availability.canStart, isTrue);
    });

    test('今天已学很多词仍可继续学习，没有每日额度限制', () {
      final availability = StudyAvailability.forNewWords(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 0,
        todayNewWords: 40,
        todayReviewedWords: 0,
      );

      expect(availability.status, StudyAvailabilityStatus.available);
      expect(availability.canStart, isTrue);
    });

    test('复习模式在没有待复习时返回无复习状态', () {
      final availability = StudyAvailability.forReview(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 0,
        todayNewWords: 20,
        todayReviewedWords: 0,
      );

      expect(availability.status, StudyAvailabilityStatus.noDueReviews);
      expect(availability.canStart, isFalse);
    });

    test('复习模式在有待复习词时总是可以开始，不限次数', () {
      final availability = StudyAvailability.forReview(
        totalWords: 100,
        unlearnedWords: 80,
        dueWords: 12,
        todayNewWords: 20,
        todayReviewedWords: 50,
      );

      expect(availability.status, StudyAvailabilityStatus.available);
      expect(availability.canStart, isTrue);
    });
  });
}

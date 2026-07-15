import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/models.dart';

void main() {
  group('WrongWordRankingItem', () {
    test('构造后所有字段都可访问', () {
      final word = Word(
        id: 1,
        word: 'abandon',
        phonetic: 'əˈbændən',
        definition: '放弃',
        wordBookId: 1,
      );
      final item = WrongWordRankingItem(
        word: word,
        wrongCount: 3,
        lastWrongTime: DateTime(2024, 1, 1),
        firstWrongTime: DateTime(2023, 12, 1),
        viewedAnswerCount: 2,
        latestReviewWrong: true,
        score: 55.0,
        breakdown: const WrongWordScoreBreakdown(
          wrongCountScore: 30,
          recencyScore: 10,
          viewedAnswerScore: 0,
          reviewWrongScore: 15,
          persistentScore: 0,
        ),
      );

      expect(item.word, word);
      expect(item.wrongCount, 3);
      expect(item.latestReviewWrong, isTrue);
      expect(item.score, 55.0);
      expect(item.breakdown.wrongCountScore, 30);
    });
  });

  group('WrongWordScoreBreakdown', () {
    test('total = 5 维得分之和', () {
      const breakdown = WrongWordScoreBreakdown(
        wrongCountScore: 30,
        recencyScore: 10,
        viewedAnswerScore: 5,
        reviewWrongScore: 15,
        persistentScore: 7.5,
      );

      expect(breakdown.total, closeTo(67.5, 0.0001));
    });

    test('全 0 时 total = 0', () {
      const breakdown = WrongWordScoreBreakdown(
        wrongCountScore: 0,
        recencyScore: 0,
        viewedAnswerScore: 0,
        reviewWrongScore: 0,
        persistentScore: 0,
      );
      expect(breakdown.total, 0);
    });
  });
}

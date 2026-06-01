import 'package:qingmang_weiji/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('WrongWordReviewResult', () {
    test('连续三次答对建议移出错词本', () {
      const result = WrongWordReviewResult(
        wordId: 12,
        wasCorrect: true,
        revealedAnswer: false,
        previousCorrectStreak: 2,
      );

      expect(result.nextCorrectStreak, 3);
      expect(result.shouldSuggestMastered, isTrue);
      expect(result.shouldStrengthen, isFalse);
    });

    test('答错会重置连续答对并保持强化', () {
      const result = WrongWordReviewResult(
        wordId: 12,
        wasCorrect: false,
        revealedAnswer: false,
        previousCorrectStreak: 2,
      );

      expect(result.nextCorrectStreak, 0);
      expect(result.shouldSuggestMastered, isFalse);
      expect(result.shouldStrengthen, isTrue);
    });

    test('查看答案即使最终答对也保持强化', () {
      const result = WrongWordReviewResult(
        wordId: 12,
        wasCorrect: true,
        revealedAnswer: true,
        previousCorrectStreak: 2,
      );

      expect(result.nextCorrectStreak, 0);
      expect(result.shouldSuggestMastered, isFalse);
      expect(result.shouldStrengthen, isTrue);
    });
  });

  group('WrongWordStrength', () {
    test('答对后错误强度最低降到一', () {
      expect(WrongWordStrength.nextWrongCountAfterCorrect(5), 4);
      expect(WrongWordStrength.nextWrongCountAfterCorrect(1), 1);
      expect(WrongWordStrength.nextWrongCountAfterCorrect(0), 1);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/review_record.dart';
import 'package:qingmang_weiji/services/session_mastery_engine.dart';

void main() {
  group('S-MARS 会话掌握算法', () {
    ReviewRecord recordWithRetention(double retention) {
      final now = DateTime.now();
      final totalDays = 10;
      final elapsedDays = ((1 - retention / 100) * 2 * totalDays).round();
      return ReviewRecord(
        wordId: 1,
        quality: 3,
        interval: totalDays,
        easeFactor: 2.5,
        repetitions: 2,
        nextReview: now.add(Duration(days: totalDays - elapsedDays)),
        lastReview: now.subtract(Duration(days: elapsedDays)),
      );
    }

    test('模式权重从高到低为拼写、听力、测验、回忆', () {
      expect(SessionMasteryEngine.modeWeight(StudyModeType.spelling), 1.00);
      expect(SessionMasteryEngine.modeWeight(StudyModeType.listening), 0.92);
      expect(SessionMasteryEngine.modeWeight(StudyModeType.quiz), 0.72);
      expect(SessionMasteryEngine.modeWeight(StudyModeType.recall), 0.55);
    });

    test('拼写首次答对能直接进入强掌握并给出高质量复习评分', () {
      final engine = SessionMasteryEngine();

      final state = engine.recordAttemptWithDuration(
        wordId: 1,
        mode: StudyModeType.spelling,
        outcome: StudyAttemptOutcome.firstCorrect,
        reviewRecord: recordWithRetention(60),
        durationMs: 3000,
      );

      expect(state.sessionScore, greaterThanOrEqualTo(82));
      expect(state.isStrongMastered, isTrue);
      expect(engine.shouldSkipMainFlow(1), isTrue);
      expect(engine.calculateReviewQuality(1), 5);
    });

    test('回忆简单不能超过拼写证明力，只能给到较高但非最高质量', () {
      final engine = SessionMasteryEngine();

      final state = engine.recordAttemptWithDuration(
        wordId: 1,
        mode: StudyModeType.recall,
        outcome: StudyAttemptOutcome.recallEasy,
        reviewRecord: recordWithRetention(60),
        durationMs: 3000,
      );

      expect(state.sessionScore, lessThan(76));
      expect(engine.shouldSkipMainFlow(1), isFalse);
      expect(engine.calculateReviewQuality(1), lessThanOrEqualTo(4));
    });

    test('查看答案会强制进入薄弱池并限制长期复习质量', () {
      final engine = SessionMasteryEngine();

      final state = engine.recordAttemptWithDuration(
        wordId: 1,
        mode: StudyModeType.listening,
        outcome: StudyAttemptOutcome.revealed,
        reviewRecord: recordWithRetention(55),
        durationMs: 3000,
      );

      expect(state.isWeak, isTrue);
      expect(engine.shouldStrengthen(1), isTrue);
      expect(engine.calculateReviewQuality(1), lessThanOrEqualTo(2));
    });

    test('答错两次会强制进入强化并限制质量评分', () {
      final engine = SessionMasteryEngine();

      engine.recordAttemptWithDuration(
        wordId: 1,
        mode: StudyModeType.quiz,
        outcome: StudyAttemptOutcome.wrong,
        reviewRecord: recordWithRetention(70),
        durationMs: 3000,
      );
      final state = engine.recordAttemptWithDuration(
        wordId: 1,
        mode: StudyModeType.spelling,
        outcome: StudyAttemptOutcome.wrong,
        reviewRecord: recordWithRetention(70),
        durationMs: 3000,
      );

      expect(state.wrongCount, 2);
      expect(state.isWeak, isTrue);
      expect(engine.calculateReviewQuality(1), lessThanOrEqualTo(2));
    });

    test('遗忘临界区答对比刚复习完答对更有证明力', () {
      final criticalEngine = SessionMasteryEngine();
      final freshEngine = SessionMasteryEngine();

      final criticalState = criticalEngine.recordAttemptWithDuration(
        wordId: 1,
        mode: StudyModeType.listening,
        outcome: StudyAttemptOutcome.firstCorrect,
        reviewRecord: recordWithRetention(55),
        durationMs: 3000,
      );
      final freshState = freshEngine.recordAttemptWithDuration(
        wordId: 1,
        mode: StudyModeType.listening,
        outcome: StudyAttemptOutcome.firstCorrect,
        reviewRecord: recordWithRetention(90),
        durationMs: 3000,
      );

      expect(criticalState.sessionScore, greaterThan(freshState.sessionScore));
    });
  });
}

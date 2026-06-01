import 'package:qingmang_weiji/models/study_session_summary.dart';
import 'package:test/test.dart';

void main() {
  group('学习完成总结', () {
    test('根据总数和弱词数计算掌握词数', () {
      const summary = StudySessionSummary(
        totalWords: 20,
        weakWords: 3,
        revealedWords: 2,
        skippedWords: 1,
      );

      expect(summary.masteredWords, 17);
    });

    test('根据掌握词数计算掌握率', () {
      const summary = StudySessionSummary(
        totalWords: 20,
        weakWords: 5,
        revealedWords: 2,
        skippedWords: 0,
      );

      expect(summary.masteryPercent, 75);
    });

    test('总数为0时掌握率为0', () {
      const summary = StudySessionSummary(
        totalWords: 0,
        weakWords: 0,
        revealedWords: 0,
        skippedWords: 0,
      );

      expect(summary.masteredWords, 0);
      expect(summary.masteryPercent, 0);
    });
  });
}

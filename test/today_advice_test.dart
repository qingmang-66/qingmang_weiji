import 'package:qingmang_weiji/models/today_advice.dart';
import 'package:test/test.dart';

void main() {
  group('今日行动建议', () {
    test('有待复习时优先建议复习', () {
      final advice = TodayAdvice.fromCounts(
        dueWords: 12,
        todayNewWords: 0,
        unlearnedWords: 50,
      );

      expect(advice.type, TodayAdviceType.reviewFirst);
    });

    test('无待复习且有未学词时建议学习新词，不管今天已学多少', () {
      final advice = TodayAdvice.fromCounts(
        dueWords: 0,
        todayNewWords: 40,
        unlearnedWords: 50,
      );

      expect(advice.type, TodayAdviceType.learnNewWords);
    });

    test('词库没有未学词且无待复习时建议等待复习', () {
      final advice = TodayAdvice.fromCounts(
        dueWords: 0,
        todayNewWords: 10,
        unlearnedWords: 0,
      );

      expect(advice.type, TodayAdviceType.waitForReview);
    });
  });
}

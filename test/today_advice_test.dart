import 'package:qingmang_weiji/models/today_advice.dart';
import 'package:test/test.dart';

void main() {
  group('今日行动建议', () {
    test('有待复习时优先建议复习', () {
      final advice = TodayAdvice.fromCounts(
        dueWords: 12,
        todayNewWords: 0,
        dailyNewLimit: 20,
        unlearnedWords: 50,
      );

      expect(advice.type, TodayAdviceType.reviewFirst);
    });

    test('无待复习且有新词额度时建议学习新词', () {
      final advice = TodayAdvice.fromCounts(
        dueWords: 0,
        todayNewWords: 8,
        dailyNewLimit: 20,
        unlearnedWords: 50,
      );

      expect(advice.type, TodayAdviceType.learnNewWords);
      expect(advice.remainingNewWords, 12);
    });

    test('新词额度已满且无待复习时建议休息', () {
      final advice = TodayAdvice.fromCounts(
        dueWords: 0,
        todayNewWords: 20,
        dailyNewLimit: 20,
        unlearnedWords: 50,
      );

      expect(advice.type, TodayAdviceType.doneToday);
    });

    test('词库没有未学词且无待复习时建议等待复习', () {
      final advice = TodayAdvice.fromCounts(
        dueWords: 0,
        todayNewWords: 10,
        dailyNewLimit: 20,
        unlearnedWords: 0,
      );

      expect(advice.type, TodayAdviceType.waitForReview);
    });
  });
}

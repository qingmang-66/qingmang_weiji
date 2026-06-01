import 'package:test/test.dart';
import 'package:qingmang_weiji/services/study_plan_logic.dart';

void main() {
  group('StudyPlanLogic 计划纯逻辑', () {
    test('固定截止日：每日新词量 = ceil(总词数 / 剩余天数)', () {
      // 100 词，10 天 -> 每天 10 词
      final daily = StudyPlanLogic.estimateDailyNewTarget(
        totalWords: 100,
        targetDate: DateTime(2026, 6, 10),
        today: DateTime(2026, 5, 31),
      );
      // 6/10 - 5/31 = 10 天
      expect(daily, 10);
    });

    test('固定截止日：不能整除时向上取整', () {
      // 105 词，10 天 -> ceil(10.5) = 11
      final daily = StudyPlanLogic.estimateDailyNewTarget(
        totalWords: 105,
        targetDate: DateTime(2026, 6, 10),
        today: DateTime(2026, 5, 31),
      );
      expect(daily, 11);
    });

    test('目标日期为今天或已过：剩余天数按 1 计算，避免除零', () {
      final daily = StudyPlanLogic.estimateDailyNewTarget(
        totalWords: 50,
        targetDate: DateTime(2026, 5, 31),
        today: DateTime(2026, 5, 31),
      );
      expect(daily, 50);
    });

    test('固定每日量：预计完成天数 = ceil(总词数 / 每日量)', () {
      expect(
        StudyPlanLogic.estimateFinishDays(totalWords: 100, dailyNewTarget: 10),
        10,
      );
      expect(
        StudyPlanLogic.estimateFinishDays(totalWords: 105, dailyNewTarget: 10),
        11,
      );
    });

    test('每日量为 0 时完成天数返回 0（避免除零）', () {
      expect(
        StudyPlanLogic.estimateFinishDays(totalWords: 100, dailyNewTarget: 0),
        0,
      );
    });

    test('计划总体进度 = 已学新词 / 总词数，封顶 1.0', () {
      expect(
        StudyPlanLogic.planProgress(learnedNewWords: 50, totalWords: 100),
        closeTo(0.5, 1e-9),
      );
      expect(
        StudyPlanLogic.planProgress(learnedNewWords: 150, totalWords: 100),
        1.0,
      );
    });

    test('总词数为 0 时进度返回 1.0', () {
      expect(
        StudyPlanLogic.planProgress(learnedNewWords: 0, totalWords: 0),
        1.0,
      );
    });
  });
}

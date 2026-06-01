import 'package:test/test.dart';
import 'package:qingmang_weiji/models/daily_task_snapshot.dart';

void main() {
  group('DailyTaskSnapshot 纯逻辑', () {
    // 构造一个测试用快照
    DailyTaskSnapshot snapshot({
      int targetNew = 0,
      int targetReview = 0,
      int completedNew = 0,
      int completedReview = 0,
    }) {
      return DailyTaskSnapshot(
        date: '2026-05-31',
        planId: 1,
        targetNewWords: targetNew,
        targetReviewWords: targetReview,
        completedNewWords: completedNew,
        completedReviewWords: completedReview,
      );
    }

    test('完成率 = 已完成总数 / 目标总数', () {
      final s = snapshot(
        targetNew: 10,
        targetReview: 10,
        completedNew: 5,
        completedReview: 5,
      );
      // (5 + 5) / (10 + 10) = 0.5
      expect(s.completionRate, closeTo(0.5, 1e-9));
    });

    test('目标总数为 0 时完成率视为 1.0（无任务即完成）', () {
      final s = snapshot();
      expect(s.completionRate, 1.0);
    });

    test('完成率封顶为 1.0', () {
      final s = snapshot(
        targetNew: 5,
        targetReview: 0,
        completedNew: 10,
        completedReview: 0,
      );
      expect(s.completionRate, 1.0);
    });

    test('新词与复习都达标时 isCompleted 为 true', () {
      final s = snapshot(
        targetNew: 3,
        targetReview: 2,
        completedNew: 3,
        completedReview: 2,
      );
      expect(s.isCompleted, isTrue);
    });

    test('任一项未达标时 isCompleted 为 false', () {
      final s = snapshot(
        targetNew: 3,
        targetReview: 2,
        completedNew: 3,
        completedReview: 1,
      );
      expect(s.isCompleted, isFalse);
    });

    test('剩余任务不为负', () {
      final s = snapshot(
        targetNew: 3,
        targetReview: 2,
        completedNew: 5,
        completedReview: 5,
      );
      expect(s.remainingNewWords, 0);
      expect(s.remainingReviewWords, 0);
    });

    test('剩余任务正常计算', () {
      final s = snapshot(
        targetNew: 10,
        targetReview: 8,
        completedNew: 4,
        completedReview: 3,
      );
      expect(s.remainingNewWords, 6);
      expect(s.remainingReviewWords, 5);
    });

    test('toMap / fromMap 往返一致', () {
      final s = snapshot(
        targetNew: 10,
        targetReview: 8,
        completedNew: 4,
        completedReview: 3,
      );
      final restored = DailyTaskSnapshot.fromMap(s.toMap());
      expect(restored.date, s.date);
      expect(restored.planId, s.planId);
      expect(restored.targetNewWords, s.targetNewWords);
      expect(restored.targetReviewWords, s.targetReviewWords);
      expect(restored.completedNewWords, s.completedNewWords);
      expect(restored.completedReviewWords, s.completedReviewWords);
    });
  });
}

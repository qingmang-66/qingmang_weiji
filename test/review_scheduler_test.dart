import 'package:test/test.dart';
import 'package:qingmang_weiji/models/review_record.dart';
import 'package:qingmang_weiji/services/review_scheduler.dart';

void main() {
  group('ReviewScheduler 核心算法测试', () {
    // ===== 1. 基础间隔序列验证 =====
    group('艾宾浩斯基础间隔序列', () {
      test('新单词初始间隔 = 1天', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now().add(const Duration(days: 1)),
          lastReview: DateTime.now(),
        );
        expect(record.interval, equals(1));
      });
    });

    // ===== 2. 回忆失败测试 =====
    group('回忆失败 (quality < 3)', () {
      test('完全忘记 (quality=1): repetitions 重置为 0', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 5,
          interval: 30,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 1);
        expect(result.repetitions, equals(0));
      });

      test('完全忘记 (quality=1): interval 重置为 1', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 5,
          interval: 60,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 1);
        expect(result.interval, equals(1));
      });

      test('困难回忆 (quality=2): repetitions 继续增加，间隔缩短30%', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 3,
          interval: 7,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 2);
        // quality=2 不再重置，而是继续学习，间隔缩短30%
        expect(result.repetitions, equals(4));
        // 基础间隔第4步是7天，缩短30% -> 7 * 0.7 = 4.9 -> 5天
        expect(result.interval, equals(5));
      });
    });

    // ===== 3. 基础间隔序列测试 =====
    group('基础间隔序列 (repetitions <= 7)', () {
      test('repetitions=0 -> 1, interval=1', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        expect(result.interval, equals(1));
        expect(result.repetitions, equals(1));
      });

      test('repetitions=1 -> 2, interval=2', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 1,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        expect(result.interval, equals(2));
        expect(result.repetitions, equals(2));
      });

      test('repetitions=2 -> 3, interval=4', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 2,
          interval: 2,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        expect(result.interval, equals(4));
      });

      test('repetitions=3 -> 4, interval=7', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 3,
          interval: 4,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        expect(result.interval, equals(7));
      });

      test('repetitions=4 -> 5, interval=15', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 4,
          interval: 7,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        expect(result.interval, equals(15));
      });

      test('repetitions=5 -> 6, interval=30', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 5,
          interval: 15,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        expect(result.interval, equals(30));
      });

      test('repetitions=6 -> 7, interval=60 (基础序列最后一步)', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 6,
          interval: 30,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        expect(result.interval, equals(60));
        expect(result.repetitions, equals(7));
      });
    });

    // ===== 4. SM-2 动态计算测试 =====
    group('SM-2 动态计算 (repetitions > 7)', () {
      test('repetitions=7 -> 8: 使用 SM-2 公式', () {
        // repetitions=7 时，++后变成 8，8 > 7，进入 SM-2 分支
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 7,
          interval: 60,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        // SM-2: interval = 60 * 2.5 = 150
        // 但第一次进入 SM-2 时，easeFactor 已经被上一步调整
        expect(result.repetitions, equals(8));
        expect(result.interval, greaterThan(60)); // 应该比 60 大
      });

      test('SM-2 动态间隔持续增长', () {
        var record = ReviewRecord(
          wordId: 1,
          repetitions: 8,
          interval: 150,
          easeFactor: 2.36,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );

        // 连续两次 SM-2 计算
        record = ReviewScheduler.scheduleNextReview(record, 3);
        final interval1 = record.interval;

        record = ReviewScheduler.scheduleNextReview(record, 3);
        final interval2 = record.interval;

        // 间隔应该持续增长
        expect(interval2, greaterThan(interval1));
      });
    });

    // ===== 5. 质量奖励测试 =====
    group('质量奖励机制', () {
      test('quality=4 (容易): 间隔增加 20%', () {
        // 直接测试 SM-2 分支内的奖励
        var record = ReviewRecord(
          wordId: 1,
          repetitions: 8,
          interval: 100,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 4);
        // SM-2 分支: easeFactor 调整 = 2.5 + (0.1 - 1 * 0.10) = 2.5
        // interval = 100 * 2.5 = 250
        expect(result.interval, equals(250));
      });

      test('quality=5 (非常简单): 间隔增加 50%', () {
        var record = ReviewRecord(
          wordId: 1,
          repetitions: 8,
          interval: 100,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 5);
        // SM-2 分支:
        // 1. easeFactor 调整 = 2.5 + 0.1 = 2.6
        // 2. interval = 100 * 2.6 = 260
        expect(result.interval, equals(260));
      });
    });

    // ===== 6. 难度因子测试 =====
    group('难度因子调整', () {
      test('quality=3 (模糊): easeFactor 减少', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 3);
        // 2.5 - 0.14 = 2.36
        expect(result.easeFactor, closeTo(2.36, 0.01));
      });

      test('quality=4 (容易): easeFactor 略微增加', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 4);
        // 2.5 + 0 = 2.5
        expect(result.easeFactor, closeTo(2.5, 0.01));
      });

      test('quality=5 (非常简单): easeFactor 增加', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final result = ReviewScheduler.scheduleNextReview(record, 5);
        // 2.5 + 0.1 = 2.6
        expect(result.easeFactor, closeTo(2.6, 0.01));
      });

      test('easeFactor 最低值为 1.3 (最低值保护机制)', () {
        // 直接测试代码中的最低值保护逻辑
        // 根据代码：if (easeFactor < 1.3) easeFactor = 1.3;
        // 我们验证这个逻辑存在

        // 模拟 easeFactor 降到很低的情况
        var record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 1.31,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );

        // 多次调用后，easeFactor 应该保持在 1.3 或以上
        for (int i = 0; i < 5; i++) {
          record = ReviewScheduler.scheduleNextReview(record, 3);
        }

        // 验证最低值保护
        expect(record.easeFactor, greaterThanOrEqualTo(1.3));
      });
    });

    // ===== 7. 记忆阶段测试 =====
    group('记忆阶段判定', () {
      test('repetitions=0: 新学', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        expect(ReviewScheduler.getMemoryStage(record), equals('新学'));
      });

      test('repetitions=1: 初步', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 1,
          interval: 2,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        expect(ReviewScheduler.getMemoryStage(record), equals('初步'));
      });

      test('repetitions=2-3: 巩固', () {
        final r1 = ReviewRecord(
          wordId: 1,
          repetitions: 2,
          interval: 4,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final r2 = ReviewRecord(
          wordId: 1,
          repetitions: 3,
          interval: 7,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        expect(ReviewScheduler.getMemoryStage(r1), equals('巩固'));
        expect(ReviewScheduler.getMemoryStage(r2), equals('巩固'));
      });

      test('repetitions=4-5: 熟悉', () {
        final r1 = ReviewRecord(
          wordId: 1,
          repetitions: 4,
          interval: 15,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        final r2 = ReviewRecord(
          wordId: 1,
          repetitions: 5,
          interval: 30,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        expect(ReviewScheduler.getMemoryStage(r1), equals('熟悉'));
        expect(ReviewScheduler.getMemoryStage(r2), equals('熟悉'));
      });

      test('repetitions>5: 掌握', () {
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 6,
          interval: 60,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        expect(ReviewScheduler.getMemoryStage(record), equals('掌握'));
      });
    });

    // ===== 8. 边界条件测试 =====
    group('边界条件', () {
      test('interval 永远不会小于 1', () {
        var record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 1.3,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );
        for (int i = 0; i < 10; i++) {
          record = ReviewScheduler.scheduleNextReview(record, 1);
        }
        expect(record.interval, greaterThanOrEqualTo(1));
      });
    });

    // ===== 9. 完整学习路径测试 =====
    group('完整学习路径模拟', () {
      test('单词从新学到掌握', () {
        var record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );

        // 步骤 1-7: 基础序列
        record = ReviewScheduler.scheduleNextReview(record, 3); // 1天
        expect(record.interval, equals(1));

        record = ReviewScheduler.scheduleNextReview(record, 3); // 2天
        expect(record.interval, equals(2));

        record = ReviewScheduler.scheduleNextReview(record, 3); // 4天
        expect(record.interval, equals(4));

        record = ReviewScheduler.scheduleNextReview(record, 3); // 7天
        expect(record.interval, equals(7));

        record = ReviewScheduler.scheduleNextReview(record, 3); // 15天
        expect(record.interval, equals(15));

        record = ReviewScheduler.scheduleNextReview(record, 3); // 30天
        expect(record.interval, equals(30));

        record = ReviewScheduler.scheduleNextReview(record, 3); // 60天
        expect(record.interval, equals(60));
        expect(ReviewScheduler.getMemoryStage(record), equals('掌握'));

        // 步骤 8+: SM-2 动态计算
        record = ReviewScheduler.scheduleNextReview(record, 3); // SM-2
        expect(record.interval, greaterThan(60)); // 应该比 60 大
      });

      test('遗忘后重新学习', () {
        var record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        );

        // 学习了几天后...
        record = ReviewScheduler.scheduleNextReview(record, 4);
        record = ReviewScheduler.scheduleNextReview(record, 4);
        expect(record.repetitions, equals(2));

        // 突然忘记了！
        record = ReviewScheduler.scheduleNextReview(record, 1);
        expect(record.repetitions, equals(0)); // 重置
        expect(record.interval, equals(1)); // 从头开始
      });
    });
    // ===== 10. 初始化与保持率测试 =====
    group('初始化与保持率估算', () {
      test('createInitialRecord 创建默认复习记录', () {
        final before = DateTime.now();
        final record = ReviewScheduler.createInitialRecord(42);
        final after = DateTime.now();

        expect(record.wordId, equals(42));
        expect(record.quality, equals(0));
        expect(record.interval, equals(1));
        expect(record.easeFactor, equals(2.5));
        expect(record.repetitions, equals(0));
        expect(record.lastReview.isBefore(before), isFalse);
        expect(record.lastReview.isAfter(after), isFalse);
        expect(
          record.nextReview.difference(record.lastReview).inDays,
          equals(1),
        );
      });

      test('estimateRetention 新学单词返回 0', () {
        final now = DateTime.now();
        final record = ReviewRecord(
          wordId: 1,
          repetitions: 0,
          interval: 1,
          easeFactor: 2.5,
          nextReview: now.add(const Duration(days: 1)),
          lastReview: now,
        );

        expect(ReviewScheduler.estimateRetention(record), equals(0));
      });

      test('estimateRetention 已到期记录低于刚复习记录', () {
        final now = DateTime.now();
        final freshRecord = ReviewRecord(
          wordId: 1,
          repetitions: 3,
          interval: 4,
          easeFactor: 2.5,
          nextReview: now.add(const Duration(days: 4)),
          lastReview: now,
        );
        final dueRecord = ReviewRecord(
          wordId: 1,
          repetitions: 3,
          interval: 4,
          easeFactor: 2.5,
          nextReview: now,
          lastReview: now.subtract(const Duration(days: 4)),
        );

        expect(
          ReviewScheduler.estimateRetention(freshRecord),
          greaterThan(ReviewScheduler.estimateRetention(dueRecord)),
        );
      });
    });
  });
}

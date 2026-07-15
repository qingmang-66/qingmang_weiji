import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/achievement_service.dart';
import 'package:qingmang_weiji/models/achievement_category.dart';
import 'package:qingmang_weiji/models/achievement_stat_type.dart';

void main() {
  group('AchievementService.registry', () {
    test('至少包含 30 个成就', () {
      expect(AchievementService.registry.length, greaterThanOrEqualTo(30));
    });

    test('所有 id 唯一', () {
      final ids = AchievementService.registry.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id 重复');
    });

    test('所有 sortOrder 唯一且升序', () {
      final orders = AchievementService.registry
          .map((a) => a.sortOrder)
          .toList();
      expect(orders.toSet().length, orders.length, reason: 'sortOrder 重复');
      for (var i = 1; i < orders.length; i++) {
        expect(orders[i] > orders[i - 1], true, reason: 'sortOrder 必须严格递增');
      }
    });

    test('至少覆盖全部 6 个核心类别', () {
      final cats = AchievementService.registry.map((a) => a.category).toSet();
      expect(cats, contains(AchievementCategory.study));
      expect(cats, contains(AchievementCategory.review));
      expect(cats, contains(AchievementCategory.streak));
      expect(cats, contains(AchievementCategory.favorite));
      expect(cats, contains(AchievementCategory.customSet));
      expect(cats, contains(AchievementCategory.plan));
    });

    test('所有 targetValue 都为正整数', () {
      for (final a in AchievementService.registry) {
        expect(a.targetValue > 0, true, reason: '${a.id} target 必须 > 0');
      }
    });

    test('所有 statType 都属于支持的枚举', () {
      final supported = AchievementStatType.values;
      for (final a in AchievementService.registry) {
        expect(
          supported.contains(a.statType),
          true,
          reason: '${a.id} statType 不在白名单',
        );
      }
    });
  });
}

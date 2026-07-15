import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/achievement_definition.dart';
import 'package:qingmang_weiji/models/achievement_progress.dart';
import 'package:qingmang_weiji/models/achievement_status.dart';
import 'package:qingmang_weiji/models/achievement_category.dart';
import 'package:qingmang_weiji/models/achievement_stat_type.dart';
import 'package:flutter/material.dart';

void main() {
  group('AchievementProgress', () {
    const def = AchievementDefinition(
      id: 'study.10',
      titleKey: 'ach.study10Title',
      descriptionKey: 'ach.study10Desc',
      icon: Icons.school,
      category: AchievementCategory.study,
      statType: AchievementStatType.learnedWords,
      targetValue: 10,
      sortOrder: 10,
    );

    test('progressRatio 在 currentValue < target 时线性', () {
      final p = AchievementProgress(
        definition: def,
        currentValue: 5,
        status: AchievementStatus.locked,
      );
      expect(p.progressRatio, 0.5);
    });

    test('progressRatio 在 currentValue > target 时截断到 1', () {
      final p = AchievementProgress(
        definition: def,
        currentValue: 100,
        status: AchievementStatus.unlocked,
      );
      expect(p.progressRatio, 1.0);
    });

    test('isUnlocked 与 status 同步', () {
      final unlocked = AchievementProgress(
        definition: def,
        currentValue: 10,
        status: AchievementStatus.unlocked,
      );
      final locked = AchievementProgress(
        definition: def,
        currentValue: 9,
        status: AchievementStatus.locked,
      );
      expect(unlocked.isUnlocked, true);
      expect(locked.isUnlocked, false);
    });

    test('copyWith 保留未传字段', () {
      final p = AchievementProgress(
        definition: def,
        currentValue: 5,
        status: AchievementStatus.locked,
      );
      final next = p.copyWith(
        currentValue: 10,
        status: AchievementStatus.unlocked,
      );
      expect(next.currentValue, 10);
      expect(next.isUnlocked, true);
      expect(next.definition, def);
    });
  });

  group('AchievementDefinition', () {
    test('字段全部必填', () {
      const def = AchievementDefinition(
        id: 'review.10',
        titleKey: 'k',
        descriptionKey: 'd',
        icon: Icons.replay,
        category: AchievementCategory.review,
        statType: AchievementStatType.totalReviews,
        targetValue: 10,
        sortOrder: 60,
      );
      expect(def.id, 'review.10');
      expect(def.targetValue, 10);
      expect(def.category, AchievementCategory.review);
      expect(def.statType, AchievementStatType.totalReviews);
    });
  });

  group('AchievementStatus enum', () {
    test('index 映射符合数据库约定', () {
      expect(AchievementStatus.locked.index, 0);
      expect(AchievementStatus.unlocked.index, 1);
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/achievement_category.dart';
import '../models/achievement_definition.dart';
import '../models/achievement_progress.dart';
import '../models/achievement_stat_type.dart';
import '../models/achievement_status.dart';
import 'database_service.dart';
import 'daos/achievement_dao.dart';
import 'daos/custom_word_set_dao.dart';
import 'daos/favorite_dao.dart';
import 'daos/stats_dao.dart';
import 'daos/wrong_word_dao.dart';
import 'weekly_report_service.dart';

/// 阶段四：成就系统核心服务
///
/// 负责：
/// - 维护 30+ 个成就静态定义（registry）
/// - 从各 DAO 抓取实时统计 (snapshot)
/// - 检测新增解锁、解锁时间，持久化到 achievements 表
/// - 广播 newlyUnlocked 事件供 UI 订阅
class AchievementService {
  final AchievementDao _achievementDao;
  final StatsDao _statsDao;
  final WrongWordDao _wrongWordDao;
  final FavoriteDao _favoriteDao;
  final CustomWordSetDao _customWordSetDao;
  final WeeklyReportService _weeklyReportService;

  AchievementService({
    AchievementDao? achievementDao,
    StatsDao? statsDao,
    WrongWordDao? wrongWordDao,
    FavoriteDao? favoriteDao,
    CustomWordSetDao? customWordSetDao,
    required WeeklyReportService weeklyReportService,
  }) : _achievementDao = achievementDao ?? DatabaseService.achievementDao,
       _statsDao = statsDao ?? DatabaseService.statsDao,
       _wrongWordDao = wrongWordDao ?? DatabaseService.wrongWordDao,
       _favoriteDao = favoriteDao ?? DatabaseService.favoriteDao,
       _customWordSetDao = customWordSetDao ?? DatabaseService.customWordSetDao,
       _weeklyReportService = weeklyReportService;

  /// 成就注册表：30 个核心成就
  ///
  /// 排序：sortOrder 升序
  static const List<AchievementDefinition> registry = [
    // ===== 学习词数 =====
    AchievementDefinition(
      id: 'study.10',
      titleKey: 'ach.study10Title',
      descriptionKey: 'ach.study10Desc',
      icon: Icons.school,
      category: AchievementCategory.study,
      statType: AchievementStatType.learnedWords,
      targetValue: 10,
      sortOrder: 10,
    ),
    AchievementDefinition(
      id: 'study.50',
      titleKey: 'ach.study50Title',
      descriptionKey: 'ach.study50Desc',
      icon: Icons.school,
      category: AchievementCategory.study,
      statType: AchievementStatType.learnedWords,
      targetValue: 50,
      sortOrder: 20,
    ),
    AchievementDefinition(
      id: 'study.100',
      titleKey: 'ach.study100Title',
      descriptionKey: 'ach.study100Desc',
      icon: Icons.school,
      category: AchievementCategory.study,
      statType: AchievementStatType.learnedWords,
      targetValue: 100,
      sortOrder: 30,
    ),
    AchievementDefinition(
      id: 'study.500',
      titleKey: 'ach.study500Title',
      descriptionKey: 'ach.study500Desc',
      icon: Icons.workspace_premium,
      category: AchievementCategory.study,
      statType: AchievementStatType.learnedWords,
      targetValue: 500,
      sortOrder: 40,
    ),
    AchievementDefinition(
      id: 'study.1000',
      titleKey: 'ach.study1000Title',
      descriptionKey: 'ach.study1000Desc',
      icon: Icons.workspace_premium,
      category: AchievementCategory.study,
      statType: AchievementStatType.learnedWords,
      targetValue: 1000,
      sortOrder: 50,
    ),
    // ===== 复习次数 =====
    AchievementDefinition(
      id: 'review.10',
      titleKey: 'ach.review10Title',
      descriptionKey: 'ach.review10Desc',
      icon: Icons.replay,
      category: AchievementCategory.review,
      statType: AchievementStatType.totalReviews,
      targetValue: 10,
      sortOrder: 60,
    ),
    AchievementDefinition(
      id: 'review.50',
      titleKey: 'ach.review50Title',
      descriptionKey: 'ach.review50Desc',
      icon: Icons.replay,
      category: AchievementCategory.review,
      statType: AchievementStatType.totalReviews,
      targetValue: 50,
      sortOrder: 70,
    ),
    AchievementDefinition(
      id: 'review.200',
      titleKey: 'ach.review200Title',
      descriptionKey: 'ach.review200Desc',
      icon: Icons.replay_circle_filled,
      category: AchievementCategory.review,
      statType: AchievementStatType.totalReviews,
      targetValue: 200,
      sortOrder: 80,
    ),
    AchievementDefinition(
      id: 'review.1000',
      titleKey: 'ach.review1000Title',
      descriptionKey: 'ach.review1000Desc',
      icon: Icons.star,
      category: AchievementCategory.review,
      statType: AchievementStatType.totalReviews,
      targetValue: 1000,
      sortOrder: 90,
    ),
    // ===== 连续学习 =====
    AchievementDefinition(
      id: 'streak.3',
      titleKey: 'ach.streak3Title',
      descriptionKey: 'ach.streak3Desc',
      icon: Icons.local_fire_department,
      category: AchievementCategory.streak,
      statType: AchievementStatType.streakDays,
      targetValue: 3,
      sortOrder: 100,
    ),
    AchievementDefinition(
      id: 'streak.7',
      titleKey: 'ach.streak7Title',
      descriptionKey: 'ach.streak7Desc',
      icon: Icons.local_fire_department,
      category: AchievementCategory.streak,
      statType: AchievementStatType.streakDays,
      targetValue: 7,
      sortOrder: 110,
    ),
    AchievementDefinition(
      id: 'streak.30',
      titleKey: 'ach.streak30Title',
      descriptionKey: 'ach.streak30Desc',
      icon: Icons.local_fire_department,
      category: AchievementCategory.streak,
      statType: AchievementStatType.streakDays,
      targetValue: 30,
      sortOrder: 120,
    ),
    AchievementDefinition(
      id: 'streak.100',
      titleKey: 'ach.streak100Title',
      descriptionKey: 'ach.streak100Desc',
      icon: Icons.emoji_events,
      category: AchievementCategory.streak,
      statType: AchievementStatType.streakDays,
      targetValue: 100,
      sortOrder: 130,
    ),
    // ===== 收藏整理 =====
    AchievementDefinition(
      id: 'fav.first',
      titleKey: 'ach.favFirstTitle',
      descriptionKey: 'ach.favFirstDesc',
      icon: Icons.bookmark_add,
      category: AchievementCategory.favorite,
      statType: AchievementStatType.favoriteCount,
      targetValue: 1,
      sortOrder: 140,
    ),
    AchievementDefinition(
      id: 'fav.20',
      titleKey: 'ach.fav20Title',
      descriptionKey: 'ach.fav20Desc',
      icon: Icons.bookmark,
      category: AchievementCategory.favorite,
      statType: AchievementStatType.favoriteCount,
      targetValue: 20,
      sortOrder: 150,
    ),
    AchievementDefinition(
      id: 'fav.100',
      titleKey: 'ach.fav100Title',
      descriptionKey: 'ach.fav100Desc',
      icon: Icons.bookmarks,
      category: AchievementCategory.favorite,
      statType: AchievementStatType.favoriteCount,
      targetValue: 100,
      sortOrder: 160,
    ),
    AchievementDefinition(
      id: 'fav.group3',
      titleKey: 'ach.favGroup3Title',
      descriptionKey: 'ach.favGroup3Desc',
      icon: Icons.folder_open,
      category: AchievementCategory.favorite,
      statType: AchievementStatType.favoriteGroupCount,
      targetValue: 3,
      sortOrder: 170,
    ),
    AchievementDefinition(
      id: 'fav.studied',
      titleKey: 'ach.favStudiedTitle',
      descriptionKey: 'ach.favStudiedDesc',
      icon: Icons.bookmark_added,
      category: AchievementCategory.specialized,
      statType: AchievementStatType.favoriteStudied,
      targetValue: 1,
      sortOrder: 180,
    ),
    // ===== 自定义词集 =====
    AchievementDefinition(
      id: 'set.first',
      titleKey: 'ach.setFirstTitle',
      descriptionKey: 'ach.setFirstDesc',
      icon: Icons.create_new_folder,
      category: AchievementCategory.customSet,
      statType: AchievementStatType.customSetCount,
      targetValue: 1,
      sortOrder: 190,
    ),
    AchievementDefinition(
      id: 'set.5',
      titleKey: 'ach.set5Title',
      descriptionKey: 'ach.set5Desc',
      icon: Icons.folder_copy,
      category: AchievementCategory.customSet,
      statType: AchievementStatType.customSetCount,
      targetValue: 5,
      sortOrder: 200,
    ),
    AchievementDefinition(
      id: 'set.studied',
      titleKey: 'ach.setStudiedTitle',
      descriptionKey: 'ach.setStudiedDesc',
      icon: Icons.style,
      category: AchievementCategory.specialized,
      statType: AchievementStatType.customSetStudied,
      targetValue: 1,
      sortOrder: 210,
    ),
    // ===== 学习计划 =====
    AchievementDefinition(
      id: 'plan.week3',
      titleKey: 'ach.planWeek3Title',
      descriptionKey: 'ach.planWeek3Desc',
      icon: Icons.flag,
      category: AchievementCategory.plan,
      statType: AchievementStatType.weeklyPlanCompletedDays,
      targetValue: 3,
      sortOrder: 220,
    ),
    AchievementDefinition(
      id: 'plan.week5',
      titleKey: 'ach.planWeek5Title',
      descriptionKey: 'ach.planWeek5Desc',
      icon: Icons.flag_circle,
      category: AchievementCategory.plan,
      statType: AchievementStatType.weeklyPlanCompletedDays,
      targetValue: 5,
      sortOrder: 230,
    ),
    AchievementDefinition(
      id: 'plan.week7',
      titleKey: 'ach.planWeek7Title',
      descriptionKey: 'ach.planWeek7Desc',
      icon: Icons.outlined_flag,
      category: AchievementCategory.plan,
      statType: AchievementStatType.weeklyPlanCompletedDays,
      targetValue: 7,
      sortOrder: 240,
    ),
    AchievementDefinition(
      id: 'plan.study5',
      titleKey: 'ach.planStudy5Title',
      descriptionKey: 'ach.planStudy5Desc',
      icon: Icons.calendar_today,
      category: AchievementCategory.plan,
      statType: AchievementStatType.weeklyStudyDays,
      targetValue: 5,
      sortOrder: 250,
    ),
    AchievementDefinition(
      id: 'plan.study7',
      titleKey: 'ach.planStudy7Title',
      descriptionKey: 'ach.planStudy7Desc',
      icon: Icons.calendar_month,
      category: AchievementCategory.plan,
      statType: AchievementStatType.weeklyStudyDays,
      targetValue: 7,
      sortOrder: 260,
    ),
    // ===== 专项学习 / 错词攻克 =====
    AchievementDefinition(
      id: 'wrong.streak3',
      titleKey: 'ach.wrongStreak3Title',
      descriptionKey: 'ach.wrongStreak3Desc',
      icon: Icons.bolt,
      category: AchievementCategory.specialized,
      statType: AchievementStatType.maxWrongWordCorrectStreak,
      targetValue: 3,
      sortOrder: 270,
    ),
    AchievementDefinition(
      id: 'wrong.streak10',
      titleKey: 'ach.wrongStreak10Title',
      descriptionKey: 'ach.wrongStreak10Desc',
      icon: Icons.flash_on,
      category: AchievementCategory.specialized,
      statType: AchievementStatType.maxWrongWordCorrectStreak,
      targetValue: 10,
      sortOrder: 280,
    ),
    // ===== 掌握率 =====
    AchievementDefinition(
      id: 'mastery.50',
      titleKey: 'ach.mastery50Title',
      descriptionKey: 'ach.mastery50Desc',
      icon: Icons.psychology,
      category: AchievementCategory.study,
      statType: AchievementStatType.masteryRatio,
      targetValue: 50,
      sortOrder: 290,
    ),
    AchievementDefinition(
      id: 'mastery.80',
      titleKey: 'ach.mastery80Title',
      descriptionKey: 'ach.mastery80Desc',
      icon: Icons.psychology_alt,
      category: AchievementCategory.study,
      statType: AchievementStatType.masteryRatio,
      targetValue: 80,
      sortOrder: 300,
    ),
  ];

  /// 互斥锁：避免并发 checkAndUnlock
  ///
  /// 服务层对所有内部调用顺序加锁，保证成就状态写库原子性。
  bool _checking = false;

  final _controller = StreamController<List<AchievementProgress>>.broadcast();
  Stream<List<AchievementProgress>> get newlyUnlockedStream =>
      _controller.stream;

  void dispose() {
    _controller.close();
  }

  /// 抓取所有统计指标 → `Map<statType, value>`
  Future<Map<AchievementStatType, int>> _buildSnapshot() async {
    final stats = await _statsDao.getStudyStats();
    final maxStreak = await _wrongWordDao.getMaxCorrectStreakInWrongWords();
    final favCount = await _favoriteDao.getFavoriteCount();
    final favGroupCount = await _favoriteDao.getFavoriteGroupCount();
    final setCount = await _customWordSetDao.getSetCount();
    final weeklyReport = await _weeklyReportService.buildCurrentWeekReport();

    // 掌握率：mastered / total × 100
    final stages = (stats['stages'] as Map?) ?? const {};
    final totalLearned = stages.values.fold<int>(0, (a, b) => a + (b as int));
    final mastered = (stages['mastered'] as int?) ?? 0;
    final masteryRatio = totalLearned == 0
        ? 0
        : ((mastered / totalLearned) * 100).round();

    return {
      AchievementStatType.learnedWords: (stats['learnedWords'] as int?) ?? 0,
      AchievementStatType.totalReviews: (stats['totalReviews'] as int?) ?? 0,
      AchievementStatType.streakDays: (stats['streak'] as int?) ?? 0,
      AchievementStatType.favoriteCount: favCount,
      AchievementStatType.favoriteGroupCount: favGroupCount,
      AchievementStatType.customSetCount: setCount,
      AchievementStatType.weeklyPlanCompletedDays:
          weeklyReport.planCompletedDays,
      AchievementStatType.weeklyStudyDays: weeklyReport.studyDays,
      AchievementStatType.maxWrongWordCorrectStreak: maxStreak,
      AchievementStatType.customSetStudied: weeklyReport.customSetsStudied,
      AchievementStatType.favoriteStudied: weeklyReport.favoritesStudied,
      AchievementStatType.masteryRatio: masteryRatio,
    };
  }

  /// 检测并解锁：把"刚刚达成"的新成就推送到流
  ///
  /// 步骤：
  /// 1. 读快照
  /// 2. 与数据库现状合并，计算每条成就的 currentValue
  /// 3. 若达到 target 且未解锁 → 标记 unlocked + 时间
  /// 4. 持久化变更；广播新增解锁
  Future<List<AchievementProgress>> checkAndUnlock() async {
    if (_checking) return const [];
    _checking = true;
    try {
      final snapshot = await _buildSnapshot();
      final existingRows = await _achievementDao.getAllRows();
      final existingMap = {
        for (final row in existingRows) row['id'] as String: row,
      };

      final newlyUnlocked = <AchievementProgress>[];
      final batchRows = <Map<String, Object?>>[];

      for (final def in registry) {
        final current = snapshot[def.statType] ?? 0;
        final existing = existingMap[def.id];
        final prevStatus = existing == null
            ? AchievementStatus.locked
            : AchievementStatus.values[(existing['status'] as int?) ?? 0];
        final prevUnlockedAt = existing == null
            ? null
            : (existing['unlocked_at'] == null
                  ? null
                  : DateTime.tryParse(existing['unlocked_at'] as String));

        final shouldUnlock = current >= def.targetValue;
        final wasUnlocked = prevStatus == AchievementStatus.unlocked;
        final unlockAt = wasUnlocked
            ? prevUnlockedAt
            : (shouldUnlock ? DateTime.now() : null);
        final newStatus = (shouldUnlock || wasUnlocked)
            ? AchievementStatus.unlocked
            : AchievementStatus.locked;

        batchRows.add({
          'id': def.id,
          'current_value': current,
          'status': newStatus.index,
          'unlocked_at': unlockAt?.toIso8601String(),
        });

        if (shouldUnlock && !wasUnlocked) {
          newlyUnlocked.add(
            AchievementProgress(
              definition: def,
              currentValue: current,
              status: newStatus,
              unlockedAt: unlockAt,
            ),
          );
        }
      }

      await _achievementDao.upsertBatch(batchRows);

      if (newlyUnlocked.isNotEmpty) {
        _controller.add(newlyUnlocked);
      }
      return newlyUnlocked;
    } catch (e) {
      debugPrint('AchievementService.checkAndUnlock error: $e');
      rethrow;
    } finally {
      _checking = false;
    }
  }

  /// 加载所有成就的当前进度（不检测）
  ///
  /// 若数据库缺行 → 补成 locked + currentValue=0，确保前端列表完整
  Future<List<AchievementProgress>> loadAll() async {
    final existingRows = await _achievementDao.getAllRows();
    final existingMap = {
      for (final row in existingRows) row['id'] as String: row,
    };

    // 补全缺失行（仅当快照需要时一次性 upsert）
    final missingRows = <Map<String, Object?>>[];
    for (final def in registry) {
      if (!existingMap.containsKey(def.id)) {
        missingRows.add({
          'id': def.id,
          'current_value': 0,
          'status': AchievementStatus.locked.index,
          'unlocked_at': null,
        });
      }
    }
    if (missingRows.isNotEmpty) {
      await _achievementDao.upsertBatch(missingRows);
    }

    // 再读一次确保包含补全
    final refreshed = await _achievementDao.getAllRows();
    final refreshedMap = {
      for (final row in refreshed) row['id'] as String: row,
    };

    final out = <AchievementProgress>[];
    for (final def in registry) {
      final row = refreshedMap[def.id];
      final current = (row?['current_value'] as int?) ?? 0;
      final status = AchievementStatus
          .values[(row?['status'] as int?) ?? AchievementStatus.locked.index];
      final unlockedAt = row?['unlocked_at'] == null
          ? null
          : DateTime.tryParse(row!['unlocked_at'] as String);
      out.add(
        AchievementProgress(
          definition: def,
          currentValue: current,
          status: status,
          unlockedAt: unlockedAt,
        ),
      );
    }
    out.sort(
      (a, b) => a.definition.sortOrder.compareTo(b.definition.sortOrder),
    );
    return out;
  }

  /// 加载最近 N 条已解锁成就
  Future<List<AchievementProgress>> loadRecentUnlocked({int limit = 3}) async {
    final rows = await _achievementDao.getUnlockedRows(limit: limit);
    final defById = {for (final d in registry) d.id: d};
    final out = <AchievementProgress>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final def = defById[id];
      if (def == null) continue;
      out.add(
        AchievementProgress(
          definition: def,
          currentValue: (row['current_value'] as int?) ?? 0,
          status: AchievementStatus.unlocked,
          unlockedAt: row['unlocked_at'] == null
              ? null
              : DateTime.tryParse(row['unlocked_at'] as String),
        ),
      );
    }
    return out;
  }
}

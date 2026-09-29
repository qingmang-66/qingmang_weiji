import 'package:flutter/foundation.dart';
import '../models/study_plan.dart';
import '../models/daily_task_snapshot.dart';
import 'study_plan_logic.dart';
import 'repositories/study_plan_repository.dart';
import 'repositories/word_repository.dart';
import 'repositories/review_repository.dart';

/// 今日任务数据，用于首页今日任务中心展示
class TodayTask {
  /// 关联计划，无计划时为 null
  final StudyPlan? plan;

  /// 今日目标新词数
  final int targetNewWords;

  /// 今日目标复习数
  final int targetReviewWords;

  /// 今日已完成新词数
  final int completedNewWords;

  /// 今日已完成复习数
  final int completedReviewWords;

  /// 当前到期复习数量
  final int dueCount;

  const TodayTask({
    this.plan,
    required this.targetNewWords,
    required this.targetReviewWords,
    this.completedNewWords = 0,
    this.completedReviewWords = 0,
    this.dueCount = 0,
  });

  /// 是否有进行中的计划
  bool get hasPlan => plan != null;

  /// 今日是否完成
  bool get isCompleted =>
      completedNewWords >= targetNewWords &&
      completedReviewWords >= targetReviewWords;
}

/// 学习计划服务
///
/// 负责计划生成、今日任务计算、完成进度回写和计划状态管理，
/// 属于跨实体业务编排层。
class StudyPlanService {
  final StudyPlanRepository _planRepository;
  final WordRepository _wordRepository;
  final ReviewRepository _reviewRepository;

  StudyPlanService({
    required StudyPlanRepository planRepository,
    required WordRepository wordRepository,
    required ReviewRepository reviewRepository,
  }) : _planRepository = planRepository,
       _wordRepository = wordRepository,
       _reviewRepository = reviewRepository;

  /// 今天的日期字符串 yyyy-MM-dd
  String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);

  //recordProgress 是读-改-写，串行化避免并发累加丢失
  Future<void> _progressChain = Future.value();

  /// 创建学习计划。
  ///
  /// 根据词库统计总词数，按计划类型估算每日新词目标。
  Future<StudyPlan> createPlan({
    required String name,
    required List<int> wordBookIds,
    required StudyPlanType type,
    DateTime? targetDate,
    int? dailyNewTarget,
  }) async {
    //并行统计计划范围内总词数
    final counts = await Future.wait(
      wordBookIds.map(_wordRepository.getWordCountInBook),
    );
    final totalWords = counts.fold<int>(0, (sum, c) => sum + c);

    // 根据类型估算每日新词目标
    int finalDailyTarget;
    if (type == StudyPlanType.fixedDaily) {
      finalDailyTarget = dailyNewTarget ?? 0;
    } else {
      // 固定截止日 / 考试目标：按目标日期估算
      final date = targetDate ?? DateTime.now().add(const Duration(days: 30));
      finalDailyTarget = StudyPlanLogic.estimateDailyNewTarget(
        totalWords: totalWords,
        targetDate: date,
        today: DateTime.now(),
      );
    }

    final now = DateTime.now();
    final plan = StudyPlan(
      name: name,
      wordBookIds: wordBookIds,
      type: type,
      targetDate: targetDate,
      dailyNewTarget: finalDailyTarget,
      totalWords: totalWords,
      status: StudyPlanStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    return await _planRepository.createPlan(plan);
  }

  /// 获取今日任务。
  ///
  /// 结合进行中的计划目标和当前到期复习量，
  /// 生成或读取今天的任务快照。
  Future<TodayTask> getTodayTask() async {
    final plan = await _planRepository.getActivePlan();

    // 统计计划范围内到期复习量（并发发起，避免逐个词库串行等待）
    final dueCount = plan == null ? 0 : await _sumDueCounts(plan.wordBookIds);

    if (plan == null || plan.id == null) {
      return TodayTask(
        targetNewWords: 0,
        targetReviewWords: 0,
        dueCount: dueCount,
      );
    }

    final today = _todayKey();
    var snapshot = await _planRepository.getSnapshot(plan.id!, today);

    // 今天还没有快照则创建：目标新词取计划每日量，目标复习取当前到期量。
    // 用「不存在才插入」而不是 upsert：本方法可能在读-改-写进度期间被并发调用，
    // REPLACE 会把刚累加的已完成数覆盖回 0
    if (snapshot == null) {
      final created = DailyTaskSnapshot(
        date: today,
        planId: plan.id!,
        targetNewWords: plan.dailyNewTarget,
        targetReviewWords: dueCount,
      );
      await _planRepository.insertSnapshotIfAbsent(created);
      // 插入可能因并发被 IGNORE（已有别处写入的快照）：重读以拿到库中的权威值，
      // 否则本次展示的目标值与库中不一致，下次刷新会跳变
      snapshot = await _planRepository.getSnapshot(plan.id!, today) ?? created;
    }

    return TodayTask(
      plan: plan,
      targetNewWords: snapshot.targetNewWords,
      targetReviewWords: snapshot.targetReviewWords,
      completedNewWords: snapshot.completedNewWords,
      completedReviewWords: snapshot.completedReviewWords,
      dueCount: dueCount,
    );
  }

  /// 并发统计多个词库的到期复习量（逐个 await 会让总等待时间线性累加）
  Future<int> _sumDueCounts(List<int> bookIds) async {
    if (bookIds.isEmpty) return 0;
    final counts = await Future.wait(
      bookIds.map(_reviewRepository.getDueWordCount),
    );
    return counts.fold<int>(0, (sum, value) => sum + value);
  }

  /// 学习完成后累加今日已完成新词/复习数。
  Future<void> recordProgress({int newWords = 0, int reviewWords = 0}) {
    if (newWords <= 0 && reviewWords <= 0) return Future.value();
    //排队执行，前一次读-改-写完成前不开始下一次
    return _progressChain = _progressChain
        .catchError((_) {})
        .then((_) => _recordProgressInner(newWords, reviewWords));
  }

  Future<void> _recordProgressInner(int newWords, int reviewWords) async {
    final plan = await _planRepository.getActivePlan();
    if (plan == null || plan.id == null) return;

    final today = _todayKey();
    var snapshot = await _planRepository.getSnapshot(plan.id!, today);
    if (snapshot == null) {
      // 与 getTodayTask 保持一致：目标复习取当前到期量。
      // 若记为 0，willComplete 会立即为真并提前写入 completedAt，
      // 导致计划完成天数虚高
      final dueCount = await _sumDueCounts(plan.wordBookIds);
      snapshot = DailyTaskSnapshot(
        date: today,
        planId: plan.id!,
        targetNewWords: plan.dailyNewTarget,
        targetReviewWords: dueCount,
      );
    }

    final updatedNew = snapshot.completedNewWords + newWords;
    final updatedReview = snapshot.completedReviewWords + reviewWords;
    final willComplete =
        updatedNew >= snapshot.targetNewWords &&
        updatedReview >= snapshot.targetReviewWords;

    final updated = snapshot.copyWith(
      completedNewWords: updatedNew,
      completedReviewWords: updatedReview,
      completedAt: willComplete && snapshot.completedAt == null
          ? DateTime.now().toIso8601String()
          : snapshot.completedAt,
    );
    await _planRepository.upsertSnapshot(updated);
  }

  /// 暂停计划
  Future<void> pausePlan(StudyPlan plan) =>
      _planRepository.updatePlanStatus(plan, StudyPlanStatus.paused);

  /// 恢复计划
  Future<void> resumePlan(StudyPlan plan) =>
      _planRepository.updatePlanStatus(plan, StudyPlanStatus.active);

  /// 完成计划
  Future<void> completePlan(StudyPlan plan) =>
      _planRepository.updatePlanStatus(plan, StudyPlanStatus.completed);

  /// 删除计划
  Future<void> deletePlan(int planId) async {
    try {
      await _planRepository.deletePlan(planId);
    } catch (e) {
      debugPrint('StudyPlanService.deletePlan error: $e');
    }
  }

  /// 获取全部计划
  Future<List<StudyPlan>> getAllPlans() => _planRepository.getAllPlans();

  /// 获取当前进行中的计划
  Future<StudyPlan?> getActivePlan() => _planRepository.getActivePlan();
}

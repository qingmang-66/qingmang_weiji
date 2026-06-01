import 'package:flutter/foundation.dart';
import '../../models/study_plan.dart';
import '../../models/daily_task_snapshot.dart';
import '../database_service.dart';

/// 学习计划数据访问层
///
/// 对 Service 和页面暴露计划与每日任务快照的访问能力，
/// 屏蔽底层 DAO 细节。
class StudyPlanRepository {
  /// 创建计划，返回带 ID 的计划
  Future<StudyPlan> createPlan(StudyPlan plan) async {
    try {
      final id = await DatabaseService.studyPlanDao.insertPlan(plan);
      return plan.copyWith(id: id);
    } catch (e) {
      debugPrint('StudyPlanRepository.createPlan error: $e');
      rethrow;
    }
  }

  /// 更新计划
  Future<void> updatePlan(StudyPlan plan) async {
    try {
      await DatabaseService.studyPlanDao.updatePlan(plan);
    } catch (e) {
      debugPrint('StudyPlanRepository.updatePlan error: $e');
      rethrow;
    }
  }

  /// 更新计划状态
  Future<void> updatePlanStatus(StudyPlan plan, StudyPlanStatus status) async {
    final updated = plan.copyWith(status: status, updatedAt: DateTime.now());
    await updatePlan(updated);
  }

  /// 获取当前进行中的计划
  Future<StudyPlan?> getActivePlan() async {
    try {
      return await DatabaseService.studyPlanDao.getActivePlan();
    } catch (e) {
      debugPrint('StudyPlanRepository.getActivePlan error: $e');
      return null;
    }
  }

  /// 获取全部计划
  Future<List<StudyPlan>> getAllPlans() async {
    try {
      return await DatabaseService.studyPlanDao.getAllPlans();
    } catch (e) {
      debugPrint('StudyPlanRepository.getAllPlans error: $e');
      return [];
    }
  }

  /// 删除计划
  Future<void> deletePlan(int planId) async {
    try {
      await DatabaseService.studyPlanDao.deletePlan(planId);
    } catch (e) {
      debugPrint('StudyPlanRepository.deletePlan error: $e');
      rethrow;
    }
  }

  /// 获取某计划某天的任务快照
  Future<DailyTaskSnapshot?> getSnapshot(int planId, String date) async {
    try {
      return await DatabaseService.studyPlanDao.getSnapshot(planId, date);
    } catch (e) {
      debugPrint('StudyPlanRepository.getSnapshot error: $e');
      return null;
    }
  }

  /// 保存/更新某天任务快照
  Future<void> upsertSnapshot(DailyTaskSnapshot snapshot) async {
    try {
      await DatabaseService.studyPlanDao.upsertSnapshot(snapshot);
    } catch (e) {
      debugPrint('StudyPlanRepository.upsertSnapshot error: $e');
      rethrow;
    }
  }

  /// 获取某计划全部快照
  Future<List<DailyTaskSnapshot>> getSnapshotsByPlan(int planId) async {
    try {
      return await DatabaseService.studyPlanDao.getSnapshotsByPlan(planId);
    } catch (e) {
      debugPrint('StudyPlanRepository.getSnapshotsByPlan error: $e');
      return [];
    }
  }
}

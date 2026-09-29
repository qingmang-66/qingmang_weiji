import 'package:flutter/foundation.dart';
import '../../models/study_plan.dart';
import '../../models/daily_task_snapshot.dart';
import '../database_service.dart';
import '../daos/study_plan_dao.dart';

/// 学习计划数据访问层
///
/// 对 Service 和页面暴露计划与每日任务快照的访问能力，
/// 屏蔽底层 DAO 细节。
class StudyPlanRepository {
  final StudyPlanDao? _studyPlanDaoOverride;

  StudyPlanRepository({StudyPlanDao? studyPlanDao})
    : _studyPlanDaoOverride = studyPlanDao;

  //惰性解析，避免测试注入时触发数据库初始化
  StudyPlanDao get _studyPlanDao =>
      _studyPlanDaoOverride ?? DatabaseService.studyPlanDao;

  /// 创建计划，返回带 ID 的计划
  Future<StudyPlan> createPlan(StudyPlan plan) async {
    try {
      final id = await _studyPlanDao.insertPlan(plan);
      return plan.copyWith(id: id);
    } catch (e) {
      debugPrint('StudyPlanRepository.createPlan error: $e');
      rethrow;
    }
  }

  /// 更新计划
  Future<void> updatePlan(StudyPlan plan) async {
    try {
      await _studyPlanDao.updatePlan(plan);
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
      return await _studyPlanDao.getActivePlan();
    } catch (e) {
      debugPrint('StudyPlanRepository.getActivePlan error: $e');
      rethrow;
    }
  }

  /// 获取全部计划
  Future<List<StudyPlan>> getAllPlans() async {
    try {
      return await _studyPlanDao.getAllPlans();
    } catch (e) {
      debugPrint('StudyPlanRepository.getAllPlans error: $e');
      rethrow;
    }
  }

  /// 删除计划
  Future<void> deletePlan(int planId) async {
    try {
      await _studyPlanDao.deletePlan(planId);
    } catch (e) {
      debugPrint('StudyPlanRepository.deletePlan error: $e');
      rethrow;
    }
  }

  /// 获取某计划某天的任务快照；快照缺失与查询失败均按无快照兼容
  Future<DailyTaskSnapshot?> getSnapshot(int planId, String date) async {
    try {
      return await _studyPlanDao.getSnapshot(planId, date);
    } catch (e) {
      debugPrint('StudyPlanRepository.getSnapshot error: $e');
      return null;
    }
  }

  /// 保存/更新某天任务快照
  Future<void> upsertSnapshot(DailyTaskSnapshot snapshot) async {
    try {
      await _studyPlanDao.upsertSnapshot(snapshot);
    } catch (e) {
      debugPrint('StudyPlanRepository.upsertSnapshot error: $e');
      rethrow;
    }
  }

  /// 仅当快照不存在时插入（补建今日任务用，避免覆盖并发累加的进度）
  Future<void> insertSnapshotIfAbsent(DailyTaskSnapshot snapshot) async {
    try {
      await _studyPlanDao.insertSnapshotIfAbsent(snapshot);
    } catch (e) {
      debugPrint('StudyPlanRepository.insertSnapshotIfAbsent error: $e');
      rethrow;
    }
  }

  /// 获取某计划全部快照；可选展示/备份允许失败时降级为空列表
  Future<List<DailyTaskSnapshot>> getSnapshotsByPlan(int planId) async {
    try {
      return await _studyPlanDao.getSnapshotsByPlan(planId);
    } catch (e) {
      debugPrint('StudyPlanRepository.getSnapshotsByPlan error: $e');
      return [];
    }
  }
}

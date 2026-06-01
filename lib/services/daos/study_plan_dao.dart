import 'package:sqflite/sqflite.dart';
import '../../models/study_plan.dart';
import '../../models/daily_task_snapshot.dart';

/// 学习计划数据访问对象
///
/// 负责 study_plans 和 daily_task_snapshots 两张表的增删改查。
class StudyPlanDao {
  final Future<Database> _dbFuture;

  StudyPlanDao(this._dbFuture);

  // ========== 学习计划 ==========

  /// 插入计划，返回新计划 ID
  Future<int> insertPlan(StudyPlan plan) async {
    final db = await _dbFuture;
    final map = plan.toMap()..remove('id');
    return await db.insert('study_plans', map);
  }

  /// 更新计划
  Future<void> updatePlan(StudyPlan plan) async {
    final db = await _dbFuture;
    if (plan.id == null) return;
    await db.update(
      'study_plans',
      plan.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  /// 获取当前进行中的计划（最近更新的一个）
  Future<StudyPlan?> getActivePlan() async {
    final db = await _dbFuture;
    final result = await db.query(
      'study_plans',
      where: 'status = ?',
      whereArgs: [StudyPlanStatus.active.index],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return StudyPlan.fromMap(result.first);
  }

  /// 获取全部计划
  Future<List<StudyPlan>> getAllPlans() async {
    final db = await _dbFuture;
    final result = await db.query('study_plans', orderBy: 'updated_at DESC');
    return result.map((row) => StudyPlan.fromMap(row)).toList();
  }

  /// 删除计划及其每日快照
  Future<void> deletePlan(int planId) async {
    final db = await _dbFuture;
    await db.delete('study_plans', where: 'id = ?', whereArgs: [planId]);
    await db.delete(
      'daily_task_snapshots',
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
  }

  // ========== 每日任务快照 ==========

  /// 插入或更新某计划某天的任务快照（按 plan_id + date 唯一）
  Future<void> upsertSnapshot(DailyTaskSnapshot snapshot) async {
    final db = await _dbFuture;
    await db.insert(
      'daily_task_snapshots',
      snapshot.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取某计划某天的任务快照
  Future<DailyTaskSnapshot?> getSnapshot(int planId, String date) async {
    final db = await _dbFuture;
    final result = await db.query(
      'daily_task_snapshots',
      where: 'plan_id = ? AND date = ?',
      whereArgs: [planId, date],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return DailyTaskSnapshot.fromMap(result.first);
  }

  /// 获取某计划的全部任务快照（按日期倒序）
  Future<List<DailyTaskSnapshot>> getSnapshotsByPlan(int planId) async {
    final db = await _dbFuture;
    final result = await db.query(
      'daily_task_snapshots',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'date DESC',
    );
    return result.map((row) => DailyTaskSnapshot.fromMap(row)).toList();
  }
}

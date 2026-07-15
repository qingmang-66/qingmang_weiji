import 'package:sqflite/sqflite.dart';
import '../../models/achievement_status.dart';

/// 阶段四：成就 DAO
///
/// 负责 `achievements` 表的 CRUD。表结构在数据库版本 4 中已存在：
///   id TEXT PRIMARY KEY,
///   current_value INTEGER DEFAULT 0,
///   status INTEGER DEFAULT 0,
///   unlocked_at TEXT
///
/// 所有方法返回的 Map 列名与 SQL 列名一致，由 Service 层负责映射。
class AchievementDao {
  final Future<Database> _dbFuture;

  AchievementDao(this._dbFuture);

  /// 读取所有进度行
  Future<List<Map<String, dynamic>>> getAllRows() async {
    final db = await _dbFuture;
    return await db.query('achievements');
  }

  /// 根据 id 读取单条
  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'achievements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// 读取已解锁条目，按 unlocked_at 倒序
  Future<List<Map<String, dynamic>>> getUnlockedRows({int? limit}) async {
    final db = await _dbFuture;
    return await db.query(
      'achievements',
      where: 'status = ?',
      whereArgs: [AchievementStatus.unlocked.index],
      orderBy: 'unlocked_at DESC',
      limit: limit,
    );
  }

  /// 插入或更新单条
  /// - currentValue/status 强制覆盖
  /// - unlockedAt 非空时覆盖；为 null 时不动
  Future<void> upsert({
    required String id,
    required int currentValue,
    required AchievementStatus status,
    DateTime? unlockedAt,
  }) async {
    final db = await _dbFuture;
    final existing = await db.query(
      'achievements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final patch = <String, Object?>{
        'current_value': currentValue,
        'status': status.index,
      };
      if (unlockedAt != null) {
        patch['unlocked_at'] = unlockedAt.toIso8601String();
      }
      await db.update('achievements', patch, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.insert('achievements', {
        'id': id,
        'current_value': currentValue,
        'status': status.index,
        'unlocked_at': unlockedAt?.toIso8601String(),
      });
    }
  }

  /// 批量插入或更新（事务）
  ///
  /// 入参 rows 每行需包含 id/current_value/status，可选 unlocked_at。
  Future<void> upsertBatch(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final db = await _dbFuture;
    await db.transaction((txn) async {
      for (final row in rows) {
        final id = row['id'] as String;
        final existing = await txn.query(
          'achievements',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final patch = <String, Object?>{
            'current_value': row['current_value'],
            'status': row['status'],
          };
          final ua = row['unlocked_at'];
          if (ua != null) patch['unlocked_at'] = ua;
          await txn.update(
            'achievements',
            patch,
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.insert('achievements', row);
        }
      }
    });
  }

  /// 重置全部进度（用于测试或用户主动清空）
  Future<void> resetAll() async {
    final db = await _dbFuture;
    await db.update('achievements', {
      'current_value': 0,
      'status': 0,
      'unlocked_at': null,
    });
  }
}

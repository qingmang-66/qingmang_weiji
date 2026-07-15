import 'package:sqflite/sqflite.dart';
import '../models/session_mastery_record.dart';
import 'database_service.dart';

/// 会话掌握记录数据库操作
class SessionMasteryRepository {
  Future<Database> get _db async => DatabaseService.database;

  /// 保存会话记录（同一天同一单词累加计数，分数取最高）
  Future<void> saveSessionRecord(SessionMasteryRecord record) async {
    final db = await _db;

    // 检查是否已有当天该单词的记录
    final existing = await db.query(
      'session_mastery_records',
      where: 'word_id = ? AND date = ?',
      whereArgs: [record.wordId, record.date],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // 已有记录，累加计数，分数取最高
      final existingRecord = SessionMasteryRecord.fromMap(existing.first);
      final updated = SessionMasteryRecord(
        id: existingRecord.id,
        wordId: record.wordId,
        date: record.date,
        // 取较高分数（保留最佳表现）
        sessionScore: record.sessionScore > existingRecord.sessionScore
            ? record.sessionScore
            : existingRecord.sessionScore,
        // 累加计数
        attemptCount: existingRecord.attemptCount + record.attemptCount,
        wrongCount: existingRecord.wrongCount + record.wrongCount,
        revealCount: existingRecord.revealCount + record.revealCount,
        retryCount: existingRecord.retryCount + record.retryCount,
        // 取较大连续正确数
        correctStreak: record.correctStreak > existingRecord.correctStreak
            ? record.correctStreak
            : existingRecord.correctStreak,
        // 取最佳模式权重
        bestModeWeight: record.bestModeWeight > existingRecord.bestModeWeight
            ? record.bestModeWeight
            : existingRecord.bestModeWeight,
        // 逻辑或验证标志（只要有一天是高权重验证就算）
        hasHighWeightVerification:
            record.hasHighWeightVerification ||
            existingRecord.hasHighWeightVerification,
        // 逻辑与验证标志（只有当天所有记录都是单一模式验证才算）
        hasOnlyRecallVerification:
            record.hasOnlyRecallVerification &&
            existingRecord.hasOnlyRecallVerification,
        hasOnlyQuizVerification:
            record.hasOnlyQuizVerification &&
            existingRecord.hasOnlyQuizVerification,
        createdAt: existingRecord.createdAt,
      );

      await db.update(
        'session_mastery_records',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
    } else {
      // 无记录，插入新记录（使用ConflictAlgorithm防止并发问题）
      await db.insert(
        'session_mastery_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// 获取指定日期的会话记录
  Future<List<SessionMasteryRecord>> getRecordsForDate(String date) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'session_mastery_records',
      where: 'date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) {
      return SessionMasteryRecord.fromMap(maps[i]);
    });
  }

  /// 获取指定单词的最近N天会话记录
  Future<List<SessionMasteryRecord>> getRecentRecordsForWord(
    int wordId, {
    int days = 7,
  }) async {
    final db = await _db;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final cutoffDateStr = _formatDate(cutoffDate);

    final List<Map<String, dynamic>> maps = await db.query(
      'session_mastery_records',
      where: 'word_id = ? AND date >= ?',
      whereArgs: [wordId, cutoffDateStr],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return SessionMasteryRecord.fromMap(maps[i]);
    });
  }

  /// 获取所有单词的最近N天会话记录
  Future<Map<int, List<SessionMasteryRecord>>> getRecentRecordsForAllWords({
    int days = 7,
  }) async {
    final db = await _db;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final cutoffDateStr = _formatDate(cutoffDate);

    final List<Map<String, dynamic>> maps = await db.query(
      'session_mastery_records',
      where: 'date >= ?',
      whereArgs: [cutoffDateStr],
      orderBy: 'word_id, date DESC',
    );

    // 按wordId分组
    final Map<int, List<SessionMasteryRecord>> result = {};
    for (final map in maps) {
      final record = SessionMasteryRecord.fromMap(map);
      result.putIfAbsent(record.wordId, () => []);
      result[record.wordId]!.add(record);
    }
    return result;
  }

  /// 删除指定日期之前的所有记录（清理旧数据）
  Future<int> deleteRecordsBeforeDate(String date) async {
    final db = await _db;
    return await db.delete(
      'session_mastery_records',
      where: 'date < ?',
      whereArgs: [date],
    );
  }

  /// 删除指定单词的所有会话记录
  Future<int> deleteRecordsForWord(int wordId) async {
    final db = await _db;
    return await db.delete(
      'session_mastery_records',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 格式化日期为YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

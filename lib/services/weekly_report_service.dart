import '../models/weekly_report.dart';
import 'database_service.dart';

/// 每周学习报告服务
///
/// 基于现有 review_records、wrong_words、daily_task_snapshots 生成轻量周报。
class WeeklyReportService {
  const WeeklyReportService();

  Future<WeeklyReport> buildCurrentWeekReport() async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return _buildReport(start: start, end: end);
  }

  Future<WeeklyReport> buildCurrentMonthReport() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return _buildReport(start: start, end: end);
  }

  Future<WeeklyReport> _buildReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await DatabaseService.database;

    final newResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT word_id) as c FROM review_records
      WHERE last_review >= ? AND last_review < ? AND repetitions = 1 AND quality > 0
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final reviewResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT word_id) as c FROM review_records
      WHERE last_review >= ? AND last_review < ? AND repetitions > 1 AND quality > 0
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final daysResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT date(last_review)) as c FROM review_records
      WHERE last_review >= ? AND last_review < ? AND quality > 0
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final avgResult = await db.rawQuery(
      '''
      SELECT AVG(quality) as avg_quality FROM review_records
      WHERE last_review >= ? AND last_review < ? AND quality > 0
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final planResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as c FROM daily_task_snapshots
      WHERE date >= ? AND date < ? AND completed_at IS NOT NULL
      ''',
      [_formatDate(start), _formatDate(end)],
    );
    final wrongRows = await db.rawQuery('''
      SELECT w.id as word_id, w.word, w.definition, ww.wrong_count, ww.last_wrong_time
      FROM wrong_words ww
      INNER JOIN words w ON w.id = ww.word_id
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
      LIMIT 10
    ''');

    return WeeklyReport(
      newWords: (newResult.first['c'] as int?) ?? 0,
      reviewWords: (reviewResult.first['c'] as int?) ?? 0,
      studyDays: (daysResult.first['c'] as int?) ?? 0,
      averageQuality: (avgResult.first['avg_quality'] as num?)?.toDouble() ?? 0,
      planCompletedDays: (planResult.first['c'] as int?) ?? 0,
      frequentWrongWords: wrongRows.map((row) {
        final lastWrong = row['last_wrong_time'] as String?;
        return FrequentWrongWord(
          wordId: row['word_id'] as int,
          word: row['word'] as String,
          definition: (row['definition'] as String?) ?? '',
          wrongCount: (row['wrong_count'] as int?) ?? 0,
          lastWrongTime: lastWrong == null
              ? null
              : DateTime.tryParse(lastWrong),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

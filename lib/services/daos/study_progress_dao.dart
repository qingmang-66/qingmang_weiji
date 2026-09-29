import 'package:flutter/foundation.dart';
import 'dao_handle.dart';
import 'package:sqflite/sqflite.dart';

/// 学习进度数据访问对象
class StudyProgressDao {
  final Future<Database> Function() _dbFuture;

  StudyProgressDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
    String source = 'normal',
    String progressKey = 'normal:global',
    String title = '继续学习',
  }) async {
    final db = await _dbFuture();
    final now = DateTime.now().toIso8601String();
    final wordIdsStr = wordIds.join(',');

    //delete+insert 必须原子，否则并发保存会交错留下幽灵行。
    //删除必须限定同一 progress_key：study_progress 支持多来源并存
    //（普通学习 / 错词专项 / 收藏专项 / 搜索结果各一条），无 where 的全表
    //删除会把其它来源的"继续学习"进度一起抹掉。
    await db.transaction((txn) async {
      await txn.delete(
        'study_progress',
        where: 'progress_key = ?',
        whereArgs: [progressKey],
      );
      await txn.insert('study_progress', {
        'word_book_id': wordBookId,
        'study_mode': studyMode,
        'is_review': isReview ? 1 : 0,
        'current_index': currentIndex,
        'word_ids': wordIdsStr,
        'updated_at': now,
        'source': source,
        'progress_key': progressKey,
        'title': title,
      });
    });
  }

  Future<Map<String, dynamic>?> getStudyProgress() async {
    final db = await _dbFuture();
    final result = await db.query(
      'study_progress',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final wordIdsStr = row['word_ids'] as String? ?? '';
    //空串 split 会得到 ['']，直接 int.parse 抛异常会让"继续学习"永久读不出进度
    final wordIds = wordIdsStr
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();

    return {
      'wordBookId': row['word_book_id'] as int,
      'studyMode': row['study_mode'] as int,
      'isReview': (row['is_review'] as int) == 1,
      'currentIndex': row['current_index'] as int,
      'wordIds': wordIds,
      //同一函数其它字段都做了兜底，这里若直接 parse 会让脏数据把
      //「继续学习」永久卡死，因此同样容错
      'updatedAt': _parseDate(row['updated_at']),
      'source': row['source'] as String? ?? 'normal',
      'progressKey': row['progress_key'] as String? ?? 'normal:global',
      'title': row['title'] as String? ?? '继续学习',
    };
  }

  /// 容错解析时间戳，解析失败按当前时间处理（保证功能可用）
  static DateTime _parseDate(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    debugPrint('⚠ 学习进度 updated_at 无法解析：$value');
    return DateTime.now();
  }

  /// 清除学习进度。
  ///
  /// [progressKey] 为空表示**清空全部来源**（仅"重置应用"这类场景可用）；
  /// 业务上"某一轮学习结束/放弃"必须只清自己那条：study_progress 是按
  /// progress_key 多来源并存的表（普通学习 / 错词专项 / 收藏专项各一条），
  /// 无 where 的全表删除会把其它词库/其它来源的"继续学习"一起抹掉。
  Future<void> clearStudyProgress({String? progressKey}) async {
    final db = await _dbFuture();
    if (progressKey == null) {
      await db.delete('study_progress');
      return;
    }
    await db.delete(
      'study_progress',
      where: 'progress_key = ?',
      whereArgs: [progressKey],
    );
  }

  Future<bool> hasStudyProgress() async {
    final db = await _dbFuture();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM study_progress',
    );
    return (result.first['count'] as int? ?? 0) > 0;
  }
}

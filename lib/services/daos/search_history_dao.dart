import 'package:sqflite/sqflite.dart';
import '../../models/search_history_item.dart';

/// 搜索历史 DAO
class SearchHistoryDao {
  final Future<Database> _dbFuture;
  static const int _maxHistory = 30;

  SearchHistoryDao(this._dbFuture);

  /// 记录一次搜索（同名旧记录会被先删除以实现去重并置顶）
  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final db = await _dbFuture;
    await db.delete('search_history', where: 'query = ?', whereArgs: [trimmed]);
    await db.insert('search_history', {
      'query': trimmed,
      'created_at': DateTime.now().toIso8601String(),
    });
    // 裁剪到最大数量
    final all = await db.query(
      'search_history',
      orderBy: 'created_at DESC',
      columns: ['id'],
    );
    if (all.length > _maxHistory) {
      final overflowIds = all
          .skip(_maxHistory)
          .map((e) => e['id'] as int)
          .toList();
      final placeholders = List.filled(overflowIds.length, '?').join(',');
      await db.delete(
        'search_history',
        where: 'id IN ($placeholders)',
        whereArgs: overflowIds,
      );
    }
  }

  /// 获取最近的搜索历史
  Future<List<SearchHistoryItem>> recent({int limit = 10}) async {
    final db = await _dbFuture;
    final result = await db.query(
      'search_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return result.map((row) => SearchHistoryItem.fromMap(row)).toList();
  }

  /// 清空历史
  Future<void> clear() async {
    final db = await _dbFuture;
    await db.delete('search_history');
  }

  /// 删除一条历史
  Future<void> deleteOne(String query) async {
    final db = await _dbFuture;
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
  }
}

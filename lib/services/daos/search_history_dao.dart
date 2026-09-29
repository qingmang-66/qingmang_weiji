import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';
import '../../models/search_history_item.dart';

/// 搜索历史 DAO
class SearchHistoryDao {
  final Future<Database> Function() _dbFuture;
  static const int _maxHistory = 30;

  SearchHistoryDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  /// 记录一次搜索（同名旧记录会被先删除以实现去重并置顶）
  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final db = await _dbFuture();
    //delete + insert + 裁剪必须是原子的，否则并发记录会交错留下重复/超量行
    await db.transaction((txn) async {
      await txn.delete(
        'search_history',
        where: 'query = ?',
        whereArgs: [trimmed],
      );
      await txn.insert('search_history', {
        'query': trimmed,
        'created_at': DateTime.now().toIso8601String(),
      });
      // 裁剪到最大数量：用子查询在库内完成，不把全部 id 拉进 Dart 再拼
      // IN 占位符 —— 导入过 >999 行历史的备份后，一次 DELETE 会因
      // "too many SQL variables" 让整个事务回滚（连新搜索都写不进去）
      await txn.rawDelete(
        '''
        DELETE FROM search_history
        WHERE id NOT IN (
          SELECT id FROM search_history
          ORDER BY created_at DESC, id DESC
          LIMIT $_maxHistory
        )
        ''',
      );
    });
  }

  /// 获取最近的搜索历史
  Future<List<SearchHistoryItem>> recent({int limit = 10}) async {
    final db = await _dbFuture();
    final result = await db.query(
      'search_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return result.map((row) => SearchHistoryItem.fromMap(row)).toList();
  }

  /// 清空历史
  Future<void> clear() async {
    final db = await _dbFuture();
    await db.delete('search_history');
  }

  /// 删除一条历史
  Future<void> deleteOne(String query) async {
    final db = await _dbFuture();
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
  }
}

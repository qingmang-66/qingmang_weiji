import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// 词库数据访问对象
class WordBookDao {
  final Future<Database> _dbFuture;

  WordBookDao(this._dbFuture);

  Future<int> insertWordBook(WordBook book) async {
    final db = await _dbFuture;
    return await db.insert('word_books', book.toMap());
  }

  Future<List<WordBook>> getAllWordBooks() async {
    final db = await _dbFuture;
    final maps = await db.query('word_books', orderBy: 'sort_order ASC, id ASC');
    return maps.map((m) => WordBook.fromMap(m)).toList();
  }

  /// 更新词库排序顺序
  Future<void> updateSortOrder(int bookId, int sortOrder) async {
    final db = await _dbFuture;
    await db.update(
      'word_books',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// 批量更新排序顺序
  Future<void> updateSortOrders(Map<int, int> sortOrderMap) async {
    if (sortOrderMap.isEmpty) return;
    final db = await _dbFuture;
    await db.transaction((txn) async {
      for (final entry in sortOrderMap.entries) {
        await txn.update(
          'word_books',
          {'sort_order': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });
  }

  Future<WordBook?> getWordBook(int id) async {
    final db = await _dbFuture;
    final maps = await db.query('word_books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WordBook.fromMap(maps.first);
  }

  Future<void> updateWordBookTotalWords(int bookId) async {
    final db = await _dbFuture;
    final count = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    final total = (count.first['c'] as int?) ?? 0;
    await db.update(
      'word_books',
      {'total_words': total},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteWordBook(int id) async {
    final db = await _dbFuture;
    await db.transaction((txn) async {
      await txn.rawDelete('''
        DELETE FROM review_records WHERE word_id IN (
          SELECT id FROM words WHERE word_book_id = ?
        )
      ''', [id]);
      await txn.delete('words', where: 'word_book_id = ?', whereArgs: [id]);
      await txn.delete('word_books', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteWordBooksBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbFuture;
    await db.transaction((txn) async {
      final placeholders = List.filled(ids.length, '?').join(',');
      await txn.rawDelete('''
        DELETE FROM review_records WHERE word_id IN (
          SELECT id FROM words WHERE word_book_id IN ($placeholders)
        )
      ''', ids);
      await txn.rawDelete('DELETE FROM words WHERE word_book_id IN ($placeholders)', ids);
      await txn.rawDelete('DELETE FROM word_books WHERE id IN ($placeholders)', ids);
    });
  }

  Future<bool> hasWordsInBook(int bookId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    return ((result.first['c'] as int?) ?? 0) > 0;
  }
}

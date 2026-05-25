import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// 单词数据访问对象
class WordDao {
  final Future<Database> _dbFuture;

  WordDao(this._dbFuture);

  Future<int> insertWord(Word word) async {
    final db = await _dbFuture;
    return await db.insert('words', word.toMap());
  }

  Future<void> insertWordsBatch(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) async {
    if (words.isEmpty) return;
    final db = await _dbFuture;
    await db.transaction((txn) async {
      for (var i = 0; i < words.length; i++) {
        await txn.insert('words', words[i].toMap());
        if (onProgress != null && i % 10 == 0) {
          onProgress(i + 1, words.length);
        }
      }
    });
    if (onProgress != null) {
      onProgress(words.length, words.length);
    }
  }

  /// 高性能批量插入：使用原始 SQL 批处理
  /// 比逐条 INSERT 快 5-10 倍，特别适合万级词库
  Future<void> insertWordsBatchFast(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) async {
    if (words.isEmpty) return;
    final db = await _dbFuture;

    const batchSize = 500;

    for (var i = 0; i < words.length; i += batchSize) {
      final batch = words.skip(i).take(batchSize).toList();

      final valuesList = batch
          .map((_) {
            return '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
          })
          .join(',');

      final sql =
          '''
        INSERT INTO words (word, phonetic, definition, example, example_translation, 
                          word_book_id, root, suffix, synonym, antonym, derivative)
        VALUES $valuesList
      ''';

      final args = <Object?>[];
      for (final word in batch) {
        args.addAll([
          word.word,
          word.phonetic,
          word.definition,
          word.example,
          word.exampleTranslation,
          word.wordBookId,
          word.root,
          word.suffix,
          word.synonym,
          word.antonym,
          word.derivative,
        ]);
      }

      await db.execute(sql, args);

      if (onProgress != null) {
        onProgress(i + batch.length, words.length);
      }
    }

    if (onProgress != null) {
      onProgress(words.length, words.length);
    }
  }

  Future<List<Word>> getWordsByBook(
    int bookId, {
    int? limit,
    int? offset,
  }) async {
    final db = await _dbFuture;
    final maps = await db.query(
      'words',
      where: 'word_book_id = ?',
      whereArgs: [bookId],
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<List<Word>> getDueWords(
    int bookId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final maps = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      INNER JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.next_review <= ?
      ORDER BY r.next_review ASC
      LIMIT ? OFFSET ?
    ''',
      [bookId, now, limit, offset],
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<List<Word>> getNewWords(
    int bookId,
    int limit, {
    int offset = 0,
  }) async {
    final db = await _dbFuture;
    final maps = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.id IS NULL
      LIMIT ? OFFSET ?
    ''',
      [bookId, limit, offset],
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<int> getDueWordCount(int bookId) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM words w
      INNER JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.next_review <= ?
    ''',
      [bookId, now],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTodayNewWordCount(int bookId) async {
    final db = await _dbFuture;
    final today = DateTime.now();
    final todayStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM review_records r
      INNER JOIN words w ON r.word_id = w.id
      WHERE w.word_book_id = ? AND r.last_review >= ?
    ''',
      [bookId, todayStart],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getUnlearnedWordCount(int bookId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.id IS NULL
    ''',
      [bookId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getWordCountInBook(int bookId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<List<Word>> searchWords(
    String query, {
    int? bookId,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _dbFuture;
    final q = '%$query%';
    String sql = '''
      SELECT * FROM words
      WHERE (word LIKE ? OR definition LIKE ? OR phonetic LIKE ?)
    ''';
    List<Object> args = [q, q, q];
    if (bookId != null) {
      sql += ' AND word_book_id = ?';
      args.add(bookId);
    }
    sql += ' LIMIT ? OFFSET ?';
    args.add(limit);
    args.add(offset);
    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<List<Word>> searchAllWords(String query, {int limit = 100}) {
    return searchWords(query, limit: limit);
  }

  Future<List<Word>> getWordsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await _dbFuture;
    final placeholders = ids.map((_) => '?').join(',');
    final maps = await db.rawQuery(
      'SELECT * FROM words WHERE id IN ($placeholders) ORDER BY id',
      ids,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<List<Word>> getAllWords() async {
    final db = await _dbFuture;
    final maps = await db.query('words');
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<void> deleteWordsBatch(List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture;
    await db.transaction((txn) async {
      final placeholders = List.filled(wordIds.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM review_records WHERE word_id IN ($placeholders)',
        wordIds,
      );
      await txn.rawDelete(
        'DELETE FROM words WHERE id IN ($placeholders)',
        wordIds,
      );
    });
  }

  Future<void> updateWordDefinition({
    required int wordId,
    String? phonetic,
    String? definition,
    String? example,
  }) async {
    final db = await _dbFuture;
    final updates = <String, dynamic>{};
    if (phonetic != null) updates['phonetic'] = phonetic;
    if (definition != null) updates['definition'] = definition;
    if (example != null) updates['example'] = example;

    if (updates.isEmpty) return;

    await db.update('words', updates, where: 'id = ?', whereArgs: [wordId]);
    debugPrint('📝 更新单词 $wordId 的释义：$updates');
  }
}

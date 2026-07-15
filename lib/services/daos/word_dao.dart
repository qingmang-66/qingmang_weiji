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

  /// 批量插入统一走 Fast 路径
  Future<void> insertWordsBatch(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) {
    return insertWordsBatchFast(words, onProgress: onProgress);
  }

  /// 高性能批量插入：使用原始 SQL 批处理
  /// 比逐条 INSERT 快 5-10 倍，特别适合万级词库
  Future<void> insertWordsBatchFast(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) async {
    if (words.isEmpty) return;
    final db = await _dbFuture;
    // Web/WASM 上超大 multi-value 语句更易失败，批次缩小
    final batchSize = kIsWeb ? 100 : 500;

    await db.transaction((txn) async {
      for (var i = 0; i < words.length; i += batchSize) {
        final batch = words.skip(i).take(batchSize).toList();
        if (kIsWeb) {
          // Web 优先用 sqflite batch，兼容性更好
          final b = txn.batch();
          for (final word in batch) {
            b.insert('words', {
              'word': word.word,
              'phonetic': word.phonetic,
              'definition': word.definition,
              'example': word.example,
              'example_translation': word.exampleTranslation,
              'word_book_id': word.wordBookId,
              'root': word.root,
              'suffix': word.suffix,
              'synonym': word.synonym,
              'antonym': word.antonym,
              'derivative': word.derivative,
            });
          }
          await b.commit(noResult: true);
        } else {
          final valuesList = List.filled(
            batch.length,
            '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          ).join(',');
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
          await txn.execute('''
            INSERT INTO words (word, phonetic, definition, example, example_translation,
              word_book_id, root, suffix, synonym, antonym, derivative)
            VALUES $valuesList
          ''', args);
        }
        onProgress?.call(i + batch.length, words.length);
      }
    });

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
    final tomorrowStart = DateTime(
      today.year,
      today.month,
      today.day + 1,
    ).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM review_records r
      INNER JOIN words w ON r.word_id = w.id
      WHERE w.word_book_id = ?
        AND r.last_review >= ?
        AND r.last_review < ?
        AND r.repetitions = 1
    ''',
      [bookId, todayStart, tomorrowStart],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTodayReviewedWordCount(int bookId) async {
    final db = await _dbFuture;
    final today = DateTime.now();
    final todayStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final tomorrowStart = DateTime(
      today.year,
      today.month,
      today.day + 1,
    ).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM review_records r
      INNER JOIN words w ON r.word_id = w.id
      WHERE w.word_book_id = ?
        AND r.last_review >= ?
        AND r.last_review < ?
        AND r.repetitions > 1
    ''',
      [bookId, todayStart, tomorrowStart],
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

  ///单次SQL聚合词库进度，避免3次独立COUNT
  Future<WordBookProgress> getWordBookProgress(int bookId) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN r.id IS NULL THEN 1 ELSE 0 END) AS unlearned,
        SUM(CASE WHEN r.id IS NOT NULL AND r.next_review <= ? THEN 1 ELSE 0 END) AS due
      FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ?
      ''',
      [now, bookId],
    );
    final row = result.first;
    return WordBookProgress(
      bookId: bookId,
      totalWords: _asInt(row['total']),
      unlearnedWords: _asInt(row['unlearned']),
      dueWords: _asInt(row['due']),
    );
  }

  ///批量聚合多词库进度，避免 N*3 查询
  Future<Map<int, WordBookProgress>> getWordBookProgressMap(
    Iterable<int> bookIds,
  ) async {
    final ids = bookIds.toSet().toList();
    if (ids.isEmpty) return {};
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT
        w.word_book_id AS book_id,
        COUNT(*) AS total,
        SUM(CASE WHEN r.id IS NULL THEN 1 ELSE 0 END) AS unlearned,
        SUM(CASE WHEN r.id IS NOT NULL AND r.next_review <= ? THEN 1 ELSE 0 END) AS due
      FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id IN ($placeholders)
      GROUP BY w.word_book_id
      ''',
      [now, ...ids],
    );
    final map = <int, WordBookProgress>{
      for (final id in ids)
        id: WordBookProgress(
          bookId: id,
          totalWords: 0,
          unlearnedWords: 0,
          dueWords: 0,
        ),
    };
    for (final row in rows) {
      final bookId = _asInt(row['book_id']);
      map[bookId] = WordBookProgress(
        bookId: bookId,
        totalWords: _asInt(row['total']),
        unlearnedWords: _asInt(row['unlearned']),
        dueWords: _asInt(row['due']),
      );
    }
    return map;
  }

  int _asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// 搜索单词
  ///
  /// [inWordFieldOnly] 为 true 时仅匹配 word 字段，排序简化为 3 档。
  /// 默认 false（多字段匹配，6 档排序）以保持向后兼容。
  Future<List<Word>> searchWords(
    String query, {
    int? bookId,
    int limit = 50,
    int offset = 0,
    bool inWordFieldOnly = false,
  }) async {
    final db = await _dbFuture;
    final trimmed = query.trim();
    final q = '%$trimmed%';
    final prefix = '$trimmed%';
    String sql;
    List<Object> args;
    if (inWordFieldOnly) {
      // 仅 word 字段：SQL 简化、参数减少、命中更精准
      sql = '''
        SELECT * FROM words
        WHERE lower(word) LIKE lower(?)
      ''';
      args = [q];
    } else {
      sql = '''
        SELECT * FROM words
        WHERE (
          word LIKE ?
          OR definition LIKE ?
          OR phonetic LIKE ?
          OR example LIKE ?
          OR example_translation LIKE ?
        )
      ''';
      args = [q, q, q, q, q];
    }
    if (bookId != null) {
      sql += ' AND word_book_id = ?';
      args.add(bookId);
    }
    if (inWordFieldOnly) {
      // 仅 3 档排序：完全匹配 > 前缀匹配 > 包含匹配
      sql += '''
        ORDER BY
          CASE
            WHEN lower(word) = lower(?) THEN 0
            WHEN lower(word) LIKE lower(?) THEN 1
            ELSE 2
          END,
          LENGTH(word) ASC,
          word ASC
        LIMIT ? OFFSET ?
      ''';
      args.addAll([trimmed, prefix, limit, offset]);
    } else {
      sql += '''
        ORDER BY
          CASE
            WHEN lower(word) = lower(?) THEN 0
            WHEN lower(word) LIKE lower(?) THEN 1
            WHEN lower(word) LIKE lower(?) THEN 2
            WHEN definition LIKE ? THEN 3
            WHEN example LIKE ? OR example_translation LIKE ? THEN 4
            ELSE 5
          END,
          LENGTH(word) ASC,
          word ASC
        LIMIT ? OFFSET ?
      ''';
      args.addAll([trimmed, prefix, q, q, q, q, limit, offset]);
    }
    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  // 阶段三：searchAllWords 同样支持 inWordFieldOnly
  Future<List<Word>> searchAllWords(
    String query, {
    int limit = 100,
    bool inWordFieldOnly = false,
  }) {
    return searchWords(query, limit: limit, inWordFieldOnly: inWordFieldOnly);
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
        'DELETE FROM custom_word_set_items WHERE word_id IN ($placeholders)',
        wordIds,
      );
      await txn.rawDelete(
        'DELETE FROM favorites WHERE word_id IN ($placeholders)',
        wordIds,
      );
      await txn.rawDelete(
        'DELETE FROM wrong_words WHERE word_id IN ($placeholders)',
        wordIds,
      );
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

import 'package:flutter/foundation.dart';
import 'dao_handle.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// 单词数据访问对象
class WordDao {
  final Future<Database> Function() _dbFuture;

  WordDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  Future<int> insertWord(Word word) async {
    final db = await _dbFuture();
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
    final db = await _dbFuture();
    // 每条词 11 个绑定变量，老版 Android SQLite（< 3.32）上限 999，
    // 按 90 行/批 = 990 个变量控制，避免 too many SQL variables
    // Web/WASM 上超大 multi-value 语句更易失败，批次进一步缩小
    final batchSize = kIsWeb ? 80 : 90;

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
    final db = await _dbFuture();
    //必须显式排序：SQLite 不保证无 ORDER BY 的返回顺序，
    //翻页叠加 offset 时结果可能重复或漏词
    final maps = await db.query(
      'words',
      where: 'word_book_id = ?',
      whereArgs: [bookId],
      orderBy: 'id ASC',
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
    final db = await _dbFuture();
    final now = DateTime.now().toIso8601String();
    final maps = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      INNER JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.next_review <= ?
      ORDER BY r.next_review ASC, w.id ASC
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
    final db = await _dbFuture();
    final maps = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.id IS NULL
      ORDER BY w.id ASC
      LIMIT ? OFFSET ?
    ''',
      [bookId, limit, offset],
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<int> getDueWordCount(int bookId) async {
    final db = await _dbFuture();
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
    final db = await _dbFuture();
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
        AND r.quality > 0
        AND (
          (r.first_learned_at >= ? AND r.first_learned_at < ?)
          OR (r.first_learned_at IS NULL AND r.repetitions = 1)
        )
    ''',
      [bookId, todayStart, tomorrowStart, todayStart, tomorrowStart],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTodayReviewedWordCount(int bookId) async {
    final db = await _dbFuture();
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
        AND r.quality > 0
        AND (
          (r.first_learned_at IS NOT NULL AND r.first_learned_at < ?)
          OR (r.first_learned_at IS NULL AND r.repetitions > 1)
        )
    ''',
      [bookId, todayStart, tomorrowStart, todayStart],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getUnlearnedWordCount(int bookId) async {
    final db = await _dbFuture();
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
    final db = await _dbFuture();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  ///单次SQL聚合词库进度，避免3次独立COUNT
  Future<WordBookProgress> getWordBookProgress(int bookId) async {
    final db = await _dbFuture();
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

  ///一次聚合取回学习可用性所需的 5 个计数，替代 5 次串行 COUNT
  Future<({int total, int unlearned, int due, int todayNew, int todayReviewed})>
  getStudyAvailabilityCounts(int bookId) async {
    final db = await _dbFuture();
    final today = DateTime.now();
    final now = today.toIso8601String();
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
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN r.id IS NULL THEN 1 ELSE 0 END) AS unlearned,
        SUM(CASE WHEN r.id IS NOT NULL AND r.next_review <= ? THEN 1 ELSE 0 END) AS due,
        SUM(CASE WHEN r.last_review >= ? AND r.last_review < ?
              AND r.quality > 0
              AND ((r.first_learned_at >= ? AND r.first_learned_at < ?)
                   OR (r.first_learned_at IS NULL AND r.repetitions = 1))
            THEN 1 ELSE 0 END) AS today_new,
        SUM(CASE WHEN r.last_review >= ? AND r.last_review < ?
              AND r.quality > 0
              AND ((r.first_learned_at IS NOT NULL AND r.first_learned_at < ?)
                   OR (r.first_learned_at IS NULL AND r.repetitions > 1))
            THEN 1 ELSE 0 END) AS today_reviewed
      FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ?
      ''',
      [
        now,
        todayStart,
        tomorrowStart,
        todayStart,
        tomorrowStart,
        todayStart,
        tomorrowStart,
        todayStart,
        bookId,
      ],
    );
    final row = result.first;
    return (
      total: _asInt(row['total']),
      unlearned: _asInt(row['unlearned']),
      due: _asInt(row['due']),
      todayNew: _asInt(row['today_new']),
      todayReviewed: _asInt(row['today_reviewed']),
    );
  }

  ///批量聚合多词库进度，避免 N*3 查询
  Future<Map<int, WordBookProgress>> getWordBookProgressMap(
    Iterable<int> bookIds,
  ) async {
    final ids = bookIds.toSet().toList();
    if (ids.isEmpty) return {};
    final db = await _dbFuture();
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

  /// 最近学过的单词（按 last_review 倒序取第一个）
  Future<Word?> getLastLearnedWord(int bookId) async {
    final db = await _dbFuture();
    final maps = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      INNER JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ?
      ORDER BY r.last_review DESC
      LIMIT 1
    ''',
      [bookId],
    );
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
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
    final db = await _dbFuture();
    // 转义 LIKE 通配符，避免用户输入的 % 和 _ 产生意外匹配；等值比较仍用原文
    final raw = query.trim();
    // 入口护栏：空查询直接返回（LIKE '%%' 会全表扫出整库），超长查询截断
    // （前导通配无法走索引，扫描代价与查询长度弱相关，但让输入保持有界）
    if (raw.isEmpty) return const <Word>[];
    final bounded = raw.length > 64 ? raw.substring(0, 64) : raw;
    final trimmed = _escapeLike(bounded);
    final q = '%$trimmed%';
    final prefix = '$trimmed%';
    String sql;
    List<Object> args;
    if (inWordFieldOnly) {
      // 仅 word 字段：SQL 简化、参数减少、命中更精准
      sql = '''
        SELECT * FROM words
        WHERE lower(word) LIKE lower(?) ESCAPE '\\'
      ''';
      args = [q];
    } else {
      sql = '''
        SELECT * FROM words
        WHERE (
          word LIKE ? ESCAPE '\\'
          OR definition LIKE ? ESCAPE '\\'
          OR phonetic LIKE ? ESCAPE '\\'
          OR example LIKE ? ESCAPE '\\'
          OR example_translation LIKE ? ESCAPE '\\'
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
            WHEN lower(word) LIKE lower(?) ESCAPE '\\' THEN 1
            ELSE 2
          END,
          LENGTH(word) ASC,
          word ASC
        LIMIT ? OFFSET ?
      ''';
      args.addAll([raw, prefix, limit, offset]);
    } else {
      sql += '''
        ORDER BY
          CASE
            WHEN lower(word) = lower(?) THEN 0
            WHEN lower(word) LIKE lower(?) ESCAPE '\\' THEN 1
            WHEN lower(word) LIKE lower(?) ESCAPE '\\' THEN 2
            WHEN definition LIKE ? ESCAPE '\\' THEN 3
            WHEN example LIKE ? ESCAPE '\\' OR example_translation LIKE ? ESCAPE '\\' THEN 4
            ELSE 5
          END,
          LENGTH(word) ASC,
          word ASC
        LIMIT ? OFFSET ?
      ''';
      args.addAll([raw, prefix, q, q, q, q, limit, offset]);
    }
    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  /// 转义 LIKE 通配符（% 和 _），配合 SQL 的 ESCAPE '\' 使用
  static String _escapeLike(String input) => input
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  // 阶段三：searchAllWords 同样支持 inWordFieldOnly
  Future<List<Word>> searchAllWords(
    String query, {
    int limit = 100,
    bool inWordFieldOnly = false,
  }) {
    return searchWords(query, limit: limit, inWordFieldOnly: inWordFieldOnly);
  }

  /// IN 子句分块大小：老版本 SQLite 的变量上限为 999，
  /// 超限会直接抛错（与 review_dao 的 400 保持一致）
  static const int _inChunkSize = 400;

  Future<List<Word>> getWordsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await _dbFuture();
    if (ids.length <= _inChunkSize) {
      final placeholders = ids.map((_) => '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM words WHERE id IN ($placeholders) ORDER BY id',
        ids,
      );
      return maps.map((m) => Word.fromMap(m)).toList();
    }
    final words = <Word>[];
    for (var i = 0; i < ids.length; i += _inChunkSize) {
      final end = i + _inChunkSize < ids.length ? i + _inChunkSize : ids.length;
      final chunk = ids.sublist(i, end);
      final placeholders = chunk.map((_) => '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM words WHERE id IN ($placeholders) ORDER BY id',
        chunk,
      );
      words.addAll(maps.map((m) => Word.fromMap(m)));
    }
    //分块查询后重新排序，保证结果顺序与单次查询一致
    words.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    return words;
  }

  Future<List<Word>> getAllWords() async {
    final db = await _dbFuture();
    final maps = await db.query('words');
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  Future<void> deleteWordsBatch(List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await _dbFuture();
    await db.transaction((txn) async {
      //与 WordBookDao._deleteWordReferencesForBooks 同样先探明实际存在的表：
      //老库/测试夹具可能缺表，一条 no such table 会让整个删除事务回滚
      final existing = (await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      )).map((row) => row['name'] as String).toSet();
      // IN 子句按 _inChunkSize 分块，避免超过老版 SQLite 的 999 变量上限
      for (var i = 0; i < wordIds.length; i += _inChunkSize) {
        final end = i + _inChunkSize < wordIds.length
            ? i + _inChunkSize
            : wordIds.length;
        final chunk = wordIds.sublist(i, end);
        final placeholders = List.filled(chunk.length, '?').join(',');
        //与 WordBookDao._deleteWordReferencesForBooks 的清理清单保持一致：
        //老库没有外键级联，只删 word_id 关联表会留下孤儿行
        for (final table in [
          'wrong_words',
          'review_records',
          'wrong_words_strength',
          'session_mastery_records',
          'reader_marks',
          'word_favorites',
        ]) {
          if (!existing.contains(table)) continue;
          await txn.rawDelete(
            'DELETE FROM $table WHERE word_id IN ($placeholders)',
            chunk,
          );
        }
        await txn.rawDelete(
          'DELETE FROM words WHERE id IN ($placeholders)',
          chunk,
        );
      }
    });
  }

  Future<void> updateWordDefinition({
    required int wordId,
    String? phonetic,
    String? definition,
    String? example,
  }) async {
    final db = await _dbFuture();
    final updates = <String, dynamic>{};
    if (phonetic != null) updates['phonetic'] = phonetic;
    if (definition != null) updates['definition'] = definition;
    if (example != null) updates['example'] = example;

    if (updates.isEmpty) return;

    await db.update('words', updates, where: 'id = ?', whereArgs: [wordId]);
    debugPrint('📝 更新单词 $wordId 的释义：$updates');
  }
}

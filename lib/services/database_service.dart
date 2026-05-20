import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

/// SQLite数据库服务
/// 兼容 Windows/Linux (sqflite_common_ffi) 和移动端 (sqflite)
class DatabaseService {
  static final Future<Database> _dbFuture = _initDB();

  static Future<Database> get database => _dbFuture;

  static Future<Database> _initDB() async {
    final dbPath = await _getDatabasePath();
    final path = join(dbPath, 'qingmang_weiji.db');

    // 确保目录存在
    final dir = Directory(dirname(path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        // 词库表 - 支持版本管理
        await db.execute('''
          CREATE TABLE word_books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            is_built_in INTEGER DEFAULT 0,
            total_words INTEGER DEFAULT 0,
            version TEXT
          )
        ''');

        // 单词表 - 增强版
        await db.execute('''
          CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            phonetic TEXT,
            definition TEXT,
            example TEXT,
            example_translation TEXT,
            word_book_id INTEGER NOT NULL,
            root TEXT,
            suffix TEXT,
            synonym TEXT,
            antonym TEXT,
            derivative TEXT,
            FOREIGN KEY (word_book_id) REFERENCES word_books(id)
          )
        ''');

        // 复习记录表
        await db.execute('''
          CREATE TABLE review_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            quality INTEGER DEFAULT 0,
            interval INTEGER DEFAULT 1,
            ease_factor REAL DEFAULT 2.5,
            repetitions INTEGER DEFAULT 0,
            next_review TEXT NOT NULL,
            last_review TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id)
          )
        ''');

        // 错词本表
        await db.execute('''
          CREATE TABLE wrong_words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            wrong_count INTEGER DEFAULT 1,
            first_wrong_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_wrong_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            note TEXT,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');

        // 学习会话表
        await db.execute('''
          CREATE TABLE study_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_book_id INTEGER NOT NULL,
            study_mode TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            words_studied INTEGER DEFAULT 0,
            correct_count INTEGER DEFAULT 0,
            wrong_count INTEGER DEFAULT 0,
            is_completed INTEGER DEFAULT 0,
            FOREIGN KEY (word_book_id) REFERENCES word_books(id)
          )
        ''');

        // 成就系统表
        await db.execute('''
          CREATE TABLE achievements (
            id TEXT PRIMARY KEY,
            current_value INTEGER DEFAULT 0,
            status INTEGER DEFAULT 0,
            unlocked_at TEXT
          )
        ''');

        // 学习进度表 - 保存未完成的会话
        await db.execute('''
          CREATE TABLE study_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_book_id INTEGER NOT NULL,
            study_mode INTEGER NOT NULL,
            is_review INTEGER DEFAULT 0,
            current_index INTEGER DEFAULT 0,
            word_ids TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // 索引优化
        await db.execute('CREATE INDEX idx_words_book_id ON words(word_book_id)');
        await db.execute('CREATE INDEX idx_review_word_id ON review_records(word_id)');
        await db.execute('CREATE INDEX idx_review_next_review ON review_records(next_review)');
        await db.execute('CREATE INDEX idx_wrong_word_id ON wrong_words(word_id)');
        await db.execute('CREATE INDEX idx_wrong_last_time ON wrong_words(last_wrong_time)');
        await db.execute('CREATE INDEX idx_session_book_id ON study_sessions(word_book_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 数据库升级：为旧版本的 word_books 表添加 version 字段
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE word_books ADD COLUMN version TEXT');
            debugPrint('✓ 数据库已升级：添加 version 字段');
          } catch (e) {
            debugPrint('⚠ 数据库升级 version 字段失败：$e');
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS wrong_words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              wrong_count INTEGER DEFAULT 1,
              first_wrong_time DATETIME DEFAULT CURRENT_TIMESTAMP,
              last_wrong_time DATETIME DEFAULT CURRENT_TIMESTAMP,
              note TEXT,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_wrong_word_id ON wrong_words(word_id)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_wrong_last_time ON wrong_words(last_wrong_time)');
        }
        if (oldVersion < 4) {
          // v4: 添加 study_sessions 和 achievements 表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS study_sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_book_id INTEGER NOT NULL,
              study_mode TEXT NOT NULL,
              start_time TEXT NOT NULL,
              end_time TEXT,
              words_studied INTEGER DEFAULT 0,
              correct_count INTEGER DEFAULT 0,
              wrong_count INTEGER DEFAULT 0,
              is_completed INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS achievements (
              id TEXT PRIMARY KEY,
              current_value INTEGER DEFAULT 0,
              status INTEGER DEFAULT 0,
              unlocked_at TEXT
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_session_book_id ON study_sessions(word_book_id)');
        }
        if (oldVersion < 5) {
          // v5: 添加学习进度表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS study_progress (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_book_id INTEGER NOT NULL,
              study_mode INTEGER NOT NULL,
              is_review INTEGER DEFAULT 0,
              current_index INTEGER DEFAULT 0,
              word_ids TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  /// 获取数据库路径（兼容桌面端和移动端）
  static Future<String> _getDatabasePath() async {
    try {
      return await getDatabasesPath();
    } catch (e) {
      // Fallback: 用应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      return join(appDir.path, 'databases');
    }
  }

  // ========== 词库操作 ==========

  static Future<int> insertWordBook(WordBook book) async {
    final db = await database;
    return await db.insert('word_books', book.toMap());
  }

  static Future<List<WordBook>> getAllWordBooks() async {
    final db = await database;
    final maps = await db.query('word_books');
    return maps.map((m) => WordBook.fromMap(m)).toList();
  }

  static Future<WordBook?> getWordBook(int id) async {
    final db = await database;
    final maps = await db.query('word_books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) {
      return null;
    }
    return WordBook.fromMap(maps.first);
  }

  static Future<void> updateWordBookTotalWords(int bookId) async {
    final db = await database;
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

  static Future<void> deleteWordBook(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // 先删复习记录（FK 指向 words），再删单词，最后删词库
      await txn.rawDelete('''
        DELETE FROM review_records WHERE word_id IN (
          SELECT id FROM words WHERE word_book_id = ?
        )
      ''', [id]);
      await txn.delete('words', where: 'word_book_id = ?', whereArgs: [id]);
      await txn.delete('word_books', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// 批量删除词库
  static Future<void> deleteWordBooksBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final placeholders = List.filled(ids.length, '?').join(',');
      // 先删复习记录
      await txn.rawDelete('''
        DELETE FROM review_records WHERE word_id IN (
          SELECT id FROM words WHERE word_book_id IN ($placeholders)
        )
      ''', ids);
      // 再删单词
      await txn.rawDelete('DELETE FROM words WHERE word_book_id IN ($placeholders)', ids);
      // 最后删词库
      await txn.rawDelete('DELETE FROM word_books WHERE id IN ($placeholders)', ids);
    });
  }

  /// 批量删除单词
  static Future<void> deleteWordsBatch(List<int> wordIds) async {
    if (wordIds.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final placeholders = List.filled(wordIds.length, '?').join(',');
      // 先删复习记录
      await txn.rawDelete('DELETE FROM review_records WHERE word_id IN ($placeholders)', wordIds);
      // 再删单词
      await txn.rawDelete('DELETE FROM words WHERE id IN ($placeholders)', wordIds);
    });
  }

  // ========== 单词操作 ==========

  static Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  static Future<void> insertWordsBatch(List<Word> words, {Function(int completed, int total)? onProgress}) async {
    if (words.isEmpty) {
      return;
    }
    final db = await database;
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

  /// 高性能批量插入：使用原始 SQL 批处理（推荐用于大词库）
  /// 
  /// 使用 INSERT INTO ... VALUES (...), (...), (...) 语法
  /// 比逐条 INSERT 快 5-10 倍，特别适合万级词库
  static Future<void> insertWordsBatchFast(List<Word> words, {Function(int completed, int total)? onProgress}) async {
    if (words.isEmpty) {
      return;
    }
    final db = await database;
    
    // 分批次处理，避免 SQL 语句过长（SQLite 有 1MB 默认限制）
    const batchSize = 500;
    
    for (var i = 0; i < words.length; i += batchSize) {
      final batch = words.skip(i).take(batchSize).toList();
      
      // 构建批量 INSERT SQL
      final valuesList = batch.map((word) {
        // 使用参数化查询防止 SQL 注入
        // 11 个字段：word, phonetic, definition, example, example_translation,
        // word_book_id, root, suffix, synonym, antonym, derivative
        return '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
      }).join(',');
      
      final sql = '''
        INSERT INTO words (word, phonetic, definition, example, example_translation, 
                          word_book_id, root, suffix, synonym, antonym, derivative)
        VALUES $valuesList
      ''';
      
      // 收集所有参数
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
      
      // 更新进度
      if (onProgress != null) {
        onProgress(i + batch.length, words.length);
      }
    }
    
    if (onProgress != null) {
      onProgress(words.length, words.length);
    }
  }

  static Future<List<Word>> getWordsByBook(int bookId, {int? limit, int? offset}) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'word_book_id = ?',
      whereArgs: [bookId],
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  /// 获取待复习的单词（next_review <= 今天）
  static Future<List<Word>> getDueWords(int bookId, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.rawQuery('''
      SELECT w.* FROM words w
      INNER JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.next_review <= ?
      ORDER BY r.next_review ASC
      LIMIT ? OFFSET ?
    ''', [bookId, now, limit, offset]);
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  /// 获取新单词（没有复习记录的）
  static Future<List<Word>> getNewWords(int bookId, int limit, {int offset = 0}) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT w.* FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.id IS NULL
      LIMIT ? OFFSET ?
    ''', [bookId, limit, offset]);
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  /// 获取待复习数量
  static Future<int> getDueWordCount(int bookId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM words w
      INNER JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.next_review <= ?
    ''', [bookId, now]);
    return (result.first['count'] as int?) ?? 0;
  }

  /// 获取今日新学词数量（今日首次创建复习记录的词数）
  /// 修复：通过 last_review 时间判断今日新学，而不是 repetitions = 0
  /// 因为首次学习后 repetitions 会变成 1
  static Future<int> getTodayNewWordCount(int bookId) async {
    final db = await database;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM review_records r
      INNER JOIN words w ON r.word_id = w.id
      WHERE w.word_book_id = ? AND r.last_review >= ?
    ''', [bookId, todayStart]);
    return (result.first['count'] as int?) ?? 0;
  }

  /// 获取未学习词数量（没有任何复习记录的词）
  static Future<int> getUnlearnedWordCount(int bookId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM words w
      LEFT JOIN review_records r ON w.id = r.word_id
      WHERE w.word_book_id = ? AND r.id IS NULL
    ''', [bookId]);
    return (result.first['count'] as int?) ?? 0;
  }

  /// 获取词库中总词数
  static Future<int> getWordCountInBook(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// 搜索单词（支持中英文）
  static Future<List<Word>> searchWords(String query, {int? bookId, int limit = 50, int offset = 0}) async {
    final db = await database;
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

  /// 全局搜索（搜索所有词库）
  static Future<List<Word>> searchAllWords(String query, {int limit = 100}) {
    return searchWords(query, limit: limit);
  }

  /// 根据ID列表获取单词
  static Future<List<Word>> getWordsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    final maps = await db.rawQuery(
      'SELECT * FROM words WHERE id IN ($placeholders) ORDER BY id',
      ids,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  // ========== 复习记录操作 ==========

  static Future<int> saveReviewRecord(ReviewRecord record) async {
    final db = await database;
    if (record.id != null) {
      await db.update(
        'review_records',
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      return record.id!;
    } else {
      return await db.insert('review_records', record.toMap());
    }
  }

  static Future<ReviewRecord?> getReviewRecord(int wordId) async {
    final db = await database;
    final maps = await db.query(
      'review_records',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return ReviewRecord.fromMap(maps.first);
  }

  // ========== 统计数据 ==========

  static Future<Map<String, dynamic>> getStudyStats() async {
    final db = await database;
    final totalWords = await db.rawQuery('SELECT COUNT(*) as c FROM words');
    final learnedWords = await db.rawQuery(
      'SELECT COUNT(DISTINCT word_id) as c FROM review_records',
    );
    final dueWords = await db.rawQuery('''
      SELECT COUNT(*) as c FROM review_records WHERE next_review <= ?
    ''', [DateTime.now().toIso8601String()]);

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();

    // todayNew：今日首次学习的词（quality > 0 且 repetitions == 1，即今天第一次完成学习）
    // 更准确的判断：今天有过学习记录，且学习后 repetitions 刚好为 1（首次学完）
    final todayNewResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT word_id) as c FROM review_records
      WHERE last_review >= ? AND repetitions = 1 AND quality > 0
    ''', [todayStart]);

    // todayReview：今日复习的词（repetitions > 1 且今天有过复习记录）
    final todayReviewResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT word_id) as c FROM review_records
      WHERE last_review >= ? AND repetitions > 1 AND quality > 0
    ''', [todayStart]);

    // 连续学习天数
    final streak = await _calculateStreak(db);

    // 记忆阶段分布 — 用 SQL CASE WHEN + GROUP BY 替代 Dart 循环，大数据量时性能更好
    final stages = <String, int>{
      '新学': 0,
      '初步': 0,
      '巩固': 0,
      '熟悉': 0,
      '掌握': 0,
    };
    final stageResult = await db.rawQuery('''
      SELECT
        CASE
          WHEN repetitions = 0 THEN '新学'
          WHEN repetitions <= 1 THEN '初步'
          WHEN repetitions <= 3 THEN '巩固'
          WHEN repetitions <= 5 THEN '熟悉'
          ELSE '掌握'
        END as stage,
        COUNT(*) as cnt
      FROM review_records
      GROUP BY stage
    ''');
    for (final row in stageResult) {
      final stage = row['stage'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (stage != null && stages.containsKey(stage)) {
        stages[stage] = cnt;
      }
    }

    return {
      'totalWords': (totalWords.first['c'] as int?) ?? 0,
      'learnedWords': (learnedWords.first['c'] as int?) ?? 0,
      'dueWords': (dueWords.first['c'] as int?) ?? 0,
      'todayNew': (todayNewResult.first['c'] as int?) ?? 0,
      'todayReview': (todayReviewResult.first['c'] as int?) ?? 0,
      'streak': streak,
      'stages': stages,
    };
  }

  /// 计算连续学习天数（从今天或昨天开始向前连续追溯）
  static Future<int> _calculateStreak(Database db) async {
    final records = await db.rawQuery('''
      SELECT DISTINCT date(last_review) as study_date FROM review_records
      ORDER BY study_date DESC LIMIT 366
    ''');
    if (records.isEmpty) {
      return 0;
    }

    final dateStrings = records.map((r) => r['study_date'] as String).toSet();

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final now = DateTime.now();
    DateTime check = DateTime(now.year, now.month, now.day);

    // 若今天还没学习，从昨天开始计算
    if (!dateStrings.contains(formatDate(check))) {
      check = check.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (dateStrings.contains(formatDate(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ========== 清除数据 ==========

  /// 获取每日复习数据（最近 days 天）
  static Future<List<Map<String, dynamic>>> getDailyReviewStats({int days = 30}) async {
    final db = await database;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startDateStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();

    final result = await db.rawQuery('''
      SELECT date(last_review) as study_date, COUNT(*) as count
      FROM review_records
      WHERE last_review >= ?
      GROUP BY date(last_review)
      ORDER BY study_date ASC
    ''', [startDateStr]);

    // 填充没有数据的日期为0
    final Map<String, int> dateCountMap = {};
    for (final row in result) {
      final date = row['study_date'] as String;
      dateCountMap[date] = row['count'] as int;
    }

    final List<Map<String, dynamic>> dailyData = [];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyData.add({
        'date': date,
        'count': dateCountMap[dateStr] ?? 0,
      });
    }

    return dailyData;
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('review_records');
    await db.delete('study_sessions');
    await db.delete('achievements');
    await db.delete('words');
    await db.delete('word_books');
  }

  /// 获取总学习统计
  static Future<Map<String, dynamic>> getOverallStats(int bookId) async {
    final db = await database;
    
    // 总单词数
    final totalWords = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM words WHERE word_book_id = ?', [bookId]
    )) ?? 0;
    
    // 已学习单词数（有复习记录）
    final learnedWords = Sqflite.firstIntValue(await db.rawQuery(
      '''SELECT COUNT(DISTINCT word_id) FROM review_records 
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)''', [bookId]
    )) ?? 0;
    
    // 今日已复习
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayReview = Sqflite.firstIntValue(await db.rawQuery(
      '''SELECT COUNT(*) FROM review_records 
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)
         AND date(last_review) = ?''', [bookId, todayStr]
    )) ?? 0;
    
    // 待复习单词数
    final dueWords = Sqflite.firstIntValue(await db.rawQuery(
      '''SELECT COUNT(*) FROM review_records r
         INNER JOIN words w ON r.word_id = w.id
         WHERE w.word_book_id = ? AND datetime(r.next_review) <= datetime(?)''',
      [bookId, today.toIso8601String()]
    )) ?? 0;
    
    // 总复习次数
    final totalReviews = Sqflite.firstIntValue(await db.rawQuery(
      '''SELECT COUNT(*) FROM review_records 
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)''', [bookId]
    )) ?? 0;
    
    // 平均回忆质量
    final avgQualityResult = await db.rawQuery(
      '''SELECT AVG(quality) as avg_q FROM review_records 
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)''', [bookId]
    );
    final avgQuality = (avgQualityResult.first['avg_q'] as double?) ?? 0.0;
    
    return {
      'total_words': totalWords,
      'learned_words': learnedWords,
      'today_review': todayReview,
      'due_words': dueWords,
      'total_reviews': totalReviews,
      'avg_quality': avgQuality,
    };
  }
  
  /// 获取复习质量分布
  static Future<List<Map<String, dynamic>>> getQualityDistribution(int bookId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT quality, COUNT(*) as count FROM review_records
      WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)
      GROUP BY quality
      ORDER BY quality ASC
    ''', [bookId]);
    
    return result.map((row) => {
      'quality': row['quality'] as int,
      'count': row['count'] as int,
    }).toList();
  }
  
  /// 获取学习间隔分布（当前复习间隔）
  static Future<List<Map<String, dynamic>>> getIntervalDistribution(int bookId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT interval, COUNT(*) as count FROM review_records
      WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)
      GROUP BY interval
      ORDER BY interval ASC
    ''', [bookId]);
    
    return result.map((row) => {
      'interval': row['interval'] as int,
      'count': row['count'] as int,
    }).toList();
  }


  /// 检查词库是否已有数据（避免重复插入）
  static Future<bool> hasWordsInBook(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE word_book_id = ?',
      [bookId],
    );
    return ((result.first['c'] as int?) ?? 0) > 0;
  }

  // ========== 备份与恢复 ==========

  /// 导出全部数据为 JSON Map
  static Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    final wordBooks = await db.query('word_books');
    final words = await db.query('words');
    final reviewRecords = await db.query('review_records');
    final studySessions = await db.query('study_sessions');
    final achievements = await db.query('achievements');
    return {
      'version': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'word_books': wordBooks,
      'words': words,
      'review_records': reviewRecords,
      'study_sessions': studySessions,
      'achievements': achievements,
    };
  }

  /// 从 JSON Map 导入全部数据（先清除再写入）
  static Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      // 清除现有数据
      await txn.delete('review_records');
      await txn.delete('words');
      await txn.delete('word_books');

      // 导入词库
      for (final wb in (data['word_books'] as List?) ?? []) {
        await txn.insert('word_books', Map<String, dynamic>.from(wb as Map));
      }

      // 导入单词
      for (final w in (data['words'] as List?) ?? []) {
        await txn.insert('words', Map<String, dynamic>.from(w as Map));
      }

      // 导入复习记录
      for (final r in (data['review_records'] as List?) ?? []) {
        await txn.insert('review_records', Map<String, dynamic>.from(r as Map));
      }

      // 导入学习会话
      for (final s in (data['study_sessions'] as List?) ?? []) {
        await txn.insert('study_sessions', Map<String, dynamic>.from(s as Map));
      }

      // 导入成就
      for (final a in (data['achievements'] as List?) ?? []) {
        await txn.insert('achievements', Map<String, dynamic>.from(a as Map));
      }
    });
  }

  // 获取所有单词（用于备份）
  static Future<List<Word>> getAllWords() async {
    final db = await database;
    final maps = await db.query('words');
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  // 获取所有复习记录（用于备份）
  static Future<List<ReviewRecord>> getAllReviewRecords() async {
    final db = await database;
    final maps = await db.query('review_records');
    return maps.map((m) => ReviewRecord.fromMap(m)).toList();
  }

  /// 更新单词的释义、音标、例句（用于 API 补充）
  static Future<void> updateWordDefinition({
    required int wordId,
    String? phonetic,
    String? definition,
    String? example,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (phonetic != null) updates['phonetic'] = phonetic;
    if (definition != null) updates['definition'] = definition;
    if (example != null) updates['example'] = example;

    if (updates.isEmpty) {
      return;
    }

    await db.update(
      'words',
      updates,
      where: 'id = ?',
      whereArgs: [wordId],
    );
    debugPrint('📝 更新单词 $wordId 的释义：$updates');
  }

  // ========== 学习进度操作 ==========

  /// 保存学习进度
  static Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final wordIdsStr = wordIds.join(',');

    // 先清除旧进度
    await db.delete('study_progress');

    // 插入新进度
    await db.insert('study_progress', {
      'word_book_id': wordBookId,
      'study_mode': studyMode,
      'is_review': isReview ? 1 : 0,
      'current_index': currentIndex,
      'word_ids': wordIdsStr,
      'updated_at': now,
    });
  }

  /// 获取学习进度
  static Future<Map<String, dynamic>?> getStudyProgress() async {
    final db = await database;
    final result = await db.query(
      'study_progress',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final wordIdsStr = row['word_ids'] as String;
    final wordIds = wordIdsStr.split(',').map((s) => int.parse(s)).toList();

    return {
      'wordBookId': row['word_book_id'] as int,
      'studyMode': row['study_mode'] as int,
      'isReview': (row['is_review'] as int) == 1,
      'currentIndex': row['current_index'] as int,
      'wordIds': wordIds,
      'updatedAt': DateTime.parse(row['updated_at'] as String),
    };
  }

  /// 清除学习进度
  static Future<void> clearStudyProgress() async {
    final db = await database;
    await db.delete('study_progress');
  }

  /// 检查是否有未完成的进度
  static Future<bool> hasStudyProgress() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM study_progress');
    return (result.first['count'] as int? ?? 0) > 0;
  }
}

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/fs_helper.dart';
import 'daos/wordbook_dao.dart';
import 'daos/word_dao.dart';
import 'daos/review_dao.dart';
import 'daos/stats_dao.dart';
import 'daos/study_progress_dao.dart';
import 'daos/wrong_word_dao.dart';
import 'daos/study_plan_dao.dart';
import 'daos/favorite_dao.dart';
import 'daos/custom_word_set_dao.dart';
import 'daos/search_history_dao.dart';
import 'daos/achievement_dao.dart';
import 'daos/weak_vocabulary_dao.dart';

/// SQLite数据库服务
/// 兼容 Windows/Linux (sqflite_common_ffi) 和移动端 (sqflite)
///
/// 架构说明：数据库逻辑已按领域拆分到各 DAO 类：
/// - [WordBookDao] 词库操作
/// - [WordDao] 单词操作
/// - [ReviewDao] 复习记录操作
/// - [StatsDao] 统计数据操作
/// - [StudyProgressDao] 学习进度操作
///
/// 本类保留所有静态方法作为兼容层，委托给各 DAO 实现。
/// 新代码建议直接使用 DAO 实例。
class DatabaseService {
  static const int databaseVersion = 14;
  static const int schemaVersion = 1;
  static const int _restoreBatchSize = 500;
  static final Future<Database> _dbFuture = _initDB();

  static const List<String> _backupTables = [
    'word_books',
    'words',
    'review_records',
    'study_sessions',
    'achievements',
    'wrong_words',
    'wrong_words_strength',
    'study_progress',
    'study_plans',
    'daily_task_snapshots',
    'favorites',
    'custom_word_sets',
    'custom_word_set_items',
    'search_history',
    'session_mastery_records',
  ];

  static const List<String> _clearOrder = [
    'custom_word_set_items',
    'daily_task_snapshots',
    'favorites',
    'search_history',
    'session_mastery_records',
    'wrong_words_strength',
    'study_progress',
    'wrong_words',
    'review_records',
    'study_sessions',
    'achievements',
    'words',
    'custom_word_sets',
    'study_plans',
    'word_books',
  ];

  static Future<Database> get database => _dbFuture;

  static List<String> get backupTables => List.unmodifiable(_backupTables);

  // DAO 实例
  static final WordBookDao wordBookDao = WordBookDao(_dbFuture);
  static final WordDao wordDao = WordDao(_dbFuture);
  static final ReviewDao reviewDao = ReviewDao(_dbFuture);
  static final StatsDao statsDao = StatsDao(_dbFuture);
  static final StudyProgressDao studyProgressDao = StudyProgressDao(_dbFuture);
  static final WrongWordDao wrongWordDao = WrongWordDao(_dbFuture);
  static final StudyPlanDao studyPlanDao = StudyPlanDao(_dbFuture);
  static final FavoriteDao favoriteDao = FavoriteDao(_dbFuture);
  static final CustomWordSetDao customWordSetDao = CustomWordSetDao(_dbFuture);
  static final SearchHistoryDao searchHistoryDao = SearchHistoryDao(_dbFuture);
  static final AchievementDao achievementDao = AchievementDao(_dbFuture);
  static final WeakVocabularyDao weakVocabularyDao = WeakVocabularyDao(
    _dbFuture,
  );

  static Future<Database> _initDB() async {
    if (kIsWeb) {
      // Web端直接用数据库名，由IndexedDB存储
      return await openDatabase(
        'qingmang_weiji.db',
        version: databaseVersion,
        onCreate: createSchema,
        onUpgrade: upgradeSchema,
      );
    }
    final dbPath = await _getDatabasePath();
    final path = join(dbPath, 'qingmang_weiji.db');
    await ensureDirectoryExists(path);
    return await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
    );
  }

  static Future<void> createSchema(Database db, int version) async {
    // 词库表 - 支持版本管理和排序
    await db.execute('''
          CREATE TABLE word_books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            is_built_in INTEGER DEFAULT 0,
            total_words INTEGER DEFAULT 0,
            version TEXT,
            sort_order INTEGER DEFAULT 0
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
            FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
          )
        ''');

    // 复习记录表
    await db.execute('''
          CREATE TABLE review_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL UNIQUE,
            quality INTEGER DEFAULT 0,
            interval INTEGER DEFAULT 1,
            ease_factor REAL DEFAULT 2.5,
            repetitions INTEGER DEFAULT 0,
            next_review TEXT NOT NULL,
            last_review TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');

    // 错词本表
    await db.execute('''
          CREATE TABLE wrong_words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL UNIQUE,
            wrong_count INTEGER DEFAULT 1,
            first_wrong_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_wrong_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            note TEXT,
            strength REAL DEFAULT 0,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');

    await db.execute('''
          CREATE TABLE wrong_words_strength (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            is_wrong INTEGER NOT NULL DEFAULT 0,
            viewed_answer INTEGER NOT NULL DEFAULT 0,
            review_mode TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_wws_word_id ON wrong_words_strength(word_id)',
    );
    await db.execute(
      'CREATE INDEX idx_wws_created_at ON wrong_words_strength(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_wws_word_created ON wrong_words_strength(word_id, created_at)',
    );

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
            FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
          )
        ''');

    // 会话掌握度记录表
    await db.execute('''
          CREATE TABLE session_mastery_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            session_score REAL NOT NULL,
            attempt_count INTEGER NOT NULL,
            wrong_count INTEGER NOT NULL,
            reveal_count INTEGER NOT NULL,
            retry_count INTEGER NOT NULL,
            correct_streak INTEGER NOT NULL,
            best_mode_weight REAL NOT NULL,
            has_high_weight_verification INTEGER NOT NULL,
            has_only_recall_verification INTEGER NOT NULL,
            has_only_quiz_verification INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_session_mastery_word_id ON session_mastery_records(word_id)',
    );
    await db.execute(
      'CREATE INDEX idx_session_mastery_date ON session_mastery_records(date)',
    );
    await db.execute(
      'CREATE INDEX idx_session_mastery_word_date ON session_mastery_records(word_id, date)',
    );

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
            updated_at TEXT NOT NULL,
            source TEXT DEFAULT "normal",
            progress_key TEXT DEFAULT "normal:global",
            title TEXT DEFAULT "继续学习",
            FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
          )
        ''');

    // 学习计划表
    await db.execute('''
          CREATE TABLE study_plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            word_book_ids TEXT NOT NULL,
            type INTEGER NOT NULL,
            target_date TEXT,
            daily_new_target INTEGER DEFAULT 0,
            total_words INTEGER DEFAULT 0,
            status INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

    // 每日任务快照表
    await db.execute('''
          CREATE TABLE daily_task_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            plan_id INTEGER NOT NULL,
            target_new_words INTEGER DEFAULT 0,
            target_review_words INTEGER DEFAULT 0,
            completed_new_words INTEGER DEFAULT 0,
            completed_review_words INTEGER DEFAULT 0,
            completed_at TEXT,
            FOREIGN KEY (plan_id) REFERENCES study_plans(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_daily_task_plan_date ON daily_task_snapshots(plan_id, date)',
    );

    // 收藏夹表
    await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL UNIQUE,
            group_name TEXT DEFAULT '默认',
            note TEXT,
            created_at TEXT NOT NULL,
            last_studied_at TEXT,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_favorites_word_id ON favorites(word_id)',
    );
    await db.execute(
      'CREATE INDEX idx_favorites_group ON favorites(group_name)',
    );

    // 自定义单词集表
    await db.execute('''
          CREATE TABLE custom_word_sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_studied_at TEXT
          )
        ''');
    // 单词集条目表
    await db.execute('''
          CREATE TABLE custom_word_set_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            set_id INTEGER NOT NULL,
            word_id INTEGER NOT NULL,
            sort_order INTEGER DEFAULT 0,
            added_at TEXT NOT NULL,
            FOREIGN KEY (set_id) REFERENCES custom_word_sets(id) ON DELETE CASCADE,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_cws_items_set_id ON custom_word_set_items(set_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_cws_items_set_word ON custom_word_set_items(set_id, word_id)',
    );

    // 搜索历史表
    await db.execute('''
          CREATE TABLE search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

    // 索引优化
    await db.execute('CREATE INDEX idx_words_book_id ON words(word_book_id)');
    await db.execute(
      'CREATE UNIQUE INDEX idx_review_word_id ON review_records(word_id)',
    );
    await db.execute(
      'CREATE INDEX idx_review_next_review ON review_records(next_review)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_wrong_word_id ON wrong_words(word_id)',
    );
    await db.execute(
      'CREATE INDEX idx_wrong_last_time ON wrong_words(last_wrong_time)',
    );
    await db.execute(
      'CREATE INDEX idx_session_book_id ON study_sessions(word_book_id)',
    );
  }

  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
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
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wrong_word_id ON wrong_words(word_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wrong_last_time ON wrong_words(last_wrong_time)',
      );
    }
    if (oldVersion < 4) {
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
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_session_book_id ON study_sessions(word_book_id)',
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
            CREATE TABLE IF NOT EXISTS study_progress (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_book_id INTEGER NOT NULL,
              study_mode INTEGER NOT NULL,
              is_review INTEGER DEFAULT 0,
              current_index INTEGER DEFAULT 0,
              word_ids TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
            )
          ''');
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
              CREATE TABLE IF NOT EXISTS session_mastery_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word_id INTEGER NOT NULL,
                date TEXT NOT NULL,
                session_score REAL NOT NULL,
                attempt_count INTEGER NOT NULL,
                wrong_count INTEGER NOT NULL,
                reveal_count INTEGER NOT NULL,
                retry_count INTEGER NOT NULL,
                correct_streak INTEGER NOT NULL,
                best_mode_weight REAL NOT NULL,
                has_high_weight_verification INTEGER NOT NULL,
                has_only_recall_verification INTEGER NOT NULL,
                has_only_quiz_verification INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
              )
            ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_session_mastery_word_id ON session_mastery_records(word_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_session_mastery_date ON session_mastery_records(date)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_session_mastery_word_date ON session_mastery_records(word_id, date)',
        );
        debugPrint('✓ 数据库已升级：添加 session_mastery_records 表');
      } catch (e) {
        debugPrint('⚠ 数据库升级 session_mastery_records 表失败：$e');
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE word_books ADD COLUMN sort_order INTEGER DEFAULT 0',
        );
        debugPrint('✓ 数据库已升级：添加 sort_order 字段');
      } catch (e) {
        debugPrint('⚠ 数据库升级 sort_order 字段失败：$e');
      }
    }
    if (oldVersion < 8) {
      await _deduplicateByWordId(db, 'review_records');
      await db.execute('DROP INDEX IF EXISTS idx_review_word_id');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_review_word_id ON review_records(word_id)',
      );
      await _addColumnIfMissing(
        db,
        table: 'study_progress',
        column: 'source',
        definition: 'TEXT DEFAULT "normal"',
      );
      await _addColumnIfMissing(
        db,
        table: 'study_progress',
        column: 'progress_key',
        definition: 'TEXT DEFAULT "normal:global"',
      );
      await _addColumnIfMissing(
        db,
        table: 'study_progress',
        column: 'title',
        definition: 'TEXT DEFAULT "继续学习"',
      );
      debugPrint('✓ 数据库已升级：添加 study_progress 多来源字段');
    }
    if (oldVersion < 9) {
      // 学习计划表
      await db.execute('''
            CREATE TABLE IF NOT EXISTS study_plans (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              word_book_ids TEXT NOT NULL,
              type INTEGER NOT NULL,
              target_date TEXT,
              daily_new_target INTEGER DEFAULT 0,
              total_words INTEGER DEFAULT 0,
              status INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
      // 每日任务快照表
      await db.execute('''
            CREATE TABLE IF NOT EXISTS daily_task_snapshots (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              plan_id INTEGER NOT NULL,
              target_new_words INTEGER DEFAULT 0,
              target_review_words INTEGER DEFAULT 0,
              completed_new_words INTEGER DEFAULT 0,
              completed_review_words INTEGER DEFAULT 0,
              completed_at TEXT,
              FOREIGN KEY (plan_id) REFERENCES study_plans(id) ON DELETE CASCADE
            )
          ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_task_plan_date ON daily_task_snapshots(plan_id, date)',
      );
      debugPrint('✓ 数据库已升级：添加 study_plans 和 daily_task_snapshots 表');
    }
    if (oldVersion < 10) {
      // 收藏夹表
      await db.execute('''
            CREATE TABLE IF NOT EXISTS favorites (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL UNIQUE,
              group_name TEXT DEFAULT '默认',
              note TEXT,
              created_at TEXT NOT NULL,
              last_studied_at TEXT,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_favorites_word_id ON favorites(word_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_favorites_group ON favorites(group_name)',
      );

      // 自定义单词集
      await db.execute('''
            CREATE TABLE IF NOT EXISTS custom_word_sets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              description TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
      await db.execute('''
            CREATE TABLE IF NOT EXISTS custom_word_set_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              set_id INTEGER NOT NULL,
              word_id INTEGER NOT NULL,
              sort_order INTEGER DEFAULT 0,
              added_at TEXT NOT NULL,
              FOREIGN KEY (set_id) REFERENCES custom_word_sets(id) ON DELETE CASCADE,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cws_items_set_id ON custom_word_set_items(set_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_cws_items_set_word ON custom_word_set_items(set_id, word_id)',
      );

      // 搜索历史
      await db.execute('''
            CREATE TABLE IF NOT EXISTS search_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              query TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
      debugPrint('✓ 数据库已升级：添加 favorites / custom_word_sets / search_history 表');
    }
    if (oldVersion < 11) {
      await _addColumnIfMissing(
        db,
        table: 'custom_word_sets',
        column: 'last_studied_at',
        definition: 'TEXT',
      );
    }
    if (oldVersion < 12) {
      await _deduplicateByWordId(db, 'wrong_words');
      await db.execute('DROP INDEX IF EXISTS idx_wrong_word_id');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_wrong_word_id ON wrong_words(word_id)',
      );
      await _addColumnIfMissing(
        db,
        table: 'wrong_words',
        column: 'strength',
        definition: 'REAL DEFAULT 0',
      );
      await db.execute('''
            CREATE TABLE IF NOT EXISTS wrong_words_strength (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              is_wrong INTEGER NOT NULL DEFAULT 0,
              viewed_answer INTEGER NOT NULL DEFAULT 0,
              review_mode TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wws_word_id ON wrong_words_strength(word_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wws_created_at ON wrong_words_strength(created_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wws_word_created ON wrong_words_strength(word_id, created_at)',
      );
      debugPrint('✓ 数据库已升级：添加薄弱词库强度记录表');
    }
    if (oldVersion < 13) {
      await _deduplicateByWordId(db, 'review_records');
      await _deduplicateByWordId(db, 'wrong_words');
    }
    if (oldVersion < 14) {
      await _addColumnIfMissing(
        db,
        table: 'wrong_words',
        column: 'strength',
        definition: 'REAL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        table: 'custom_word_sets',
        column: 'last_studied_at',
        definition: 'TEXT',
      );
    }
    await _deduplicateByWordId(db, 'review_records');
    await _deduplicateByWordId(db, 'wrong_words');
    await db.execute('DROP INDEX IF EXISTS idx_review_word_id');
    await db.execute('DROP INDEX IF EXISTS idx_wrong_word_id');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_review_word_id ON review_records(word_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wrong_word_id ON wrong_words(word_id)',
    );
  }

  static Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> _deduplicateByWordId(Database db, String table) async {
    await db.execute('''
      DELETE FROM $table
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM $table
        GROUP BY word_id
      )
    ''');
  }

  /// 获取数据库路径（兼容桌面端和移动端）
  static Future<String> _getDatabasePath() async {
    try {
      return await getDatabasesPath();
    } catch (e) {
      final appDir = await getApplicationDocumentsDirectory();
      return join(appDir.path, 'databases');
    }
  }

  // ========== 词库操作（委托 WordBookDao）==========

  static Future<int> insertWordBook(WordBook book) =>
      wordBookDao.insertWordBook(book);
  static Future<List<WordBook>> getAllWordBooks() =>
      wordBookDao.getAllWordBooks();
  static Future<WordBook?> getWordBook(int id) => wordBookDao.getWordBook(id);
  static Future<void> updateWordBookTotalWords(int bookId) =>
      wordBookDao.updateWordBookTotalWords(bookId);
  static Future<void> deleteWordBook(int id) => wordBookDao.deleteWordBook(id);
  static Future<void> deleteWordBooksBatch(List<int> ids) =>
      wordBookDao.deleteWordBooksBatch(ids);
  static Future<bool> hasWordsInBook(int bookId) =>
      wordBookDao.hasWordsInBook(bookId);
  static Future<void> updateSortOrder(int bookId, int sortOrder) =>
      wordBookDao.updateSortOrder(bookId, sortOrder);
  static Future<void> updateSortOrders(Map<int, int> sortOrderMap) =>
      wordBookDao.updateSortOrders(sortOrderMap);

  // ========== 单词操作（委托 WordDao）==========

  static Future<int> insertWord(Word word) => wordDao.insertWord(word);
  static Future<void> insertWordsBatch(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) => wordDao.insertWordsBatch(words, onProgress: onProgress);
  static Future<void> insertWordsBatchFast(
    List<Word> words, {
    Function(int completed, int total)? onProgress,
  }) => wordDao.insertWordsBatchFast(words, onProgress: onProgress);
  static Future<List<Word>> getWordsByBook(
    int bookId, {
    int? limit,
    int? offset,
  }) => wordDao.getWordsByBook(bookId, limit: limit, offset: offset);
  static Future<List<Word>> getDueWords(
    int bookId, {
    int limit = 50,
    int offset = 0,
  }) => wordDao.getDueWords(bookId, limit: limit, offset: offset);
  static Future<List<Word>> getNewWords(
    int bookId,
    int limit, {
    int offset = 0,
  }) => wordDao.getNewWords(bookId, limit, offset: offset);
  static Future<int> getDueWordCount(int bookId) =>
      wordDao.getDueWordCount(bookId);
  static Future<int> getTodayNewWordCount(int bookId) =>
      wordDao.getTodayNewWordCount(bookId);
  static Future<int> getTodayReviewedWordCount(int bookId) =>
      wordDao.getTodayReviewedWordCount(bookId);
  static Future<int> getUnlearnedWordCount(int bookId) =>
      wordDao.getUnlearnedWordCount(bookId);
  static Future<int> getWordCountInBook(int bookId) =>
      wordDao.getWordCountInBook(bookId);
  static Future<WordBookProgress> getWordBookProgress(int bookId) =>
      wordDao.getWordBookProgress(bookId);
  static Future<Map<int, WordBookProgress>> getWordBookProgressMap(
    Iterable<int> bookIds,
  ) => wordDao.getWordBookProgressMap(bookIds);
  static Future<List<Word>> searchWords(
    String query, {
    int? bookId,
    int limit = 50,
    int offset = 0,
    bool inWordFieldOnly = false,
  }) => wordDao.searchWords(
    query,
    bookId: bookId,
    limit: limit,
    offset: offset,
    inWordFieldOnly: inWordFieldOnly,
  );
  static Future<List<Word>> searchAllWords(
    String query, {
    int limit = 100,
    bool inWordFieldOnly = false,
  }) => wordDao.searchAllWords(
    query,
    limit: limit,
    inWordFieldOnly: inWordFieldOnly,
  );
  static Future<List<Word>> getWordsByIds(List<int> ids) =>
      wordDao.getWordsByIds(ids);
  static Future<List<Word>> getAllWords() => wordDao.getAllWords();
  static Future<void> deleteWordsBatch(List<int> wordIds) =>
      wordDao.deleteWordsBatch(wordIds);
  static Future<void> updateWordDefinition({
    required int wordId,
    String? phonetic,
    String? definition,
    String? example,
  }) => wordDao.updateWordDefinition(
    wordId: wordId,
    phonetic: phonetic,
    definition: definition,
    example: example,
  );

  // ========== 复习记录操作（委托 ReviewDao）==========

  static Future<int> saveReviewRecord(ReviewRecord record) =>
      reviewDao.saveReviewRecord(record);
  static Future<ReviewRecord?> getReviewRecord(int wordId) =>
      reviewDao.getReviewRecord(wordId);
  static Future<Map<int, ReviewRecord?>> getReviewRecordsByWordIds(
    List<int> wordIds,
  ) => reviewDao.getReviewRecordsByWordIds(wordIds);
  static Future<List<ReviewRecord>> getAllReviewRecords() =>
      reviewDao.getAllReviewRecords();

  // ========== 统计数据（委托 StatsDao）==========

  static Future<Map<String, dynamic>> getStudyStats() =>
      statsDao.getStudyStats();
  static Future<List<Map<String, dynamic>>> getDailyReviewStats({
    int days = 30,
  }) => statsDao.getDailyReviewStats(days: days);
  static Future<Map<String, dynamic>> getOverallStats(int bookId) =>
      statsDao.getOverallStats(bookId);
  static Future<List<Map<String, dynamic>>> getQualityDistribution(
    int bookId,
  ) => statsDao.getQualityDistribution(bookId);
  static Future<List<Map<String, dynamic>>> getIntervalDistribution(
    int bookId,
  ) => statsDao.getIntervalDistribution(bookId);
  static Future<Map<DateTime, int>> getHeatmapData() =>
      statsDao.getHeatmapData();
  static Future<ReviewForecast> getReviewForecast({int days = 7}) =>
      statsDao.getReviewForecast(days: days);

  // ========== 学习进度操作（委托 StudyProgressDao）==========

  static Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
    String source = 'normal',
    String progressKey = 'normal:global',
    String title = '继续学习',
  }) => studyProgressDao.saveStudyProgress(
    wordBookId: wordBookId,
    studyMode: studyMode,
    isReview: isReview,
    currentIndex: currentIndex,
    wordIds: wordIds,
    source: source,
    progressKey: progressKey,
    title: title,
  );

  static Future<Map<String, dynamic>?> getStudyProgress() =>
      studyProgressDao.getStudyProgress();
  static Future<void> clearStudyProgress() =>
      studyProgressDao.clearStudyProgress();
  static Future<bool> hasStudyProgress() => studyProgressDao.hasStudyProgress();

  // ========== 清除数据 ==========

  static Future<void> clearAllData() async {
    final db = await database;
    final existing = await _existingTables(db);
    await db.transaction((txn) async {
      for (final table in _clearOrder) {
        if (!existing.contains(table)) continue;
        await txn.delete(table);
      }
    });
  }

  // ========== 备份与恢复 ==========

  static const List<String> _restoreOrder = [
    'word_books',
    'study_plans',
    'custom_word_sets',
    'words',
    'review_records',
    'study_sessions',
    'achievements',
    'wrong_words',
    'wrong_words_strength',
    'study_progress',
    'daily_task_snapshots',
    'favorites',
    'custom_word_set_items',
    'search_history',
    'session_mastery_records',
  ];

  static Future<Set<String>> _existingTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    return rows.map((row) => row['name'] as String).toSet();
  }

  static Future<Map<String, dynamic>> exportAll() async =>
      exportAllFrom(await database);

  static Future<Map<String, dynamic>> exportAllFrom(Database db) async {
    final existing = await _existingTables(db);
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTables) {
      // 旧库可能缺表：跳过而不是整次备份失败
      if (!existing.contains(table)) {
        tables[table] = const [];
        continue;
      }
      tables[table] = await db.query(table);
    }
    return {
      'appVersion': AppConstants.appVersion,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };
  }

  static Future<void> importAll(Map<String, dynamic> tables) async =>
      importAllInto(await database, tables);

  static Future<void> importAllInto(
    Database db,
    Map<String, dynamic> tables,
  ) async {
    final existing = await _existingTables(db);
    final columns = <String, Set<String>>{};
    for (final table in _backupTables) {
      if (!existing.contains(table)) {
        columns[table] = <String>{};
        continue;
      }
      columns[table] = (await db.rawQuery(
        'PRAGMA table_info($table)',
      )).map((row) => row['name'] as String).toSet();
    }
    await db.transaction((txn) async {
      for (final table in _clearOrder) {
        if (!existing.contains(table)) continue;
        await txn.delete(table);
      }
      //事务内批量 insert，保持原子性
      for (final table in _restoreOrder) {
        if (!existing.contains(table)) continue;
        final allowed = columns[table] ?? const <String>{};
        var batch = txn.batch();
        var pending = 0;
        for (final rawRow in (tables[table] as List?) ?? const []) {
          final row = Map<String, dynamic>.from(rawRow as Map)
            ..removeWhere((key, value) => !allowed.contains(key));
          if (row.isEmpty) continue;
          batch.insert(table, row);
          pending++;
          if (pending >= _restoreBatchSize) {
            await batch.commit(noResult: true);
            batch = txn.batch();
            pending = 0;
          }
        }
        if (pending > 0) await batch.commit(noResult: true);
      }
    });
  }
}

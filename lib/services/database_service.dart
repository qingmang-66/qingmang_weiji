import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/fs_helper.dart';
import '../utils/platform_info.dart';
import 'daos/wordbook_dao.dart';
import 'daos/word_dao.dart';
import 'daos/review_dao.dart';
import 'daos/stats_dao.dart';
import 'daos/study_progress_dao.dart';
import 'daos/wrong_word_dao.dart';
import 'daos/study_plan_dao.dart';
import 'daos/search_history_dao.dart';
import 'daos/weak_vocabulary_dao.dart';
import 'daos/reader_dao.dart';
import 'daos/favorite_dao.dart';

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
  static const int databaseVersion = 23;
  static const int schemaVersion = 1;
  static const int _restoreBatchSize = 500;
  // 数据库句柄缓存：打开失败后会被丢弃，下一次访问自动重试。
  // 此前是 static final 的失败 Future 会被永久缓存——瞬时故障（文件锁、
  // 磁盘抖动、云盘同步占用）恢复后 App 也无法自愈，只能杀进程重启。
  static Future<Database>? _cachedDbFuture;

  static const List<String> _backupTables = [
    'word_books',
    'words',
    'review_records',
    'study_sessions',
    'wrong_words',
    'wrong_words_strength',
    'study_progress',
    'study_plans',
    'daily_task_snapshots',
    'search_history',
    'session_mastery_records',
    'reader_marks',
    'reader_bookmarks',
    'reader_progress',
    'word_favorites',
  ];

  static const List<String> _clearOrder = [
    'daily_task_snapshots',
    'search_history',
    'session_mastery_records',
    'reader_bookmarks',
    'reader_progress',
    'reader_marks',
    'word_favorites',
    'wrong_words_strength',
    'study_progress',
    'wrong_words',
    'review_records',
    'study_sessions',
    'words',
    'study_plans',
    'word_books',
  ];

  static Future<Database> get database {
    final cached = _cachedDbFuture;
    if (cached != null) return cached;
    final future = _initDB();
    _cachedDbFuture = future;
    // 失败即失效缓存，让下一次访问重新尝试打开；identical 校验防止
    // 并发场景下清掉后来者新建的 future。onError 吞掉的是本监听链的
    // 副本错误，调用方拿到的仍是同一个失败 Future（不会重复上报）
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_cachedDbFuture, future)) _cachedDbFuture = null;
      },
    );
    return future;
  }

  /// 数据库句柄提供者：各 DAO 持有该函数而不是 Future 实例，
  /// 这样 [database] 的失败自愈（重开）对 DAO 同样生效
  static Future<Database> databaseHandle() => database;

  static List<String> get backupTables => List.unmodifiable(_backupTables);

  // DAO 实例
  static final WordBookDao wordBookDao = WordBookDao(databaseHandle);
  static final WordDao wordDao = WordDao(databaseHandle);
  static final ReviewDao reviewDao = ReviewDao(databaseHandle);
  static final StatsDao statsDao = StatsDao(databaseHandle);
  static final StudyProgressDao studyProgressDao = StudyProgressDao(
    databaseHandle,
  );
  static final WrongWordDao wrongWordDao = WrongWordDao(databaseHandle);
  static final StudyPlanDao studyPlanDao = StudyPlanDao(databaseHandle);
  static final SearchHistoryDao searchHistoryDao = SearchHistoryDao(
    databaseHandle,
  );
  static final WeakVocabularyDao weakVocabularyDao = WeakVocabularyDao(
    databaseHandle,
  );
  static final ReaderDao readerDao = ReaderDao(databaseHandle);
  static final FavoriteDao favoriteDao = FavoriteDao(databaseHandle);

  static Future<Database> _initDB() async {
    //瞬时故障（文件锁、磁盘抖动）下重试，避免整个应用生命周期不可用
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final db = await _openDB();
        // 版本日志放在数据库完全打开之后：不占用打开流程的语句额度，
        // 避免在并行场景下增大文件锁竞争窗口
        await _logSqliteVersion(db);
        return db;
      } catch (e) {
        lastError = e;
        debugPrint('数据库打开失败（第 $attempt 次）：$e');
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
    Error.throwWithStackTrace(lastError!, StackTrace.current);
  }

  static Future<Database> _openDB() async {
    if (kIsWeb) {
      // Web端直接用数据库名，由IndexedDB存储（外键开关见 _configureDatabase）
      return await openDatabase(
        'qingmang_weiji.db',
        version: databaseVersion,
        onConfigure: _configureDatabase,
        onCreate: createSchema,
        onUpgrade: upgradeSchema,
        onDowngrade: (db, oldVersion, newVersion) async {
          debugPrint('数据库降级：$oldVersion → $newVersion，保留现有数据继续使用');
        },
      );
    }
    final dbPath = await _getDatabasePath();
    final path = join(dbPath, 'qingmang_weiji.db');
    await ensureDirectoryExists(path);
    await _migrateLegacyDesktopDatabase(path);
    return await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: _configureDatabase,
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
      //用户回装旧版本时 sqflite 默认直接抛 onDowngrade 异常 → 数据库永久
      //打不开。这里接受降级继续使用：新版本只做加列/加表，旧代码用不到的
      //列不影响功能，保住用户数据比强行报错更符合预期。
      onDowngrade: (db, oldVersion, newVersion) async {
        debugPrint('数据库降级：$oldVersion → $newVersion，保留现有数据继续使用');
      },
    );
  }

  /// 打开数据库时的统一配置（Web 与其它平台共用）
  static Future<void> _configureDatabase(Database db) async {
    //外键必须显式开启，否则级联删除失效产生孤儿行
    await db.execute('PRAGMA foreign_keys = ON');
    //并发健壮性：默认回滚日志模式下读写互斥，备份导出/学习落库/进度保存
    //重叠时极易 database is locked；WAL 允许读写并发，busy_timeout 让写锁
    //竞争等待而不是立即抛错。Web(IndexedDB 实现) 不支持 WAL，跳过。
    if (!kIsWeb) {
      try {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA busy_timeout = 5000');
      } catch (e) {
        debugPrint('配置 WAL/busy_timeout 失败（不影响功能）：$e');
      }
    }
  }

  /// 打印当前环境的 SQLite 版本（仅用于排查环境差异）。
  /// SQLite < 3.32 时 IN 变量上限为 999，< 3.25 不支持窗口函数。
  static Future<void> _logSqliteVersion(Database db) async {
    try {
      final rows = await db.rawQuery('SELECT sqlite_version() AS v');
      if (rows.isNotEmpty) {
        debugPrint('SQLite 版本: ${rows.first['v']}');
      }
    } catch (e) {
      debugPrint('读取 SQLite 版本失败：$e');
    }
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
            first_learned_at TEXT,
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
            correct_streak INTEGER DEFAULT 0,
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
    //(word_id, date) 唯一：同一天同一词的掌握记录只应有一条（应用层按 max 合并）
    await db.execute(
      'CREATE UNIQUE INDEX idx_session_mastery_word_date ON session_mastery_records(word_id, date)',
    );

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

    // 搜索历史表
    await db.execute('''
          CREATE TABLE search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

    // 阅读模式勾记表
    await db.execute('''
          CREATE TABLE reader_marks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_reader_marks_word_id ON reader_marks(word_id)',
    );

    // 阅读模式书签表
    // word_text：记录创建时的词文本快照，词库重新导入后用于识别"序号已失效"。
    // 注意必须在这里（createSchema）与 upgradeSchema 的 v22 分支同时存在：
    // 新库只走 onCreate、不走 onUpgrade，只补一处会让全新安装缺列。
    await db.execute('''
          CREATE TABLE reader_bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_book_id INTEGER NOT NULL,
            word_index INTEGER NOT NULL,
            word_text TEXT,
            custom_name TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_reader_bookmarks_book ON reader_bookmarks(word_book_id)',
    );

    // 阅读模式进度表
    await db.execute('''
          CREATE TABLE reader_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_book_id INTEGER NOT NULL UNIQUE,
            word_index INTEGER NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
          )
        ''');

    // 收藏夹表（单词级、跨词库全局唯一）
    await db.execute('''
          CREATE TABLE word_favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL UNIQUE,
            source TEXT,
            note TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_word_favorites_created ON word_favorites(created_at)',
    );

    // 索引优化：word_id 列级 UNIQUE 已自动生成索引，不再手工重复建（写放大）
    await db.execute('CREATE INDEX idx_words_book_id ON words(word_book_id)');
    //单词文本索引：词典查询/前缀匹配按 word 过滤，避免整表扫描
    await db.execute('CREATE INDEX idx_words_word ON words(word)');
    await db.execute(
      'CREATE INDEX idx_review_next_review ON review_records(next_review)',
    );
    //「今日新学/复习、周报、逐日明细」都按 first_learned_at 过滤
    await db.execute(
      'CREATE INDEX idx_review_first_learned ON review_records(first_learned_at)',
    );
    await db.execute(
      'CREATE INDEX idx_review_last_review ON review_records(last_review)',
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
      // 幂等加列，失败直接抛出中止升级，避免版本号被标记后无法重试
      await _addColumnIfMissing(
        db,
        table: 'word_books',
        column: 'version',
        definition: 'TEXT',
      );
      debugPrint('✓ 数据库已升级：添加 version 字段');
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
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_session_mastery_word_date ON session_mastery_records(word_id, date)',
      );
      debugPrint('✓ 数据库已升级：添加 session_mastery_records 表');
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(
        db,
        table: 'word_books',
        column: 'sort_order',
        definition: 'INTEGER DEFAULT 0',
      );
      debugPrint('✓ 数据库已升级：添加 sort_order 字段');
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
      // 搜索历史
      await db.execute('''
            CREATE TABLE IF NOT EXISTS search_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              query TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
      debugPrint('✓ 数据库已升级：添加 search_history 表');
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
    }
    if (oldVersion < 15) {
      // 首次学习时间：用于精确区分“今日新学”与“今日复习”
      await _addColumnIfMissing(
        db,
        table: 'review_records',
        column: 'first_learned_at',
        definition: 'TEXT',
      );
    }
    if (oldVersion < 16) {
      // 阅读模式：勾记/书签/进度
      await db.execute('''
            CREATE TABLE IF NOT EXISTS reader_marks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL UNIQUE,
              created_at TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reader_marks_word_id ON reader_marks(word_id)',
      );
      await db.execute('''
            CREATE TABLE IF NOT EXISTS reader_bookmarks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_book_id INTEGER NOT NULL,
              word_index INTEGER NOT NULL,
              word_text TEXT,
              custom_name TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
            )
          ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reader_bookmarks_book ON reader_bookmarks(word_book_id)',
      );
      await db.execute('''
            CREATE TABLE IF NOT EXISTS reader_progress (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_book_id INTEGER NOT NULL UNIQUE,
              word_index INTEGER NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
            )
          ''');
      debugPrint('✓ 数据库已升级：添加阅读模式表（勾记/书签/进度）');
    }
    if (oldVersion < 17) {
      // 收藏夹 / 自定义单词集功能已整体下线，这里清理掉遗留的表。
      // 先删条目表（外键指向词集）再删主表，避免外键约束报错。
      await db.execute('DROP TABLE IF EXISTS custom_word_set_items');
      await db.execute('DROP TABLE IF EXISTS favorites');
      await db.execute('DROP TABLE IF EXISTS custom_word_sets');
      debugPrint('✓ 数据库已升级：移除已下线的收藏夹 / 自定义单词集表');
    }
    if (oldVersion < 18) {
      // 词集：收藏夹（单词级、跨词库全局唯一）重新启用。
      // 注意 v17 曾 DROP 过同名的旧表，所以老库必须先升到 17 再走到这里建表，
      // 因此新表名沿用 word_favorites 而不是 favorites，语义也更明确。
      await db.execute('''
            CREATE TABLE IF NOT EXISTS word_favorites (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL UNIQUE,
              source TEXT,
              note TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_word_favorites_created ON word_favorites(created_at)',
      );
      // 错词的"连续答对次数"持久化：原先只存在学习页内存里，
      // 中途退出/重启就归零，导致"连续答对 3 次移出错词本"实际难以达成
      await _addColumnIfMissing(
        db,
        table: 'wrong_words',
        column: 'correct_streak',
        definition: 'INTEGER DEFAULT 0',
      );
      debugPrint('✓ 数据库已升级：添加收藏夹表与错词连续答对次数');
    }
    if (oldVersion < 19) {
      // 成就功能已整体下线，清理遗留的成就表。
      await db.execute('DROP TABLE IF EXISTS achievements');
      debugPrint('✓ 数据库已升级：移除已下线的成就表');
    }
    if (oldVersion < 20) {
      // 统计/首页查询大量按 last_review 过滤，补索引避免全表扫描
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_review_last_review ON review_records(last_review)',
      );
      debugPrint('✓ 数据库已升级：添加 review_records(last_review) 索引');
    }
    if (oldVersion < 21) {
      // words(word)：词典查询/前缀匹配；first_learned_at：今日新学与周报统计
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_words_word ON words(word)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_review_first_learned ON review_records(first_learned_at)',
      );
      debugPrint(
        '✓ 数据库已升级：添加 words(word) 与 review_records(first_learned_at) 索引',
      );
    }
    if (oldVersion < 22) {
      // 书签词文本快照：词库重新导入/词序变化后，word_index 会静默指向
      // 另一个词；记录创建时的词文本即可在书签面板提示"词序已变化"
      await _addColumnIfMissing(
        db,
        table: 'reader_bookmarks',
        column: 'word_text',
        definition: 'TEXT',
      );
      debugPrint('✓ 数据库已升级：书签增加词文本快照列');
    }
    if (oldVersion < 23) {
      // v22 的 createSchema 漏了 word_text（只在升级分支补过），于是"以 v22
      // 全新安装"的库——既不走 onCreate 也不满足 oldVersion < 22——永远缺列，
      // 加书签时 SqliteException: table reader_bookmarks has no column named
      // word_text。这里幂等补齐（已升级过的库是无害的 no-op）。
      await _addColumnIfMissing(
        db,
        table: 'reader_bookmarks',
        column: 'word_text',
        definition: 'TEXT',
      );
      debugPrint('✓ 数据库已升级：补齐 reader_bookmarks.word_text');
    }
    await _deduplicateByWordId(db, 'review_records');
    await _deduplicateByWordId(db, 'wrong_words');
    //session_mastery_records 依赖应用层"先查后改"保证同天同词唯一，旧库可能残留
    //重复行且只建了普通索引，这里去重后重建为唯一索引
    await _deduplicateSessionMastery(db);
    //旧库的 word_id 列可能没有 UNIQUE 约束，手工 UNIQUE 索引是其唯一性保障，必须保留
    await db.execute('DROP INDEX IF EXISTS idx_review_word_id');
    await db.execute('DROP INDEX IF EXISTS idx_wrong_word_id');
    await db.execute('DROP INDEX IF EXISTS idx_session_mastery_word_date');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_review_word_id ON review_records(word_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wrong_word_id ON wrong_words(word_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_session_mastery_word_date ON session_mastery_records(word_id, date)',
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

  /// 按 word_id 去重，保留 id 最大（即最后写入）的一行，
  /// 避免把最新的复习状态/累计错误次数当作重复行丢弃
  static Future<void> _deduplicateByWordId(Database db, String table) async {
    await db.execute('''
      DELETE FROM $table
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM $table
        GROUP BY word_id
      )
    ''');
  }

  /// 按 (word_id, date) 去重，保留 session_score 最大（并列取 id 最大）的一行，
  /// 与 SessionMasteryRepository「同日同词取较高值合并」的语义保持一致
  static Future<void> _deduplicateSessionMastery(Database db) async {
    await db.execute('''
      DELETE FROM session_mastery_records
      WHERE id NOT IN (
        SELECT (
          SELECT t2.id FROM session_mastery_records t2
          WHERE t2.word_id = t1.word_id AND t2.date = t1.date
          ORDER BY t2.session_score DESC, t2.id DESC
          LIMIT 1
        )
        FROM (SELECT DISTINCT word_id, date FROM session_mastery_records) t1
      )
    ''');
  }

  /// 获取数据库路径（兼容桌面端和移动端）
  ///
  /// Windows/Linux 必须显式落到用户级 AppSupport 目录：`getDatabasesPath()`
  /// 在 sqflite_common_ffi 下返回的是**相对当前工作目录**的
  /// `.dart_tool/sqflite_common_ffi/databases`
  /// （见 sqflite_common_ffi 的 getDatabasesPathPlatform），会带来三个后果：
  /// 1. 换"起始位置"启动（快捷方式、从别的目录命令行启动）→ CWD 变化 →
  ///    应用会新建一个空库，用户看到"学习数据全没了"；
  /// 2. 绿色包换目录/覆盖升级 → 数据留在旧目录；
  /// 3. 数据被藏在 `.dart_tool` 这种"缓存目录"里，`flutter clean` 会被一并删除。
  static Future<String> _getDatabasePath() async {
    if (!kIsWeb && (isWindowsPlatform || isLinuxPlatform)) {
      try {
        final dir = await getApplicationSupportDirectory();
        return join(dir.path, 'databases');
      } catch (e) {
        // path_provider 不可用时（单元测试没有平台通道、插件异常）退回
        // ffi 的默认路径，保证数据库仍能打开
        _safeLog('获取应用数据目录失败，退回默认数据库路径：$e');
      }
    }
    try {
      return await getDatabasesPath();
    } catch (e) {
      final appDir = await getApplicationDocumentsDirectory();
      return join(appDir.path, 'databases');
    }
  }

  /// 旧版桌面端数据库位置（CWD 下的相对路径），仅用于一次性迁移
  static String? _legacyDesktopDatabasePath() {
    final cwd = currentDirectoryPath;
    if (cwd == null || cwd.isEmpty) return null;
    return join(
      cwd,
      '.dart_tool',
      'sqflite_common_ffi',
      'databases',
      'qingmang_weiji.db',
    );
  }

  /// 把旧版"相对工作目录"的数据库搬到新的用户级目录。
  ///
  /// 只在"新位置还没有库 + 旧位置有库"时复制（不删除旧文件，避免迁移失败
  /// 造成不可逆的数据丢失；旧文件由用户自行清理）。失败静默降级为新库，
  /// 不影响启动。
  static Future<void> _migrateLegacyDesktopDatabase(String newPath) async {
    if (kIsWeb || (!isWindowsPlatform && !isLinuxPlatform)) return;
    try {
      if (await fileExists(newPath)) return;
      final legacy = _legacyDesktopDatabasePath();
      if (legacy == null || legacy == newPath) return;
      if (!await fileExists(legacy)) return;
      await copyFile(legacy, newPath);
      //WAL 的 -wal 文件里可能还有未合并的写入，一并搬过去
      for (final suffix in const ['-wal', '-shm']) {
        if (await fileExists('$legacy$suffix')) {
          await copyFile('$legacy$suffix', '$newPath$suffix');
        }
      }
      _safeLog('✓ 已把旧版数据库迁移到用户目录：$newPath（旧文件保留在 $legacy）');
    } catch (e) {
      _safeLog('旧版数据库迁移失败（将使用新位置）：$e');
    }
  }

  /// 容错日志：单元测试等"没有初始化 Flutter Binding"的环境中
  /// debugPrint 自身会抛异常（ServicesBinding.instance 不可用），
  /// 若直接调用会把一个"只是记录日志"的动作变成新的失败点。
  static void _safeLog(String message) {
    try {
      debugPrint(message);
    } catch (_) {
      // 没有绑定就没有日志，忽略
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

  /// 删除词库（连带清理关联数据，并把该 id 从学习计划里剔除）
  static Future<void> deleteWordBook(int id) async {
    await wordBookDao.deleteWordBook(id);
    try {
      await studyPlanDao.pruneWordBook(id);
    } catch (e) {
      debugPrint('清理计划中的悬空词库 id 失败（不影响删除）：$e');
    }
  }

  /// 重置词库学习进度（保留单词，清复习/错词/会话/阅读进度）
  static Future<void> resetWordBookProgress(int id) =>
      wordBookDao.resetBookProgress(id);

  static Future<void> deleteWordBooksBatch(List<int> ids) async {
    await wordBookDao.deleteWordBooksBatch(ids);
    for (final id in ids) {
      try {
        await studyPlanDao.pruneWordBook(id);
      } catch (e) {
        debugPrint('清理计划中的悬空词库 id 失败（不影响删除）：$e');
      }
    }
  }

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
  static Future<void> clearStudyProgress({String? progressKey}) =>
      studyProgressDao.clearStudyProgress(progressKey: progressKey);
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
      // 复位自增计数器，避免"初始化应用"后新建数据的 id 从旧计数继续涨。
      // sqlite_sequence 是 schema 内部表且只在存在 AUTOINCREMENT 表时才有，
      // 失败不影响清空本身
      try {
        await txn.delete('sqlite_sequence');
      } catch (e) {
        debugPrint('复位 sqlite_sequence 失败（可忽略）：$e');
      }
    });
  }

  // ========== 备份与恢复 ==========

  static const List<String> _restoreOrder = [
    'word_books',
    'study_plans',
    'words',
    'review_records',
    'study_sessions',
    'wrong_words',
    'wrong_words_strength',
    'study_progress',
    'daily_task_snapshots',
    'search_history',
    'session_mastery_records',
    'word_favorites',
    //阅读模式三张表同时出现在 _backupTables 与 _clearOrder 中，
    //必须一并回填，否则恢复备份会把它们清空后不再写回
    'reader_marks',
    'reader_bookmarks',
    'reader_progress',
  ];

  static Future<Set<String>> _existingTables(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    return rows.map((row) => row['name'] as String).toSet();
  }

  static Future<Map<String, dynamic>> exportAll() async =>
      exportAllFrom(await database);

  static Future<Map<String, dynamic>> exportAllFrom(Database db) async {
    //整库读取包在一个事务里：导出期间若有并发写，逐表单独查询会读到
    //跨表不一致的快照，恢复时可能因外键校验失败整批回滚
    final tables = <String, List<Map<String, Object?>>>{};
    await db.transaction((txn) async {
      final existing = await _existingTables(txn);
      for (final table in _backupTables) {
        // 旧库可能缺表：跳过而不是整次备份失败
        if (!existing.contains(table)) {
          tables[table] = const [];
          continue;
        }
        tables[table] = await txn.query(table);
      }
    });
    return {
      'appVersion': AppConstants.appVersion,
      // schemaVersion 是历史字段，恒为 1（早期版本的备份格式版本），保留以兼容旧备份
      'schemaVersion': schemaVersion,
      // databaseVersion 才是真正决定"这份备份能不能被本版本正确导入"的依据：
      // 表结构低于当前版本的备份走列白名单裁剪，高于当前版本的必须拒绝
      'databaseVersion': databaseVersion,
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
    // 导入会先无条件清空全部业务表：空数据（含所有表都为空数组）必须拒绝，
    // 否则一个 {"tables":{}} 的"备份"就能不可逆地清光用户全部学习数据。
    // BackupService 的校验是第一道防线，这里是绕过它调用时的双保险。
    final totalRows = tables.values.whereType<List>().fold<int>(
      0,
      (sum, rows) => sum + rows.length,
    );
    if (totalRows == 0) {
      throw Exception('导入数据为空，已拒绝以保护现有数据');
    }
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
      var insertedRows = 0;
      for (final table in _restoreOrder) {
        if (!existing.contains(table)) continue;
        final allowed = columns[table] ?? const <String>{};
        var batch = txn.batch();
        var pending = 0;
        for (final rawRow in (tables[table] as List?) ?? const []) {
          final row = Map<String, dynamic>.from(rawRow as Map)
            ..removeWhere((key, value) => !allowed.contains(key));
          //整行都不认识的列：按列白名单裁剪后为空 → 跳过（不写入空行）
          if (row.isEmpty) continue;
          //用 replace 而非默认 abort：备份内部若有重复唯一键（如 words.id、
          //review_records.word_id），abort 会整批回滚导致恢复失败；replace
          //保留最后一条，语义与"整库覆盖"一致。导入前已清空全部业务表，
          //父子顺序由 _restoreOrder 保证，替换父行时其子行尚未写入。
          batch.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          pending++;
          if (pending >= _restoreBatchSize) {
            await batch.commit(noResult: true);
            insertedRows += pending;
            batch = txn.batch();
            pending = 0;
          }
        }
        if (pending > 0) {
          await batch.commit(noResult: true);
          insertedRows += pending;
        }
      }
      // 校验只数"原始行数"，这里必须再数一次"真正写进去的行数"：
      // 备份的表名对、但行内列名全是历史/被改过的键时，上面会逐行跳过，
      // 而清空已经发生 —— 若不在这里抛错回滚，用户会得到"恢复成功"+
      // 现有数据被清光的结果（空表校验挡不住这种备份）。
      if (insertedRows == 0) {
        throw Exception('备份内容与当前版本不兼容（没有可导入的字段），已回滚，未改动任何数据');
      }
    });
  }

  /// 把旧词库的学习记录迁移到新词库（词库升级时使用）。
  ///
  /// 词库升级若直接删除旧词库，会经外键级联（ON DELETE CASCADE）把用户在该词库上的
  /// 复习记录、错词、收藏、勾记、掌握度等全部删掉。因此升级流程必须改为：
  /// 导入新词库 → 调用本方法迁移 → 再删除旧词库。
  ///
  /// 迁移按「单词文本」建立 旧词 id → 新词 id 的映射（大小写不敏感；新库内若有重复词，
  /// 取 id 最小的那条以保证确定性）。目标记录已存在时**跳过该词**：既不用 REPLACE
  /// 覆盖（那会删掉冲突行），也不删除任何一侧的数据，旧记录随后随旧词库一并清理。
  static Future<void> migrateWordBookReferences({
    required int fromBookId,
    required int toBookId,
    Database? databaseOverride,
  }) async {
    if (fromBookId == toBookId) return;
    final db = databaseOverride ?? await database;

    // 1. 建立映射（GROUP BY 保证一词一条，MIN 保证结果确定）
    final pairs = await db.rawQuery(
      '''
      SELECT ow.id AS old_id, MIN(nw.id) AS new_id
      FROM words ow
      INNER JOIN words nw ON lower(nw.word) = lower(ow.word)
      WHERE ow.word_book_id = ? AND nw.word_book_id = ?
      GROUP BY ow.id
      ''',
      [fromBookId, toBookId],
    );
    final mapping = <int, int>{
      for (final row in pairs) (row['old_id'] as int): (row['new_id'] as int),
    };
    //注意：映射为空时也不能提前返回——词库级引用（书签/阅读进度/学习进度/
    //会话）仍需迁移，否则旧词库删除时会把这些数据一并级联清掉。
    //word_id 级迁移在映射为空时自然不做任何事（下方的批次循环不会进入）。

    //word_id 带 UNIQUE 约束的表必须跳过"目标已占用"的行，否则会触发唯一冲突
    const uniqueWordIdTables = [
      'review_records',
      'wrong_words',
      'word_favorites',
      'reader_marks',
    ];
    const plainWordIdTables = [
      'wrong_words_strength',
    ];

    await db.transaction((txn) async {
      for (final table in uniqueWordIdTables) {
        await _migrateWordIds(
          txn,
          table: table,
          mapping: mapping,
          skipOccupied: true,
        );
      }
      for (final table in plainWordIdTables) {
        await _migrateWordIds(
          txn,
          table: table,
          mapping: mapping,
          skipOccupied: false,
        );
      }
      //session_mastery_records 的唯一键是 (word_id, date)，不能放进上面
      //任何一组：裸 UPDATE 会在"两条旧词同日都有记录"或"新词同日已有记录"
      //时撞 UNIQUE 索引、整个迁移事务回滚；按 word_id 的占用检查又太粗
      //（同日以外的记录会被整条跳过）。逐行按复合键迁移并合并冲突。
      await _migrateSessionMasteryWordIds(txn, mapping: mapping);
      // 词库级引用：这几张表的 word_book_id 无唯一约束，直接迁移
      for (final table in ['reader_bookmarks', 'study_sessions']) {
        await txn.update(
          table,
          {'word_book_id': toBookId},
          where: 'word_book_id = ?',
          whereArgs: [fromBookId],
        );
      }
      //study_progress 除 word_book_id 外还持有 word_ids（逗号串，存的是旧词 id），
      //必须按 mapping 同步重写，否则迁移后这些 id 全部悬空、续学进度失效
      final progressRows = await txn.query(
        'study_progress',
        columns: ['id', 'word_ids'],
        where: 'word_book_id = ?',
        whereArgs: [fromBookId],
      );
      for (final row in progressRows) {
        final raw = (row['word_ids'] as String?) ?? '';
        final remapped = raw
            .split(',')
            .map((token) {
              final id = int.tryParse(token);
              //未匹配到新词的 id 保留原值（随后随旧词库一并清理）
              return id == null ? token : '${mapping[id] ?? id}';
            })
            .join(',');
        await txn.update(
          'study_progress',
          {'word_book_id': toBookId, 'word_ids': remapped},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      //reader_progress.word_book_id 有 UNIQUE：新词库已有进度时保留新库那条（它更新）
      final existingProgress = await txn.query(
        'reader_progress',
        columns: ['id'],
        where: 'word_book_id = ?',
        whereArgs: [toBookId],
        limit: 1,
      );
      if (existingProgress.isEmpty) {
        await txn.update(
          'reader_progress',
          {'word_book_id': toBookId},
          where: 'word_book_id = ?',
          whereArgs: [fromBookId],
        );
      }
    });
  }

  /// 按 [mapping] 把 [table].word_id 从旧词 id 改为新词 id。
  ///
  /// 分块执行以避开 SQLite 的 IN 变量上限；[skipOccupied] 为 true 时跳过
  /// 「目标 id 已被占用」的行（保留目标侧记录，不覆盖、不删除）。
  /// 迁移 session_mastery_records 的 word_id 引用。
  ///
  /// 唯一键是 (word_id, date)：目标词同一天已有记录时不能 UPDATE 过去，
  /// 按 _deduplicateSessionMastery 的语义合并——保留 session_score 较高者，
  /// 删除旧词那行；其余日期直接改写 word_id。
  static Future<void> _migrateSessionMasteryWordIds(
    Transaction txn, {
    required Map<int, int> mapping,
  }) async {
    if (mapping.isEmpty) return;
    for (final entry in mapping.entries) {
      final rows = await txn.query(
        'session_mastery_records',
        where: 'word_id = ?',
        whereArgs: [entry.key],
      );
      for (final row in rows) {
        final date = row['date'] as String;
        final rowId = row['id'] as int;
        final existing = await txn.query(
          'session_mastery_records',
          where: 'word_id = ? AND date = ?',
          whereArgs: [entry.value, date],
        );
        if (existing.isEmpty) {
          await txn.update(
            'session_mastery_records',
            {'word_id': entry.value},
            where: 'id = ?',
            whereArgs: [rowId],
          );
          continue;
        }
        //冲突：保留分数较高者，删除旧行
        final oldScore = (row['session_score'] as num?)?.toDouble() ?? 0;
        final newScore =
            (existing.first['session_score'] as num?)?.toDouble() ?? 0;
        if (oldScore > newScore) {
          await txn.update(
            'session_mastery_records',
            {'session_score': oldScore},
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
        await txn.delete(
          'session_mastery_records',
          where: 'id = ?',
          whereArgs: [rowId],
        );
      }
    }
  }

  static Future<void> _migrateWordIds(
    Transaction txn, {
    required String table,
    required Map<int, int> mapping,
    required bool skipOccupied,
  }) async {
    const chunkSize = 400;
    final oldIds = mapping.keys.toList(growable: false);
    for (var i = 0; i < oldIds.length; i += chunkSize) {
      final end = i + chunkSize < oldIds.length ? i + chunkSize : oldIds.length;
      final slice = oldIds.sublist(i, end);
      final placeholders = slice.map((_) => '?').join(',');
      final rows = await txn.query(
        table,
        columns: ['word_id'],
        where: 'word_id IN ($placeholders)',
        whereArgs: slice,
      );
      final present = rows
          .map((row) => row['word_id'] as int)
          .toSet()
          .toList(growable: false);
      if (present.isEmpty) continue;

      var occupied = const <int>{};
      if (skipOccupied) {
        final targetIds = present
            .map((id) => mapping[id]!)
            .toSet()
            .toList(growable: false);
        final targetPlaceholders = targetIds.map((_) => '?').join(',');
        final occupiedRows = await txn.query(
          table,
          columns: ['word_id'],
          where: 'word_id IN ($targetPlaceholders)',
          whereArgs: targetIds,
        );
        occupied = occupiedRows.map((row) => row['word_id'] as int).toSet();
      }
      final occupiedSet = occupied.toSet();
      for (final oldId in present) {
        final newId = mapping[oldId]!;
        if (occupiedSet.contains(newId)) {
          //目标已被占用（新库上该词已有记录，或本批内已有一条旧记录先迁到
          //同一新词——旧库存在仅大小写/空格不同的重复词时会出现）。跳过并
          //保持两边原样：既不覆盖也不删除，稍后随旧词库一并清理。
          //occupiedSet 必须在循环内同步，否则第二条 UPDATE 会撞 UNIQUE
          //约束让整个迁移事务回滚、词库升级失败
          continue;
        }
        await txn.update(
          table,
          {'word_id': newId},
          where: 'word_id = ?',
          whereArgs: [oldId],
        );
        occupiedSet.add(newId);
      }
    }
  }
}

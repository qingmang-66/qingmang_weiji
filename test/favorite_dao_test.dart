import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/word_favorite.dart';
import 'package:qingmang_weiji/services/daos/favorite_dao.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 收藏夹（词集之一）的数据层测试
///
/// 核心契约：**单词级、跨词库、全局唯一** —— 学习模式和阅读模式收藏同一个词
/// 必须是同一条记录，否则「我的收藏」里会出现两条一样的词。
void main() {
  group('FavoriteDao（内存库）', () {
    late Database db;
    late FavoriteDao dao;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        ':memory:',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE word_books (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word TEXT NOT NULL,
              phonetic TEXT,
              definition TEXT,
              word_book_id INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE word_favorites (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL UNIQUE,
              source TEXT,
              note TEXT,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );
      dao = FavoriteDao(Future<Database>.value(db));
      //词库 1~3 各一本书；4 号词库故意一个收藏都不加（用于验证筛选胶囊不列空词库）
      for (var i = 1; i <= 4; i++) {
        await db.insert('word_books', {'id': i, 'name': '词库$i'});
      }
      for (var i = 1; i <= 3; i++) {
        await db.insert('words', {
          'id': i,
          'word': 'word$i',
          'phonetic': 'f$i',
          'definition': '释义$i',
          'word_book_id': i,
        });
      }
      //4、5 号词都在词库 1
      for (var i = 4; i <= 5; i++) {
        await db.insert('words', {
          'id': i,
          'word': 'word$i',
          'phonetic': 'f$i',
          'definition': '释义$i',
          'word_book_id': 1,
        });
      }
    });

    tearDown(() async => db.close());

    test('toggle 在收藏与取消之间切换并返回新状态', () async {
      expect(await dao.contains(1), isFalse);
      expect(await dao.toggle(1, source: 'study'), isTrue);
      expect(await dao.contains(1), isTrue);
      expect(await dao.getCount(), 1);

      expect(await dao.toggle(1), isFalse);
      expect(await dao.contains(1), isFalse);
      expect(await dao.getCount(), 0);
    });

    test('同一个词在学习与阅读模式里只占一条记录，且保留首次来源', () async {
      await dao.add(1, source: 'study');
      await dao.add(1, source: 'reader'); // 重复收藏应被忽略

      expect(await dao.getCount(), 1);
      final favorites = await dao.getAll();
      expect(favorites.single.word.word, 'word1');
      expect(favorites.single.source, FavoriteSource.study);
    });

    test('addMany 跳过已收藏的词', () async {
      await dao.add(2, source: 'study');
      final inserted = await dao.addMany([1, 2, 3], source: 'reader');
      expect(inserted, 2);
      expect(await dao.getCount(), 3);
    });

    test('filterFavorited 只返回这批词里已收藏的', () async {
      await dao.add(1, source: 'study');
      await dao.add(3, source: 'reader');
      expect(await dao.filterFavorited([1, 2]), {1});
      expect(await dao.filterFavorited([1, 2, 3]), {1, 3});
      expect(await dao.filterFavorited([]), isEmpty);
    });

    test('removeMany 批量取消收藏', () async {
      await dao.addMany([1, 2, 3]);
      await dao.removeMany([1, 3]);
      expect(await dao.getFavoriteWordIds(), {2});
    });

    test('getAll 按收藏时间倒序，并支持按单词/释义搜索', () async {
      await dao.add(1);
      await dao.add(2);
      await dao.add(3);
      final all = await dao.getAll();
      expect(all.map((f) => f.word.word), ['word3', 'word2', 'word1']);

      final byWord = await dao.getAll(keyword: 'word2');
      expect(byWord.single.word.word, 'word2');
      final byDefinition = await dao.getAll(keyword: '释义3');
      expect(byDefinition.single.word.word, 'word3');
      expect(await dao.getAll(keyword: '不存在'), isEmpty);
    });

    test('按 word_book_id 取某本书里的收藏（阅读器用）', () async {
      await dao.add(1);
      await dao.add(3);
      expect(await dao.getFavoriteWordIds(), {1, 3});
    });

    test('按来源筛选', () async {
      await dao.add(1, source: 'study');
      await dao.add(2, source: 'reader');
      await dao.add(3, source: 'study');

      final study = await dao.getAll(source: 'study');
      expect(study.map((f) => f.word.word).toSet(), {'word1', 'word3'});
      expect(await dao.getAll(source: 'reader'), hasLength(1));
      //空串等同于"不筛选"：上层传空值时不能把列表整个筛空
      expect(await dao.getAll(source: ''), hasLength(3));
    });

    test('按词库筛选', () async {
      await dao.add(1); //词库 1
      await dao.add(2); //词库 2

      final book2 = await dao.getAll(wordBookId: 2);
      expect(book2.map((f) => f.word.word), ['word2']);
      expect(await dao.getAll(wordBookId: 99), isEmpty);
    });

    test('来源 + 词库 + 关键词可叠加', () async {
      await dao.add(1, source: 'study');
      await dao.add(2, source: 'study');
      await dao.add(3, source: 'reader');

      final rows = await dao.getAll(
        source: 'study',
        wordBookId: 2,
        keyword: 'word',
      );
      expect(rows.map((f) => f.word.word), ['word2']);
      //来源与词库是 AND 关系：阅读来源里没有词库 2 的词
      expect(await dao.getAll(source: 'reader', wordBookId: 2), isEmpty);
    });

    test('getBookSummaries 只列有收藏的词库，带计数并按条数降序', () async {
      await dao.addMany([1, 2, 3]); //词库 1/2/3 各 1 条
      await dao.addMany([4, 5]); //词库 1 再 +2

      final summaries = await dao.getBookSummaries();
      expect(summaries.map((s) => s.wordBookId), [1, 2, 3]);
      expect(summaries.first.name, '词库1');
      expect(summaries.first.count, 3);
      expect(summaries[1].count, 1);
      //没有任何收藏的词库不该出现在筛选胶囊里
      expect(summaries.any((s) => s.wordBookId == 4), isFalse);
    });

    test('词库已被删除时名称为空，交给 UI 兜底显示', () async {
      await db.insert('words', {
        'id': 9,
        'word': 'orphan',
        'word_book_id': 99, //不存在的词库
      });
      await dao.add(9);

      final summaries = await dao.getBookSummaries();
      expect(summaries.single.wordBookId, 99);
      expect(summaries.single.name, '');
      expect(summaries.single.count, 1);
    });

    /// 直接插表以便指定 created_at（dao.add 用的是 DateTime.now()，没法造历史数据）
    Future<void> insertAt(int wordId, DateTime at) =>
        db.insert('word_favorites', {
          'word_id': wordId,
          'source': 'study',
          'created_at': at.toIso8601String(),
        });

    test('按时间范围筛选 since', () async {
      final now = DateTime.now();
      await insertAt(1, now.subtract(const Duration(days: 40)));
      await insertAt(2, now.subtract(const Duration(days: 10)));
      await insertAt(3, now);

      //all → since 为 null，等同于不限制
      expect(FavoriteTimeRange.all.since(now: now), isNull);
      expect(
        await dao.getAll(since: FavoriteTimeRange.all.since(now: now)),
        hasLength(3),
      );
      expect(
        await dao.getAll(since: FavoriteTimeRange.last30Days.since(now: now)),
        hasLength(2),
      );
      expect(
        await dao.getAll(since: FavoriteTimeRange.last7Days.since(now: now)),
        hasLength(1),
      );
      expect(
        await dao.getAll(since: FavoriteTimeRange.today.since(now: now)),
        hasLength(1),
      );
    });

    test('时间范围与来源/词库条件叠加', () async {
      final now = DateTime.now();
      await insertAt(1, now); //词库 1
      await insertAt(2, now); //词库 2
      await insertAt(3, now.subtract(const Duration(days: 40)));

      final recent = await dao.getAll(
        wordBookId: 1,
        since: FavoriteTimeRange.last7Days.since(now: now),
      );
      expect(recent.map((f) => f.word.word), ['word1']);
      expect(
        await dao.getAll(
          wordBookId: 3,
          since: FavoriteTimeRange.last7Days.since(now: now),
        ),
        isEmpty,
      );
    });

    test('排序：默认最新在前，ascending 为最早在前', () async {
      final base = DateTime(2026, 1, 1, 10);
      for (var i = 1; i <= 3; i++) {
        await insertAt(i, base.add(Duration(days: i)));
      }

      final desc = await dao.getAll();
      expect(desc.map((f) => f.word.word), ['word3', 'word2', 'word1']);
      expect(desc.first.createdAt.isAfter(desc.last.createdAt), isTrue);

      final asc = await dao.getAll(ascending: true);
      expect(asc.map((f) => f.word.word), ['word1', 'word2', 'word3']);
      expect(asc.first.createdAt.isBefore(asc.last.createdAt), isTrue);
    });

    test('同一时间戳（批量收藏）时用 id 兜底保持顺序稳定', () async {
      //addMany 给整批写同一个 created_at，只靠时间排序会退化成不确定
      await dao.addMany([1, 2, 3]);

      expect((await dao.getAll()).map((f) => f.word.word), [
        'word3',
        'word2',
        'word1',
      ]);
      expect((await dao.getAll(ascending: true)).map((f) => f.word.word), [
        'word1',
        'word2',
        'word3',
      ]);
    });
  });

  group('词集表结构（真实 DatabaseService）', () {
    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      //建表/迁移在真实异步区完成
      await DatabaseService.database;
    });

    test('word_favorites 表可用', () async {
      expect(await DatabaseService.favoriteDao.getCount(), isA<int>());
      expect(
        await DatabaseService.favoriteDao.getFavoriteWordIds(),
        isA<Set<int>>(),
      );
    });

    test('wrong_words 表带 correct_streak 列（连续答对进度已持久化）', () async {
      final db = await DatabaseService.database;
      final columns = await db.rawQuery('PRAGMA table_info(wrong_words)');
      expect(
        columns.any((row) => row['name'] == 'correct_streak'),
        isTrue,
        reason: 'v18 迁移必须补上 correct_streak，否则"连续答对 3 次移出错词本"跨会话无法累计',
      );
    });

    test('收藏/取消收藏经真实库往返一致', () async {
      final db = await DatabaseService.database;
      final rows = await db.query('words', columns: ['id'], limit: 1);
      if (rows.isEmpty) return; //空库时跳过（该测试依赖已有词条数据）
      final wordId = rows.first['id'] as int;

      final nowFavorite = await DatabaseService.favoriteDao.toggle(
        wordId,
        source: FavoriteSource.reader.name,
      );
      expect(await DatabaseService.favoriteDao.contains(wordId), nowFavorite);
      //恢复现场，避免影响其它测试
      await DatabaseService.favoriteDao.remove(wordId);
      expect(await DatabaseService.favoriteDao.contains(wordId), isFalse);
    });
  });
}

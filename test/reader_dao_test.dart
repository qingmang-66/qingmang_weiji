import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/daos/reader_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReaderDao', () {
    late Database db;
    late ReaderDao dao;

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
              word_book_id INTEGER NOT NULL,
              FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE reader_marks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL UNIQUE,
              created_at TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
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
          await db.execute('''
            CREATE TABLE reader_progress (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_book_id INTEGER NOT NULL UNIQUE,
              word_index INTEGER NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
            )
          ''');
          //两本词书，各若干词
          await db.insert('word_books', {'name': 'book1'});
          await db.insert('word_books', {'name': 'book2'});
          for (var i = 1; i <= 3; i++) {
            await db.insert('words', {'word': 'w$i', 'word_book_id': 1});
          }
          await db.insert('words', {'word': 'x1', 'word_book_id': 2});
        },
      );
      dao = ReaderDao(Future.value(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('toggleMark 切换勾记', () async {
      expect(await dao.toggleMark(1), true);
      expect(await dao.getMarkedWordIds(1), {1});
      //再次切换为取消
      expect(await dao.toggleMark(1), false);
      expect(await dao.getMarkedWordIds(1), isEmpty);
    });

    test('getMarkedWordIds 只统计指定词书', () async {
      await dao.toggleMark(1);
      await dao.toggleMark(4); //book2的词
      expect(await dao.getMarkedWordIds(1), {1});
      expect(await dao.getMarkedWordIds(2), {4});
    });

    test('getMarkCounts 总数与区间统计', () async {
      await dao.toggleMark(1);
      await dao.toggleMark(2);
      //手工插入一条昨天的勾记
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      await db.insert('reader_marks', {'word_id': 3, 'created_at': yesterday});
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final r = await dao.getMarkCounts(
        start: today,
        end: today.add(const Duration(days: 1)),
      );
      expect(r.total, 3);
      //今天的两条计入区间，昨天那条不计
      expect(r.range, 2);
    });

    test('书签增删改查与时间戳', () async {
      final id1 = await dao.addBookmark(bookId: 1, wordIndex: 0);
      await dao.addBookmark(bookId: 1, wordIndex: 2, customName: '我的书签');
      final list = await dao.getBookmarks(1);
      expect(list.length, 2);
      expect(list[0].id, id1);
      expect(list[0].wordIndex, 0);
      expect(list[0].customName, isNull);
      //时间戳为有效日期
      expect(
        list[0].createdAt.isBefore(
          DateTime.now().add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(list[1].customName, '我的书签');
      //按创建顺序返回
      expect(list[0].id < list[1].id, isTrue);

      await dao.renameBookmark(id1, '改名');
      expect((await dao.getBookmarks(1)).first.customName, '改名');

      await dao.deleteBookmark(id1);
      expect((await dao.getBookmarks(1)).length, 1);
    });

    test('hasBookmarkAt 位置查重', () async {
      await dao.addBookmark(bookId: 1, wordIndex: 5);
      expect(await dao.hasBookmarkAt(1, 5), isTrue);
      expect(await dao.hasBookmarkAt(1, 6), isFalse);
      expect(await dao.hasBookmarkAt(2, 5), isFalse);
    });

    test('saveProgress 插入与更新', () async {
      await dao.saveProgress(bookId: 1, wordIndex: 10);
      expect(await dao.getProgress(1), 10);
      //再次保存为更新，不产生新行
      await dao.saveProgress(bookId: 1, wordIndex: 20);
      expect(await dao.getProgress(1), 20);
      final rows = await db.query('reader_progress');
      expect(rows.length, 1);

      expect(await dao.getProgress(2), isNull);
    });
  });
}

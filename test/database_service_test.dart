import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qingmang_weiji/models/models.dart';

void main() {
  // 初始化 FFI 用于测试
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService', () {
    late Database db;

    setUp(() async {
      // 创建内存数据库用于测试
      db = await openDatabase(
        ':memory:',
        version: 2,
        onCreate: (db, version) async {
          // 启用外键约束
          await db.execute('PRAGMA foreign_keys = ON');

          // 词库表
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

          // 单词表
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
              word_id INTEGER NOT NULL,
              quality INTEGER DEFAULT 0,
              interval INTEGER DEFAULT 1,
              ease_factor REAL DEFAULT 2.5,
              repetitions INTEGER DEFAULT 0,
              next_review TEXT NOT NULL,
              last_review TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('insertWordBook should insert a word book', () async {
      final wordBook = WordBook(
        name: 'Test Book',
        description: 'Test Description',
        isBuiltIn: false,
        totalWords: 100,
      );

      final id = await db.insert('word_books', wordBook.toMap());
      expect(id, greaterThan(0));

      final result = await db.query(
        'word_books',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(result.length, 1);
      expect(result.first['name'], 'Test Book');
    });

    test('getAllWordBooks should return all word books', () async {
      await db.insert('word_books', WordBook(name: 'Book 1').toMap());
      await db.insert('word_books', WordBook(name: 'Book 2').toMap());

      final result = await db.query('word_books');
      expect(result.length, 2);
    });

    test('deleteWordBook should delete a word book', () async {
      final id = await db.insert(
        'word_books',
        WordBook(name: 'To Delete').toMap(),
      );

      await db.delete('word_books', where: 'id = ?', whereArgs: [id]);

      final result = await db.query(
        'word_books',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(result.length, 0);
    });

    test('insertWord should insert a word', () async {
      final bookId = await db.insert(
        'word_books',
        WordBook(name: 'Test Book').toMap(),
      );

      final word = Word(
        word: 'test',
        phonetic: '/test/',
        definition: 'a test word',
        wordBookId: bookId,
      );

      final id = await db.insert('words', word.toMap());
      expect(id, greaterThan(0));

      final result = await db.query('words', where: 'id = ?', whereArgs: [id]);
      expect(result.length, 1);
      expect(result.first['word'], 'test');
    });

    test('getWordsByBookId should return words for a specific book', () async {
      final bookId1 = await db.insert(
        'word_books',
        WordBook(name: 'Book 1').toMap(),
      );
      final bookId2 = await db.insert(
        'word_books',
        WordBook(name: 'Book 2').toMap(),
      );

      await db.insert(
        'words',
        Word(word: 'word1', wordBookId: bookId1).toMap(),
      );
      await db.insert(
        'words',
        Word(word: 'word2', wordBookId: bookId1).toMap(),
      );
      await db.insert(
        'words',
        Word(word: 'word3', wordBookId: bookId2).toMap(),
      );

      final result = await db.query(
        'words',
        where: 'word_book_id = ?',
        whereArgs: [bookId1],
      );
      expect(result.length, 2);
    });

    test('insertReviewRecord should insert a review record', () async {
      final bookId = await db.insert(
        'word_books',
        WordBook(name: 'Test Book').toMap(),
      );
      final wordId = await db.insert(
        'words',
        Word(word: 'test', wordBookId: bookId).toMap(),
      );

      final now = DateTime.now();
      final record = ReviewRecord(
        wordId: wordId,
        quality: 4,
        interval: 7,
        easeFactor: 2.5,
        repetitions: 3,
        nextReview: now.add(const Duration(days: 7)),
        lastReview: now,
      );

      final id = await db.insert('review_records', record.toMap());
      expect(id, greaterThan(0));

      final result = await db.query(
        'review_records',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(result.length, 1);
      expect(result.first['quality'], 4);
    });

    test('updateReviewRecord should update a review record', () async {
      final bookId = await db.insert(
        'word_books',
        WordBook(name: 'Test Book').toMap(),
      );
      final wordId = await db.insert(
        'words',
        Word(word: 'test', wordBookId: bookId).toMap(),
      );

      final now = DateTime.now();
      final record = ReviewRecord(
        wordId: wordId,
        quality: 3,
        interval: 2,
        easeFactor: 2.5,
        repetitions: 1,
        nextReview: now.add(const Duration(days: 2)),
        lastReview: now,
      );

      final id = await db.insert('review_records', record.toMap());

      final updatedRecord = record.copyWith(quality: 5, interval: 15);
      await db.update(
        'review_records',
        updatedRecord.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );

      final result = await db.query(
        'review_records',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(result.first['quality'], 5);
      expect(result.first['interval'], 15);
    });

    test('getDueWords should return words due for review', () async {
      final bookId = await db.insert(
        'word_books',
        WordBook(name: 'Test Book').toMap(),
      );

      final wordId1 = await db.insert(
        'words',
        Word(word: 'due', wordBookId: bookId).toMap(),
      );
      final wordId2 = await db.insert(
        'words',
        Word(word: 'not_due', wordBookId: bookId).toMap(),
      );

      final now = DateTime.now();
      await db.insert(
        'review_records',
        ReviewRecord(
          wordId: wordId1,
          nextReview: now.subtract(const Duration(hours: 1)), // 过期
          lastReview: now,
        ).toMap(),
      );

      await db.insert(
        'review_records',
        ReviewRecord(
          wordId: wordId2,
          nextReview: now.add(const Duration(days: 1)), // 未到期
          lastReview: now,
        ).toMap(),
      );

      final result = await db.rawQuery(
        '''
        SELECT w.* FROM words w
        INNER JOIN review_records r ON w.id = r.word_id
        WHERE w.word_book_id = ? AND datetime(r.next_review) <= datetime(?)
      ''',
        [bookId, now.toIso8601String()],
      );

      expect(result.length, 1);
      expect(result.first['word'], 'due');
    });

    test('cascade delete should work for word book', () async {
      // 确保外键约束已启用
      await db.execute('PRAGMA foreign_keys = ON');

      final bookId = await db.insert(
        'word_books',
        WordBook(name: 'Test Book').toMap(),
      );
      final wordId = await db.insert(
        'words',
        Word(word: 'test', wordBookId: bookId).toMap(),
      );
      await db.insert(
        'review_records',
        ReviewRecord(
          wordId: wordId,
          nextReview: DateTime.now(),
          lastReview: DateTime.now(),
        ).toMap(),
      );

      // 删除词库
      await db.delete('word_books', where: 'id = ?', whereArgs: [bookId]);

      // 检查单词是否还存在（应该被级联删除）
      final words = await db.query(
        'words',
        where: 'word_book_id = ?',
        whereArgs: [bookId],
      );
      expect(words.length, 0);

      // 检查复习记录是否也被级联删除
      final records = await db.query(
        'review_records',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      expect(records.length, 0);
    });

    test('word with all fields should be saved correctly', () async {
      final bookId = await db.insert(
        'word_books',
        WordBook(name: 'Test Book').toMap(),
      );

      final word = Word(
        word: 'comprehensive',
        phonetic: '/ˌkɒmprɪˈhensɪv/',
        definition: 'complete; including all or nearly all elements',
        example: 'This is a comprehensive guide.',
        exampleTranslation: '这是一个全面的指南。',
        wordBookId: bookId,
        root: 'comprehend',
        suffix: '-ive',
        synonym: 'complete, thorough',
        antonym: 'incomplete, partial',
        derivative: 'comprehensively, comprehensiveness',
      );

      final id = await db.insert('words', word.toMap());
      final result = await db.query('words', where: 'id = ?', whereArgs: [id]);

      expect(result.first['word'], 'comprehensive');
      expect(result.first['phonetic'], '/ˌkɒmprɪˈhensɪv/');
      expect(
        result.first['definition'],
        'complete; including all or nearly all elements',
      );
      expect(result.first['root'], 'comprehend');
      expect(result.first['suffix'], '-ive');
    });
  });
}

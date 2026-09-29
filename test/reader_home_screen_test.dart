import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qingmang_weiji/models/models.dart';
import 'package:qingmang_weiji/screens/reader_home_screen.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:qingmang_weiji/services/di_container.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';
import 'package:qingmang_weiji/services/repositories/review_repository.dart';
import 'package:qingmang_weiji/services/repositories/wordbook_repository.dart';

class FakeWordBookRepository extends WordBookRepository {
  List<WordBook> books = [];

  @override
  Future<List<WordBook>> getAllWordBooks({bool withCounts = true}) async =>
      books;
}

class FakeReviewRepository extends ReviewRepository {
  @override
  Future<int> getDueWordCount(int bookId) async => 0;

  @override
  Future<int> getTodayNewWordCount(int bookId) async => 0;

  @override
  Future<WordBookProgress> getWordBookProgress(int bookId) async =>
      WordBookProgress(
        bookId: bookId,
        totalWords: 0,
        unlearnedWords: 0,
        dueWords: 0,
      );
}

Widget app(WordBookProvider provider) => MultiProvider(
  providers: [
    Provider.value(value: DIContainer.instance),
    ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ChangeNotifierProvider<WordBookProvider>.value(value: provider),
  ],
  child: const MaterialApp(home: ReaderHomeScreen()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeBooks = FakeWordBookRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DIContainer.instance.wordBookRepository = fakeBooks;
    DIContainer.instance.reviewRepository = FakeReviewRepository();
    //预热数据库，建表在真实异步区完成
    await DatabaseService.database;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseService.database;
    await db.delete('reader_progress');
    //清除词书，满足外键约束
    await db.delete('words');
    await db.delete('word_books');
    fakeBooks.books = [];
  });

  Future<void> pumpShelf(WidgetTester tester, WordBookProvider provider) async {
    await tester.pumpWidget(app(provider));
    await tester.pump();
    //真实异步IO，用 runAsync 等待加载完成
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  testWidgets('空词书显示引导提示', (tester) async {
    final provider = WordBookProvider();
    await provider.init();
    await pumpShelf(tester, provider);
    expect(find.textContaining('还没有词书'), findsOneWidget);
  });

  testWidgets('显示词书卡片和阅读进度', (tester) async {
    //testWidgets 内直接 await 真实IO会挂起，播种需包在 runAsync 里
    await tester.runAsync(() async {
      final db = await DatabaseService.database;
      //播种词书和单词
      await db.insert('word_books', {
        'id': 1,
        'name': '测试词书',
        'total_words': 4,
      });
      for (var i = 1; i <= 4; i++) {
        await db.insert('words', {'id': i, 'word': 'w$i', 'word_book_id': 1});
      }
      //已读到第3个词（序号2）
      await DatabaseService.readerDao.saveProgress(bookId: 1, wordIndex: 2);
    });

    fakeBooks.books = [WordBook(id: 1, name: '测试词书', totalWords: 4)];
    final provider = WordBookProvider();
    await provider.init();
    await pumpShelf(tester, provider);

    expect(find.text('测试词书'), findsOneWidget);
    expect(find.textContaining('4 词'), findsOneWidget);
    //进度：已读 3/4 · 75%
    expect(find.textContaining('已读 3/4'), findsOneWidget);
  });
}

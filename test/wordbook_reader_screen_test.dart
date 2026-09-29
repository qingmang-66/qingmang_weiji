import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qingmang_weiji/models/models.dart';
import 'package:qingmang_weiji/screens/wordbook_reader_screen.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:qingmang_weiji/services/di_container.dart';
import 'package:qingmang_weiji/services/providers/reader_settings_provider.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/services/repositories/word_repository.dart';
import 'package:qingmang_weiji/services/repositories/wordbook_repository.dart';

class FakeWordRepository extends WordRepository {
  List<Word> words = [];

  @override
  Future<List<Word>> getWordsByBook(
    int bookId, {
    int? limit,
    int? offset,
  }) async => words;
}

class FakeWordBookRepository extends WordBookRepository {
  @override
  Future<WordBook?> getWordBook(int id) async => WordBook(id: id, name: '测试词书');
}

Word w(String text, int id) => Word(
  id: id,
  wordBookId: 1,
  word: text,
  phonetic: '/test/',
  definition: '$text 释义',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeWords = FakeWordRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DIContainer.instance.wordRepository = fakeWords;
    DIContainer.instance.wordBookRepository = FakeWordBookRepository();
    //预热数据库，建表在真实异步区完成
    await DatabaseService.database;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseService.database;
    await db.delete('reader_marks');
    await db.delete('reader_bookmarks');
    await db.delete('reader_progress');
    //播种词书和单词，满足 reader 表外键约束（先清旧数据避免主键冲突）
    await db.delete('words', where: 'word_book_id = ?', whereArgs: [1]);
    await db.delete('word_books', where: 'id = ?', whereArgs: [1]);
    await db.insert('word_books', {'id': 1, 'name': '测试词书'});
    for (var i = 1; i <= 5; i++) {
      await db.insert('words', {'id': i, 'word': 'seed$i', 'word_book_id': 1});
    }
  });

  Future<void> pumpReader(WidgetTester tester) async {
    final settings = ReaderSettingsProvider();
    await settings.loadPreferences();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: DIContainer.instance),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(home: WordbookReaderScreen(bookId: 1)),
      ),
    );
    await tester.pump();
    //sqflite ffi 是真实异步IO，用 runAsync 等待数据加载完成
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    //沉浸式交互：顶栏/底栏默认收起，点击屏幕中间唤出后再操作
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
  }

  test('诊断：DatabaseService 阅读表可用', () async {
    final marks = await DatabaseService.readerDao.getMarkedWordIds(1);
    final bookmarks = await DatabaseService.readerDao.getBookmarks(1);
    final progress = await DatabaseService.readerDao.getProgress(1);
    expect(marks, isEmpty);
    expect(bookmarks, isEmpty);
    expect(progress, isNull);
  });

  testWidgets('渲染词条并显示书名', (tester) async {
    fakeWords.words = [for (var i = 1; i <= 5; i++) w('word$i', i)];
    await pumpReader(tester);
    expect(find.text('word1'), findsOneWidget);
    expect(find.text('word2'), findsOneWidget);
    expect(find.textContaining('测试词书'), findsOneWidget);
  });

  //等待真实异步DB写入完成并刷新
  Future<void> settleDb(WidgetTester tester) async {
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  //SnackBar 的自动消失定时器在 runAsync 真实时钟下创建，fake pump 推不动它，
  //会一直悬浮挡住底栏按钮；用 clearSnackBars 立即移除
  Future<void> dismissSnack(WidgetTester tester) async {
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).clearSnackBars();
    await tester.pumpAndSettle();
  }

  testWidgets('长按词条勾记后显示勾选图标', (tester) async {
    fakeWords.words = [for (var i = 1; i <= 3; i++) w('word$i', i)];
    await pumpReader(tester);
    await tester.longPress(find.text('word2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记住了'));
    await settleDb(tester);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    //再次长按可取消
    await tester.longPress(find.text('word2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消记住'));
    await settleDb(tester);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('添加书签并在列表中显示日期', (tester) async {
    fakeWords.words = [for (var i = 1; i <= 3; i++) w('word$i', i)];
    await pumpReader(tester);
    await tester.tap(find.byIcon(Icons.bookmark_add));
    await settleDb(tester);
    await dismissSnack(tester);
    //打开书签列表，应有以单词+释义命名的条目和日期
    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();
    //书签标题为"单词 释义"，与页面释义区分开
    expect(find.text('word1 word1 释义'), findsOneWidget);
    //副标题包含日期时间（yyyy-MM-dd HH:mm）
    expect(
      find.textContaining(RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}')),
      findsOneWidget,
    );
  });

  testWidgets('数字标签命名模式', (tester) async {
    fakeWords.words = [for (var i = 1; i <= 3; i++) w('word$i', i)];
    await pumpReader(tester);
    await tester.tap(find.byIcon(Icons.bookmark_add));
    await settleDb(tester);
    await dismissSnack(tester);
    //切换为数字标签命名（顶栏不再放设置按钮，唯一入口是底栏的「阅读设置」）。
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    //设置面板改为二级导航：先进「书签」分组再选命名方式
    await tester.ensureVisible(find.text('书签命名方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('书签命名方式'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('数字标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('数字标签'));
    await settleDb(tester);
    await tester.pumpAndSettle();
    //返回键/点遮罩在二级卡片里先退回一级列表，再点一次才关闭整个面板
    //（此前会一步直接关掉面板，用户反馈"返回直接从二级全部退出"）
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();
    expect(find.text('书签 1'), findsOneWidget);
  });

  testWidgets('长按菜单可在此处添加书签', (tester) async {
    fakeWords.words = [for (var i = 1; i <= 3; i++) w('word$i', i)];
    await pumpReader(tester);
    await tester.longPress(find.text('word2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在此处添加书签'));
    await settleDb(tester);
    await dismissSnack(tester);
    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();
    expect(find.text('word2 word2 释义'), findsOneWidget);
  });

  testWidgets('删除书签后列表立即刷新', (tester) async {
    fakeWords.words = [for (var i = 1; i <= 3; i++) w('word$i', i)];
    await pumpReader(tester);
    await tester.tap(find.byIcon(Icons.bookmark_add));
    await settleDb(tester);
    await dismissSnack(tester);
    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();
    expect(find.text('word1 word1 释义'), findsOneWidget);
    //打开书签操作菜单并删除
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除书签'));
    await tester.pumpAndSettle();
    await settleDb(tester);
    await tester.pumpAndSettle();
    //无需关闭重开，列表立即变为空态
    expect(find.text('word1 word1 释义'), findsNothing);
    expect(find.text('还没有书签'), findsOneWidget);
  });

  testWidgets('空词书显示空态', (tester) async {
    fakeWords.words = [];
    await pumpReader(tester);
    expect(find.text('当前词库还没有单词，请导入内置词库或添加单词。'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/models/models.dart';
import 'package:qingmang_weiji/screens/achievement_center_screen.dart';
import 'package:qingmang_weiji/screens/favorites_screen.dart';
import 'package:qingmang_weiji/screens/search_screen.dart';
import 'package:qingmang_weiji/services/di_container.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';
import 'package:qingmang_weiji/services/repositories/achievement_repository.dart';
import 'package:qingmang_weiji/services/repositories/favorite_repository.dart';
import 'package:qingmang_weiji/services/repositories/search_history_repository.dart';
import 'package:qingmang_weiji/services/repositories/word_repository.dart';

class FakeWordRepository extends WordRepository {
  final Map<String, Completer<List<Word>>> pending = {};
  final List<String> queries = [];

  @override
  Future<List<Word>> searchAllWords(
    String query, {
    int limit = 100,
    bool inWordFieldOnly = false,
  }) {
    queries.add(query);
    return pending.putIfAbsent(query, Completer<List<Word>>.new).future;
  }
}

class FakeSearchHistoryRepository extends SearchHistoryRepository {
  @override
  Future<List<SearchHistoryItem>> recent({int limit = 10}) =>
      Future<List<SearchHistoryItem>>.value(const []);

  @override
  Future<void> record(String query) => Future<void>.value();
}

class FavoriteCall {
  FavoriteCall(this.group, this.sort, this.completer);

  final String? group;
  final FavoriteSortMode sort;
  final Completer<List<Word>> completer;
}

class FakeFavoriteRepository extends FavoriteRepository {
  final List<FavoriteCall> calls = [];
  bool initialLoaded = false;

  @override
  Future<List<MapEntry<String, int>>> getGroups() async => const [
    MapEntry('A组', 1),
    MapEntry('B组', 1),
  ];

  @override
  Future<List<Word>> getFavoriteWords({
    String? groupName,
    FavoriteSortMode orderBy = FavoriteSortMode.createdDesc,
  }) {
    if (!initialLoaded) {
      initialLoaded = true;
      return Future.value([word('初始', 1)]);
    }
    final completer = Completer<List<Word>>();
    calls.add(FavoriteCall(groupName, orderBy, completer));
    return completer.future;
  }

  @override
  Future<List<FavoriteWord>> getAllFavorites({String? groupName}) async => [];
}

class FakeAchievementRepository implements AchievementRepository {
  int calls = 0;

  @override
  Future<List<AchievementProgress>> loadAndCheck() async {
    calls++;
    if (calls == 1) throw StateError('加载失败');
    return const [];
  }

  @override
  Future<List<AchievementProgress>> loadAll() async => const [];

  @override
  Future<List<AchievementProgress>> getRecent({int limit = 3}) async =>
      const [];

  @override
  Stream<List<AchievementProgress>> get newlyUnlockedStream =>
      const Stream.empty();
}

Word word(String text, int id) =>
    Word(id: id, wordBookId: 1, word: text, definition: '$text释义');

Widget app(Widget home, {bool withWordBooks = false}) {
  return MultiProvider(
    providers: [
      Provider.value(value: DIContainer.instance),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      if (withWordBooks)
        ChangeNotifierProvider(create: (_) => WordBookProvider()),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> pumpFrames(WidgetTester tester, [int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump();
  }
}

Future<void> selectSort(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.sort));
  //背景有持续动画，不能用pumpAndSettle
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final item = find.text(label).last;
  await tester.tap(item);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final words = FakeWordRepository();
  final history = FakeSearchHistoryRepository();
  final favorites = FakeFavoriteRepository();
  final achievements = FakeAchievementRepository();

  setUpAll(() {
    DIContainer.instance.wordRepository = words;
    DIContainer.instance.searchHistoryRepository = history;
    DIContainer.instance.favoriteRepository = favorites;
    DIContainer.instance.achievementRepository = achievements;
  });

  setUp(() {
    words.pending.clear();
    words.queries.clear();
    favorites.calls.clear();
    favorites.initialLoaded = false;
  });

  testWidgets('搜索只提交最新请求结果', (tester) async {
    await tester.pumpWidget(app(const SearchScreen(), withWordBooks: true));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 300));

    expect(words.pending.containsKey('new'), isTrue);
    words.pending['new']!.complete([word('new-result', 2)]);
    await pumpFrames(tester);
    //搜索结果用RichText高亮，需开启findRichText
    expect(find.text('new-result', findRichText: true), findsOneWidget);

    words.pending['old']!.complete([word('old-result', 1)]);
    await pumpFrames(tester);
    expect(find.text('new-result', findRichText: true), findsOneWidget);
    expect(find.text('old-result', findRichText: true), findsNothing);
  });

  testWidgets('清空查询后可再次搜索相同内容', (tester) async {
    await tester.pumpWidget(app(const SearchScreen(), withWordBooks: true));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'same');
    await tester.pump(const Duration(milliseconds: 300));
    words.pending['same']!.complete([word('same-result', 3)]);
    await tester.pump();

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    words.pending.remove('same');
    await tester.enterText(find.byType(TextField), 'same');
    await tester.pump(const Duration(milliseconds: 300));

    expect(words.queries.where((q) => q == 'same').length, 2);
  });

  testWidgets('收藏排序只提交最新筛选快照结果', (tester) async {
    await tester.pumpWidget(app(const FavoritesScreen()));
    await tester.pump();
    await tester.pump();

    await selectSort(tester, '字母 A→Z');
    await selectSort(tester, '最近复习');

    expect(favorites.calls.length, greaterThanOrEqualTo(2));
    final oldCall = favorites.calls[0];
    final newCall = favorites.calls[1];
    newCall.completer.complete([word('最新排序', 5)]);
    await pumpFrames(tester);
    oldCall.completer.complete([word('旧排序', 4)]);
    await pumpFrames(tester);

    expect(find.text('最新排序'), findsOneWidget);
    expect(find.text('旧排序'), findsNothing);
  });

  testWidgets('收藏分组只提交最新筛选快照结果', (tester) async {
    await tester.pumpWidget(app(const FavoritesScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('A组 (1)'), findsOneWidget);
    expect(find.text('B组 (1)'), findsOneWidget);

    await tester.tap(find.text('A组 (1)'));
    await tester.pump();
    await tester.tap(find.text('B组 (1)'));
    await tester.pump();

    expect(favorites.calls.length, greaterThanOrEqualTo(2));
    final oldCall = favorites.calls[0];
    final newCall = favorites.calls[1];
    newCall.completer.complete([word('B组结果', 7)]);
    await pumpFrames(tester);
    oldCall.completer.complete([word('A组旧结果', 6)]);
    await pumpFrames(tester);

    expect(find.text('B组结果'), findsOneWidget);
    expect(find.text('A组旧结果'), findsNothing);
  });

  testWidgets('成就加载失败后停止加载并提供重试', (tester) async {
    await tester.pumpWidget(app(const AchievementCenterScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('加载成就失败'), findsWidgets);
    expect(find.text('重试'), findsWidgets);

    await tester.tap(find.text('重试').first);
    await tester.pump();
    expect(achievements.calls, 2);
    expect(find.text('该类别暂无成就'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

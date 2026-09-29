import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/models/models.dart';
import 'package:qingmang_weiji/screens/pre_study_screen.dart';
import 'package:qingmang_weiji/services/di_container.dart';
import 'package:qingmang_weiji/services/providers/study_settings_provider.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/services/repositories/review_repository.dart';

class FakeReviewRepository extends ReviewRepository {
  FakeReviewRepository({this.error, this.completer, this.initialRecord});

  final Object? error;
  final Completer<ReviewRecord?>? completer;
  final ReviewRecord? initialRecord;
  final List<ReviewRecord> savedRecords = [];
  int calls = 0;
  int saveFailures = 0;

  @override
  Future<ReviewRecord?> getReviewRecord(int wordId) async {
    calls++;
    if (error != null) throw error!;
    if (completer != null) return completer!.future;
    return initialRecord;
  }

  @override
  Future<Map<int, ReviewRecord?>> getReviewRecordsByWordIds(
    List<int> wordIds,
  ) async {
    final record = await getReviewRecord(wordIds.first);
    return {for (final id in wordIds) id: record};
  }

  @override
  Future<int> saveReviewRecord(ReviewRecord record, {int? bookId}) async {
    savedRecords.add(record);
    if (saveFailures > 0) {
      saveFailures--;
      throw StateError('save failed');
    }
    return record.id ?? 1;
  }
}

Widget buildScreen({
  required List<Word> words,
  required FakeReviewRepository repository,
  int mode = 1,
}) {
  return MultiProvider(
    providers: [
      Provider.value(value: DIContainer.instance),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => StudySettingsProvider()),
    ],
    child: MaterialApp(
      home: DirectStudyScreen(
        isReview: false,
        wordBookId: 1,
        presetWords: words,
        studyMode: mode,
        reviewRepository: repository,
      ),
    ),
  );
}

void main() {
  final word = Word(id: 1, wordBookId: 1, word: 'apple', definition: '苹果');

  testWidgets('五种学习模式均可完成初始化', (tester) async {
    for (var mode = 1; mode <= 5; mode++) {
      await tester.pumpWidget(
        buildScreen(
          words: [word],
          repository: FakeReviewRepository(),
          mode: mode,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '模式$mode初始化失败');
      expect(find.textContaining('1 / 1'), findsOneWidget);
    }
  });

  testWidgets('空列表显示可返回空状态且不预加载', (tester) async {
    final repository = FakeReviewRepository();
    await tester.pumpWidget(
      buildScreen(words: const [], repository: repository),
    );
    await tester.pump();

    expect(find.text('暂无可学习单词'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缺少数据库ID的单词会被过滤', (tester) async {
    final repository = FakeReviewRepository();
    final noId = Word(wordBookId: 1, word: 'invalid', definition: '无效');
    await tester.pumpWidget(
      buildScreen(words: [noId, word], repository: repository),
    );
    await tester.pump();

    expect(repository.calls, 1);
    expect(find.textContaining('1 / 1'), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预加载失败停止准备并显示错误', (tester) async {
    await tester.pumpWidget(
      buildScreen(
        words: [word],
        repository: FakeReviewRepository(error: StateError('database failed')),
      ),
    );
    await tester.pump();

    expect(find.text('学习初始化失败'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    expect(find.text('apple'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败后重试仍基于持久化前记录', (tester) async {
    final initial = ReviewRecord(
      wordId: 1,
      quality: 3,
      interval: 6,
      easeFactor: 2.5,
      repetitions: 2,
      nextReview: DateTime(2026, 7, 20),
      lastReview: DateTime(2026, 7, 14),
    );
    final repository = FakeReviewRepository(initialRecord: initial)
      ..saveFailures = 1;
    final nextWord = Word(
      id: 2,
      wordBookId: 1,
      word: 'banana',
      definition: '香蕉',
    );
    await tester.pumpWidget(
      buildScreen(words: [word, nextWord], repository: repository),
    );
    await tester.pump();

    //三档评分不再依赖"先显示释义"：底部只有 不认识 / 模糊 / 认识，
    //想不起来也可以直接评分（释义由延时或点空白处出现）
    expect(find.text('显示释义'), findsNothing);
    await tester.tap(find.text('认识'));
    await tester.pump();
    //第一次保存失败（saveFailures=1）后按钮恢复可点，再点一次走重试路径
    await tester.tap(find.text('认识'));
    await tester.pump();

    expect(repository.savedRecords, hasLength(2));
    expect(
      repository.savedRecords[1].interval,
      repository.savedRecords[0].interval,
    );
    expect(
      repository.savedRecords[1].repetitions,
      repository.savedRecords[0].repetitions,
    );
  });

  testWidgets('dispose后预加载完成不会setState', (tester) async {
    final completer = Completer<ReviewRecord?>();
    await tester.pumpWidget(
      buildScreen(
        words: [word],
        repository: FakeReviewRepository(completer: completer),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    completer.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

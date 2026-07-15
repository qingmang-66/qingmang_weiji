import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/daos/review_dao.dart';
import 'package:qingmang_weiji/services/daos/study_plan_dao.dart';
import 'package:qingmang_weiji/services/daos/word_dao.dart';
import 'package:qingmang_weiji/services/repositories/review_repository.dart';
import 'package:qingmang_weiji/services/repositories/study_plan_repository.dart';
import 'package:qingmang_weiji/services/repositories/word_repository.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  final failure = StateError('database unavailable');
  final failureMatcher = isA<StateError>().having(
    (e) => e.message,
    'message',
    'database unavailable',
  );

  //先挂上await监听，再completeError，避免未处理异步异常
  Future<void> expectFails(
    Future<void> Function() action,
    Completer<Database> db,
  ) async {
    final result = expectLater(action(), throwsA(failureMatcher));
    db.completeError(failure);
    await result;
  }

  group('ReviewRepository关键读取错误契约', () {
    late Completer<Database> db;
    late ReviewRepository repository;

    setUp(() {
      db = Completer<Database>();
      repository = ReviewRepository(
        wordDao: WordDao(db.future),
        reviewDao: ReviewDao(db.future),
      );
    });

    test('学习可用性查询传播数据库异常', () async {
      await expectFails(
        () => repository.getStudyAvailability(
          1,
          isReview: false,
          dailyNewLimit: 20,
          dailyReviewLimit: 50,
        ),
        db,
      );
    });

    test('批量复习记录查询传播数据库异常', () async {
      await expectFails(
        () => repository.getReviewRecordsByWordIds(const [1, 2]),
        db,
      );
    });

    test('业务计数查询传播数据库异常', () async {
      await expectFails(() => repository.getDueWordCount(1), db);
      db = Completer<Database>();
      repository = ReviewRepository(
        wordDao: WordDao(db.future),
        reviewDao: ReviewDao(db.future),
      );
      await expectFails(() => repository.getTodayNewWordCount(1), db);
      db = Completer<Database>();
      repository = ReviewRepository(
        wordDao: WordDao(db.future),
        reviewDao: ReviewDao(db.future),
      );
      await expectFails(() => repository.getTodayReviewedWordCount(1), db);
      db = Completer<Database>();
      repository = ReviewRepository(
        wordDao: WordDao(db.future),
        reviewDao: ReviewDao(db.future),
      );
      await expectFails(() => repository.getUnlearnedWordCount(1), db);
    });
  });

  group('StudyPlanRepository关键读取错误契约', () {
    test('活动计划和计划列表查询传播数据库异常', () async {
      var db = Completer<Database>();
      var repository = StudyPlanRepository(
        studyPlanDao: StudyPlanDao(db.future),
      );
      await expectFails(() => repository.getActivePlan(), db);

      db = Completer<Database>();
      repository = StudyPlanRepository(studyPlanDao: StudyPlanDao(db.future));
      await expectFails(() => repository.getAllPlans(), db);
    });
  });

  group('WordRepository关键读取错误契约', () {
    late Completer<Database> db;
    late WordRepository repository;

    setUp(() {
      db = Completer<Database>();
      repository = WordRepository(wordDao: WordDao(db.future));
    });

    Future<void> run(Future<void> Function() action) async {
      db = Completer<Database>();
      repository = WordRepository(wordDao: WordDao(db.future));
      await expectFails(action, db);
    }

    test('分页与到期/新词读取传播数据库异常', () async {
      await run(() => repository.getWordsByBook(1));
      await run(() => repository.getDueWords(1));
      await run(() => repository.getNewWords(1, 20));
      await run(() => repository.getWordsPaginated(1));
      await run(
        () => repository.getNewWordsWithinDailyRemaining(1, dailyLimit: 20),
      );
      await run(
        () => repository.getDueWordsWithinDailyRemaining(1, dailyLimit: 50),
      );
    });

    test('搜索传播数据库异常', () async {
      await run(() => repository.searchWords('test'));
      await run(() => repository.searchAllWords('test'));
    });

    test('词数与按ID读取传播数据库异常', () async {
      await run(() => repository.getWordCountInBook(1));
      await run(() => repository.hasWordsInBook(1));
      await run(() => repository.getWordsByIds(const [1, 2]));
    });
  });
}

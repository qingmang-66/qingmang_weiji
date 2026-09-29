import 'dart:async';

import 'package:flutter/foundation.dart';

import 'session_mastery_repository.dart';
import 'tts_service.dart';
import 'dictionary_api_service.dart';
import 'youdao_service.dart';
import 'local_dictionary_service.dart';
import 'repositories/repositories.dart';
import 'notification_service.dart';
import 'reminder_sound_service.dart';
import 'specialized_study_service.dart';
import 'wrong_word_service.dart';
import 'wrong_word_ranking_service.dart';
import 'study_plan_service.dart';
import 'weekly_report_service.dart';
import 'weak_vocabulary_service.dart';
import 'favorite_service.dart';
import 'database_service.dart';

/// Dependency Injection Container
/// Centralizes initialization and access to services and repositories
class DIContainer {
  DIContainer._();

  static final DIContainer instance = DIContainer._();

  /// init 幂等闸门：所有依赖都是 late final，二次赋值会抛 LateInitializationError
  bool _initialized = false;

  // Services
  late final TtsService ttsService;
  late final DictionaryApiService dictionaryApiService;
  late final YoudaoService youdaoService;
  late final LocalDictionaryService localDictionaryService;
  late final NotificationService notificationService;
  late final WrongWordService wrongWordService;
  late final WrongWordRankingService wrongWordRankingService;
  late final SpecializedStudyService specializedStudyService;
  late final StudyPlanService studyPlanService;
  late final WeeklyReportService weeklyReportService;
  late final WeakVocabularyService weakVocabularyService;
  late final FavoriteService favoriteService;

  // Repositories
  late final WordRepository wordRepository;
  late final WordBookRepository wordBookRepository;
  late final ReviewRepository reviewRepository;
  late final StatsRepository statsRepository;
  late final StudyProgressRepository studyProgressRepository;
  late final StudyPlanRepository studyPlanRepository;
  late final SearchHistoryRepository searchHistoryRepository;
  late final WeakVocabularyRepository weakVocabularyRepository;
  late final WeeklyReportRepository weeklyReportRepository;

  /// Initialize all services and repositories
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // DatabaseService auto-initializes via static field

    // Initialize services
    ttsService = TtsService();
    dictionaryApiService = DictionaryApiService();
    youdaoService = YoudaoService();
    localDictionaryService = LocalDictionaryService();
    notificationService = NotificationService();
    wrongWordService = WrongWordService();
    wrongWordRankingService = WrongWordRankingService();

    // Initialize repositories
    wordRepository = WordRepository();
    wordBookRepository = WordBookRepository();
    reviewRepository = ReviewRepository();
    statsRepository = StatsRepository();
    studyProgressRepository = StudyProgressRepository();
    studyPlanRepository = StudyPlanRepository();
    searchHistoryRepository = SearchHistoryRepository();

    // 薄弱词库服务（周报依赖它，需提前创建）
    weakVocabularyService = WeakVocabularyService(
      dao: DatabaseService.weakVocabularyDao,
      wrongWordDao: DatabaseService.wrongWordDao,
    );
    weakVocabularyRepository = WeakVocabularyRepository(weakVocabularyService);

    // 收藏夹（词集之一）：只依赖 DAO，无规则逻辑
    favoriteService = FavoriteService(dao: DatabaseService.favoriteDao);

    // 周报服务
    weeklyReportService = WeeklyReportService(
      statsDao: DatabaseService.statsDao,
      weakVocabularyService: weakVocabularyService,
    );
    weeklyReportRepository = WeeklyReportRepository(weeklyReportService);

    specializedStudyService = SpecializedStudyService(
      wrongWordService: wrongWordService,
    );

    // 计划服务依赖仓库，需在仓库初始化后构造
    studyPlanService = StudyPlanService(
      planRepository: studyPlanRepository,
      wordRepository: wordRepository,
      reviewRepository: reviewRepository,
    );

    // 初始化本地通知服务（时区通道 + 插件注册 + 冷启动通知 payload）：
    // 全是平台通道往返，放在这里 await 会把首帧整体往后推，
    // 而它在下游任何使用点前完成即可 —— scheduleDailyReminder / cancelReminder
    // 都会先确保 init 完成（init 内部有并发闸门，重复调用只会初始化一次）。
    unawaited(notificationService.init());

    // 后台数据维护：清理过期的作答事件与会话掌握记录。
    // 两张事件表都是"每次作答追加一行"且此前没有任何清理语句，
    // 长期使用会无界增长（备份体积、错因聚合、连击扫描都受影响）。
    unawaited(_runDataMaintenance());
  }

  /// 过期事件清理（尽力而为：失败不影响启动）
  Future<void> _runDataMaintenance() async {
    try {
      await DatabaseService.wrongWordDao.pruneStrengthEvents();
      await SessionMasteryRepository().deleteRecordsBeforeDate(
        _dateKey(DateTime.now().subtract(const Duration(days: 180))),
      );
    } catch (e) {
      debugPrint('过期数据清理失败（可忽略）：$e');
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// 释放需要显式关闭的运行时资源
  void dispose() {
    unawaited(ReminderSoundService.instance.dispose());
    weakVocabularyService.dispose();
    weeklyReportService.dispose();
    notificationService.dispose();
    ttsService.dispose();
    DictionaryApiService.shutdown();
    YoudaoService.shutdown();
  }

  /// Get a service by type
  T get<T>() {
    if (T == TtsService) return ttsService as T;
    if (T == DictionaryApiService) return dictionaryApiService as T;
    if (T == YoudaoService) return youdaoService as T;
    if (T == LocalDictionaryService) return localDictionaryService as T;
    if (T == NotificationService) return notificationService as T;
    if (T == WrongWordService) return wrongWordService as T;
    if (T == WrongWordRankingService) return wrongWordRankingService as T;
    if (T == SpecializedStudyService) return specializedStudyService as T;
    if (T == StudyPlanService) return studyPlanService as T;
    if (T == WeeklyReportService) return weeklyReportService as T;
    if (T == WordRepository) return wordRepository as T;
    if (T == WordBookRepository) return wordBookRepository as T;
    if (T == ReviewRepository) return reviewRepository as T;
    if (T == StatsRepository) return statsRepository as T;
    if (T == StudyProgressRepository) return studyProgressRepository as T;
    if (T == StudyPlanRepository) return studyPlanRepository as T;
    if (T == SearchHistoryRepository) return searchHistoryRepository as T;
    if (T == WeakVocabularyService) return weakVocabularyService as T;
    if (T == FavoriteService) return favoriteService as T;
    if (T == WeakVocabularyRepository) return weakVocabularyRepository as T;
    if (T == WeeklyReportRepository) return weeklyReportRepository as T;
    throw Exception('Service of type $T not registered');
  }
}

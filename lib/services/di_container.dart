import 'tts_service.dart';
import 'dictionary_api_service.dart';
import 'youdao_service.dart';
import 'local_dictionary_service.dart';
import 'repositories/repositories.dart';
import 'notification_service.dart';
import 'specialized_study_service.dart';
import 'wrong_word_service.dart';
import 'wrong_word_ranking_service.dart';
import 'study_plan_service.dart';
import 'weekly_report_service.dart';
import 'achievement_service.dart';
import 'weak_vocabulary_service.dart';
import 'database_service.dart';

/// Dependency Injection Container
/// Centralizes initialization and access to services and repositories
class DIContainer {
  DIContainer._();

  static final DIContainer instance = DIContainer._();

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
  late final AchievementService achievementService;
  late final WeakVocabularyService weakVocabularyService;

  // Repositories
  late final WordRepository wordRepository;
  late final WordBookRepository wordBookRepository;
  late final ReviewRepository reviewRepository;
  late final StatsRepository statsRepository;
  late final StudyProgressRepository studyProgressRepository;
  late final StudyPlanRepository studyPlanRepository;
  late final FavoriteRepository favoriteRepository;
  late final CustomWordSetRepository customWordSetRepository;
  late final SearchHistoryRepository searchHistoryRepository;
  late final AchievementRepository achievementRepository;
  late final WeakVocabularyRepository weakVocabularyRepository;
  late final WeeklyReportRepository weeklyReportRepository;

  /// Initialize all services and repositories
  Future<void> init() async {
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
    favoriteRepository = FavoriteRepository();
    customWordSetRepository = CustomWordSetRepository();
    searchHistoryRepository = SearchHistoryRepository();

    // 薄弱词库服务（成就/周报都依赖它，需提前创建）
    weakVocabularyService = WeakVocabularyService(
      dao: DatabaseService.weakVocabularyDao,
      wrongWordDao: DatabaseService.wrongWordDao,
    );
    weakVocabularyRepository = WeakVocabularyRepository(weakVocabularyService);

    // 周报服务（成就服务依赖它，需在成就服务之前创建）
    weeklyReportService = WeeklyReportService(
      statsDao: DatabaseService.statsDao,
      weakVocabularyService: weakVocabularyService,
    );
    weeklyReportRepository = WeeklyReportRepository(weeklyReportService);

    // 成就服务（依赖周报服务）
    achievementService = AchievementService(
      weeklyReportService: weeklyReportService,
    );
    achievementRepository = AchievementRepository(achievementService);

    specializedStudyService = SpecializedStudyService(
      wrongWordService: wrongWordService,
      favoriteRepository: favoriteRepository,
      customWordSetRepository: customWordSetRepository,
    );

    // 计划服务依赖仓库，需在仓库初始化后构造
    studyPlanService = StudyPlanService(
      planRepository: studyPlanRepository,
      wordRepository: wordRepository,
      reviewRepository: reviewRepository,
    );

    // 初始化本地通知服务
    await notificationService.init();
  }

  /// 释放需要显式关闭的运行时资源
  void dispose() {
    weakVocabularyService.dispose();
    weeklyReportService.dispose();
    notificationService.dispose();
    ttsService.dispose();
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
    if (T == FavoriteRepository) return favoriteRepository as T;
    if (T == CustomWordSetRepository) return customWordSetRepository as T;
    if (T == SearchHistoryRepository) return searchHistoryRepository as T;
    if (T == AchievementService) return achievementService as T;
    if (T == AchievementRepository) return achievementRepository as T;
    if (T == WeakVocabularyService) return weakVocabularyService as T;
    if (T == WeakVocabularyRepository) return weakVocabularyRepository as T;
    if (T == WeeklyReportRepository) return weeklyReportRepository as T;
    throw Exception('Service of type $T not registered');
  }
}

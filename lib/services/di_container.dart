import 'tts_service.dart';
import 'dictionary_api_service.dart';
import 'youdao_service.dart';
import 'local_dictionary_service.dart';
import 'repositories/repositories.dart';
import 'notification_service.dart';
import 'specialized_study_service.dart';
import 'wrong_word_service.dart';
import 'study_plan_service.dart';
import 'weekly_report_service.dart';

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
  late final SpecializedStudyService specializedStudyService;
  late final StudyPlanService studyPlanService;
  late final WeeklyReportService weeklyReportService;

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
    weeklyReportService = const WeeklyReportService();

    // 初始化本地通知服务
    await notificationService.init();
  }

  /// Get a service by type
  T get<T>() {
    if (T == TtsService) return ttsService as T;
    if (T == DictionaryApiService) return dictionaryApiService as T;
    if (T == YoudaoService) return youdaoService as T;
    if (T == LocalDictionaryService) return localDictionaryService as T;
    if (T == NotificationService) return notificationService as T;
    if (T == WrongWordService) return wrongWordService as T;
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
    throw Exception('Service of type $T not registered');
  }
}

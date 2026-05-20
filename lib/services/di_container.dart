import 'tts_service.dart';
import 'dictionary_api_service.dart';
import 'youdao_service.dart';
import 'event_bus.dart';
import 'local_dictionary_service.dart';
import 'repositories/repositories.dart';

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
  late final EventBus eventBus;

  // Repositories
  late final WordRepository wordRepository;
  late final WordBookRepository wordBookRepository;
  late final ReviewRepository reviewRepository;
  late final StatsRepository statsRepository;

  /// Initialize all services and repositories
  Future<void> init() async {
    // DatabaseService auto-initializes via static field

    // Initialize services
    ttsService = TtsService();
    dictionaryApiService = DictionaryApiService();
    youdaoService = YoudaoService();
    localDictionaryService = LocalDictionaryService();
    eventBus = EventBus();

    // Initialize repositories
    wordRepository = WordRepository();
    wordBookRepository = WordBookRepository();
    reviewRepository = ReviewRepository();
    statsRepository = StatsRepository();
  }

  /// Get a service by type
  T get<T>() {
    if (T == TtsService) return ttsService as T;
    if (T == DictionaryApiService) return dictionaryApiService as T;
    if (T == YoudaoService) return youdaoService as T;
    if (T == LocalDictionaryService) return localDictionaryService as T;
    if (T == EventBus) return eventBus as T;
    if (T == WordRepository) return wordRepository as T;
    if (T == WordBookRepository) return wordBookRepository as T;
    if (T == ReviewRepository) return reviewRepository as T;
    if (T == StatsRepository) return statsRepository as T;
    throw Exception('Service of type $T not registered');
  }
}

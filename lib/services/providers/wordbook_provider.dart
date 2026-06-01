import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di_container.dart';
import '../repositories/wordbook_repository.dart';
import '../repositories/review_repository.dart';
import '../../models/word_book.dart';
import '../../models/word.dart';
import '../../models/wordbook_progress.dart';

/// 词库状态管理
class WordBookProvider extends ChangeNotifier {
  late final WordBookRepository _wordBookRepository;
  late final ReviewRepository _reviewRepository;

  List<WordBook> _wordBooks = [];
  WordBook? _currentBook;
  int _dueCount = 0;
  int _todayNewCount = 0;
  WordBookProgress? _currentBookProgress;
  // streak 统一由 StudySettingsProvider 管理，此处仅作缓存引用
  int _streak = 0;
  bool _isLoading = true;
  bool _hasInitError = false;
  String? _errorMessage;

  // 通知设置
  bool _notificationsEnabled = true;

  List<WordBook> get wordBooks => _wordBooks;
  WordBook? get currentBook => _currentBook;
  int get dueCount => _dueCount;
  int get todayNewCount => _todayNewCount;
  WordBookProgress? get currentBookProgress => _currentBookProgress;
  int get streak => _streak;
  bool get isLoading => _isLoading;
  bool get hasInitError => _hasInitError;
  String? get errorMessage => _errorMessage;
  bool get notificationsEnabled => _notificationsEnabled;

  set notificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    _saveNotificationSetting(enabled);
    notifyListeners();
  }

  /// 从 StudySettingsProvider 同步 streak 值（由外部调用）
  void syncStreak(int newStreak) {
    if (_streak != newStreak) {
      _streak = newStreak;
      notifyListeners();
    }
  }

  /// 初始化加载词库
  Future<void> init() async {
    _wordBookRepository = DIContainer.instance.wordBookRepository;
    _reviewRepository = DIContainer.instance.reviewRepository;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await loadWordBooks();
    } catch (e) {
      _hasInitError = true;
      _errorMessage = '加载词库失败：$e';
      _isLoading = false;
      debugPrint('WordBookProvider.init error: $e');
      notifyListeners();
    }
  }

  /// 加载所有词库
  Future<void> loadWordBooks({bool seedIfEmpty = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _wordBooks = await _wordBookRepository.getAllWordBooks();
      if (_currentBook == null && _wordBooks.isNotEmpty) {
        _currentBook = _wordBooks.first;
      }
      if (_currentBook != null) {
        await refreshDueCount();
      }
    } catch (e) {
      _errorMessage = '加载词库失败：$e';
      debugPrint('loadWordBooks error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 选择当前词库
  Future<void> selectWordBook(WordBook book) async {
    _currentBook = book;
    await refreshDueCount();
    notifyListeners();
  }

  /// 创建新词库
  Future<int> createWordBook(String name, String description) async {
    final id = await _wordBookRepository.insertWordBook(
      WordBook(name: name, description: description, isBuiltIn: false),
    );
    await loadWordBooks();
    return id;
  }

  /// 创建新词库（不刷新列表，用于导入后手动刷新）
  Future<int> createWordBookSilent(
    String name,
    String description, {
    bool isBuiltIn = false,
  }) async {
    return await _wordBookRepository.insertWordBook(
      WordBook(name: name, description: description, isBuiltIn: isBuiltIn),
    );
  }

  /// 检查词库名称是否已存在
  bool isBookNameExists(String name) {
    return _wordBooks.any((book) => book.name == name);
  }

  /// 删除词库
  Future<void> deleteWordBook(int id) async {
    final wasCurrentBook = _currentBook?.id == id;
    await _wordBookRepository.deleteWordBook(id);
    if (wasCurrentBook) _currentBook = null;
    await loadWordBooks(seedIfEmpty: false);
  }

  /// 刷新待复习数量
  Future<void> refreshDueCount() async {
    final book = _currentBook;
    if (book != null) {
      try {
        final bookId = book.id;
        if (bookId != null) {
          _dueCount = await _reviewRepository.getDueWordCount(bookId);
          _todayNewCount = await _reviewRepository.getTodayNewWordCount(bookId);
          _currentBookProgress = await _reviewRepository.getWordBookProgress(
            bookId,
          );
        }
      } catch (e) {
        debugPrint('refreshDueCount error: $e');
        _dueCount = 0;
        _todayNewCount = 0;
      }
    }
    notifyListeners();
  }

  int remainingNewWords(int dailyLimit) {
    final remaining = dailyLimit - _todayNewCount;
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _saveNotificationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', enabled);
    } catch (e) {
      debugPrint('保存通知设置失败：$e');
    }
  }

  /// 批量删除词库
  Future<void> deleteWordBooksBatch(List<int> ids) async {
    final wasCurrentBook =
        _currentBook != null && ids.contains(_currentBook!.id);
    await _wordBookRepository.deleteWordBooksBatch(ids);
    if (wasCurrentBook) _currentBook = null;
    await loadWordBooks(seedIfEmpty: false);
  }

  /// 批量删除单词
  Future<void> deleteWordsBatch(List<int> wordIds) async {
    await DIContainer.instance.wordRepository.deleteWordsBatch(wordIds);
    await loadWordBooks();
  }

  /// 导入内置词库
  Future<void> importBuiltInBook(
    String name,
    String description,
    List<Map<String, String>> words,
  ) async {
    // 检查是否已存在
    if (_wordBooks.any((book) => book.name == name)) {
      return;
    }

    // 创建词库
    final bookId = await createWordBookSilent(
      name,
      description,
      isBuiltIn: true,
    );

    // 导入单词
    if (bookId > 0 && words.isNotEmpty) {
      final wordRepository = DIContainer.instance.wordRepository;
      final wordList = words
          .map(
            (wordData) => Word(
              word: wordData['word'] ?? '',
              phonetic: wordData['phonetic'] ?? '',
              definition: wordData['definition'] ?? '',
              wordBookId: bookId,
            ),
          )
          .toList();

      await wordRepository.insertWordsBatch(wordList);
    }

    // 刷新列表
    await loadWordBooks();
  }

  /// 重排序词库（拖拽排序后调用）
  Future<void> reorderWordBooks(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    // 在列表中移动
    final book = _wordBooks.removeAt(oldIndex);
    if (newIndex > oldIndex) {
      _wordBooks.insert(newIndex - 1, book);
    } else {
      _wordBooks.insert(newIndex, book);
    }

    // 更新所有词库的sortOrder
    final sortOrderMap = <int, int>{};
    for (int i = 0; i < _wordBooks.length; i++) {
      if (_wordBooks[i].id != null) {
        sortOrderMap[_wordBooks[i].id!] = i;
      }
    }

    // 保存到数据库
    await _wordBookRepository.updateSortOrders(sortOrderMap);
    notifyListeners();
  }
}

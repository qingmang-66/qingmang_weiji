import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di_container.dart';
import '../notification_service.dart';
import '../../models/word_book.dart';

/// 词库状态管理
class WordBookProvider extends ChangeNotifier {
  final _wordBookRepository = DIContainer.instance.wordBookRepository;
  final _reviewRepository = DIContainer.instance.reviewRepository;

  List<WordBook> _wordBooks = [];
  WordBook? _currentBook;
  int _dueCount = 0;
  int _todayNewCount = 0;
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

  /// 初始化加载词库
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await loadWordBooks();
      await _loadStreak();
    } catch (e) {
      _hasInitError = true;
      _errorMessage = '加载词库失败：$e';
      _isLoading = false;
      debugPrint('WordBookProvider.init error: $e');
      notifyListeners();
    }
  }

  /// 加载连续打卡天数
  Future<void> _loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _streak = prefs.getInt('streak') ?? 0;
    } catch (e) {
      debugPrint('加载打卡天数失败：$e');
    }
    notifyListeners();
  }

  /// 保存连续打卡天数
  Future<void> _saveStreak(int streak) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('streak', streak);
    } catch (e) {
      debugPrint('保存打卡天数失败：$e');
    }
  }

  /// 更新连续打卡天数
  Future<void> updateStreak(int newStreak) async {
    _streak = newStreak;
    await _saveStreak(newStreak);
    notifyListeners();
  }

  /// 加载所有词库
  Future<void> loadWordBooks() async {
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
    final id = await _wordBookRepository.insertWordBook(WordBook(
      name: name,
      description: description,
      isBuiltIn: false,
    ));
    await loadWordBooks();
    return id;
  }

  /// 创建新词库（不刷新列表，用于导入后手动刷新）
  Future<int> createWordBookSilent(String name, String description, {bool isBuiltIn = false}) async {
    return await _wordBookRepository.insertWordBook(WordBook(
      name: name,
      description: description,
      isBuiltIn: isBuiltIn,
    ));
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
    await loadWordBooks();
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
        }
      } catch (e) {
        debugPrint('refreshDueCount error: $e');
        _dueCount = 0;
        _todayNewCount = 0;
      }
    }
    notifyListeners();
    if (_dueCount > 0 && _notificationsEnabled) {
      NotificationService().checkAndShowReminder(_dueCount);
    }
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
    final wasCurrentBook = _currentBook != null && ids.contains(_currentBook!.id);
    await _wordBookRepository.deleteWordBooksBatch(ids);
    if (wasCurrentBook) _currentBook = null;
    await loadWordBooks();
  }

  /// 批量删除单词
  Future<void> deleteWordsBatch(List<int> wordIds) async {
    await DIContainer.instance.wordRepository.deleteWordsBatch(wordIds);
    await loadWordBooks();
  }
}

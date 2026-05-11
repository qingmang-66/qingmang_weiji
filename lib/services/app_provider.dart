import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';
import 'database_service.dart';
import 'definition_service.dart';
import 'notification_service.dart';
import 'seed_service.dart';

/// 应用状态管理
class AppProvider extends ChangeNotifier {
  List<WordBook> _wordBooks = [];
  WordBook? _currentBook;
  int _dueCount = 0;
  int _todayNewCount = 0;
  bool _isLoading = true;
  bool _hasInitError = false;
  String? _errorMessage;

  bool _isDarkMode = false;
  bool _isEnglishLocale = false;
  int _dailyNewWords = AppConstants.defaultDailyNewWords;
  int _dailyReviewWords = AppConstants.defaultDailyReviewWords;
  bool _autoPlayAudio = false;
  double _speechRate = 0.45;

  // 发音设置
  String _audioSource = 'tts'; // 'tts' 或 'online'
  String _accentType = 'us'; // 'us' 或 'uk'

  // 释义设置
  bool _useOnlineDefinition = true; // true=混合模式, false=纯离线
  DictionarySource _dictionarySource = DictionarySource.freeDictionary;

  // 连续学习天数
  int _streak = 0;
  String? _lastStudyDate;

  // 错词缓存（避免每次 rebuild 都查询）
  int _wrongWordCount = 0;

  // 通知设置
  bool _notificationsEnabled = true;

  // 新用户引导状态
  final bool _hasSeenOnboarding = false;

  // ========== Getters ==========

  List<WordBook> get wordBooks => _wordBooks;
  WordBook? get currentBook => _currentBook;
  int get dueCount => _dueCount;
  int get todayNewCount => _todayNewCount;
  bool get isLoading => _isLoading;
  bool get hasInitError => _hasInitError;
  String? get errorMessage => _errorMessage;
  bool get isDarkMode => _isDarkMode;
  bool get isEnglishLocale => _isEnglishLocale;
  int get dailyNewWords => _dailyNewWords;
  int get dailyReviewWords => _dailyReviewWords;
  bool get autoPlayAudio => _autoPlayAudio;
  double get speechRate => _speechRate;
  int get streak => _streak;
  bool get isOnlineAudio => _audioSource == 'online';
  String get accentType => _accentType;
  bool get useOnlineDefinition => _useOnlineDefinition;
  DictionarySource get dictionarySource => _dictionarySource;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  // ========== Setters ==========

  set useOnlineDefinition(bool value) {
    if (_useOnlineDefinition != value) {
      _useOnlineDefinition = value;
      _saveDefinitionPreference();
      notifyListeners();
    }
  }

  set dictionarySource(DictionarySource value) {
    if (_dictionarySource != value) {
      _dictionarySource = value;
      _saveDictionarySourcePreference();
      DefinitionService.setDictionarySource(value);
      notifyListeners();
    }
  }

  set notificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    _saveNotificationSetting(enabled);
    notifyListeners();
  }

  // ========== 初始化 ==========

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _loadPreferences();
      Translations.setLocale(_isEnglishLocale);
      await loadWordBooks();
    } catch (e) {
      _hasInitError = true;
      _errorMessage = '应用初始化失败：$e';
      _isLoading = false;
      debugPrint('AppProvider.init error: $e');
      notifyListeners();
    }
  }

  // ========== 偏好加载/保存 ==========

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _isEnglishLocale = prefs.getBool('isEnglishLocale') ?? false;
      _dailyNewWords = prefs.getInt('dailyNewWords') ?? AppConstants.defaultDailyNewWords;
      _dailyReviewWords = prefs.getInt('dailyReviewWords') ?? AppConstants.defaultDailyReviewWords;
      _autoPlayAudio = prefs.getBool('autoPlayAudio') ?? false;
      _speechRate = prefs.getDouble('speechRate') ?? 0.45;

      // 打卡数据
      _streak = prefs.getInt('streak') ?? 0;
      _lastStudyDate = prefs.getString('lastStudyDate');
      _checkStreak();

      // 发音设置
      _audioSource = prefs.getString(AppConstants.settingAudioSource) ?? 'tts';
      _accentType = prefs.getString(AppConstants.settingAccentType) ?? 'us';

      // 释义设置
      _useOnlineDefinition = prefs.getBool('useOnlineDefinition') ?? true;
      final sourceIndex = prefs.getInt('dictionarySource') ?? 0;
      _dictionarySource = DictionarySource.values[sourceIndex.clamp(0, DictionarySource.values.length - 1)];
      DefinitionService.setDictionarySource(_dictionarySource);

      // 通知设置
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    } catch (e) {
      debugPrint('加载偏好失败：$e');
    }
  }

  void _checkStreak() {
    if (_lastStudyDate == null) {
      return;
    }
    final lastDate = DateTime.tryParse(_lastStudyDate!);
    if (lastDate == null) {
      return;
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastStudyDateTime = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final diff = todayDate.difference(lastStudyDateTime).inDays;
    if (diff > 1) {
      _streak = 0;
    }
  }

  Future<void> updateStreak() async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    if (_lastStudyDate == todayStr) {
      return;
    }
    final lastDate = _lastStudyDate != null ? DateTime.tryParse(_lastStudyDate!) : null;
    if (lastDate != null) {
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      final diff = todayDay.difference(lastDay).inDays;
      if (diff == 1) {
        _streak++;
      } else if (diff > 1) {
        _streak = 1;
      }
    } else {
      _streak = 1;
    }
    _lastStudyDate = todayStr;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('streak', _streak);
      await prefs.setString('lastStudyDate', todayStr);
    } catch (e) {
      debugPrint('保存打卡数据失败：$e');
    }
    notifyListeners();
  }

  Future<void> _saveDefinitionPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useOnlineDefinition', _useOnlineDefinition);
    } catch (e) {
      debugPrint('保存释义偏好失败：$e');
    }
  }

  Future<void> _saveDictionarySourcePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dictionarySource', _dictionarySource.index);
    } catch (e) {
      debugPrint('保存词典源偏好失败：$e');
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

  Future<void> _savePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('保存偏好失败：$e');
    }
  }

  // ========== 词库操作 ==========

  Future<void> loadWordBooks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _wordBooks = await DatabaseService.getAllWordBooks();
      if (_wordBooks.isEmpty) {
        await SeedService.seedBuiltInData();
        _wordBooks = await DatabaseService.getAllWordBooks();
      }
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

  Future<void> selectWordBook(WordBook book) async {
    _currentBook = book;
    await refreshDueCount();
    notifyListeners();
  }

  Future<int> createWordBook(String name, String description) async {
    final id = await DatabaseService.insertWordBook(WordBook(
      name: name,
      description: description,
      isBuiltIn: false,
    ));
    await loadWordBooks();
    return id;
  }

  Future<void> deleteWordBook(int id) async {
    final wasCurrentBook = _currentBook?.id == id;
    await DatabaseService.deleteWordBook(id);
    if (wasCurrentBook) _currentBook = null;
    await loadWordBooks();
  }

  Future<void> refreshDueCount() async {
    if (_currentBook != null) {
      try {
        _dueCount = await DatabaseService.getDueWordCount(_currentBook!.id!);
        _todayNewCount = await DatabaseService.getTodayNewWordCount(_currentBook!.id!);
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

  // ========== 偏好设置方法 ==========

  void setDarkMode(bool value) {
    _isDarkMode = value;
    _savePreference('isDarkMode', value);
    notifyListeners();
  }

  void setEnglishLocale(bool value) {
    _isEnglishLocale = value;
    Translations.setLocale(value);
    _savePreference('isEnglishLocale', value);
    notifyListeners();
  }

  void setDailyNewWords(int value) {
    _dailyNewWords = value;
    _savePreference('dailyNewWords', value);
    notifyListeners();
  }

  void setDailyReviewWords(int value) {
    _dailyReviewWords = value;
    _savePreference('dailyReviewWords', value);
    notifyListeners();
  }

  void setAutoPlayAudio(bool value) {
    _autoPlayAudio = value;
    _savePreference('autoPlayAudio', value);
    notifyListeners();
  }

  void setSpeechRate(double value) {
    _speechRate = value;
    _savePreference('speechRate', value);
    notifyListeners();
  }

  void setAudioSource(String source) {
    _audioSource = source;
    _savePreference(AppConstants.settingAudioSource, source);
    notifyListeners();
  }

  void setAccentType(String type) {
    _accentType = type;
    _savePreference(AppConstants.settingAccentType, type);
    notifyListeners();
  }
}

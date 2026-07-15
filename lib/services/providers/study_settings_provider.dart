import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../models/notification_settings.dart';
import '../notification_service.dart';

/// 学习设置状态管理
class StudySettingsProvider extends ChangeNotifier {
  final NotificationService _notificationService;
  final Future<SharedPreferences> Function() _preferencesLoader;

  StudySettingsProvider({
    NotificationService? notificationService,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _notificationService = notificationService ?? NotificationService(),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  int _dailyNewWords = AppConstants.defaultDailyNewWords;
  int _dailyReviewWords = AppConstants.defaultDailyReviewWords;
  bool _autoPlayAudio = false;
  double _speechRate = 0.45;

  // 发音设置
  String _audioSource = 'tts'; // 'tts' 或 'online'
  String _accentType = 'us'; // 'us' 或 'uk'

  // 释义设置
  bool _useOnlineDefinition = true;
  DictionarySource _dictionarySource = DictionarySource.freeDictionary;

  // 连续学习天数
  int _streak = 0;
  String? _lastStudyDate;

  // 智能模式切换设置
  bool _enableSmartModeSwitch = false;

  // ============ 通知提醒设置 ============
  /// 本地通知提醒设置
  NotificationSettings _notificationSettings = NotificationSettings.defaults;
  NotificationSettings get notificationSettings => _notificationSettings;

  int get dailyNewWords => _dailyNewWords;
  int get dailyReviewWords => _dailyReviewWords;
  bool get autoPlayAudio => _autoPlayAudio;
  double get speechRate => _speechRate;
  bool get isOnlineAudio => _audioSource == 'online';
  String get accentType => _accentType;
  bool get useOnlineDefinition => _useOnlineDefinition;
  DictionarySource get dictionarySource => _dictionarySource;
  int get streak => _streak;
  bool get enableSmartModeSwitch => _enableSmartModeSwitch;

  /// 初始化加载设置
  Future<void> loadPreferences() async {
    try {
      final prefs = await _preferencesLoader();
      _dailyNewWords =
          prefs.getInt('dailyNewWords') ?? AppConstants.defaultDailyNewWords;
      _dailyReviewWords =
          prefs.getInt('dailyReviewWords') ??
          AppConstants.defaultDailyReviewWords;
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
      _dictionarySource = DictionarySource
          .values[sourceIndex.clamp(0, DictionarySource.values.length - 1)];

      // 智能模式切换设置
      _enableSmartModeSwitch = prefs.getBool('enableSmartModeSwitch') ?? false;

      // 通知提醒设置
      final condIndex = prefs.getInt(NotificationSettings.keyCondition) ?? 2;
      _notificationSettings = NotificationSettings(
        enabled: prefs.getBool(NotificationSettings.keyEnabled) ?? false,
        reminderHour: prefs.getInt(NotificationSettings.keyHour) ?? 20,
        reminderMinute: prefs.getInt(NotificationSettings.keyMinute) ?? 0,
        condition:
            NotificationCondition.values[condIndex.clamp(
              0,
              NotificationCondition.values.length - 1,
            )],
      );

      //通知调度失败不影响其余设置同步到UI
      try {
        await _applyNotificationSchedule(_notificationSettings);
      } catch (e) {
        debugPrint('恢复通知调度失败：$e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('加载学习设置失败：$e');
    }
  }

  /// 检查连续打卡
  void _checkStreak() {
    if (_lastStudyDate == null) return;
    final lastDate = DateTime.tryParse(_lastStudyDate!);
    if (lastDate == null) return;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastStudyDateTime = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    );
    final diff = todayDate.difference(lastStudyDateTime).inDays;
    if (diff > 1) {
      _streak = 0;
    }
  }

  /// 更新连续打卡
  Future<void> updateStreak() async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    if (_lastStudyDate == todayStr) return;

    final lastDate = _lastStudyDate != null
        ? DateTime.tryParse(_lastStudyDate!)
        : null;
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
      final prefs = await _preferencesLoader();
      await prefs.setInt('streak', _streak);
      await prefs.setString('lastStudyDate', todayStr);
    } catch (e) {
      debugPrint('保存打卡数据失败：$e');
    }
    notifyListeners();
  }

  // ========== 设置方法 ==========

  Future<void> setDailyNewWords(int value) async {
    _dailyNewWords = value;
    await _savePreference('dailyNewWords', value);
    notifyListeners();
  }

  Future<void> setDailyReviewWords(int value) async {
    _dailyReviewWords = value;
    await _savePreference('dailyReviewWords', value);
    notifyListeners();
  }

  Future<void> setAutoPlayAudio(bool value) async {
    _autoPlayAudio = value;
    await _savePreference('autoPlayAudio', value);
    notifyListeners();
  }

  Future<void> setSpeechRate(double value) async {
    _speechRate = value;
    await _savePreference('speechRate', value);
    notifyListeners();
  }

  Future<void> setAudioSource(String source) async {
    _audioSource = source;
    await _savePreference(AppConstants.settingAudioSource, source);
    notifyListeners();
  }

  Future<void> setAccentType(String type) async {
    _accentType = type;
    await _savePreference(AppConstants.settingAccentType, type);
    notifyListeners();
  }

  Future<void> setUseOnlineDefinition(bool value) async {
    if (_useOnlineDefinition != value) {
      _useOnlineDefinition = value;
      await _savePreference('useOnlineDefinition', value);
      notifyListeners();
    }
  }

  Future<void> setDictionarySource(DictionarySource value) async {
    if (_dictionarySource != value) {
      _dictionarySource = value;
      await _savePreference('dictionarySource', value.index);
      notifyListeners();
    }
  }

  Future<void> setEnableSmartModeSwitch(bool value) async {
    _enableSmartModeSwitch = value;
    notifyListeners();
    await _savePreference('enableSmartModeSwitch', value);
  }

  // ============ 通知提醒设置 ============
  /// 更新通知提醒设置，并同步到本地存储与通知服务
  Future<void> updateNotificationSettings(NotificationSettings settings) async {
    final oldSettings = _notificationSettings;
    final prefs = await _preferencesLoader();
    try {
      await _saveNotificationSettings(prefs, settings);
      await _applyNotificationSchedule(settings);
      _notificationSettings = settings;
      notifyListeners();
    } catch (_) {
      await _saveNotificationSettings(prefs, oldSettings);
      try {
        await _applyNotificationSchedule(oldSettings);
      } catch (restoreError) {
        debugPrint('恢复通知调度失败：$restoreError');
      }
      rethrow;
    }
  }

  Future<void> _saveNotificationSettings(
    SharedPreferences prefs,
    NotificationSettings settings,
  ) async {
    await prefs.setBool(NotificationSettings.keyEnabled, settings.enabled);
    await prefs.setInt(NotificationSettings.keyHour, settings.reminderHour);
    await prefs.setInt(NotificationSettings.keyMinute, settings.reminderMinute);
    await prefs.setInt(
      NotificationSettings.keyCondition,
      settings.condition.index,
    );
  }

  Future<void> _applyNotificationSchedule(NotificationSettings settings) async {
    if (settings.enabled) {
      await _notificationService.scheduleDailyReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
        title: '清茫微记 · 学习提醒',
        body: '该背单词啦，坚持就是胜利！',
      );
    } else {
      await _notificationService.cancelReminder();
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    try {
      final prefs = await _preferencesLoader();
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
      debugPrint('保存设置失败：$e');
    }
  }
}

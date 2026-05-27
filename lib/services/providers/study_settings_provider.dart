import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

/// 学习设置状态管理
class StudySettingsProvider extends ChangeNotifier {
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
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
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

  set useOnlineDefinition(bool value) {
    if (_useOnlineDefinition != value) {
      _useOnlineDefinition = value;
      _savePreference('useOnlineDefinition', value);
      notifyListeners();
    }
  }

  set dictionarySource(DictionarySource value) {
    if (_dictionarySource != value) {
      _dictionarySource = value;
      _savePreference('dictionarySource', value.index);
      notifyListeners();
    }
  }

  Future<void> setEnableSmartModeSwitch(bool value) async {
    _enableSmartModeSwitch = value;
    await _savePreference('enableSmartModeSwitch', value);
    notifyListeners();
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
      debugPrint('保存设置失败：$e');
    }
  }
}

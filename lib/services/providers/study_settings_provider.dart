import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../utils/translations.dart';
import '../../models/notification_settings.dart';
import '../../models/recall_button_layout.dart';
import '../dictionary_api_service.dart';
import '../notification_service.dart';
import '../reminder_sound_service.dart';

/// 回忆模式里「释义」的出现方式
///
/// 旧版是底部一个常驻的「显示释义」大按钮，每次都要伸手去点一下；
/// 现在改为「延时自动出现」「点空白处出现」「按空格键出现」三种触发，
/// 可任选其一，也可以全都要。
enum RecallRevealTrigger {
  /// 停留一段时间后自动显示
  delayed,

  /// 点击题面空白处显示
  tapBlank,

  /// 桌面端按空格键显示
  space,

  /// 三种触发都生效
  all,
}

/// 延时档位（秒）
///
/// 分了 3 档：3 秒（反应很快、适合复习已熟悉的词）、6 秒（默认，
/// 足够回忆一次又不会让节奏卡住）、10 秒（思考型，适合新词）。
/// 除此之外设置页还提供「自定义」档：任意 1~60 秒（见
/// [kRecallRevealDelayMin] / [kRecallRevealDelayMax]），
/// 存下来的值不在档位里时选中态落在「自定义」上。
const List<int> kRecallRevealDelayOptions = [3, 6, 10];

/// 自定义等待时长的可调范围（秒）
const int kRecallRevealDelayMin = 1;
const int kRecallRevealDelayMax = 60;

/// 学习设置状态管理
class StudySettingsProvider extends ChangeNotifier {
  final NotificationService _notificationService;
  final Future<SharedPreferences> Function() _preferencesLoader;

  StudySettingsProvider({
    NotificationService? notificationService,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _notificationService = notificationService ?? NotificationService(),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

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

  // ============ 回忆模式：释义显示方式 ============
  static const String _keyRecallRevealTrigger = 'recallRevealTrigger';
  static const String _keyRecallRevealDelay = 'recallRevealDelaySeconds';

  /// 释义触发方式，默认三种都要（最不容易"卡住不知道怎么办"）
  RecallRevealTrigger _recallRevealTrigger = RecallRevealTrigger.all;

  /// 自动显示释义的等待时长（秒），默认 6 秒
  int _recallRevealDelaySeconds = 6;

  RecallRevealTrigger get recallRevealTrigger => _recallRevealTrigger;
  int get recallRevealDelaySeconds => _recallRevealDelaySeconds;

  /// 是否启用"停留一段时间自动显示释义"
  bool get recallAutoReveal =>
      _recallRevealTrigger == RecallRevealTrigger.delayed ||
      _recallRevealTrigger == RecallRevealTrigger.all;

  /// 是否启用"点击空白处显示释义"
  bool get recallTapToReveal =>
      _recallRevealTrigger == RecallRevealTrigger.tapBlank ||
      _recallRevealTrigger == RecallRevealTrigger.all;

  /// 是否启用"按空格键显示释义"（回忆模式）
  bool get recallSpaceToReveal =>
      _recallRevealTrigger == RecallRevealTrigger.space ||
      _recallRevealTrigger == RecallRevealTrigger.all;

  // ============ 测验模式：选项区垂直位置 ============
  static const String _keyQuizOptionsVertical = 'quizOptionsVertical';

  /// 四个选项作为整体在屏幕剩余区域里的垂直位置（0~100）。
  /// 0 = 紧接题面卡片（默认，与旧版观感一致），100 = 整体沉到屏幕下方。
  int _quizOptionsVertical = 0;

  int get quizOptionsVertical => _quizOptionsVertical;

  // ============ 回忆模式：评分按键布局 ============
  // 参考手游的自定义键位：每颗键用「锚点 + dp 偏移」描述自己的位置与尺寸，
  // 三颗键完全独立。整体作为一份 JSON 落盘，保存一次只通知一次。
  static const String _keyRecallButtonLayout = 'recallButtonLayout';

  /// 已废弃的旧布局存储键（键中心比例 + 全局缩放/透明度）。
  /// 旧坐标是相对比例，没有运行时尺寸无法换算成新锚点模型，读到即清除，
  /// 布局回落到默认一排（与旧默认布局视觉一致）。
  static const List<String> _legacyRecallButtonKeys = [
    'recallButtonPositions',
    'recallButtonScale',
    'recallButtonOpacity',
  ];

  /// 三颗评分键的布局（1=不认识 3=模糊 4=认识）
  RecallButtonLayout _recallButtonLayout = RecallButtonLayout.defaults();

  RecallButtonLayout get recallButtonLayout => _recallButtonLayout;

  /// 批量保存整套布局：一次落盘 + 恰好一次通知。
  ///
  /// 编辑器点"保存"会一次性提交三颗键的全部字段，这里不能逐字段
  /// notifyListeners——学习页就挂在这个 Provider 上，5 次通知就是 5 次重建。
  Future<void> applyRecallButtonLayout(RecallButtonLayout next) async {
    _recallButtonLayout = next;
    notifyListeners();
    await _savePreference(_keyRecallButtonLayout, next.encode());
  }

  /// 恢复默认键位布局（位置 / 尺寸 / 透明度）
  Future<void> resetRecallButtonLayout() async {
    _recallButtonLayout = RecallButtonLayout.defaults();
    notifyListeners();
    final prefs = await _preferencesLoader();
    await prefs.setString(_keyRecallButtonLayout, _recallButtonLayout.encode());
    for (final key in _legacyRecallButtonKeys) {
      await prefs.remove(key);
    }
  }

  // ============ 通知提醒设置 ============
  /// 本地通知提醒设置
  NotificationSettings _notificationSettings = NotificationSettings.defaults;
  NotificationSettings get notificationSettings => _notificationSettings;

  bool get autoPlayAudio => _autoPlayAudio;
  double get speechRate => _speechRate;
  bool get isOnlineAudio => _audioSource == 'online';
  String get accentType => _accentType;
  bool get useOnlineDefinition => _useOnlineDefinition;
  DictionarySource get dictionarySource => _dictionarySource;
  int get streak => _streak;
  bool get enableSmartModeSwitch => _enableSmartModeSwitch;

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 初始化加载设置
  Future<void> loadPreferences() async {
    try {
      final prefs = await _preferencesLoader();
      _autoPlayAudio = prefs.getBool('autoPlayAudio') ?? false;
      // 缓存语言（通知文案用，见 _notificationTranslations 的同步约束）
      _notificationEnglish = prefs.getBool('isEnglishLocale') ?? false;
      // 语速收敛到 0.0~1.0：损坏/旧版偏好里的越界值会让平台侧行为异常
      final rawSpeechRate = prefs.getDouble('speechRate') ?? 0.45;
      _speechRate = rawSpeechRate.isFinite
          ? rawSpeechRate.clamp(0.0, 1.0)
          : 0.45;

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

      // 回忆模式释义显示设置（枚举按 name 存，避免顺序变化后错位；
      // 旧版的 'both' 已不存在，会走 orElse 落到默认的 all）
      final revealTriggerName = prefs.getString(_keyRecallRevealTrigger);
      _recallRevealTrigger = RecallRevealTrigger.values.firstWhere(
        (v) => v.name == revealTriggerName,
        orElse: () => RecallRevealTrigger.all,
      );
      // 测验模式选项区垂直位置（0~100，越界/损坏回落默认 0）
      final quizVertical = prefs.getInt(_keyQuizOptionsVertical) ?? 0;
      _quizOptionsVertical = quizVertical.clamp(0, 100);
      final revealDelay = prefs.getInt(_keyRecallRevealDelay) ?? 6;
      // 档位或自定义值都合法（1~60 秒）；越界/损坏才回落默认 6 秒
      _recallRevealDelaySeconds = (revealDelay >= kRecallRevealDelayMin &&
              revealDelay <= kRecallRevealDelayMax)
          ? revealDelay
          : 6;

      // 回忆模式评分键布局（锚点 + dp 偏移）；旧版三键数据读到即清除，
      // 布局保持默认值——旧的比例坐标没有运行时尺寸无法换算
      final layoutRaw = prefs.getString(_keyRecallButtonLayout);
      var legacyFound = false;
      for (final key in _legacyRecallButtonKeys) {
        if (prefs.containsKey(key)) legacyFound = true;
      }
      if (layoutRaw != null && !legacyFound) {
        _recallButtonLayout = RecallButtonLayout.decode(layoutRaw);
      } else if (legacyFound) {
        for (final key in _legacyRecallButtonKeys) {
          await prefs.remove(key);
        }
        await prefs.setString(
          _keyRecallButtonLayout,
          _recallButtonLayout.encode(),
        );
      }

      // 通知提醒设置
      _notificationSettings = NotificationSettings(
        enabled: prefs.getBool(NotificationSettings.keyEnabled) ?? false,
        reminderHour: prefs.getInt(NotificationSettings.keyHour) ?? 20,
        reminderMinute: prefs.getInt(NotificationSettings.keyMinute) ?? 0,
        soundEnabled: prefs.getBool(NotificationSettings.keySound) ?? true,
      );

      //通知调度失败不影响其余设置同步到UI。
      //这里是"尽力而为"的后台副作用，**刻意不 await**：通知插件要经过
      //平台通道（flutter_timezone / local_notifier / flutter_local_notifications），
      //在个别环境（测试环境、异常 ROM）里会长时间不返回。loadPreferences 位于
      //启动路径上，一旦被它拖住，设置页会停在半初始化状态
      //（测试里表现为用例直接超时）。授权流程不受影响：那一步在用户主动
      //开关提醒时（updateNotificationSettings）才走，那里仍然 await。
      unawaited(_restoreNotificationSchedule());
      notifyListeners();
    } catch (e) {
      debugPrint('加载学习设置失败：$e');
    }
  }

  /// 启动时恢复通知调度（后台执行，失败只记日志）
  ///
  /// 提醒开关处于开启状态时复查一次通知权限：POST_NOTIFICATIONS 不会随
  /// 云备份/换机迁移一起过来，若不复查就会出现"开关显示已开启、提醒永远不来"
  /// 的静默失败。已授权时系统不会弹框，只有真正缺权限时才会申请一次。
  Future<void> _restoreNotificationSchedule() async {
    try {
      await _applyNotificationSchedule(
        _notificationSettings,
        ensurePermission: _notificationSettings.enabled,
      );
    } catch (e) {
      debugPrint('恢复通知调度失败：$e');
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

  /// 保存回忆模式的释义显示设置
  Future<void> setRecallRevealTrigger(RecallRevealTrigger value) async {
    if (_recallRevealTrigger == value) return;
    _recallRevealTrigger = value;
    notifyListeners();
    await _savePreference(_keyRecallRevealTrigger, value.name);
  }

  Future<void> setRecallRevealDelaySeconds(int value) async {
    // 自定义档允许任意 1~60 秒；越界值收敛到边界，避免滑块/输入喂进怪值
    final safe = value.clamp(kRecallRevealDelayMin, kRecallRevealDelayMax);
    if (_recallRevealDelaySeconds == safe) return;
    _recallRevealDelaySeconds = safe;
    notifyListeners();
    await _savePreference(_keyRecallRevealDelay, safe);
  }

  Future<void> setQuizOptionsVertical(int value) async {
    final safe = value.clamp(0, 100);
    if (_quizOptionsVertical == safe) return;
    _quizOptionsVertical = safe;
    notifyListeners();
    await _savePreference(_keyQuizOptionsVertical, safe);
  }

  Future<void> setAutoPlayAudio(bool value) async {
    _autoPlayAudio = value;
    notifyListeners();
    await _savePreference('autoPlayAudio', value);
  }

  Future<void> setSpeechRate(double value) async {
    // 语速必须收敛到 TTS 引擎支持的 0.0~1.0：旧版/损坏的偏好或外部调用
    // 可能传入越界值或 NaN，被平台拒绝或产生异常语速
    final safe = value.isFinite ? value.clamp(0.0, 1.0) : 0.45;
    if (_speechRate == safe) return;
    _speechRate = safe;
    notifyListeners();
    await _savePreference('speechRate', safe);
  }

  Future<void> setAudioSource(String source) async {
    _audioSource = source;
    notifyListeners();
    await _savePreference(AppConstants.settingAudioSource, source);
  }

  Future<void> setAccentType(String type) async {
    if (_accentType == type) return;
    _accentType = type;
    notifyListeners();
    // 切换口音必须清掉发音缓存：缓存文件名只含单词（不含口音），
    // 不清的话已缓存过的词会继续播旧口音，而且不会再发请求
    unawaited(DictionaryApiService.clearAudioCache());
    await _savePreference(AppConstants.settingAccentType, type);
  }

  Future<void> setUseOnlineDefinition(bool value) async {
    if (_useOnlineDefinition != value) {
      _useOnlineDefinition = value;
      //先通知再落盘：写盘慢时界面才不会有"点了没反应"的空窗
      notifyListeners();
      await _savePreference('useOnlineDefinition', value);
    }
  }

  Future<void> setDictionarySource(DictionarySource value) async {
    if (_dictionarySource != value) {
      _dictionarySource = value;
      notifyListeners();
      await _savePreference('dictionarySource', value.index);
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
    // 刷新语言缓存：用户切换界面语言后立刻改提醒时，通知文案要用新语言
    _notificationEnglish =
        prefs.getBool('isEnglishLocale') ?? _notificationEnglish;
    try {
      await _saveNotificationSettings(prefs, settings);
      //用户手动改动提醒设置：此时才复查通知权限（拿不到会抛，下面回滚 + UI 提示）
      await _applyNotificationSchedule(settings, ensurePermission: true);
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
    await prefs.setBool(NotificationSettings.keySound, settings.soundEnabled);
  }

  Future<void> _applyNotificationSchedule(
    NotificationSettings settings, {
    bool ensurePermission = false,
  }) async {
    //提示音开关独立于提醒开关：关闭后提醒照常弹出，只是不发声
    ReminderSoundService.instance.enabled = settings.soundEnabled;
    if (settings.enabled) {
      // 通知文案跟随界面语言（同步取缓存值，见 _notificationTranslations）。
      // 此前硬编码中文，英文界面用户每天收到中文提醒
      final tr = _notificationTranslations;
      await _notificationService.scheduleDailyReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
        title: tr.notificationReminderTitle,
        body: tr.notificationReminderBody,
        //只有用户主动打开提醒时才复查权限，避免每次冷启动都弹权限框
        ensurePermission: ensurePermission,
      );
    } else {
      await _notificationService.cancelReminder();
    }
  }

  /// 界面语言缓存（通知文案用）。
  ///
  /// 必须同步取用：_applyNotificationSchedule 由 loadPreferences 以
  /// unawaited 方式启动（防平台通道拖慢启动），在这里插入额外的 await
  /// 会让"加载完成"与"调度完成"的时序不再确定。
  bool _notificationEnglish = false;

  Translations get _notificationTranslations => _notificationEnglish
      ? const Translations(true)
      : const Translations(false);

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

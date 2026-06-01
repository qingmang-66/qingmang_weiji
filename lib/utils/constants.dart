/// 词典源枚举
enum DictionarySource {
  freeDictionary,  // Free Dictionary API（英英释义）
  youdao,          // 有道词典（中英释义）
}

/// 应用常量
class AppConstants {
  static const String appName = '清茫微记';
  static const String appNameEn = '清茫微记';
  static const String appVersion = '2.0.1';

  // 每日学习目标
  static const int defaultDailyNewWords = 20;
  static const int defaultDailyReviewWords = 50;

  // SM-2 回忆质量
  static const int qualityAgain = 1;    // 完全忘记
  static const int qualityHard = 2;     // 困难
  static const int qualityGood = 3;     // 模糊
  static const int qualityEasy = 4;     // 容易
  static const int qualityPerfect = 5;  // 非常简单

  // 质量标签
  static const Map<int, String> qualityLabels = {
    1: '忘记了',
    2: '困难',
    3: '模糊',
    4: '容易',
    5: '非常简单',
  };

  // 质量颜色
  static const Map<int, int> qualityColors = {
    1: 0xFFE53935, // 红
    2: 0xFFFF9800, // 橙
    3: 0xFFFFC107, // 黄
    4: 0xFF4CAF50, // 绿
    5: 0xFF2196F3, // 蓝
  };

  // 学习模式
  static const int studyModeRecall = 1;     // 看英文想中文（回忆模式）
  static const int studyModeSpell = 2;     // 拼写模式（看中文拼英文）
  static const int studyModeListen = 3;     // 听力模式（听发音说中文）
  static const int studyModeQuiz = 4;       // 测验模式（选择题）

  // 学习模式标签
  static const Map<int, String> studyModeLabels = {
    1: '回忆模式',
    2: '拼写模式',
    3: '听力模式',
    4: '测验模式',
  };

  // 学习模式图标
  static const Map<int, String> studyModeIcons = {
    1: 'visibility',
    2: 'edit',
    3: 'headphones',
    4: 'quiz',
  };

  // 内置词库
  static const String cet4BookName = 'CET-4 四级核心词';
  static const String cet6BookName = 'CET-6 六级核心词';
  static const String kaoyanBookName = '考研英语大纲词';

  // CSV导入模板示例
  static const String csvTemplate = 'word,phonetic,definition,example,example_translation\nhello,/həˈloʊ/,你好,Hello!,你好！';

  // JSON导入模板示例
  static const String jsonTemplate = '[{"word":"hello","phonetic":"/həˈloʊ/","definition":"你好","example":"Hello!","example_translation":"你好！"}]';

  // 设置键名
  static const String settingAudioSource = 'audio_source'; // 'tts' 或 'online'
  static const String settingAccentType = 'accent_type';   // 'us' 或 'uk'
  static const String settingBackupPath = 'last_backup_path';
}

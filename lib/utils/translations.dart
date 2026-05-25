/// 翻译服务 - 简单的双语对照
class Translations {
  static bool _isEnglish = false;
  
  /// 设置当前语言
  static void setLocale(bool isEnglish) {
    _isEnglish = isEnglish;
  }
  
  /// 获取当前语言
  static bool get isEnglish => _isEnglish;
  
  /// 翻译方法
  static String t(String zh, String en) {
    return _isEnglish ? en : zh;
  }
  
  // ========== 常用文本 ==========
  
  // 应用名称
  static String get appName => t('清茫微记', 'QingMang Notes');
  static String get appSlogan => t('让记忆更简单', 'Make memory easier');
  
  // 导航
  static String get navHome => t('首页', 'Home');
  static String get navWordBooks => t('词库', 'Word Books');
  static String get navStats => t('统计', 'Statistics');
  static String get navSettings => t('设置', 'Settings');
  
  // 首页
  static String get todayNewWords => t('今日新词', 'Today New');
  static String get reviewWords => t('待复习', 'To Review');
  static String get startStudy => t('开始学习', 'Start Learning');
  static String get selectWordBook => t('选择词库', 'Select Word Book');
  
  // 词库
  static String get myWordBooks => t('我的词库', 'My Word Books');
  static String get createBook => t('创建词库', 'Create Book');
  static String get bookName => t('词库名称', 'Book Name');
  static String get bookDescription => t('词库描述', 'Description');
  static String get wordCount => t('单词数', 'Words');
  
  // 学习
  static String get learning => t('学习中', 'Learning');
  static String get correct => t('正确', 'Correct');
  static String get incorrect => t('错误', 'Incorrect');
  static String get nextWord => t('下一个', 'Next');
  static String get finishStudy => t('完成学习', 'Finish');
  
  // 设置
  static String get appearance => t('外观', 'Appearance');
  static String get darkMode => t('深色模式', 'Dark Mode');
  static String get language => t('语言', 'Language');
  static String get learningSettings => t('学习设置', 'Learning Settings');
  static String get dailyNewWords => t('每日新词', 'Daily New Words');
  static String get dailyReviewLimit => t('每日复习上限', 'Daily Review Limit');
  static String get audio => t('发音', 'Audio');
  static String get autoPlayAudio => t('自动发音', 'Auto Play');
  static String get onlineAudio => t('在线真人发音', 'Online Voice');
  static String get localTTS => t('本地 TTS', 'Local TTS');
  static String get speechRate => t('语速', 'Speech Rate');
  static String get slow => t('慢速', 'Slow');
  static String get normal => t('正常', 'Normal');
  static String get fast => t('快速', 'Fast');
  static String get usPronunciation => t('美音', 'US Pronunciation');
  static String get ukPronunciation => t('英音', 'UK Pronunciation');
  static String get dataManagement => t('数据管理', 'Data Management');
  static String get backupData => t('备份数据', 'Backup Data');
  static String get restoreData => t('恢复数据', 'Restore Data');
  static String get importWordBook => t('导入词库', 'Import Word Book');
  static String get clearAllData => t('清除所有数据', 'Clear All Data');
  static String get about => t('关于', 'About');
  static String get version => t('版本', 'Version');
  static String get openSourceLicense => t('开源协议', 'Open Source License');
  
  // 统计
  static String get totalWords => t('总单词数', 'Total Words');
  static String get learnedWords => t('已学习', 'Learned');
  static String get streak => t('连续学习', 'Streak');
  static String get days => t('天', 'days');
  
  // 按钮
  static String get confirm => t('确定', 'Confirm');
  static String get cancel => t('取消', 'Cancel');
  static String get save => t('保存', 'Save');
  static String get delete => t('删除', 'Delete');
  static String get edit => t('编辑', 'Edit');
  static String get add => t('添加', 'Add');
  static String get import => t('导入', 'Import');
  static String get export => t('导出', 'Export');
  
  // 消息
  static String get backupSuccess => t('备份成功', 'Backup Success');
  static String get backupFailed => t('备份失败', 'Backup Failed');
  static String get restoreSuccess => t('恢复成功', 'Restore Success');
  static String get restoreFailed => t('恢复失败', 'Restore Failed');
  static String get importSuccess => t('导入成功', 'Import Success');
  static String get importFailed => t('导入失败', 'Import Failed');
  static String get deleteConfirm => t('确认删除？', 'Confirm Delete?');
  static String get clearConfirm => t('确定清除所有数据吗？此操作不可恢复。', 'Confirm clear all data? This cannot be undone.');
  
  // 其他
  static String get loading => t('正在加载...', 'Loading...');
  static String get noData => t('暂无数据', 'No Data');
  static String get error => t('错误', 'Error');
  static String get success => t('成功', 'Success');

// 统计增强
static String get estimatedVocabulary => t('估算词汇量', 'Estimated Vocabulary');
static String get studyStreak => t('学习连续', 'Study Streak');
static String get studyCalendar => t('学习日历', 'Study Calendar');
static String get voiceSource => t('发音源', 'Voice Source');
static String get youdaoOnline => t('有道在线', 'Youdao Online');
static String get youdaoVoiceDesc => t('有道真人发音 (需网络)', 'Youdao Voice (need network)');
static String get localTtsDesc => t('本地 TTS 合成音', 'Local TTS');
static String get bookNameHint => t('例如：GRE 核心词', 'e.g., GRE Core Words');
static String get descriptionOptional => t('描述（可选）', 'Description (Optional)');
static String get briefDescription => t('简单描述这个词库', 'Brief description');
static String get one => t('一', 'Mon');
static String get two => t('二', 'Tue');
static String get three => t('三', 'Wed');
static String get four => t('四', 'Thu');
static String get five => t('五', 'Fri');
static String get six => t('六', 'Sat');
static String get seven => t('日', 'Sun');
static String get todayWords => t('今日词数', "Today's Words");
static String get next => t('下一个', 'Next');

// 统计页面完整翻译
static String get notLearned => t('未学习', 'Not Learned');
static String get learned => t('已学习', 'Learned');
static String get todayData => t('今日数据', 'Today');
static String get newWords => t('新学', 'New');
static String get review => t('复习', 'Review');
static String get totalWordsCount => t('总词数', 'Total');
static String get memoryStages => t('记忆阶段分布', 'Memory Stages');
static String get initial => t('初步', 'Initial');
static String get consolidating => t('巩固', 'Consolidating');
static String get familiar => t('熟悉', 'Familiar');
static String get mastered => t('掌握', 'Mastered');
static String get achievements => t('成就徽章', 'Achievements');
static String get firstStudy => t('首次学习', 'First Study');
static String get streak3Days => t('3天连续', '3-Day Streak');
static String get streak7Days => t('7天连续', '7-Day Streak');
static String get streak30Days => t('30天连续', '30-Day Streak');
static String get streak100Days => t('百天连续', '100-Day Streak');
static String get learn10Words => t('学习10词', 'Learn 10 Words');
static String get learn50Words => t('学习50词', 'Learn 50 Words');
static String get learn100Words => t('学习100词', 'Learn 100 Words');
static String get todayNew => t('今日新学', 'Today New');
static String get efficientStudy => t('高效学习', 'Efficient Study');

// 统计页面新增翻译
static String get vocabulary => t('词汇量', 'Vocabulary');
static String get progress => t('学习进度', 'Progress');
static String get startLearning => t('开始学习吧！', 'Start learning!');
static String get beginner => t('入门级 — 继续加油！', 'Beginner — Keep going!');
static String get elementary => t('基础级 — 已超越大部分初学者', 'Elementary — Beyond most beginners');
static String get cet4Level => t('CET-4 水平 — 日常英语无障碍', 'CET-4 Level — Daily English fluent');
static String get cet6Level => t('CET-6 水平 — 可应对多数场景', 'CET-6 Level — Handle most situations');
static String get graduateLevel => t('考研水平 — 学术英语基础', 'Graduate Level — Academic English ready');
static String get ieltsToeflLevel => t('雅思/托福水平 — 高阶英语能力', 'IELTS/TOEFL Level — Advanced English');
static String get expertLevel => t('专业级 — 英语达人！', 'Expert Level — English master!');
static String get dayStreak => t('天连续', 'Day Streak');
static String get todayReviewed => t('今日复习', 'Today Reviewed');
static String get due => t('待复习', 'Due');
static String get newWordsCount => t('新学', 'New');
static String get reviewCount => t('复习', 'Review');
static String get studyRecord => t('学习记录', 'Study Record');
static String get pastYear => t('过去一年的学习记录', 'Study record of the past year');
static String get activeDays => t('活跃天数', 'Active');
static String get totalWordsLabel => t('总词数', 'Words');
static String get bestDay => t('单日最高', 'Best Day');
static String get less => t('少', 'Less');
static String get more => t('多', 'More');
static String get wordsUnit => t('词', 'words');
static String get reviewTrend => t('复习趋势', 'Review Trend');
static String get total => t('总计', 'Total');
static String get avg => t('日均', 'Avg');
static String get max => t('峰值', 'Max');
static String get noDataYet => t('暂无数据', 'No data yet');
static String get memoryStageDistribution => t('记忆阶段分布', 'Memory Stage Distribution');
static String get startStudyingToSee => t('开始学习后查看分布', 'Start studying to see distribution');
static String get achievementCenter => t('成就中心', 'Achievements');
static String get firstStep => t('初次见面', 'First Step');
static String get allMilestonesAchieved => t('🎉 已达成所有里程碑！', '🎉 All milestones achieved!');
static String get daysToReach => t('天', 'days');
static String get daysToNext => t('还需', '');
static String get nextMilestone => t('天达成下一里程碑', 'days to next milestone');
static String get noAchievementsYet => t('暂无成就', 'No achievements yet');
static String get reviewMaster => t('复习达人', 'Review Master');
static String get learn500Words => t('学习500词', '500 Words');
}

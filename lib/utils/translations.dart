import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';

/// 翻译服务 - 简单的双语对照
///
/// 使用方式：
/// ```dart
/// // 在 Widget 中推荐使用 BuildContext 扩展
/// final tr = context.tr;
/// Text(tr.appName)
///
/// // 在非 Widget 代码中直接构造
/// const tr = Translations(false); // 中文
/// const tr = Translations(true);  // 英文
/// ```
class Translations {
  final bool isEnglish;
  const Translations(this.isEnglish);

  /// 翻译方法
  String t(String zh, String en) {
    return isEnglish ? en : zh;
  }

  // ========== 常用文本 ==========

  // 应用名称
  String get appName => t('清茫微记', '清茫微记');
  String get appSlogan => t('让记忆更简单', 'Make memory easier');

  // 导航
  String get navHome => t('首页', 'Home');
  String get navWordBooks => t('词库', 'Word Books');
  String get navStats => t('统计', 'Statistics');
  String get navSettings => t('设置', 'Settings');

  // 首页
  String get todayNewWords => t('今日新词', 'Today New');
  String get reviewWords => t('待复习', 'To Review');
  String get startStudy => t('开始学习', 'Start Learning');
  String get selectWordBook => t('选择词库', 'Select Word Book');
  String get homeFavoritesTitle => t('收藏夹', 'Favorites');
  String get homeFavoritesSubtitle =>
      t('查看收藏单词并进行专项学习', 'View favorites and start specialized study');
  String get homeCustomSetsTitle => t('自定义单词集', 'Custom Word Sets');
  String get homeCustomSetsSubtitle =>
      t('创建专题词集并进行专项学习', 'Create custom sets and start specialized study');
  String get noLearnableWordsInSet =>
      t('当前词集没有可学习单词', 'No learnable words in current set');

  // 词库
  String get myWordBooks => t('我的词库', 'My Word Books');
  String get createBook => t('创建词库', 'Create Book');
  String get bookName => t('词库名称', 'Book Name');
  String get bookDescription => t('词库描述', 'Description');
  String get wordCount => t('单词数', 'Words');

  // 学习
  String get learning => t('学习中', 'Learning');
  String get correct => t('正确', 'Correct');
  String get incorrect => t('错误', 'Incorrect');
  String get nextWord => t('下一个', 'Next');
  String get finishStudy => t('完成学习', 'Finish');

  // 设置
  String get appearance => t('外观', 'Appearance');
  String get darkMode => t('深色模式', 'Dark Mode');
  String get splashAnimationSpeed => t('开启动画速度', 'Splash Animation Speed');
  String get splashAnimationSpeedDesc =>
      t('调整启动页动画播放速度', 'Adjust the speed of the splash screen animation');
  String get speedFast => t('快速', 'Fast');
  String get speedComfortable => t('舒适', 'Comfortable');
  String get speedSlow => t('缓慢', 'Slow');
  String get navPosition => t('导航位置', 'Navigation Position');
  String get navPositionTitle => t('导航栏位置', 'Navigation Bar Position');
  String get navPositionDesc => t(
    '选择导航栏显示在左侧还是底部',
    'Choose whether to show the navigation bar on the left or bottom',
  );
  String get navBottom => t('底部', 'Bottom');
  String get navLeft => t('左侧', 'Left');
  String get language => t('语言', 'Language');
  String get learningSettings => t('学习设置', 'Learning Settings');
  String get dailyNewWords => t('每日新词', 'Daily New Words');
  String get dailyReviewLimit => t('每日复习上限', 'Daily Review Limit');
  String get audio => t('发音', 'Audio');
  String get autoPlayAudio => t('自动发音', 'Auto Play');
  String get onlineAudio => t('在线真人发音', 'Online Voice');
  String get localTTS => t('本地 TTS', 'Local TTS');
  String get speechRate => t('语速', 'Speech Rate');
  String get slow => t('慢速', 'Slow');
  String get normal => t('正常', 'Normal');
  String get fast => t('快速', 'Fast');
  String get usPronunciation => t('美音', 'US Pronunciation');
  String get ukPronunciation => t('英音', 'UK Pronunciation');
  String get dataManagement => t('数据管理', 'Data Management');
  String get backupData => t('备份数据', 'Backup Data');
  String get restoreData => t('恢复数据', 'Restore Data');
  String get importWordBook => t('导入词库', 'Import Word Book');
  String get clearAllData => t('清除所有数据', 'Clear All Data');
  String get about => t('关于', 'About');
  String get version => t('版本', 'Version');
  String get openSourceLicense => t('开源协议', 'Open Source License');

  // 统计
  String get totalWords => t('总单词数', 'Total Words');
  String get learnedWords => t('已学习', 'Learned');
  String get streak => t('连续学习', 'Streak');
  String get days => t('天', 'days');

  // 按钮
  String get confirm => t('确定', 'Confirm');
  String get cancel => t('取消', 'Cancel');
  String get save => t('保存', 'Save');
  String get delete => t('删除', 'Delete');
  String get edit => t('编辑', 'Edit');
  String get add => t('添加', 'Add');
  String get import => t('导入', 'Import');
  String get export => t('导出', 'Export');

  // 消息
  String get backupSuccess => t('备份成功', 'Backup Success');
  String get backupFailed => t('备份失败', 'Backup Failed');
  String get restoreSuccess => t('恢复成功', 'Restore Success');
  String get restoreFailed => t('恢复失败', 'Restore Failed');
  String get importSuccess => t('导入成功', 'Import Success');
  String get importFailed => t('导入失败', 'Import Failed');
  String get deleteConfirm => t('确认删除？', 'Confirm Delete?');
  String get clearConfirm =>
      t('确定清除所有数据吗？此操作不可恢复。', 'Confirm clear all data? This cannot be undone.');

  // 其他
  String get loading => t('正在加载...', 'Loading...');
  String get noData => t('暂无数据', 'No Data');
  String get error => t('错误', 'Error');
  String get success => t('成功', 'Success');

  // 统计增强
  String get estimatedVocabulary => t('估算词汇量', 'Estimated Vocabulary');
  String get studyStreak => t('学习连续', 'Study Streak');
  String get studyCalendar => t('学习日历', 'Study Calendar');
  String get voiceSource => t('发音源', 'Voice Source');
  String get youdaoOnline => t('有道在线', 'Youdao Online');
  String get localTtsDesc => t('本地 TTS 合成音', 'Local TTS');
  String get bookNameHint => t('例如：GRE 核心词', 'e.g., GRE Core Words');
  String get descriptionOptional => t('描述（可选）', 'Description (Optional)');
  String get briefDescription => t('简单描述这个词库', 'Brief description');
  String get one => t('一', 'Mon');
  String get two => t('二', 'Tue');
  String get three => t('三', 'Wed');
  String get four => t('四', 'Thu');
  String get five => t('五', 'Fri');
  String get six => t('六', 'Sat');
  String get seven => t('日', 'Sun');
  String get todayWords => t('今日词数', "Today's Words");
  String get next => t('下一个', 'Next');

  // 统计页面完整翻译
  String get notLearned => t('未学习', 'Not Learned');
  String get learned => t('已学习', 'Learned');
  String get todayData => t('今日数据', 'Today');
  String get newWords => t('新学', 'New');
  String get review => t('复习', 'Review');
  String get totalWordsCount => t('总词数', 'Total');
  String get memoryStages => t('记忆阶段分布', 'Memory Stages');
  String get initial => t('初步', 'Initial');
  String get consolidating => t('巩固', 'Consolidating');
  String get familiar => t('熟悉', 'Familiar');
  String get mastered => t('掌握', 'Mastered');
  String get achievements => t('成就徽章', 'Achievements');
  String get firstStudy => t('首次学习', 'First Study');
  String get streak3Days => t('3天连续', '3-Day Streak');
  String get streak7Days => t('7天连续', '7-Day Streak');
  String get streak30Days => t('30天连续', '30-Day Streak');
  String get streak100Days => t('百天连续', '100-Day Streak');
  String get learn10Words => t('学习10词', 'Learn 10 Words');
  String get learn50Words => t('学习50词', 'Learn 50 Words');
  String get learn100Words => t('学习100词', 'Learn 100 Words');
  String get todayNew => t('今日新学', 'Today New');
  String get efficientStudy => t('高效学习', 'Efficient Study');

  // 统计页面新增翻译
  String get studyStats => t('学习统计', 'Study Stats');
  String get vocabulary => t('词汇量', 'Vocabulary');
  String get progress => t('学习进度', 'Progress');
  String get startLearning => t('开始学习吧！', 'Start learning!');
  String get beginner => t('入门级 — 继续加油！', 'Beginner — Keep going!');
  String get graduateLevel =>
      t('考研水平 — 学术英语基础', 'Graduate Level — Academic English ready');
  String get ieltsToeflLevel =>
      t('雅思/托福水平 — 高阶英语能力', 'IELTS/TOEFL Level — Advanced English');
  String get expertLevel => t('专业级 — 英语达人！', 'Expert Level — English master!');
  String get dayStreak => t('天连续', 'Day Streak');
  String get todayReviewed => t('今日复习', 'Today Reviewed');
  String get due => t('待复习', 'Due');
  String get newWordsCount => t('新学', 'New');
  String get reviewCount => t('复习', 'Review');
  String get studyRecord => t('学习记录', 'Study Record');
  String get pastYear => t('过去一年的学习记录', 'Study record of the past year');
  String get activeDays => t('活跃天数', 'Active Days');
  String get totalWordsLabel => t('总词数', 'Total Words');
  String get learnedWordsLabel => t('已学', 'Learned');
  String get unlearnedWordsLabel => t('未学', 'Unlearned');
  String get progressPercentLabel => t('完成度', 'Progress');
  String get bestDay => t('单日最高', 'Best Day');
  String get less => t('少', 'Less');
  String get more => t('多', 'More');
  String get wordsUnit => t('词', 'words');
  String get reviewTrend => t('复习趋势', 'Review Trend');
  String get reviewForecastTitle => t('未来复习压力', 'Upcoming Review Load');
  String get reviewForecastDesc =>
      t('未来 7 天预计到期复习数量', 'Due reviews expected in the next 7 days');
  String get noUpcomingReviews =>
      t('未来 7 天暂无复习压力', 'No upcoming review load in the next 7 days');
  String get total => t('总计', 'Total');
  String get avg => t('日均', 'Avg');
  String get max => t('峰值', 'Max');
  String get noDataYet => t('暂无数据', 'No data yet');
  String get memoryStageDistribution =>
      t('记忆阶段分布', 'Memory Stage Distribution');
  String get startStudyingToSee =>
      t('开始学习后查看分布', 'Start studying to see distribution');
  String get achievementsLabel => t('成就', 'Achievements');
  String get achievementCenter => t('成就中心', 'Achievement Center');
  String get firstStep => t('初次见面', 'First Step');
  String get allMilestonesAchieved =>
      t('🎉 已达成所有里程碑！', '🎉 All milestones achieved!');
  String get daysToReach => t('天', 'days');
  String get daysToNext => t('还需', '');
  String get nextMilestone => t('天达成下一里程碑', 'days to next milestone');
  String get noAchievementsYet => t('暂无成就', 'No achievements yet');
  String get reviewMaster => t('复习达人', 'Review Master');
  String get learn500Words => t('学习500词', '500 Words');

  // ========== 新增翻译键（第 3 轮） ==========

  // 首页
  String get currentBook => t('当前词库', 'Current Book');
  String get emptyWordBook => t('暂无词库', 'No Word Books');
  String get emptyWordBookDesc =>
      t('添加词库以开始学习', 'Add a word book to start learning');
  String get goToWordBooks => t('前往词库', 'Go to Word Books');
  String get continueStudy => t('继续上次学习', 'Continue Last Study');
  String get continueStudyUnavailable => t(
    '上次学习进度已失效，请重新开始',
    'Last study progress is no longer available. Please start again.',
  );
  String get startNewWords => t('开始学习新词', 'Start New Words');
  String get quickActions => t('快捷操作', 'Quick Actions');
  String get wrongWords => t('错词本', 'Wrong Words');
  String get wrongWordsCount => t('个错词', ' wrong words');
  String get wrongWordsReviewTitle => t('错词专项复习', 'Wrong Words Review');
  String get selectedWrongWordsReviewTitle =>
      t('选中错词复习', 'Selected Wrong Words Review');
  String get noWrongWordsToReview => t('没有可复习的错词', 'No wrong words to review');
  String get chooseWrongWordsReviewMode =>
      t('选择错词复习模式', 'Choose wrong words review mode');
  String get initFailed => t('初始化失败', 'Initialization Failed');
  String get unknownError => t('未知错误', 'Unknown Error');
  String get retry => t('重试', 'Retry');
  String get today => t('Today', 'Today');
  String get todayAdviceTitle => t('今日建议', 'Today Advice');
  String get todayAdviceReview =>
      t('优先完成到期复习，避免记忆回落。', 'Review due words first to protect retention.');
  String get todayAdviceNewWords =>
      t('今天还有新词额度，可以继续推进词库。', 'You still have new-word capacity today.');
  String get todayAdviceDone =>
      t('今日计划已完成，保持节奏即可。', 'Today’s plan is complete. Keep the rhythm.');
  String get todayAdviceWaitReview => t(
    '当前词库新词已完成，等待后续复习安排。',
    'All new words are learned. Wait for upcoming reviews.',
  );
  String get newWordsLabel => t('新词', 'New');

  // 词库页面
  String get wordBooksTitle => t('词库', 'Word Books');
  String get selectedCount => t('已选择', 'Selected');
  String get wordBooksCount => t('个词库', ' word books');
  String get builtInBooks => t('内置词库', 'Built-in Books');
  String get batchDelete => t('批量删除词库', 'Batch Delete');
  String get createWordBook => t('创建词库', 'Create Word Book');
  String get importing => t('正在导入...', 'Importing...');
  String get importProgress => t('', '');
  String get pleaseSelect => t('请选择词库', 'Please select');
  String get deleteCount => t('删除', 'Delete');
  String get noWordBooksYet => t('还没有词库', 'No word books yet');
  String get noWordBooksDesc =>
      t('添加内置词库或创建自定义词库', 'Add built-in books or create custom ones');
  String get addBuiltIn => t('添加内置词库', 'Add Built-in');
  String get confirmDeleteTitle => t('确认删除', 'Confirm Delete');
  String get confirmDeleteBooks => t('确定要删除选中的', 'Confirm delete selected');
  String get deletedCount => t('已删除', 'Deleted');
  String get wordBooks => t('个词库', ' word books');
  String get bookNameLabel => t('词库名称', 'Book Name');
  String get bookNameExample => t('例如：GRE核心词', 'e.g., GRE Core Words');
  String get descriptionLabel => t('描述（可选）', 'Description (Optional)');
  String get create => t('创建', 'Create');
  String get confirmDeleteBook => t('确定要删除词库', 'Confirm delete word book');
  String get selectAll => t('全选', 'Select All');
  String get close => t('关闭', 'Close');
  String get importSelected => t('导入', 'Import');
  String get importCount => t('', '');
  String get wordsSuffix => t('词', ' words');
  String get importSuccessCount => t('成功导入', 'Successfully imported');
  String get importFailedRetry =>
      t('导入失败，请稍后重试', 'Import failed, please retry');
  String get wordList => t('个单词', ' words');

  // 学习页面
  String get selectAtLeastOne =>
      t('请至少选择一个单词', 'Please select at least one word');
  String get noSelectedWords => t('没有选中的单词', 'No selected words');
  String get study => t('学习', 'Study');
  String get reviewMode => t('复习', 'Review');
  String get selectStudyMode => t('选择学习模式', 'Select Study Mode');
  String get emptyBookHint =>
      t('词库为空，请先添加单词', 'Book is empty, please add words first');
  String get dailyNewCompletedTitle =>
      t('今日新词已完成', 'Daily new words completed');
  String get dailyNewCompletedDesc => t(
    '今天的新词额度已用完，词库里仍有未学单词，明天会继续安排。',
    'Your daily new-word quota is used. There are still unlearned words, and they will continue tomorrow.',
  );
  String get allNewWordsLearnedTitle => t('当前词库已全部学完', 'All new words learned');
  String get allNewWordsLearnedDesc => t(
    '当前词库没有新的未学单词了，后续会按遗忘曲线安排复习。',
    'This word book has no unlearned words. Reviews will follow the memory schedule.',
  );
  String get noDueReviewsTitle => t('今天没有待复习单词', 'No reviews due today');
  String get noDueReviewsDesc => t(
    '当前没有到期复习的单词，可以学习新词或稍后再来。',
    'There are no due reviews now. You can study new words or come back later.',
  );
  String get dailyReviewCompletedTitle =>
      t('今日复习已完成', 'Daily reviews completed');
  String get dailyReviewCompletedDesc => t(
    '今天的复习额度已用完，剩余待复习单词会保留到后续安排。',
    'Your daily review quota is used. Remaining due words will stay scheduled.',
  );
  String get emptyBookDesc => t(
    '当前词库还没有单词，请导入内置词库或添加单词。',
    'This word book has no words. Import a built-in book or add words first.',
  );
  String get todayProgress => t('今日进度', 'Today Progress');
  String get remainingUnlearned => t('未学剩余', 'Unlearned Left');
  String get dueReviewsLabel => t('待复习', 'Due Reviews');
  String get adjustDailyLimit => t('调整每日上限', 'Adjust Daily Limit');
  String get goReview => t('去复习', 'Review');
  String get goStudyNewWords => t('学习新词', 'Study New Words');
  String get studyNewWords => t('学习新词', 'Study New Words');
  String get reviewWordsTitle => t('复习单词', 'Review Words');
  String get selectedWordsCount => t('共', 'Total ');
  String get wordsCountSuffix => t('个单词', ' words');
  String get dailyNewLimitPrefix => t('每日新词上限：', 'Daily new word limit: ');
  String get dailyReviewLimitPrefix => t('每日复习上限：', 'Daily review limit: ');
  String get loaded => t('已加载 ', 'Loaded ');
  String get modeSelection => t('模式选择', 'Mode Selection');
  String get recallMode => t('回忆模式', 'Recall Mode');
  String get spellingMode => t('拼写模式', 'Spelling Mode');
  String get listeningMode => t('听力模式', 'Listening Mode');
  String get quizModeEnToCn => t('测验模式(英选中)', 'Quiz (EN→CN)');
  String get quizModeCnToEn => t('测验模式(中选英)', 'Quiz (CN→EN)');
  String get reviewAdvice => t(
    '复习时建议优先回忆模式，其他模式适合切换练习。',
    'For review, recall mode is recommended; other modes are for variety.',
  );
  String get studyAdvice => t(
    '学习时可以先回忆，再切到拼写和听力巩固。',
    'Start with recall, then switch to spelling and listening to consolidate.',
  );
  String get startLearningBtn => t('开始学习', 'Start Learning');
  String get saveRecordFailed =>
      t('保存学习记录失败，请重试', 'Failed to save study record, please retry');
  String get totalLearned => t('共学习了', 'Total studied ');
  String get wordsLearnedSuffix => t('个单词', ' words');
  String get reviewComplete => t('复习完成！', 'Review Complete!');
  String get studyComplete => t('学习完成！', 'Study Complete!');
  String get back => t('返回', 'Back');
  String get noWordsToStudy => t('暂无可学习单词', 'No words to study');
  String get studyInitializationFailed =>
      t('学习初始化失败', 'Study initialization failed');
  String get studySummaryTitle => t('学习总结', 'Study Summary');
  String get masteredCount => t('掌握词数', 'Mastered');
  String get skippedCount => t('跳过词数', 'Skipped');
  String get weakWordsHint =>
      t('薄弱词会优先进入强化练习', 'Weak words enter strengthen practice first');
  String get masteryRate => t('掌握率', 'Mastery');
  String get correctCount => t('答对数', 'Correct');
  String get wrongCount => t('答错数', 'Wrong');
  String get revealedCount => t('查看答案', 'Revealed');
  String get accuracyRate => t('正确率', 'Accuracy');
  String get wrongWordsList => t('答错单词', 'Wrong Words');
  String get revealedWordsList => t('查看过答案的单词', 'Revealed Words');
  String get backToHome => t('返回首页', 'Back to Home');
  String get reviewWrongWords => t('复习错词', 'Review Wrong Words');
  String get strengthenMode => t('强化', 'Strengthen');
  String get strengthenModeStart =>
      t('进入错词强化模式', 'Entering wrong-word strengthen mode');
  String get keyboardShortcuts => t('快捷键', 'Keyboard Shortcuts');
  String get shortcutEnter => t('Enter', 'Enter');
  String get shortcutEnterDesc => t('检查答案 / 下一题', 'Check answer / Next word');
  String get shortcutCtrlEnter => t('Ctrl/Alt+Enter', 'Ctrl/Alt+Enter');
  String get shortcutCtrlEnterDesc => t('查看答案', 'Reveal answer');
  String get shortcutSpace => t('Space', 'Space');
  String get shortcutSpaceDesc => t('播放发音', 'Play pronunciation');
  String get shortcutNumber => t('1-5', '1-5');
  String get shortcutNumberDesc =>
      t('选择回忆评分 / 选项', 'Select recall quality / option');
  String get addFromBuiltIn => t('从内置词库添加', 'Add from Built-in');
  String get selectBuiltInBookHint =>
      t('请选择一个内置词库', 'Please select a built-in wordbook');
  String get addSelected => t('添加选中', 'Add Selected');
  String get added => t('已添加', 'Added');
  String get selected => t('已选', 'Selected');
  // 阶段三：搜索范围收窄到 word 字段，提示语相应更新
  String get searchWordHint => t('搜索单词...', 'Search words...');
  // 阶段三：搜索增强相关文案
  String get temporaryStudy => t('临时学习', 'Temporary Study');
  String get addToSet => t('加入单词集', 'Add to Set');
  String get toggleFavorite => t('收藏/取消收藏', 'Toggle Favorite');
  String get noSearchWords => t('搜索结果没有可学习单词', 'No learnable words in results');
  String get spellingCloseHint =>
      t('很接近了，再检查一下拼写！', 'Close! Double-check your spelling!');
  String get playFailed => t('播放失败', 'Playback failed');
  String get noDefinition => t('暂无释义', 'No definition');
  String get spellingPrompt =>
      t('根据释义，拼写单词', 'Spell the word based on definition');
  String get listeningPrompt => t('听发音，拼写单词', 'Spell the word after listening');
  String get spellingHint => t('直接输入答案', 'Type the answer directly');
  String get spellingHintDesktop => t(
    '直接输入 · Enter 检查/下一题 · Ctrl/Alt+Enter 查看答案',
    'Type directly · Enter to check/next · Ctrl/Alt+Enter to reveal',
  );
  String get listeningHint => t('听发音后输入答案', 'Listen and type the answer');
  String get listeningHintDesktop => t(
    '直接输入 · Enter 检查/下一题 · Ctrl/Alt+Enter 查看答案 · Space 重播',
    'Type directly · Enter to check/next · Ctrl/Alt+Enter to reveal · Space to replay',
  );
  String get enterEnglishWord => t('请输入英文单词', 'Enter the English word');
  String get checkAnswer => t('检查答案', 'Check Answer');
  String get recheck => t('再次检查', 'Recheck');
  String get answerWrong => t('回答错误，可以继续尝试', 'Incorrect, keep trying');
  String get viewAnswerHint =>
      t('如果想看正确答案，请点击下方按钮。', 'Tap below to view the correct answer.');
  String get clearRetry => t('清空重试', 'Clear & Retry');
  String get viewAnswer => t('查看答案', 'View Answer');
  String get answerCorrect => t('回答正确', 'Correct!');
  String get answerRevealed => t('已查看答案', 'Answer Revealed');
  String get correctAnswer => t('正确答案：', 'Correct answer: ');
  String get definitionLabel => t('释义', 'Definition');
  String get nextQuestion => t('下一题', 'Next');
  String get finish => t('完成', 'Finish');
  String get forget => t('忘记', 'Forgot');
  String get vague => t('模糊', 'Vague');
  String get remember => t('记住', 'Remember');
  String get familiarLabel => t('熟悉', 'Familiar');
  String get showDefinition => t('显示释义', 'Show Definition');
  String get recallHint => t('点击按钮显示释义', 'Tap to show definition');
  String get recallHintDesktop => t(
    'Enter 显示释义 · Space 发音',
    'Enter to show definition · Space to play audio',
  );
  String get qualityHint => t('选择记忆质量', 'Select memory quality');
  String get qualityHintDesktop => t(
    '数字键 1-4 选择记忆质量 · Space 发音',
    'Keys 1-4 for quality · Space to play audio',
  );
  String get qualitySelectHint => t('选择记忆质量', 'Select memory quality');
  String get qualitySelectHintDesktop =>
      t('数字键 1-4 选择记忆质量', 'Keys 1-4 to select memory quality');
  String get qualityKeyHint => t(
    '1 忘记  ·  2 模糊  ·  3 记住  ·  4 熟悉',
    '1 Forgot  ·  2 Vague  ·  3 Remember  ·  4 Familiar',
  );
  String get quizPromptEn =>
      t('请选择正确中文释义', 'Select the correct Chinese meaning');
  String get quizPromptCn => t('请选择正确英文单词', 'Select the correct English word');
  String get quizHint => t('点击选项', 'Tap an option');
  String get quizHintDesktop => t('数字键 1-', 'Keys 1-');
  String get quizHintSuffix => t('', '');
  String get quizHintSuffixDesktop =>
      t(' 选择答案 · Enter 下一题', ' to select · Enter for next');
  String get modeTitleRecall => t('回忆模式', 'Recall');
  String get modeTitleSpelling => t('拼写模式', 'Spelling');
  String get modeTitleListening => t('听力模式', 'Listening');
  String get modeTitleQuizEn => t('测验模式 · 英选中', 'Quiz · EN→CN');
  String get modeTitleQuizCn => t('测验模式 · 中选英', 'Quiz · CN→EN');

  // 单词详情页
  String get wordDetailTitle => t('单词详情', 'Word Detail');
  String get definitionSection => t('释义', 'Definition');
  String get exampleSection => t('例句', 'Example');
  String get rootAffixSection => t('词根词缀', 'Root & Affix');
  String get rootLabel => t('词根', 'Root');
  String get affixLabel => t('词缀', 'Affix');
  String get synonymSection => t('同义词', 'Synonyms');
  String get antonymSection => t('反义词', 'Antonyms');
  String get derivativeSection => t('派生词', 'Derivatives');

  // 错词本
  String get loadWrongWordsFailed => t('加载错词本失败', 'Failed to load wrong words');
  String get removedFromWrongWords => t('已从错词本移除', 'Removed from wrong words');
  String get operationFailed => t('操作失败', 'Operation failed');
  String get confirmMastered => t('确认掌握', 'Confirm Mastered');
  String get confirmMarkMastered => t('确定将', 'Confirm mark');
  String get markedMasteredCount => t('已标记', 'Marked');
  String get featureInDevelopment =>
      t('专项复习功能开发中...', 'Special review feature coming soon...');

  // 设置页面
  String get noBackupFiles =>
      t('暂无备份文件，请先备份', 'No backup files, please backup first');
  String get getBackupListFailed => t('获取备份列表失败', 'Failed to get backup list');
  String get confirmRestoreHint => t(
    '确定要恢复备份吗？这将覆盖当前数据。',
    'Restore backup? This will overwrite current data.',
  );
  String get restoreBackup => t('恢复备份', 'Restore Backup');
  String get restore => t('恢复', 'Restore');
  String get selectFileFailed => t('选择文件失败', 'Failed to select file');
  String get wordBookName => t('词库名称', 'Word Book Name');
  String get confirmInitializeHint => t(
    '确定要初始化应用吗？这会清空数据并重新显示首次引导页。',
    'Initialize app? This will clear data and show onboarding again.',
  );
  String get initializeApp => t('初始化应用', 'Initialize App');
  String get initialize => t('初始化', 'Initialize');
  String get initializeSuccess =>
      t('应用已初始化，正在显示首次引导页', 'App initialized. Showing onboarding.');
  String get initializeFailed => t('初始化失败', 'Initialization failed');

  // 引导页
  String get welcomeTitle => t('欢迎使用清茫微记', 'Welcome to 清茫微记');
  String get welcomeDesc => t(
    '一款围绕词库、复习计划和学习反馈构建的英语记忆工具。',
    'A vocabulary learning app built around word books, review planning, and learning feedback.',
  );
  String get chooseBookTitle =>
      t('先选择适合你的词库', 'Start with the right word book');
  String get chooseBookDesc => t(
    '内置初中、高中、四六级、考研、托福和 SAT 词库，也可以导入或创建自己的词库。',
    'Use built-in junior, senior, CET, graduate, TOEFL, and SAT books, or import your own.',
  );
  String get practiceModesTitle =>
      t('用不同模式强化记忆', 'Practice with multiple modes');
  String get practiceModesDesc => t(
    '回忆、拼写、听力和双向测验会从不同角度帮助你巩固单词。',
    'Recall, spelling, listening, and two-way quizzes reinforce words from different angles.',
  );
  String get reviewScheduleTitle =>
      t('按遗忘曲线安排复习', 'Review on a memory schedule');
  String get reviewScheduleDesc => t(
    '学习结果会转化为复习记录，帮助你优先处理真正需要巩固的单词。',
    'Your results become review records, helping you focus on words that need reinforcement.',
  );
  String get dataProgressTitle => t('用数据看见进步', 'See progress through data');
  String get dataProgressDesc => t(
    '统计页面会展示学习日历、复习趋势、记忆阶段和词汇量估算。',
    'The statistics page shows calendar activity, review trends, memory stages, and vocabulary estimates.',
  );
  String get skip => t('跳过', 'Skip');
  String get getStarted => t('开始学习', 'Get Started');
  String get nextStep => t('下一步', 'Next');
  String get chooseGuideLanguage =>
      t('选择引导语言 / Choose Guide Language', 'Choose Guide Language');
  String get guideLanguageDesc => t(
    '你可以先用中文、English，或中英文一起了解核心功能。',
    'You can use Chinese, English, or both to learn core features.',
  );
  String get languageZh => t('中文', 'Chinese');
  String get languageZhDesc => t('界面和引导使用中文', 'Interface and guide in Chinese');
  String get languageEn => t('English', 'English');
  String get languageEnDesc =>
      t('Use English for the app', 'Use English for the app');
  String get languageBilingual => t('中英一起', 'Bilingual');
  String get languageBilingualDesc =>
      t('引导页同时显示中英文', 'Guide shows both Chinese and English');

  // 引导页 highlights
  String get hlWordBookMgmt => t('词库管理', 'Word books');
  String get hlSmartReview => t('科学复习', 'Smart review');
  String get hlAnalytics => t('学习统计', 'Analytics');
  String get hlBuiltInBooks => t('内置词库', 'Built-in books');
  String get hlCustomBooks => t('自定义词库', 'Custom books');
  String get hlBatchActions => t('批量管理', 'Batch actions');
  String get hlRecallMode => t('回忆模式', 'Recall');
  String get hlSpellingListening => t('拼写/听力', 'Spelling & listening');
  String get hlTwoWayQuiz => t('双向测验', 'Two-way quiz');
  String get hlDueReview => t('待复习提醒', 'Due review');
  String get hlMemoryStages => t('记忆阶段', 'Memory stages');
  String get hlStreaks => t('连续学习', 'Streaks');
  String get hlCalendar => t('学习日历', 'Calendar');
  String get hlReviewTrend => t('复习趋势', 'Review trend');
  String get hlVocabEstimate => t('词汇估算', 'Vocabulary estimate');

  // 错词本补充
  String get refresh => t('刷新', 'Refresh');
  String get specialReview => t('专项复习', 'Special Review');
  String get cancelSelect => t('取消选择', 'Cancel Select');
  String get great => t('太棒了！', 'Great!');
  String get noWrongWordsHint =>
      t('目前没有错词，继续保持！', 'No wrong words, keep it up!');
  String get lookUpDict => t('查词典', 'Look up');
  String get markAsMastered => t('标记为已掌握', 'Mark as mastered');

  // 搜索页面
  String get searchHint => t('搜索单词...', 'Search words...');
  String get searchEmptyHint =>
      t('输入单词或释义进行搜索', 'Enter a word or definition to search');
  String get noMatchFound => t('未找到匹配的单词', 'No matching words found');
  String get tryOtherKeywords => t('尝试其他关键词', 'Try other keywords');
  String get allWordBooks => t('全部词库', 'All Word Books');
  String get recentSearch => t('最近搜索', 'Recent Search');
  String get cancelFavorite => t('已取消收藏', 'Unfavorited');
  String get favoriteActionFailed => t('收藏操作失败', 'Favorite action failed');

  // 统计页面成就
  String get beginnerAchiever => t('初学者', 'Beginner');
  String get vocabExpert => t('词汇达人', 'Vocab Expert');
  String get vocabMaster => t('词汇大师', 'Vocab Master');
  String get reviewNovice => t('复习新手', 'Review Novice');
  String get reviewExpert => t('复习达人', 'Review Expert');
  String get perfectionist => t('完美主义者', 'Perfectionist');

  // 学习页面 (study_screen)
  String get saveRecordFailedHint =>
      t('保存学习记录失败，请重试', 'Failed to save record, please retry');
  String get reviewCompleteTitle => t('复习完成！', 'Review Complete!');
  String get studyCompleteTitle => t('学习完成！', 'Study Complete!');
  String get todayStudiedCount => t('今天复习了', 'Today reviewed ');
  String get todayLearnedCount => t('今天学习了', 'Today studied ');
  String get streakDays => t('已连续学习', 'Streak of');
  String get daysUnit => t(' 天', ' days');
  String get keepGoing =>
      t('继续保持，每天进步一点点', 'Keep going, progress a little every day');
  String get loadingText => t('加载中...', 'Loading...');
  String get learnNewWordsTitle => t('学习新词', 'Learn New Words');
  String get noReviewWords => t('没有待复习的单词！', 'No words to review!');
  String get noNewWords => t('没有新单词了！', 'No new words!');
  String get greatKeepGoing => t('太棒了，继续保持！', 'Great, keep it up!');
  String get showDefinitionBtn => t('显示释义', 'Show Definition');
  String get fetchingDefinition => t('正在获取释义...', 'Fetching definition...');
  String get swipeHint => t('左滑困难 · 右滑容易', 'Swipe left: hard · right: easy');

  // UI 展示页
  String get uiShowcaseTitle => t('UI 组件展示', 'UI Showcase');
  String get buttonComponents => t('按钮组件', 'Buttons');
  String get cardComponents => t('卡片组件', 'Cards');
  String get dialogComponents => t('对话框组件', 'Dialogs');
  String get loadingComponents => t('加载组件', 'Loading');
  String get primaryBtn => t('主要按钮', 'Primary');
  String get secondaryBtn => t('次要按钮', 'Secondary');
  String get textBtn => t('文字按钮', 'Text');
  String get dialogTitle => t('对话框标题', 'Dialog Title');
  String get dialogContent => t('这是对话框内容', 'This is dialog content');
  String get showDialogBtn => t('显示对话框', 'Show Dialog');

  // study_components
  String get recallQuality => t('回忆质量如何？', 'How well did you recall?');
  String get quizResult => t('答题结果如何？', 'How was the quiz result?');
  String get recallQualityHint =>
      t('根据本次复习的记忆程度选择', 'Select based on your recall quality');
  String get quizResultHint =>
      t('根据答对或答错映射到复习质量', 'Maps to review quality based on correct/wrong');
  String get forgot => t('忘记', 'Forgot');
  String get difficult => t('困难', 'Hard');
  String get easy => t('容易', 'Easy');
  String get wrong => t('错误', 'Wrong');
  String get right => t('正确', 'Right');

  // stage_pie_chart
  String get newLearned => t('新学', 'New');
  String get startToSeeDistribution =>
      t('开始学习后查看分布', 'Start learning to see distribution');

  // review_line_chart
  String get days7 => t('7天', '7d');
  String get days14 => t('14天', '14d');
  String get days30 => t('30天', '30d');
  String get dailyAvg => t('日均', 'Daily Avg');
  String get peak => t('峰值', 'Peak');
  String get wordUnit => t('词', 'words');

  // study_calendar
  String get viewDescription => t('查看功能说明', 'View description');
  String get yearSuffix => t('年', '');
  String get monthSuffix => t('月', '');
  String get studyDaysLabel => t('学习天数', 'Study Days');
  String get studyWordsLabel => t('学习单词', 'Words Studied');
  String get calendarGuideTitle => t('学习日历说明', 'Calendar Guide');
  String get calendarGuide1 =>
      t('• 颜色深浅表示学习数量', '• Color depth indicates study amount');
  String get calendarGuide2 => t('• 今天的日期有蓝色边框', '• Today has a blue border');
  String get calendarGuide3 =>
      t('• 点击右上角可切换月份', '• Tap top-right to switch months');
  String get gotIt => t('知道了', 'Got it');

  // study_heatmap
  String get pastYearRecord => t('过去一年的学习记录', 'Past year learning record');
  String get dailyMax => t('单日最高', 'Daily Max');

  // stats_cards
  String get vocabularyLevel => t('词汇量', 'Vocabulary');
  String get studyProgress => t('学习进度', 'Progress');
  String get startLearningHint => t('开始学习吧！', 'Start learning!');
  String get beginnerLevel => t('入门级 — 继续加油！', 'Beginner — Keep going!');
  String get basicLevel =>
      t('基础级 — 已超越大部分初学者', 'Basic — Beyond most beginners');
  String get cet4Level =>
      t('CET-4 水平 — 日常英语无障碍', 'CET-4 — Daily English is easy');
  String get cet6Level =>
      t('CET-6 水平 — 可应对多数场景', 'CET-6 — Most scenarios covered');
  String get ielts7Level => t('雅思 7+ 水平 — 英语流利', 'IELTS 7+ — Fluent English');
  String get nearNativeLevel => t('专八水平 — 接近母语者', 'Near-native level');
  String get streakCheckIn => t('连续打卡', 'Streak');
  String get totalStudy => t('累计学习', 'Total');

  // word_card
  String get queryDict => t('查询字典', 'Query Dict');
  String get exampleLabel => t('例句', 'Example');
  String get playPronunciation => t('播放发音', 'Play pronunciation');

  // dictionary_dialog
  String get noDefinitionFound =>
      t('未找到该单词的释义', 'No definition found for this word');
  String get noPhonetic => t('无音标', 'No phonetic');
  String get queryFailed => t('查询失败', 'Query failed');

  // settings_sections
  String get darkModeActive => t('当前使用黑夜模式', 'Dark mode is active');
  String get autoModeDesc =>
      t('跟随系统设置自动切换白天/黑夜模式', 'Auto-switch light/dark mode with system');
  String get lightModeActive => t('当前使用白天模式', 'Light mode is active');
  String get displayMode => t('显示模式', 'Display Mode');
  String get lightMode => t('白天模式', 'Light');
  String get darkModeLabel => t('黑夜模式', 'Dark');
  String get systemMode => t('跟随系统', 'System');
  // 通知提醒
  String get notificationSettings => t('提醒设置', 'Reminder Settings');
  String get enableReminder => t('启用每日提醒', 'Enable Daily Reminder');
  String get reminderTime => t('提醒时间', 'Reminder Time');
  String get reminderCondition => t('提醒条件', 'Reminder Condition');
  String get twentyFourHour => t('24 小时制', '24-hour format');
  String get customTime => t('自定义时间', 'Custom time');
  String get selectCustomTime => t('选择自定义时间', 'Select custom time');
  String get hour => t('小时', 'Hour');
  String get minute => t('分钟', 'Minute');
  String get condHasDue => t('有待复习时', 'When reviews are due');
  String get condPlanIncomplete =>
      t('今日计划未完成时', 'When today plan is incomplete');
  String get condEither => t('待复习或计划未完成时', 'When due or plan incomplete');
  // 学习计划
  String get studyPlan => t('学习计划', 'Study Plan');
  String get studyPlanEntry => t('学习计划管理', 'Study Plan Management');
  String get currentLanguage => t('当前语言', 'Current Language');
  String get chineseLabel => t('中文', '中文');
  String get dailyUnit => t('个', 'words');
  String dailyNewWordsCount(int count) =>
      t('$count$dailyUnit', '$count $dailyUnit');
  String dailyReviewWordsCount(int count) =>
      t('$count$dailyUnit', '$count $dailyUnit');
  String dailyNewWordsDesc(int count) => t(
    '每天最多学习 $count 个新词，用完后首页会提示今日新词已完成',
    'Learn up to $count new words per day; Home will show completion after the limit is used',
  );
  String dailyReviewWordsDesc(int count) => t(
    '每天最多安排 $count 个到期复习词，优先保证复习压力可控',
    'Review up to $count due words per day to keep workload manageable',
  );
  String get autoPlayDesc =>
      t('显示单词时自动播放发音', 'Auto-play pronunciation when showing word');
  String get youdaoVoiceDesc => t(
    '使用有道真人发音，音质更自然但需要网络',
    'Use Youdao voice for natural pronunciation; network required',
  );
  String get localTtsDesc2 => t(
    '使用本地 TTS 合成音，离线可用但自然度较低',
    'Use local TTS voice; works offline but sounds less natural',
  );
  String get dictDefinition => t('词典释义', 'Dictionary Definition');
  String get onlineDefinitionFallback =>
      t('在线释义补充', 'Online Definition Fallback');
  String get onlineDefOn =>
      t('开启：释义缺失时自动从网络获取补充', 'On: auto-fetch from network when missing');
  String get onlineDefOff =>
      t('关闭：仅使用本地词库释义', 'Off: use local definitions only');
  String get dictSource => t('词典源', 'Dictionary Source');
  String get dictSourceDesc => t(
    '英英释义适合沉浸理解，中英释义更适合快速确认含义',
    'English definitions support immersion; Chinese-English definitions help quick confirmation',
  );
  String get enEnDefinition => t('英英释义', 'English');
  String get zhEnDefinition => t('中英释义', 'Chinese');
  String get youdaoDict => t('有道词典', 'Youdao Dictionary');
  String get exportToLocal => t(
    '导出到本地备份；手机端可分享到文件管理器/网盘',
    'Export to local backup; on mobile you can share to Files/Drive',
  );
  String get restoreFromBackup =>
      t('从本地备份或系统文件选择历史版本', 'Restore from local backup or system files');
  String get pickExternalBackup =>
      t('从系统文件选择备份…', 'Pick backup from system files…');
  String get backupSharedHint => t(
    '备份已生成，请通过分享面板保存到安全位置',
    'Backup created. Use the share sheet to save it somewhere safe',
  );
  String get importFromTxt =>
      t('从 TXT 文件导入新单词', 'Import words from a TXT file');
  String get notificationPermissionDenied => t(
    '通知权限未授予，提醒可能无法显示。可在系统设置中开启',
    'Notification permission denied. Reminders may not show. Enable it in system settings',
  );
  String get openSystemSettings => t('打开系统设置', 'Open system settings');
  String get resetApp => t('初始化应用', 'Reset App');
  String get resetAppDesc =>
      t('清空数据并重新显示首次引导页', 'Clear data and show onboarding again');
  String get developer => t('开发者', 'Developer');
  String get qingmang => t('清茫', '清茫');
  String get githubLinkCopied => t('GitHub 链接已复制', 'GitHub link copied');
  String get enterNumber => t('请输入数字', 'Enter number');
  String get selectBackupFile => t('选择备份文件', 'Select backup file');
  String get deleteBackup => t('删除备份', 'Delete Backup');
  String get deleteBackupDesc =>
      t('管理并删除本地备份文件', 'Manage and delete local backup files');
  String get confirmDeleteBackup => t(
    '确定要删除此备份文件吗？此操作不可撤销。',
    'Are you sure to delete this backup? This cannot be undone.',
  );
  String get deleteBackupSuccess => t('备份已删除', 'Backup deleted');
  String get deleteBackupFailed => t('删除备份失败', 'Delete backup failed');
  String get closeLabel => t('关闭', 'Close');
  String get errorTitle => t('错误', 'Error');
  String get successTitle => t('成功', 'Success');
  String get fileOpFailed => t('文件操作失败', 'File operation failed');
  String get networkError => t('网络错误', 'Network error');
  String get dbError => t('数据库错误', 'Database error');
  String get englishLabel => t('English', 'English');

  // smart_mode_switch
  String get smartModeSwitch => t('智能模式切换', 'Smart Mode Switch');
  String get smartModeSwitchDesc => t(
    '开启后，系统会根据你的答题表现自动调整学习模式',
    'System will auto-adjust learning mode based on your performance',
  );
  String get smartModeSkipMastered => t('已掌握词自动跳过', 'Auto-skip mastered words');
  String get smartModeSwitchWeak =>
      t('薄弱词切换高效模式', 'Switch weak words to efficient mode');
  String get smartModeSpotCheck => t('低频抽查已掌握词', 'Low-frequency spot check');
  String get skippedWords => t('跳过词', 'Skipped');
  String get smartModeEnabled => t('智能模式已开启', 'Smart mode enabled');
  String get smartModeDisabled => t('智能模式已关闭', 'Smart mode disabled');

  // S-MARS增强功能翻译
  String get scoreDistribution => t('分数分布', 'Score Distribution');
  String get masteryStatus => t('掌握状态', 'Mastery Status');
  String get strongMastered => t('强掌握', 'Strong Mastered');
  String get weakWords => t('薄弱词', 'Weak Words');

  // ========== 通知提醒设置 ==========
  String get reminderCondHasDue => t('有待复习单词时', 'When words are due');
  String get reminderCondPlanIncomplete =>
      t('今日计划未完成时', 'When daily plan is incomplete');
  String get reminderCondEither =>
      t('待复习或计划未完成时', 'When due or plan incomplete');
  String get reminderEnabledDesc => t('已开启每日定时提醒', 'Daily reminder enabled');
  String get reminderDisabledDesc =>
      t('开启后将在指定时间提醒你学习', 'Get reminded to study at a set time');

  // ========== 学习计划 ==========
  String get studyPlanDesc =>
      t('制定背词计划，按目标稳步推进', 'Plan your word learning goals');
  String get createPlan => t('创建计划', 'Create Plan');
  String get planName => t('计划名称', 'Plan Name');
  String get planType => t('计划类型', 'Plan Type');
  String get planTypeFixedDaily => t('每日固定量', 'Fixed Daily');
  String get planTypeFixedDeadline => t('按截止日期', 'By Deadline');
  String get planTypeExamTarget => t('考试目标', 'Exam Target');
  String get planTargetDate => t('目标日期', 'Target Date');
  String get planDailyNewTarget => t('每日新词目标', 'Daily New Target');
  String get planStatusActive => t('进行中', 'Active');
  String get planStatusPaused => t('已暂停', 'Paused');
  String get planStatusCompleted => t('已完成', 'Completed');
  String get pausePlan => t('暂停', 'Pause');
  String get resumePlan => t('恢复', 'Resume');
  String get completePlan => t('完成', 'Complete');
  String get deletePlan => t('删除', 'Delete');
  String get noPlanYet => t('还没有学习计划', 'No study plan yet');
  String get planProgress => t('计划进度', 'Plan Progress');
  String get createPlanFailed => t('创建计划失败', 'Failed to create plan');
  String get pleaseEnterNameAndSelectBook =>
      t('请输入计划名称并选择词库', 'Please enter plan name and select a word book');
  String get planNameRequired => t('请输入计划名称', 'Please enter a plan name');
  String get wordBookRequired =>
      t('请至少选择一个词库', 'Please select at least one word book');
  String get dailyTargetPositiveInteger =>
      t('每日新词目标必须是正整数', 'Daily new word target must be a positive integer');
  String get targetDateRequired => t('请选择目标日期', 'Please select a target date');

  // ========== 今日任务 ==========
  String get todayTask => t('今日任务', "Today's Task");
  String get todayTaskNew => t('今日新词', 'New Words Today');
  String get todayTaskReview => t('今日复习', 'Reviews Today');
  String get taskCompleted => t('任务完成！', 'Task Completed!');
  String get taskCompletedDesc =>
      t('太棒了，今天的学习目标已达成', 'Great job, today\'s goal is reached');
  String get oneClickStart => t('一键开始', 'Quick Start');

  // ========== 阶段三：收藏夹增强 ==========
  String get editFavorite => t('编辑收藏', 'Edit Favorite');
  String get favoriteActionTitle => t('收藏操作', 'Favorite Actions');
  String get moveToGroup => t('移动到分组', 'Move to Group');
  String get removeSelected => t('移除选中', 'Remove Selected');
  String get removeFromFavorites => t('取消收藏', 'Remove from Favorites');
  String get deselectAll => t('全不选', 'Deselect All');
  String get batchMode => t('批量', 'Batch');
  String batchRemoveConfirm(int count) =>
      t('确认从收藏夹移除 $count 个单词？', 'Remove $count words from favorites?');
  String get lastStudiedAt => t('上次复习', 'Last Studied');
  String get neverStudied => t('从未复习', 'Never Studied');
  String get noteHint => t('备注（可选）', 'Note (optional)');
  String get groupHint => t('选择分组', 'Choose Group');
  String get newGroupNameHint => t('新建分组', 'New Group');
  String get sortBy => t('排序方式', 'Sort By');
  String get sortCreatedDesc => t('最近收藏', 'Recently Added');
  String get sortWordAsc => t('字母 A→Z', 'Alphabetical A→Z');
  String get sortLastStudiedDesc => t('最近复习', 'Recently Studied');
  String get favoriteUpdated => t('收藏已更新', 'Favorite Updated');
  String get addedToFavorites => t('已加入收藏夹', 'Added to Favorites');
  String get removedFromFavorites => t('已从收藏夹移除', 'Removed from Favorites');
  String get addToFavorites => t('加入收藏夹', 'Add to Favorites');
  String get addToFavoritesFailed => t('加入收藏失败', 'Failed to add to favorites');
  String get loadFavoritesFailed => t('加载收藏夹失败', 'Failed to load favorites');
  String get noFavoritesToStudy =>
      t('当前收藏夹没有可学习单词', 'No learnable words in current favorites');
  String get removeFavoriteFailed => t('取消收藏失败', 'Failed to remove favorite');
  String get favoritesTitle => t('收藏夹', 'Favorites');
  String get noFavoritesYet => t('还没有收藏单词', 'No favorites yet');
  String get startFavoritesSpecialStudy =>
      t('开始收藏夹专项学习', 'Start Favorites Study');
  String get moveFavoriteFailed => t('移动分组失败', 'Failed to move favorite');
  String get batchRemoveFavoritesFailed =>
      t('批量移除失败', 'Failed to batch remove favorites');
  String get updateFavoriteFailed => t('更新收藏失败', 'Failed to update favorite');
  String allGroupsWithCount(int count) => t('全部 ($count)', 'All ($count)');
  String daysAgo(int days) => t('$days 天前', '$days days ago');
  String hoursAgo(int hours) => t('$hours 小时前', '$hours hours ago');
  String get justNow => t('刚刚', 'Just now');

  // 阶段三：自定义词集增强
  String get customWordSets => t('自定义单词集', 'Custom Word Sets');
  String get search => t('搜索', 'Search');
  String get searchSetsHint =>
      t('搜索词集名称或描述', 'Search sets by name or description');
  String get setNameLabel => t('名称', 'Name');
  String get setNameHint => t('请输入词集名称', 'Enter set name');
  String get setDescriptionLabel => t('描述（可选）', 'Description (optional)');
  String get setDescriptionHint => t('例如：商务场景常用词汇', 'e.g. Business vocabulary');
  String get renameSet => t('重命名单词集', 'Rename Set');
  String get rename => t('重命名', 'Rename');
  String get remove => t('移除', 'Remove');
  String get createWordSet => t('创建单词集', 'Create Word Set');
  String get createNewSet => t('创建新词集', 'Create New Set');
  String get setActionTitle => t('词集操作', 'Set Actions');
  String get wordAlreadyInSet => t('该词已在词集中', 'Word already in set');
  String get addedToSet => t('已加入单词集', 'Added to set');
  String get addToSetFailed => t('加入单词集失败', 'Failed to add to set');
  String get deleteSet => t('删除单词集', 'Delete Set');
  String deleteSetConfirm(String name) => t(
    '确定删除 "$name" 吗？词集内的单词条目也会被移除，但不会删除词库中的原始单词。',
    'Delete "$name"? Entries inside will be removed, but the original words in the wordbook are not deleted.',
  );
  String get noCustomSets => t('还没有自定义单词集', 'No Custom Word Sets Yet');
  String get batchRemoveWords => t('批量移除单词', 'Batch Remove Words');
  String batchRemoveWordsConfirm(int n) => t(
    '确定从词集中移除选中的 $n 个单词吗？原始词库中的单词不会被删除。',
    'Remove $n words from the set? Original words in the wordbook are not deleted.',
  );
  String get emptySetHint => t(
    '词集中还没有单词，可从单词详情页加入',
    'No words in this set. Add words from the word detail page.',
  );
  String get startSetStudy => t('开始词集专项学习', 'Start Set Study');
  String get sortUpdatedDesc => t('最近更新', 'Recently Updated');
  String get sortNameAsc => t('字母 A→Z', 'Alphabetical A→Z');
  String get sortWordCountDesc => t('单词数从多到少', 'Word Count Desc');
  String get sortAddedAsc => t('加入顺序', 'Add Order');
  String get moveToSet => t('移动到词集', 'Move to Set');
  String get moveToSetTitle => t('选择目标词集', 'Choose Target Set');
  String get moveToSetFailed => t('移动失败', 'Move Failed');
  String get movedToSet => t('已移动到目标词集', 'Moved to Target Set');
  String get noOtherSets => t('没有其他可用的词集', 'No Other Sets Available');
  String get alreadyInSet => t('该词已在词集中', 'Word Already in Set');
  String get select => t('选择', 'Select');
  String wordCountUnit(int n) => t('$n 个单词', '$n words');
  String selectedWordCount(int n) => t('已选 $n 个', 'Selected $n');

  // 阶段四：高频错词排行
  String get topWrongWords => t('高频错词', 'Top Wrong Words');
  String get topWrongWordsDesc =>
      t('基于错误次数、最近错误、查看答案等综合评分', 'Ranked by wrong count, recency, and more');
  String get rank => t('排名', 'Rank');
  String get scoreLabel => t('热度', 'Score');
  String get sortByHotness => t('按热度排序', 'Sort by Hotness');
  String get hotnessSortFailed => t('热度排序失败', 'Hotness sort failed');
  String get noWrongWordsRanked => t('暂无错词数据', 'No Wrong Words Ranked');
  String get noWrongWordsRankedHint => t(
    '完成几次学习后这里会显示最顽固的错词',
    'Finish some study sessions to see top recurring wrong words',
  );
  String get noTopWrongWordsShort => t('暂无错词', 'No wrong words yet');
  String get scoreBreakdown => t('评分明细', 'Score Breakdown');
  String get wrongCountScore => t('错误次数', 'Wrong Count');
  String get recencyScore => t('近期错误', 'Recency');
  String get viewedAnswerScore => t('查看答案', 'Viewed Answer');
  String get reviewWrongScore => t('复习再错', 'Review Wrong');
  String get persistentScore => t('长期顽固', 'Persistent');

  String get weakVocabulary => t('薄弱词库', 'Weak Vocabulary');
  String get weakVocabularySubtitle =>
      t('根据错题、复习表现和掌握度自动分析', 'Analyze weak words from mistakes and mastery');
  String get weakVocabularyEntryHint =>
      t('查看哪些错词最需要优先复习', 'See which wrong words need review first');
  String get weakVocabularyReviewTitle => t('薄弱词专项复习', 'Weak Words Review');
  String get currentWeakWords => t('当前薄弱词', 'Current Weak Words');
  String get averageWeaknessScore => t('平均薄弱分', 'Average Weakness Score');
  String get criticalWeak => t('严重薄弱', 'Critical');
  String get weakLevelWeak => t('明显薄弱', 'Weak');
  String get shakyWeak => t('轻度薄弱', 'Shaky');
  String get normalWeak => t('普通关注', 'Normal');
  String get solidWeak => t('基本稳固', 'Solid');
  String get weaknessScore => t('薄弱分', 'Weakness Score');
  String get whyWeak => t('为什么薄弱', 'Why weak?');
  String get startWeakReview => t('专项复习', 'Review');
  String get conquerTopWeakWords =>
      t('攻克前 10 个薄弱词', 'Review Top 10 Weak Words');
  String get noWeakWords => t('暂无薄弱词', 'No weak words');
  String get noWeakWordsDesc =>
      t('目前没有需要重点关注的词，继续保持！', 'No words need special attention right now.');
  String get sortByWeakness => t('薄弱优先', 'Weakness First');
  String get sortByWrongCount => t('错误最多', 'Most Mistakes');
  String get sortByRecentWrong => t('最近出错', 'Recent Mistake');
  String get sortByMastery => t('掌握最低', 'Lowest Mastery');
  String get wrongCountLabel => t('错误', 'Mistakes');
  String get viewedAnswerCountLabel => t('查看答案', 'Viewed');
  String get correctStreakLabel => t('连续答对', 'Streak');
  String get wrongFrequency => t('错误频率', 'Mistake Frequency');
  String get masteryGap => t('掌握度缺口', 'Mastery Gap');
  String get memoryStability => t('记忆稳定性', 'Memory Stability');
  String get recentMistake => t('近期错误', 'Recent Mistake');
  String get behaviorSignal => t('行为信号', 'Behavior Signal');

  // 周报
  String get weeklyReport => t('每周学习报告', 'Weekly Report');
  String get weeklyReportDetail => t('周报详情', 'Report Detail');
  String get weekRange => t('本周', 'This Week');
  String get lastWeek => t('上周', 'Last Week');
  String get nextWeek => t('下周', 'Next Week');
  String get prevWeekTooltip => t('上周', 'Previous week');
  String get nextWeekTooltip => t('下周', 'Next week');
  String get thisWeekLabel => t('本周', 'This Week');
  String get exportReport => t('导出周报', 'Export Report');
  String get loadingError => t('加载失败', 'Loading failed');
  String get saveFailed => t('保存失败', 'Save failed');
  String get exportFailed => t('导出失败', 'Export failed');
  String get screenshotFailed =>
      t('截图失败，请重试', 'Screenshot failed, please retry');
  String get savedTo => t('已保存到：', 'Saved to: ');
  String get weeklyReportFilePrefix => t('周报_', 'WeeklyReport_');
  String get unitWords => t('个', ' words');
  String get unitDays => t('天', ' days');
  String get trendImproved => t('上升', 'Up');
  String get trendDeclined => t('下降', 'Down');
  String get trendStable => t('持平', 'Stable');
  String get planCompletedDays => t('计划完成', 'Plan Done');
  String get totalSessions => t('学习会话', 'Sessions');
  String get avgSessionScore => t('平均掌握', 'Avg Mastery');
  String get topWeakWords => t('薄弱词排行', 'Top Weak Words');
  String get frequentWrongWords => t('高频错词', 'Frequent Wrong Words');
  String get averageQuality => t('平均质量', 'Avg Quality');
  String get reviewedWords => t('已复习', 'Reviewed');
  String get viewDetail => t('查看详情', 'View Detail');
  String get loadingWeeklyReport => t('正在生成周报...', 'Generating report...');
  String get noFrequentWrongWords =>
      t('本周暂无高频错词，继续保持。', 'No frequent wrong words this week.');

  // 月报
  String get monthlyReport => t('月度学习报告', 'Monthly Report');
  String get generatingMonthlyReport =>
      t('正在生成月报...', 'Generating monthly report...');
  String monthlySummary(int total, int newWords, int reviewWords) => t(
    '本月累计 $total 次学习，新学 $newWords 个，复习 $reviewWords 个。',
    'This month: $total sessions, $newWords new, $reviewWords reviewed.',
  );
  String monthlySubtitle(int days, int planDays, int quality) => t(
    '学习天数 $days 天 · 计划完成 $planDays 天 · 平均质量 $quality%',
    '$days days studied · $planDays plan completed · avg quality $quality%',
  );

  // ========== 阶段四：成就系统 ==========

  // Tab
  String get tabAll => t('全部', 'All');
  String get tabUnlocked => t('已解锁', 'Unlocked');
  String get tabLocked => t('未解锁', 'Locked');

  // 类别
  String get filterAll => t('全部', 'All');
  String get categoryStudy => t('学习', 'Study');
  String get categoryReview => t('复习', 'Review');
  String get categoryStreak => t('连续', 'Streak');
  String get categoryFavorite => t('收藏', 'Favorite');
  String get categoryCustomSet => t('词集', 'Custom Set');
  String get categoryPlan => t('计划', 'Plan');
  String get categorySpecialized => t('专项', 'Specialized');

  // 卡片与提示
  String get recentAchievements => t('最近成就', 'Recent Achievements');
  String get achievementUnlocked => t('🎉 解锁新成就', '🎉 Achievement Unlocked');
  String get noAchievementsInCategory =>
      t('该类别暂无成就', 'No achievements in this category');
  String get loadAchievementsFailed =>
      t('加载成就失败', 'Failed to load achievements');
  String get viewAll => t('查看全部', 'View All');
  String get unlockProgress => t('解锁进度', 'Unlocked');

  // 成就标题
  String get achStudy10Title => t('初学者', 'Beginner');
  String get achStudy50Title => t('勤奋学子', 'Diligent Learner');
  String get achStudy100Title => t('学有所成', 'Centurion');
  String get achStudy500Title => t('词汇专家', 'Lexicon Expert');
  String get achStudy1000Title => t('词汇大师', 'Lexicon Master');

  String get achReview10Title => t('复习新手', 'Review Rookie');
  String get achReview50Title => t('复习达人', 'Review Expert');
  String get achReview200Title => t('复习高手', 'Review Pro');
  String get achReview1000Title => t('复习传奇', 'Review Legend');

  String get achStreak3Title => t('初燃', 'First Spark');
  String get achStreak7Title => t('连击一周', 'Weekly Streak');
  String get achStreak30Title => t('月之恒', 'Monthly Dedication');
  String get achStreak100Title => t('百日筑基', '100-Day Streak');

  String get achFavFirstTitle => t('初识珍藏', 'First Bookmark');
  String get achFav20Title => t('收藏入门', 'Curator');
  String get achFav100Title => t('收藏家', 'Collector');
  String get achFavGroup3Title => t('井井有条', 'Well Organized');
  String get achFavStudiedTitle => t('反复咀嚼', 'Revisited Favorites');

  String get achSetFirstTitle => t('创建词集', 'First Set');
  String get achSet5Title => t('词集管理', 'Set Curator');
  String get achSetStudiedTitle => t('温故词集', 'Revisited Sets');

  String get achPlanWeek3Title => t('计划启动', 'Plan Kicked Off');
  String get achPlanWeek5Title => t('计划稳步', 'Plan Steady');
  String get achPlanWeek7Title => t('计划全勤', 'Plan All-In');
  String get achPlanStudy5Title => t('勤学5日', '5 Study Days');
  String get achPlanStudy7Title => t('全勤一周', '7 Study Days');

  String get achWrongStreak3Title => t('错题连击3', 'Wrong Streak 3');
  String get achWrongStreak10Title => t('错题连击10', 'Wrong Streak 10');

  String get achMastery50Title => t('掌握过半', 'Half Mastered');
  String get achMastery80Title => t('融会贯通', 'Fully Mastered');

  // 成就描述
  String get achStudy10Desc => t('学习 10 个单词', 'Learn 10 words');
  String get achStudy50Desc => t('学习 50 个单词', 'Learn 50 words');
  String get achStudy100Desc => t('学习 100 个单词', 'Learn 100 words');
  String get achStudy500Desc => t('学习 500 个单词', 'Learn 500 words');
  String get achStudy1000Desc => t('学习 1000 个单词', 'Learn 1000 words');

  String get achReview10Desc => t('完成 10 次复习', 'Complete 10 reviews');
  String get achReview50Desc => t('完成 50 次复习', 'Complete 50 reviews');
  String get achReview200Desc => t('完成 200 次复习', 'Complete 200 reviews');
  String get achReview1000Desc => t('完成 1000 次复习', 'Complete 1000 reviews');

  String get achStreak3Desc => t('连续学习 3 天', 'Study 3 days in a row');
  String get achStreak7Desc => t('连续学习 7 天', 'Study 7 days in a row');
  String get achStreak30Desc => t('连续学习 30 天', 'Study 30 days in a row');
  String get achStreak100Desc => t('连续学习 100 天', 'Study 100 days in a row');

  String get achFavFirstDesc => t('收藏第一个单词', 'Bookmark first word');
  String get achFav20Desc => t('收藏 20 个单词', 'Bookmark 20 words');
  String get achFav100Desc => t('收藏 100 个单词', 'Bookmark 100 words');
  String get achFavGroup3Desc => t('建立 3 个收藏分组', 'Create 3 favorite groups');
  String get achFavStudiedDesc =>
      t('通过收藏进行过一次专项学习', 'Start a specialized study from favorites');

  String get achSetFirstDesc => t('创建第一个自定义词集', 'Create first custom set');
  String get achSet5Desc => t('创建 5 个自定义词集', 'Create 5 custom sets');
  String get achSetStudiedDesc =>
      t('通过自定义词集进行过一次专项学习', 'Start a specialized study from a custom set');

  String get achPlanWeek3Desc =>
      t('本周计划完成 3 天', 'Complete plan 3 days this week');
  String get achPlanWeek5Desc =>
      t('本周计划完成 5 天', 'Complete plan 5 days this week');
  String get achPlanWeek7Desc =>
      t('本周计划完成 7 天', 'Complete plan 7 days this week');
  String get achPlanStudy5Desc => t('本周学习 5 天', 'Study 5 days this week');
  String get achPlanStudy7Desc => t('本周学习 7 天', 'Study 7 days this week');

  String get achWrongStreak3Desc =>
      t('在错词本中连续答对 3 次', 'Answer 3 wrong words correctly in a row');
  String get achWrongStreak10Desc =>
      t('在错词本中连续答对 10 次', 'Answer 10 wrong words correctly in a row');

  String get achMastery50Desc => t('词库掌握率达 50%', 'Mastery ratio reaches 50%');
  String get achMastery80Desc => t('词库掌握率达 80%', 'Mastery ratio reaches 80%');

  // TTS 发音异常提示
  String get ttsLocalFailedTitle => t('本地 TTS 异常', 'Local TTS Error');
  String get ttsLocalFailedMessage => t(
    '本地 TTS 播放失败，当前无法正常发音。部分手机需安装系统英文语音包（如 Google 文字转语音）。',
    'Local TTS playback failed. Some devices need an English voice pack (e.g. Google Text-to-speech).',
  );
  String get ttsMissingEngineMessage => t(
    '未检测到英文语音引擎。可安装系统语音包，或切换为在线真人发音。',
    'No English TTS engine found. Install a system voice pack, or switch to online voice.',
  );
  String get ttsOnlineFailedTitle => t('在线发音异常', 'Online Voice Error');
  String get ttsOnlineFailedMessage => t(
    '在线真人发音播放失败，当前无法正常发音。',
    'Online voice playback failed and is currently unavailable.',
  );
  String get ttsBothUnavailableTitle =>
      t('发音功能暂时不可用', 'Pronunciation Unavailable');
  String get ttsBothUnavailableMessage => t(
    '本地 TTS 和在线发音均出现异常，发音功能暂时不可用。',
    'Both local TTS and online voice encountered errors. Pronunciation is temporarily unavailable.',
  );
  String get switchVoiceSourceTitle => t('切换发音源', 'Switch Voice Source');
  String get confirmSwitchToOnlineMessage =>
      t('是否切换为在线真人发音？', 'Switch to online voice?');
  String get confirmSwitchToLocalMessage =>
      t('是否切换为本地 TTS？', 'Switch to local TTS?');
  String get switchToOnline => t('切换为在线真人发音', 'Switch to Online Voice');
  String get switchToLocalTts => t('切换为本地 TTS', 'Switch to Local TTS');
}

/// BuildContext 扩展，方便在 Widget 中获取翻译实例
///
/// 使用方式：`context.tr.study` 替代之前的 `Translations.study`
extension TranslationsX on BuildContext {
  /// 获取与当前语言环境对应的翻译实例
  Translations get tr => Translations(read<ThemeProvider>().isEnglishLocale);
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import 'constants.dart';
import 'platform_info.dart';

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
  String get appName => t('清茫微记', AppConstants.appNameEn);
  String get appSlogan => t('让记忆更简单', 'Make memory easier');

  // 导航
  String get navHome => t('首页', 'Home');
  String get navWordBooks => t('词库', 'Word Books');
  String get navReader => t('阅读', 'Read');
  String get navStats => t('统计', 'Statistics');
  String get navSettings => t('设置', 'Settings');

  // 阅读书架
  String readerWordsCount(int n) =>
      t('$n 词', '$n ${n == 1 ? 'word' : 'words'}');
  String readerProgressLabel(int current, int total, int pct) =>
      t('已读 $current/$total · $pct%', 'Read $current/$total · $pct%');
  String get readerEmptyHint => t(
    '还没有词书。先去"词库"页导入或创建一本词书，再回来开启翻页阅读。',
    'No word books yet. Import or create one in "Word Books", then start reading here.',
  );

  // 首页
  String get todayNewWords => t('今日新词', 'Today New');
  String get reviewWords => t('待复习', 'To Review');
  String get startStudy => t('开始学习', 'Start Learning');
  String get selectWordBook => t('选择词库', 'Select Word Book');

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
    '选择导航栏显示在底部，还是桌面端的左侧/右侧',
    'Show the navigation bar at the bottom, or on the left/right on desktop',
  );
  String get navBottom => t('底部', 'Bottom');
  String get navLeft => t('左侧', 'Left');
  String get navRight => t('右侧', 'Right');
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

  // 设置页分类（一级入口）与二级/三级页面
  String get settingsCommonTitle => t('常用设置', 'Common');
  String get settingsOtherTitle => t('更多设置', 'More');
  String get settingsAudioDictEntry => t('发音与词典', 'Audio & Dictionary');
  String get settingsAudioDictEntryDesc =>
      t('发音源 · 语速 · 词典来源', 'Voice · Speech rate · Dictionary');
  String get settingsRecallEntryDesc =>
      t('释义何时出现 · 等待时长', 'When the definition shows · Delay');
  String get settingsAppearanceAdvancedDesc =>
      t('启动动画 · 循环动效 · 导航位置', 'Splash speed · Loop effects · Navigation');
  String get settingsAppearanceCategory => t('外观与显示', 'Appearance');
  String get settingsAppearanceCategoryDesc =>
      t('主题模式 · 界面风格 · 语言', 'Theme mode · UI style · Language');
  String get settingsStudyCategory => t('学习与发音', 'Study & Audio');
  String get settingsStudyCategoryDesc =>
      t('发音 · 词典 · 回忆模式', 'Audio · Dictionary · Recall');
  String get settingsDataCategory => t('数据与备份', 'Data & Backup');
  String get settingsDataCategoryDesc =>
      t('备份 · 恢复 · 导入 · 初始化', 'Backup · Restore · Import · Reset');
  String get settingsHelpCategory => t('帮助与关于', 'Help & About');
  String get settingsHelpCategoryDesc =>
      t('新手引导 · 功能提示 · 关于本应用', 'Guide · Tips · About');

  // 回忆模式：释义显示方式
  String get recallSettingsTitle => t('回忆模式设置', 'Recall Settings');
  String get recallRevealSectionTitle => t('释义显示', 'Show definition');
  String get recallRevealTriggerLabel => t('如何显示释义', 'How to reveal');
  String get recallRevealDelayed => t('延时自动', 'After delay');
  String get recallRevealTapBlank => t('点击空白', 'Tap blank');
  String get recallRevealSpace => t('Space 键', 'Space key');
  String get recallRevealAll => t('全部', 'All');
  String get recallRevealTriggerDesc => t(
    '回忆模式不再有「显示释义」按钮：可以停留一段时间自动出现、点题面空白处，或直接按空格键',
    'The reveal button is gone: the definition can appear after a delay, on tapping blank space, or by pressing Space',
  );
  /// 移动端没有物理空格键：说明文案不提 Space，避免用户找不存在的触发方式
  String get recallRevealTriggerDescMobile => t(
    '回忆模式不再有「显示释义」按钮：可以停留一段时间自动出现，或点题面空白处',
    'The reveal button is gone: the definition can appear after a delay or on tapping blank space',
  );
  String get recallRevealDelayLabel => t('等待时长', 'Delay');
  String get recallRevealDelayDesc =>
      t('停留多久后自动显示释义', 'How long before the definition appears');
  String recallRevealDelaySeconds(int seconds) => t('$seconds 秒', '$seconds s');
  String get recallRevealDelayCustom => t('自定义', 'Custom');
  String get recallRevealDelayCustomTitle =>
      t('自定义等待时长', 'Custom delay');
  String recallRevealDelayCustomHint(int seconds) =>
      t('停留 $seconds 秒后自动显示释义', 'Reveal automatically after $seconds s');

  // 测验模式设置
  String get quizSettingsTitle => t('测验模式设置', 'Quiz Settings');
  String get quizOptionsPositionLabel => t('选项垂直位置', 'Options height');
  String get quizOptionsPositionDesc => t(
    '四个选项作为一个整体，在屏幕上下方向的整体位置',
    'Where the four options sit vertically on screen, as a whole',
  );
  String get quizOptionsPositionTop => t('靠上', 'Top');
  String get quizOptionsPositionMiddle => t('居中', 'Middle');
  String get quizOptionsPositionBottom => t('靠下', 'Bottom');

  // 统计
  String get totalWords => t('总单词数', 'Total Words');
  String get learnedWords => t('已学习', 'Learned');
  String get streak => t('连续学习', 'Streak');
  String get days => t('天', 'days');

  // 按钮
  String get confirm => t('确定', 'Confirm');
  String get cancel => t('取消', 'Cancel');
  String get exitStudyTitle => t('退出学习', 'Exit Study');
  String get exitStudyMessage => t(
    '当前进度将自动保存，可稍后从首页继续学习',
    'Progress will be saved. You can resume from home later',
  );
  String get exitAutoSaveHint =>
      t('退出学习时进度会自动保存', 'Progress auto-saves when you exit');
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

  /// 恢复成功后展示导入了多少条数据：词库 / 单词 / 复习记录 / 学习计划
  String restoreSuccessWithCounts({
    required int wordBooks,
    required int words,
    required int records,
    required int studyPlans,
  }) {
    final booksLabel = t('词库', 'books');
    final wordsLabel = t('词', 'words');
    final recordsLabel = t('记录', 'records');
    final plansLabel = t('计划', 'plans');
    return t(
      '恢复成功：$wordBooks 个$booksLabel、$words 个$wordsLabel、'
          '$records 条$recordsLabel、$studyPlans 个$plansLabel',
      'Restored: $wordBooks $booksLabel, $words $wordsLabel, '
          '$records $recordsLabel, $studyPlans $plansLabel',
    );
  }

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

  /// 首页词集段标题。原名「快捷操作」，但里面装的是"我的词汇集合"，
  /// 与阅读模式并列，故改为「词集」。
  String get wordCollections => t('词集', 'Collections');
  String get wrongWords => t('错词本', 'Wrong Words');
  String wrongWordsCount(int n) =>
      t('$n 个错词', '$n wrong ${n == 1 ? 'word' : 'words'}');
  String get wrongWordsReviewTitle => t('错词专项复习', 'Wrong Words Review');
  String get selectedWrongWordsReviewTitle =>
      t('选中错词复习', 'Selected Wrong Words Review');
  String get noWrongWordsToReview => t('没有可复习的错词', 'No wrong words to review');
  String get chooseWrongWordsReviewMode =>
      t('选择错词复习模式', 'Choose wrong words review mode');

  // ========== 词集（错题集 / 收藏夹） ==========
  String get wrongWordCollection => t('错题集', 'Mistakes');
  String get favorites => t('收藏夹', 'Favorites');
  String get addToFavorites => t('收藏', 'Add to Favorites');
  String get removeFromFavorites => t('取消收藏', 'Remove from Favorites');
  String get favoriteAdded => t('已加入收藏夹', 'Added to favorites');
  String get favoriteRemoved => t('已移出收藏夹', 'Removed from favorites');
  String favoriteBatchRemoveConfirm(int count) => t(
    '确定取消收藏选中的 $count 个单词？此操作不可撤销',
    'Remove $count selected words from favorites? This cannot be undone',
  );
  String get favoritesEmpty => t('收藏夹还是空的', 'No favorites yet');
  String get favoritesEmptyHint => t(
    '学习或阅读时点右上角 ☆，就能把单词收进这里',
    'Tap ☆ while studying or reading to save a word here',
  );
  String get favoriteSearchHint => t('搜索收藏的单词', 'Search favorites');
  String get favoriteReviewTitle => t('收藏词专项复习', 'Favorites Review');
  String get favoriteFromStudy => t('学习', 'Study');
  String get favoriteFromReader => t('阅读', 'Reader');
  String get favoriteFromHomeSearch => t('首页搜索', 'Home search');
  String get filterBySource => t('来源', 'Source');
  String get filterByWordBook => t('词库', 'Word Book');
  String get allSources => t('全部来源', 'All sources');
  String get clearFilters => t('清除筛选', 'Clear filters');
  String get filterByTime => t('时间', 'Time');
  String get timeRangeAll => t('全部时间', 'All time');
  String get timeRangeToday => t('今天', 'Today');
  String get timeRange7Days => t('近 7 天', 'Last 7 days');
  String get timeRange30Days => t('近 30 天', 'Last 30 days');
  String get sortNewestFirst => t('最新在前', 'Newest first');
  String get sortOldestFirst => t('最早在前', 'Oldest first');
  String get collectionSettings => t('词集设置', 'Collection Settings');
  String get showCountOnHome => t('在首页显示数量', 'Show count on home');
  String get showCountOnHomeHint =>
      t('关闭后首页词集入口只显示图标与名称', 'Hide the count badge on the home entry');
  String get showMasteryProgress => t('显示攻克进度', 'Show mastery progress');
  String get showMasteryProgressHint => t(
    '在错题列表显示"连续答对 x/3"，答对 3 次自动移出错题集',
    'Show "x/3 correct in a row" in the list',
  );
  String get wrongCause => t('错因', 'Cause');
  String get filterByCause => t('按错因筛选', 'Filter by cause');
  String get allCauses => t('全部错因', 'All causes');
  String get causeRevealed => t('看答案', 'Revealed');
  String get causeSpelling => t('拼写错', 'Spelling');
  String get causeListening => t('听写错', 'Listening');
  String get causeQuiz => t('选错', 'Quiz');
  String get causeRecall => t('回忆不出', 'Recall');
  String get causeUnknown => t('暂无错因数据', 'No cause data');
  String get undo => t('撤销', 'Undo');
  String get restoredToWrongWords => t('已恢复到错题集', 'Restored to mistakes');
  String get nothingToUndo => t('没有可撤销的操作', 'Nothing to undo');

  // 阅读模式：标记（记住了 / 收藏）
  String get readerMarkSection => t('标记', 'Marks');
  String get rememberedMarkIcon => t('记住了 · 图标', 'Remembered · icon');
  String get rememberedMarkRow => t('记住了 · 行底色', 'Remembered · row tint');
  String get rememberedMarkWord =>
      t('记住了 · 整行文字变色', 'Remembered · whole-row text');
  String get markColorLabel => t('标记颜色', 'Mark color');
  String get showFavoriteStar => t('显示收藏星标', 'Favorite star');
  String get showFavoriteStarHint =>
      t('在已收藏的单词行尾显示一颗金色星标', 'Show a gold star at the end of favorited words');
  String get initFailed => t('初始化失败', 'Initialization Failed');
  String get unknownError => t('未知错误', 'Unknown Error');
  String get retry => t('重试', 'Retry');
  String get today => t('今天', 'Today');
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
  String get pleaseSelect => t('请选择词库', 'Please select');
  String get deleteCount => t('删除', 'Delete');
  String get noWordBooksYet => t('还没有词库', 'No word books yet');
  String get noWordBooksDesc =>
      t('添加内置词库或创建自定义词库', 'Add built-in books or create custom ones');
  String get addBuiltIn => t('添加内置词库', 'Add Built-in');
  //词库卡片右侧操作按钮的无障碍提示
  String get browseWordList => t('查看单词列表', 'View words');
  String get learningProgress => t('学习进度', 'Progress');
  String get exitMultiSelect => t('取消多选', 'Cancel selection');
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
  String get wordsSuffix => t('词', ' words');
  String get importSuccessCount => t('成功导入', 'Successfully imported');

  /// 内置词库弹窗里给「已在本机」的词库打的标记
  String get alreadyImported => t('已导入', 'Imported');
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

  /// 带单复数的"N 个单词"：中文永远用"个"，英文 1 用 word、其余用 words
  String wordsCount(int n) => t('$n 个单词', '$n ${n == 1 ? 'word' : 'words'}');
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
  String get readerMode => t('阅读模式', 'Reader Mode');
  String get markRemembered => t('记住了', 'Got It');
  String get unmarkRemembered => t('取消记住', 'Unmark');
  String get bookmarksTitle => t('书签', 'Bookmarks');
  // 阅读器底部工具栏（小说式交互：点击屏幕唤出）
  String get readerCatalog => t('目录', 'Contents');
  String get readerNight => t('夜间', 'Night');
  String get readerDay => t('日间', 'Day');
  // 底栏"标记"用「标记」而不是「记住了」，避免与长按菜单里的同名项混淆
  String get readerMark => t('标记', 'Mark');
  String get addBookmarkBtn => t('添加书签', 'Add Bookmark');
  String get bookmarkAdded => t('书签已添加', 'Bookmark added');
  String get bookmarkExists => t('该位置已有书签', 'A bookmark already exists here');
  String get bookmarkLabel => t('书签', 'Bookmark ');
  String get bookmarkNameHint => t('输入书签名称', 'Enter bookmark name');
  String get renameBookmarkBtn => t('重命名', 'Rename');
  String get deleteBookmarkBtn => t('删除书签', 'Delete Bookmark');
  String get readerSettingsTitle => t('阅读设置', 'Reader Settings');
  //设置面板分组标题
  String get groupText => t('文字', 'Text');
  String get groupPageTurn => t('翻页', 'Page Turn');
  String get groupBookmark => t('书签', 'Bookmark');
  String get groupBackground => t('背景', 'Background');
  String get groupSpacing => t('间距', 'Spacing');
  String get lineSpacingLabel => t('行段间距', 'Line Spacing');
  String get pageMarginLabel => t('页面边距', 'Page Margin');
  String get sizeSmall => t('小', 'Small');
  String get sizeMedium => t('适中', 'Medium');
  String get sizeLarger => t('较大', 'Roomy');
  String get sizeLarge => t('大', 'Large');
  String get sizeCustom => t('自定义', 'Custom');
  //一级分组摘要
  String get groupTextDesc => t('字号、粗细', 'Font size & weight');
  String get groupSpacingDesc => t('行段间距、页面边距', 'Spacing & margins');
  String get groupBackgroundDesc => t('背景色、文字色、壁纸', 'Colors & wallpaper');
  String get groupPageTurnDesc => t('翻页效果、点击与音量键', 'Turn effect & controls');
  String get groupBookmarkDesc => t('书签命名方式', 'Bookmark naming');
  String get groupMarkDesc => t('标记方式与颜色', 'Marks & colors');
  String get fontSizeLabel => t('字体大小', 'Font Size');
  String get fontWeightLabel => t('字体粗细', 'Font Weight');
  String get weightNormal => t('正常', 'Normal');
  String get weightMedium => t('中等', 'Medium');
  String get weightBold => t('加粗', 'Bold');
  String get bookmarkNamingLabel => t('书签命名', 'Bookmark Naming');
  String get namingByWord => t('单词+释义', 'Word + Definition');
  String get namingByNumber => t('数字标签', 'Numbered');
  String get namingCustom => t('自定义命名', 'Custom');
  String get bgColorLabel => t('背景颜色', 'Background Color');
  String get bgColorLockedByImage => t(
    '已使用自定义背景图片，移除图片后即可调节背景颜色',
    'A custom background image is in use. Remove it to adjust the background color.',
  );
  String get bgImageLabel => t('背景图片', 'Background Image');
  String get bgDepthLabel => t('景深效果', 'Depth Blur');
  String get bgOverlayLabel => t('壁纸遮罩透明度', 'Wallpaper Overlay');
  String get chooseImageBtn => t('选择背景图片', 'Choose Image');
  String get removeImageBtn => t('移除背景图片', 'Remove Image');
  String get pickImageFailed => t('选择图片失败', 'Failed to pick image');
  String get pagePrefix => t('第 ', 'Page ');
  String get pageSuffix => t(' 页', '');
  String get addBookmarkHere => t('在此处添加书签', 'Bookmark Here');
  String get noBookmarksHint => t('还没有书签', 'No bookmarks yet');
  String get textColorLabel => t('文字颜色', 'Text Color');
  String get textColorAuto => t('自动', 'Auto');
  String get pageTransitionLabel => t('翻页效果', 'Page Turn Effect');
  String get transitionNone => t('直接', 'Instant');
  String get transitionSlide => t('平滑', 'Slide');
  String get transitionCurl => t('仿真', 'Curl');
  String get tapTurnLabel => t('点击屏幕左右翻页', 'Tap Sides to Turn');
  String get volumeTurnLabel => t('音量键翻页', 'Volume Keys to Turn');
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

  /// 顶栏问号入口（仅桌面端存在）：键位速查
  String get operationTips => t('操作提示', 'How to Use');
  String get loopEffects => t('循环动效', 'Looping effects');
  String get loopEffectsDesc => t(
    '背景光斑缓慢流动、按钮与卡片的流光。默认开启，低端机或想省电可以关掉',
    'Drifting background orbs and shimmer on cards. On by default — turn it off to save power',
  );
  String get copyWord => t('复制单词', 'Copy word');
  String get copiedToClipboard => t('已复制', 'Copied');
  String get shortcutEnter => t('Enter', 'Enter');
  String get shortcutEnterDesc => t('检查答案 / 下一题', 'Check answer / Next word');
  String get shortcutCtrlEnter => t('Ctrl/Alt+Enter', 'Ctrl/Alt+Enter');
  String get shortcutCtrlEnterDesc => t('查看答案', 'Reveal answer');
  String get shortcutSpace => t('Space', 'Space');
  String get shortcutSpaceDesc => t('播放发音', 'Play pronunciation');
  String get shortcutNumber => t('1-3', '1-3');
  String get shortcutNumberDesc => t('选择回忆评分', 'Select recall quality');
  String get shortcutQuizNumber => t('1-4', '1-4');
  String get shortcutQuizNumberDesc => t('选择答案选项', 'Pick an answer option');
  String get shortcutExit => t('Esc', 'Esc');
  String get shortcutExitDesc => t('退出学习', 'Exit study');
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
  String get noSearchWords => t('搜索结果没有可学习单词', 'No learnable words in results');
  String get spellingCloseHint =>
      t('很接近了，再检查一下拼写！', 'Close! Double-check your spelling!');
  String get pleaseInputAnswer =>
      t('请先输入答案再检查', 'Type your answer before checking');
  String get playFailed => t('播放失败', 'Playback failed');
  String get noDefinition => t('暂无释义', 'No definition');
  String get quizFallbackOption => t('干扰选项', 'Option');
  String get spellingPrompt =>
      t('根据释义，拼写单词', 'Spell the word based on definition');
  String get listeningPrompt => t('听发音，拼写单词', 'Spell the word after listening');
  String get spellingHint => t('直接输入答案', 'Type the answer directly');
  String get listeningHint => t('听发音后输入答案', 'Listen and type the answer');
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
  String get unknownLabel => t('不认识', "Don't know");
  String get vague => t('模糊', 'Vague');
  String get recallKnown => t('认识', 'Known');
  String get familiarLabel => t('熟悉', 'Familiar');
  String get showDefinition => t('显示释义', 'Show Definition');
  //三档评分下的操作提示：评分不再依赖"先看释义"
  String get recallHint => t(
    '想不起来就点「不认识」，或上下滑动直接评分',
    "Tap Don't know when stuck, or swipe up/down to rate",
  );
  String get qualityHint =>
      t('上滑 = 记住 · 下滑 = 不认识', 'Swipe up: remember · down: don\'t know');
  //释义出现方式的提示文案（随设置动态组合）
  String recallRevealHintBoth(int seconds) =>
      t('停留 $seconds 秒或点击空白处显示释义', 'After $seconds s, or tap blank space');
  String get recallRevealHintTap => t('点击空白处显示释义', 'Tap blank space to reveal');
  String recallRevealHintDelay(int seconds) =>
      t('停留 $seconds 秒后显示释义', 'Reveals after $seconds s');
  String get quizPromptEn =>
      t('请选择正确中文释义', 'Select the correct Chinese meaning');
  String get quizPromptCn => t('请选择正确英文单词', 'Select the correct English word');
  String get quizHint =>
      t('点击选项作答，也可左右滑动切题', 'Tap an option, or swipe to change question');
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
  // 英文分支必须是纯英文：引导页在英文档位下会原样展示 _en 文案，
  // 混入中文（此前是 "Welcome to 清茫微记"）会让用户以为语言没切换成功
  String get welcomeTitle => t('欢迎使用清茫微记', 'Welcome to Qingmang Weiji');
  //引导页文案刻意压短：中英双语拼接后一屏放不下需要滚动，
  //只保留一句话说明，细节交给用户上手探索
  String get welcomeDesc => t(
    '围绕词库、复习与反馈的英语记忆工具。',
    'Vocabulary learning with books, review, and feedback.',
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
  String get previousStep => t('上一步', 'Back');
  //中英两份文案各自只保留本语言文本：引导页「中英一起」会用
  //"$中文 / $英文"自行拼接，标题里再自带一份英文就会重复三次
  String get chooseGuideLanguage => t('选择引导语言', 'Choose Guide Language');
  String get guideLanguageDesc =>
      t('选择引导与界面的语言。', 'Pick the language for the guide and app.');
  String get languageZh => t('中文', 'Chinese');
  String get languageEn => t('English', 'English');
  String get languageBilingual => t('中英一起', 'Bilingual');

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

  // 引导页：显示模式 + 界面风格
  String get onboardingAppearanceTitle =>
      t('选择显示模式与界面风格', 'Display mode & UI style');
  String get onboardingAppearanceDesc =>
      t('两项都可以随时在设置里调整。', 'Both can be changed later in Settings.');
  String get onboardingStyleFluidName => t('流体渐变', 'Fluid Gradient');
  String get onboardingStyleGlassName => t('液态玻璃', 'Liquid Glass');
  String get onboardingStylePreview => t('实时预览', 'Live preview');

  // 引导页：学习闭环
  String get onboardingLoopTitle =>
      t('学会一个单词的完整闭环', 'The full loop of learning a word');
  String get onboardingLoopDesc =>
      t('练习、复习、反馈，直到真正记住。', 'Practice, review, feedback — until it sticks.');
  String get hlMultiModePractice => t('多模式练习', 'Multi-mode practice');
  String get hlSpacedReview => t('遗忘曲线复习', 'Spaced review');
  String get hlDataFeedback => t('结果反馈', 'Result feedback');

  // 引导页：选择词库
  String get onboardingBooksTitle =>
      t('选择要学的词库', 'Pick the word books to learn');
  String get onboardingBooksDesc =>
      t('勾选内置词库，立即导入开学。', 'Tick built-in books to import and start.');
  String get onboardingBooksImporting => t('正在导入词库…', 'Importing word books…');
  String onboardingSelectedBooks(int count) => t(
    '已选择 $count 本，点「开始学习」后立即导入',
    '$count selected — imported right after you start',
  );
  String get onboardingBooksNoneSelected =>
      t('也可以先跳过，稍后在词库页添加', 'You can skip this and add books later');
  String get onboardingBooksCap => t(
    '先选 3 本就够了，其余可以稍后在词库页添加',
    'Three books is plenty for now — add more later in Word Books',
  );
  String get onboardingImportFailed =>
      t('导入失败，可稍后在词库页重试', 'Import failed. You can retry in Word Books later');
  String get onboardingCompleteFailed => t(
    '保存引导状态失败，请重启应用后重试',
    'Failed to save onboarding state. Please restart the app and try again',
  );
  String get onboardingStartNow => t('开始学习', 'Start learning');
  String get onboardingStartLater => t('稍后再说', 'Maybe later');

  // 设置：帮助与引导
  String get helpAndGuide => t('帮助与引导', 'Help & Guide');
  String get replayOnboarding => t('重看新手引导', 'Replay onboarding');
  String get replayOnboardingDesc => t(
    '重新走一遍语言、界面风格与词库设置流程',
    'Walk through language, UI style, and word book setup again',
  );
  String get replayTips => t('重看功能提示', 'Replay feature tips');
  String get replayTipsDesc => t(
    '再次播放首页、词库、阅读、统计、学习模式与查词典的操作指引',
    'Replay the guided tour for Home, Word Books, Reader, Statistics, Study and dictionary lookup',
  );
  String get replayTipsDone => t('功能提示已重置', 'Feature tips reset');

  // 上下文引导气泡
  String get coachDone => t('知道了', 'Got it');
  String get coachHomeTitle => t('每天从这里开始', 'Start here every day');
  String get coachHomeMsg => t(
    '今日任务卡片会告诉你还要学多少、复习多少，点下面的按钮就能开始。',
    'The today card shows what is left to learn and review. Tap the button below to start.',
  );
  String get coachNavTitle => t('五个主要入口', 'Five main sections');
  String get coachNavMsg => t(
    '首页看今日任务，词库管理单词，阅读在语境里巩固，统计看进步，设置调整偏好。',
    'Home for today, Word Books to manage words, Read for context, Statistics for progress, Settings for preferences.',
  );
  String get coachNoBookTitle => t('先添加一个词库', 'Add a word book first');
  String get coachNoBookMsg => t(
    '点这里去词库页，内置了初高中、四六级、考研等词库，也能导入你自己的单词表。',
    'Tap here to open Word Books — built-in books are ready, and you can import your own list.',
  );
  String get coachWordbookTitle => t('添加更多词库', 'Add more word books');
  String get coachWordbookMsg => t(
    '点这里导入内置词库，或从 TXT / Excel 导入你自己的单词表。',
    'Import built-in books here, or bring your own list from TXT / Excel.',
  );
  String get coachReaderTitle => t('阅读模式', 'Reader mode');
  String get coachReaderMsg => t(
    '这里把词书变成小说式翻页阅读，点任意一本书，在整句语境里巩固单词。',
    'Reader turns a word book into page-by-page reading — tap a book to reinforce words in context.',
  );
  String get coachReaderEmptyMsg => t(
    '导入词库后，这里就能像读小说一样翻页阅读，在语境里巩固单词。',
    'Once you import a word book, you can read it page by page right here.',
  );
  String get coachStatsTitle => t('用数据看见进步', 'See progress in data');
  String get coachStatsMsg => t(
    '学习日历、复习趋势和记忆阶段都在这里，坚持几天就能看出变化。',
    'Calendar, review trends, and memory stages live here. A few days in, you will see the change.',
  );
  String get coachStudyModeTitle => t('挑一个练习模式', 'Pick a practice mode');
  String get coachStudyModeMsg => t(
    '回忆、拼写、听力、中英双向测验各练不同能力，可以随时换。',
    'Recall, spelling, listening, and two-way quizzes train different skills — switch anytime.',
  );
  String get coachStudyStartTitle => t('选好词就开始', 'Pick words and start');
  String get coachStudyStartMsg => t(
    '勾选这次要学的词，点这里进入练习；中途退出会自动保存进度。',
    'Tick the words for this session and tap here to begin. Progress is saved if you leave.',
  );
  String get coachStudyDictTitle =>
      t('做题时也能查词典', 'Look words up while practicing');
  String get coachStudyDictMsg => t(
    '遇到卡住的词，点右上角这个按钮查音标、中文释义和例句；查词前会先确认一次，避免不小心看到答案。',
    'Stuck on a word? Tap this button in the top bar for phonetics, Chinese definitions and examples. A confirmation step keeps the answer from showing by accident.',
  );
  // 交互方式的引导按平台各写一份：桌面端讲右键/键位，移动端讲长按/手势，
  // 不再在同一句话里写"（桌面端右键）"这种两头兼顾的括号
  String get coachReaderDictTitle => isDesktopPlatform
      ? t('右键单词查词典', 'Right-click a word to look it up')
      : t('长按单词查词典', 'Long-press a word to look it up');
  String get coachReaderDictMsg => isDesktopPlatform
      ? t(
          '在阅读页右键任意单词，菜单里选「查词典」，就能看到音标、中文释义和双语例句。',
          'Right-click any word in the reader and pick "Look Up" to see phonetics, definitions and bilingual examples.',
        )
      : t(
          '在阅读页长按任意单词，菜单里选「查词典」，就能看到音标、中文释义和双语例句。',
          'Long-press any word in the reader and pick "Look Up" to see phonetics, definitions and bilingual examples.',
        );

  // ---- 引导补充：首页搜索 ----
  String get coachHomeSearchTitle => t('想查哪个词就搜哪个词', 'Search any word');
  String get coachHomeSearchMsg => isDesktopPlatform
      ? t(
          '点这里输入单词，边搜边收藏；词书里没有的词也能直接送去查词典。也可以按 Ctrl + F 快速唤起。',
          'Type a word here to search and favorite it straight from the results; words outside your books can be looked up too. Ctrl + F opens it as well.',
        )
      : t(
          '点这里输入单词，边搜边收藏；词书里没有的词也能直接送去查词典。',
          'Type a word here to search and favorite it straight from the results; words outside your books can be looked up too.',
        );

  // ---- 引导补充：五种练习模式 ----
  String get coachModeRecallTitle => t('① 回忆', '1. Recall');
  String get coachModeRecallMsg => t(
    '先自己想词义，再点开答案自评"忘了 / 模糊 / 记得 / 秒答"，适合快速过一遍。',
    'Think of the meaning first, then reveal and rate yourself (forgot / fuzzy / remembered / instant) — good for a quick pass.',
  );
  String get coachModeSpellingTitle => t('② 拼写', '2. Spelling');
  String get coachModeSpellingMsg => isDesktopPlatform
      ? t(
          '看中文释义，把英文单词完整敲出来。进入这一题就会自动聚焦输入框，直接打字后回车即可；输入法也会自动切到英文。',
          'See the Chinese definition and type the English word. The field is focused for you — just type and press Enter. The keyboard switches to English automatically.',
        )
      : t(
          '看中文释义，把英文单词完整敲出来。点输入框会自动弹出英文键盘，输入法也会切到英文。',
          'See the Chinese definition and type the English word. Tapping the field brings up the English keyboard and switches the input method to English.',
        );
  String get coachModeListeningTitle => t('③ 听力', '3. Listening');
  String get coachModeListeningMsg => isDesktopPlatform
      ? t(
          '只播发音，听音写词；按空格可重播，同样直接打字回车提交。',
          'Only the audio plays — write the word you hear. Press Space to replay, then type and press Enter.',
        )
      : t(
          '只播发音，听音写词；点喇叭可以重播，输完点「检查答案」核对。',
          'Only the audio plays — write the word you hear. Tap the speaker to replay, then check your answer.',
        );
  String get coachModeEnCnTitle => t('④ 英选中', '4. English → Chinese');
  String get coachModeEnCnMsg => isDesktopPlatform
      ? t(
          '给出英文选中文释义，四选一；可按数字键 1-4 作答。',
          'Pick the Chinese meaning of an English word, one of four. Press 1-4 to answer.',
        )
      : t(
          '给出英文选中文释义，四选一，点选项作答；答对会自动进入下一题。',
          'Pick the Chinese meaning of an English word, one of four. Tap an option — a correct answer moves on automatically.',
        );
  String get coachModeCnEnTitle => t('⑤ 中选英', '5. Chinese → English');
  String get coachModeCnEnMsg => t(
    '反过来考：给中文选英文，检验能不能主动想起来，比认词更难也更有效。',
    'The reverse direction: pick the English word for a Chinese meaning. Harder than recognizing, and more effective.',
  );
  String get coachSmartModeTitle => t('智能模式（可选）', 'Smart mode (optional)');
  String get coachSmartModeMsg => t(
    '打开后按每个词的掌握程度自动换模式：会的跳过、不稳的多考、偶尔抽查，省时间。',
    'When on, each word switches mode by how well you know it — skip the mastered, drill the shaky, spot-check occasionally.',
  );
  // ---- 引导补充：做题页动作 ----
  String get coachStudyFavoriteTitle =>
      t('收藏想再看的词', 'Favorite words to revisit');
  String get coachStudyFavoriteMsg => t(
    '点这里的星标收藏当前单词，和阅读模式、收藏夹共用同一份数据，之后可在收藏夹里专项复习。',
    'Tap the star to favorite the current word. It is the same list as the reader and Favorites, and can be reviewed as a set later.',
  );
  String get coachStudyTipsTitle => t('答题提示都在这里', 'Tips live here');
  String get coachStudyShortcutMsg => t(
    '点右上角的问号，随时查看完整键位：回车检查/下一题，Ctrl+回车看答案，空格发音，数字键作答。',
    'Tap the question mark in the top bar for every shortcut: Enter to check / next, Ctrl+Enter to reveal, Space to play audio, number keys to answer.',
  );

  // ---- 引导补充：词库页 ----
  String get coachWordbookBatchTitle => t('批量管理词库', 'Batch manage word books');
  String get coachWordbookBatchMsg => t(
    '点这里进入多选，一次删除多个词库；旁边的 + 可以新建自己的词库。',
    'Tap to enter multi-select and delete several word books at once. The + next to it creates your own.',
  );
  String get coachWordbookCardTitle => t('点卡片切换当前词库', 'Tap a card to switch');
  String get coachWordbookCardMsg => t(
    '点词库卡片把它设为"当前词库"，首页的学习按钮就跟着它走；进度条是已学比例。',
    'Tap a card to make it the current word book — the study button on Home follows it. The bar shows how much you have learned.',
  );

  // ---- 引导补充：阅读器 ----
  String get coachReaderEntryTitle => isDesktopPlatform
      ? t('右键词条，四个动作', 'Right-click an entry')
      : t('长按词条，四个动作', 'Long-press an entry');
  String get coachReaderEntryMsg => isDesktopPlatform
      ? t(
          '右键任意词条打开菜单：记住了、收藏、加书签、查词典。'
              '"记住了"表示已掌握（绿色对勾），"收藏"表示想再看（金色星标），两者可以同时存在。',
          'Right-click any entry to open the menu: Remember, Favorite, Bookmark, Look up. Remember (green check) means mastered; Favorite (gold star) means revisit later — both can apply.',
        )
      : t(
          '长按任意词条打开菜单：记住了、收藏、加书签、查词典。'
              '"记住了"表示已掌握（绿色对勾），"收藏"表示想再看（金色星标），两者可以同时存在。',
          'Long-press any entry to open the menu: Remember, Favorite, Bookmark, Look up. Remember (green check) means mastered; Favorite (gold star) means revisit later — both can apply.',
        );
  String get coachReaderBookmarkTitle => t('书签与书签列表', 'Bookmarks');
  String get coachReaderBookmarkMsg => t(
    '这枚按钮打开书签列表，可以跳回任意一段接着读；它右边的「加书签」按钮把当前位置存下来。',
    'This button opens the bookmark list so you can jump back anywhere; the "add bookmark" button next to it saves your current spot.',
  );
  String get coachReaderSettingsTitle => t('阅读设置', 'Reader settings');
  // 音量键翻页只有移动端有，桌面端不提
  String get coachReaderSettingsMsg => isMobilePlatform
      ? t(
          '字号、字体粗细、行距、翻页方式（平移/仿真翻页）、背景图与深浅、标记样式、音量键翻页都在这里调。',
          'Font size, weight, line height, page transition (slide / curl), wallpaper, mark styles and volume-key paging all live here.',
        )
      : t(
          '字号、字体粗细、行距、翻页方式（平移/仿真翻页）、背景图与深浅、标记样式都在这里调。',
          'Font size, weight, line height, page transition (slide / curl), wallpaper and mark styles all live here.',
        );

  // ---- 引导补充：统计页 ----
  String get coachStatsAdviceTitle => t('今天该学什么', 'What to do today');
  String get coachStatsAdviceMsg => t(
    '这张卡根据待复习量给出建议：复习、学新词，还是先歇一歇。',
    'This card suggests what fits today — review, new words, or take a break — based on what is due.',
  );

  // ---- 引导补充：设置页 ----
  String get coachSettingsAppearanceTitle =>
      t('设置都在这一页', 'Everything is on this page');
  // 导航栏位置设置只在桌面端出现，移动端不列这一项
  String get coachSettingsAppearanceMsg => isDesktopPlatform
      ? t(
          '往下滚依次是：外观与风格（深色 / 液态玻璃 / 古典风格、导航栏位置），'
              '发音与词典释义（在线离线发音、英式美式口音、语速、自动发音、本地或在线释义），'
              '学习提醒（每天的提醒时间与星期），数据管理（备份 / 恢复 / 导入），'
              '以及帮助与引导（想重看这些提示就回到这里重置）。',
          'Scrolling down you will find: Appearance (dark mode / Liquid Glass / Classic, nav bar position), '
              'Audio & definitions (online or offline audio, UK/US accent, speed, auto-play, local or online dictionary), '
              'Study reminders (daily time and weekdays), Data management (backup / restore / import), '
              'and Help & guide (reset these tips to replay them).',
        )
      : t(
          '往下滚依次是：外观与风格（深色 / 液态玻璃 / 古典风格），'
              '发音与词典释义（在线离线发音、英式美式口音、语速、自动发音、本地或在线释义），'
              '学习提醒（每天的提醒时间与星期），数据管理（备份 / 恢复 / 导入），'
              '以及帮助与引导（想重看这些提示就回到这里重置）。',
          'Scrolling down you will find: Appearance (dark mode / Liquid Glass / Classic), '
              'Audio & definitions (online or offline audio, UK/US accent, speed, auto-play, local or online dictionary), '
              'Study reminders (daily time and weekdays), Data management (backup / restore / import), '
              'and Help & guide (reset these tips to replay them).',
        );

  // ---- 引导补充：错词集 ----
  String get coachWrongWordsStudyTitle =>
      t('错词专项复习', 'Focused wrong-word review');
  String get coachWrongWordsStudyMsg => t(
    '点这里把错词打包成一次专项复习；连续答对 3 次会自动移出错词本。',
    'Pack the wrong words into one focused session. Get one right three times in a row and it leaves the list automatically.',
  );
  String get coachWrongWordsItemTitle =>
      t('错词带错因与进度', 'Cause and progress labels');
  String get coachWrongWordsItemMsg => t(
    '每条都标注错了几次、主要错因（看答案 / 拼写 / 听写 / 选错 / 回忆不出），以及离"移出"还差几次连续答对。',
    'Each row shows how often you missed it, the dominant cause (revealed / spelling / listening / quiz / recall), and how many correct runs are left.',
  );

  // ---- 引导补充：收藏集 ----
  String get coachFavoritesSearchTitle => t('在收藏里找词', 'Find within favorites');
  String get coachFavoritesSearchMsg => t(
    '输入单词或释义即可在自己的收藏里搜索，比翻列表快得多。',
    'Type a word or definition to search inside your favorites — much faster than scrolling.',
  );
  String get coachFavoritesStudyTitle =>
      t('收藏专项复习', 'Focused favorites review');
  String get coachFavoritesStudyMsg => t(
    '点这里把收藏的词集中复习一遍；点右侧的调整按钮还能按来源、词库、时间筛选。',
    'Review all favorites in one session. Tap the tune button next to it to filter by source, word book or date.',
  );

  // ---- 首页快捷搜索 ----
  String get quickSearchTitle => t('搜索单词', 'Search words');
  String get quickSearchHomeHint => t('搜索单词并收藏', 'Search words to favorite');
  String get quickSearchHint => t('输入单词即可搜索', 'Type a word to search');
  String get quickSearchTip => t(
    '点星标收藏，点书本图标查词典，点整行看词条详情',
    'Star to favorite, book icon to look up, tap the row for details',
  );
  String get quickSearchMinChars => t('再输入一个字母试试', 'Type one more letter');
  String get quickSearchNoResult => t('没有匹配的单词', 'No matching word');
  String get quickSearchFavoriteFailed =>
      t('收藏失败，请重试', 'Failed to favorite, please retry');

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
  String get sortBy => t('排序方式', 'Sort By');
  String get select => t('选择', 'Select');

  /// 顶栏「更多」菜单的入口提示（筛选 / 排序 / 集合设置 / 多选都收在里面）
  String get moreOptions => t('更多', 'More');

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
  // 年/月后缀已由 formatYear / formatMonth / yearLabel / monthLabel 取代
  String get studyDaysLabel => t('学习天数', 'Study Days');
  String get studyWordsLabel => t('学习单词', 'Words Studied');
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
  String get darkModeActive => t('当前使用深色模式', 'Dark mode is active');
  String get autoModeDesc =>
      t('跟随系统设置自动切换浅色/深色模式', 'Auto-switch light/dark mode with system');
  String get lightModeActive => t('当前使用浅色模式', 'Light mode is active');
  String get displayMode => t('显示模式', 'Display Mode');
  String get lightMode => t('浅色模式', 'Light');
  String get darkModeLabel => t('深色模式', 'Dark');
  String get systemMode => t('跟随系统', 'System');
  String get uiStyle => t('界面风格', 'UI Style');
  String get uiStyleFluid => t('流体渐变', 'Fluid');
  String get uiStyleGlass => t('液态玻璃', 'Liquid Glass');
  String get uiStyleFluidDesc =>
      t('当前使用流体渐变风格', 'Using the fluid gradient style');
  String get uiStyleGlassDesc => t(
    '当前使用液态玻璃风格，按钮与卡片呈磨砂通透质感',
    'Using the liquid glass style; buttons and cards look frosted and translucent',
  );
  // 通知提醒
  String get notificationSettings => t('提醒设置', 'Reminder Settings');
  String get enableReminder => t('启用每日提醒', 'Enable Daily Reminder');
  String get reminderTime => t('提醒时间', 'Reminder Time');
  String get settingsReminderOff => t('未开启提醒', 'Reminder off');
  String get reminderCondition => t('提醒条件', 'Reminder Condition');
  String get reminderSound => t('提醒声音', 'Reminder Sound');
  String get reminderSoundOnDesc =>
      t('提醒时播放系统提示音', 'Play a system sound with the reminder');
  String get reminderSoundOffDesc =>
      t('提醒时静默，仅弹出通知', 'Silent reminder, notification only');
  String get reminderSoundPreview => t('试听', 'Preview');
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
      t('$count$dailyUnit', '$count ${count == 1 ? 'word' : 'words'}');
  String dailyReviewWordsCount(int count) =>
      t('$count$dailyUnit', '$count ${count == 1 ? 'word' : 'words'}');
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
  String get bilingualExample => t('双语例句', 'Bilingual Example');
  String get lookupDictionary => t('查词典', 'Look Up');
  String get dictLookupConfirmHint => t(
    '学习模式中查询词典会显示该词释义，可能影响记忆效果。确认查询？',
    'Looking up the dictionary during study reveals the definition and may weaken recall. Continue?',
  );
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
  String get notificationScheduleFailedDesktop => t(
    '提醒设置失败：Windows 端提醒依赖应用保持运行，请确认系统通知未被关闭',
    'Failed to set the reminder: on Windows the app must stay running and system notifications must be enabled',
  );
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
  String get todayStudyTitle => t('今日学习', 'Today');
  String get todayLearnedLabel => t('今日已学', 'Learned Today');
  String get lastLearnedLabel => t('上次学到', 'Last word');
  String get taskCompleted => t('任务完成！', 'Task Completed!');
  String get taskCompletedDesc =>
      t('太棒了，今天的学习目标已达成', 'Great job, today\'s goal is reached');
  String get oneClickStart => t('一键开始', 'Quick Start');

  String get justNow => t('刚刚', 'Just now');

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

  /// 带单复数的"N 天"：英文 1 用 day
  String daysCount(int n) => t('$n 天', '$n ${n == 1 ? 'day' : 'days'}');
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
  String get statsLoadFailed => t('统计数据加载失败', 'Failed to load statistics');
  String get statsLoadFailedDesc =>
      t('请检查网络或稍后重试', 'Please check your network or retry later');

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

  // 学习报告（精简统计页）
  String get studyReport => t('学习报告', 'Study Report');
  String get readerStatsTitle => t('阅读模式统计', 'Reader Stats');
  String get readerStatsDesc =>
      t('阅读中点击"记住了"的单词数量', 'Words marked as known in reader');
  String get readerStatsTotal => t('累计', 'Total');
  String get readerStatsToday => t('今日', 'Today');
  String get readerStatsWeek => t('本周', 'This Week');
  String get readerStatsMonth => t('本月', 'This Month');
  String get reportDay => t('日', 'Day');
  String get reportWeek => t('周', 'Week');
  String get reportMonth => t('月', 'Month');
  String get reportYear => t('年', 'Year');
  String get reportNewWords => t('新学', 'New');
  String get reportPracticed => t('练习', 'Practiced');
  String get reportRemembered => t('记住', 'Remembered');
  String get reportAccuracy => t('正确率', 'Accuracy');
  String get reportPracticedSeries => t('练习', 'Practiced');
  String get reportRememberedSeries => t('记住', 'Remembered');
  String get reportNoData => t('暂无学习记录', 'No study records');
  String get reportSelectPeriod => t('选择周期', 'Select Period');
  String get reportChartLine => t('折线', 'Line');
  String get reportChartBar => t('条形', 'Bar');

  // ========== 逐日明细表 ==========
  String get dailyColDate => t('日期', 'Date');
  String get dailyColNew => t('学', 'New');
  String get dailyColPracticed => t('练', 'Practiced');
  String get dailyColRemembered => t('记住', 'Remembered');
  String get dailyColWrong => t('填错', 'Wrong');
  String get dailyColAccuracy => t('正确率', 'Accuracy');
  String get dailySummaryRow => t('汇总', 'Total');
  String get correctRateLabel => t('正确率', 'Correct Rate');
  String get wrongRateLabel => t('错误率', 'Wrong Rate');
  String get studiedDaysLabel => t('学习天数', 'Days Studied');
  String noStudyDataIn(String range) =>
      t('$range暂无学习记录', 'No study records in $range');
  String get last7DaysLabel => t('最近7天', 'last 7 days');
  String get last30DaysLabel => t('最近30天', 'last 30 days');
  String get dailyDetailsTitle => t('每日明细', 'Daily Details');

  // Tab
  String get tabAll => t('全部', 'All');

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

  /// 缺英文语音引擎时，弹窗里的"直达系统语音设置"入口
  String get openVoiceSettings => t('打开语音设置', 'Open Voice Settings');

  // 后台运行 / 电池优化引导（Android 提醒可靠性）
  String get batterySettingsTitle => t('后台运行设置', 'Background Settings');
  String get batterySettingsDesc => t(
    '提醒不按时到达时，可在此关闭本应用的电池优化/省电限制',
    'If reminders arrive late, disable battery optimization for this app',
  );
  String get batterySettingsFailed => t(
    '无法打开系统设置，请手动前往「设置 → 应用 → 电池」关闭本应用的省电限制',
    'Cannot open system settings. Please disable battery optimization manually in Settings → Apps → Battery',
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
  String get pressAgainToExit => t('再按一次返回键退出应用', 'Press back again to exit');
  String get notificationReminderTitle =>
      t('清茫微记 · 学习提醒', 'Qingmang Weiji · Study Reminder');
  String get notificationReminderBody =>
      t('该背单词啦，坚持就是胜利！', 'Time to review your words — keep it up!');
  String get backupPasswordTitle => t('备份口令', 'Backup Password');
  String get backupPasswordSetHint => t(
    '设置口令后导出加密备份，恢复时需要输入同一口令。留空则导出未加密的明文备份。',
    'Set a password to export an encrypted backup; you will need it to restore. Leave empty for a plain backup.',
  );
  String get backupPasswordRestoreTitle => t('输入备份口令', 'Enter Backup Password');
  String get backupPasswordRestoreHint =>
      t('该备份已加密，请输入备份时设置的口令。', 'This backup is encrypted. Enter its password.');
  String get backupPasswordLabel => t('口令', 'Password');
  String get backupPasswordConfirmLabel => t('确认口令', 'Confirm Password');
  String get backupPasswordMismatch =>
      t('两次输入的口令不一致', 'Passwords do not match');
  String get backupPasswordWrong =>
      t('备份口令错误或文件已损坏', 'Wrong password or the file is corrupted');
  String get bookmarkOutdated => t('词序已变化', 'position changed');

  // ---- 年/月展示 ----
  // 英文不用"年/月"后缀直接拼接（会得到 "20263" 这种字符串）：
  // 中文 "2026年3月"、英文 "Mar 2026"。
  static const List<String> _monthNamesEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// 年份展示：中文 "2026年"，英文 "2026"
  String formatYear(int year) => isEnglish ? '$year' : '$year年';

  /// 月份展示：中文 "3月"，英文 "Mar"
  String formatMonth(int month) {
    if (!isEnglish) return '$month月';
    final idx = month - 1;
    if (idx < 0 || idx >= _monthNamesEn.length) return '$month';
    return _monthNamesEn[idx];
  }

  /// 年月组合：中文 "2026年3月"，英文 "Mar 2026"
  String formatYearMonth(int year, int month) =>
      isEnglish ? '${formatMonth(month)} $year' : '$year年$month月';

  /// 滚轮/表头的单位标签
  String get yearLabel => t('年', 'Year');
  String get monthLabel => t('月', 'Month');
}

/// 只广播"语言"这一件事的 ChangeNotifier。
///
/// ThemeProvider 的任何字段（主题/玻璃风格/导航位置/动画速度…）变化都会
/// notifyListeners，若直接把它挂给 InheritedNotifier，无关字段的变化也会让
/// 全站使用文案的组件重建。这里只在语言翻转时才通知，重建面收窄到语言事件。
class AppLocaleNotifier extends ChangeNotifier {
  bool _english = false;

  bool get english => _english;

  void syncFrom(bool isEnglishLocale) {
    if (_english == isEnglishLocale) return;
    _english = isEnglishLocale;
    notifyListeners();
  }
}

/// 全局唯一的语言通知器，由 [withLocaleScope] 挂进组件树、
/// [QingMangMaterialApp] 在语言变化时同步。
final AppLocaleNotifier appLocaleNotifier = AppLocaleNotifier();

class _LocaleScope extends InheritedNotifier<AppLocaleNotifier> {
  const _LocaleScope({required super.notifier, required super.child});
}

/// 包在 MaterialApp.builder 里（Navigator 之上）：
/// 让所有通过 `context.tr` 取文案的组件订阅 [appLocaleNotifier]，
/// 语言切换时立即重建——包括 ListView 里已挂载的屏幕外缓存项。
Widget withLocaleScope(Widget child) =>
    _LocaleScope(notifier: appLocaleNotifier, child: child);

/// BuildContext 扩展，方便在 Widget 中获取翻译实例
///
/// 使用方式：`context.tr.study` 替代之前的 `Translations.study`
extension TranslationsX on BuildContext {
  /// 获取与当前语言环境对应的翻译实例。
  ///
  /// 返回 const 实例：Translations 是纯函数包装（只持有一个 bool），
  /// 用 const 字面量可让 VM 复用同一个 canonical 对象，
  /// 避免每帧几十次 `context.tr` 各分配一个新实例。
  ///
  /// 依赖建立：优先经 [_LocaleScope]（InheritedNotifier）订阅语言事件，
  /// 语言切换 → notifyListeners → 所有使用过 `context.tr` 的 element
  /// 标脏重建（此前用 `read` 不订阅，切换语言后懒加载列表的已构建项
  /// 要等滚动重建才换成新语言，表现为"要滑一会才切换语言"）。
  /// 组件树外（widget test 等）回退到直接读 ThemeProvider。
  Translations get tr {
    final scope = dependOnInheritedWidgetOfExactType<_LocaleScope>();
    final english =
        scope?.notifier?.english ?? read<ThemeProvider>().isEnglishLocale;
    return english ? const Translations(true) : const Translations(false);
  }
}

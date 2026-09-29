/// 上下文引导的高亮目标锚点。
///
/// 引导会跨页面（首页 → 词库 → 阅读 → 统计，以及学习模式页）串成一条流程，
/// 目标控件分散在各页面，因此这些 Key 集中在这里共享，
/// 由各页面把自己的关键控件挂上去，由引导流程统一读取位置。
library;

import 'package:flutter/widgets.dart';

/// 首页「开始学习 / 继续学习」按钮
final GlobalKey guideHomePrimaryKey = GlobalKey();

/// 首页空状态里的「去添加词库」按钮
final GlobalKey guideHomeEmptyKey = GlobalKey();

/// 首页底部导航栏 / 侧边导航栏
final GlobalKey guideNavKey = GlobalKey();

/// 词库页顶部「导入内置词库」按钮
final GlobalKey guideWordBookImportKey = GlobalKey();

/// 阅读书架里的第一本书
final GlobalKey guideReaderBookKey = GlobalKey();

/// 阅读书架空状态
final GlobalKey guideReaderEmptyKey = GlobalKey();

/// 统计页「学习报告」卡片
final GlobalKey guideStatsReportKey = GlobalKey();

/// 学习前置页「学习模式」选择卡片
final GlobalKey guideStudyModeKey = GlobalKey();

/// 学习前置页「开始学习」按钮
final GlobalKey guideStudyStartKey = GlobalKey();

/// 做题页顶栏「查词典」按钮
final GlobalKey guideStudyDictKey = GlobalKey();

/// 阅读页当前阅读位置的那个词条（长按/右键可查词典）
final GlobalKey guideReaderDictKey = GlobalKey();

// ---- 首页快捷搜索 ----

/// 首页顶栏「搜索单词」入口
final GlobalKey guideHomeSearchKey = GlobalKey();

// ---- 选词页：五种学习模式 ----

/// 选词页「回忆」模式
final GlobalKey guideStudyModeRecallKey = GlobalKey();

/// 选词页「拼写」模式
final GlobalKey guideStudyModeSpellingKey = GlobalKey();

/// 选词页「听力」模式
final GlobalKey guideStudyModeListeningKey = GlobalKey();

/// 选词页「英选中」模式
final GlobalKey guideStudyModeEnCnKey = GlobalKey();

/// 选词页「中选英」模式
final GlobalKey guideStudyModeCnEnKey = GlobalKey();

/// 选词页「智能模式」开关卡片
final GlobalKey guideStudySmartModeKey = GlobalKey();

// ---- 做题页：收藏 / 快捷键 ----

/// 做题页顶栏「收藏」星标
final GlobalKey guideStudyFavoriteKey = GlobalKey();

/// 做题页顶栏「操作提示」问号按钮（仅桌面端存在，移动端不显示该功能）
final GlobalKey guideStudyShortcutKey = GlobalKey();

// ---- 词库页 ----

/// 词库页「批量管理」按钮
final GlobalKey guideWordBookBatchKey = GlobalKey();

/// 词库页第一张词库卡片
final GlobalKey guideWordBookFirstKey = GlobalKey();

// ---- 阅读器 ----

/// 阅读器右上角「阅读设置」按钮
final GlobalKey guideReaderSettingsKey = GlobalKey();

/// 阅读器右上角「书签」按钮
final GlobalKey guideReaderBookmarkKey = GlobalKey();

// ---- 统计页 ----

/// 统计页「今日建议」卡片
final GlobalKey guideStatsAdviceKey = GlobalKey();

// ---- 设置页 ----

/// 设置页「外观」分组。
///
/// 设置页是懒加载的长列表，只有滚动到可见范围的分组才会被构建，
/// 因此这里只给首个分组挂锚点，其余分组由这条提示的文案一并说明。
final GlobalKey guideSettingsAppearanceKey = GlobalKey();

// ---- 错词集 ----

/// 错词集「专项复习」按钮
final GlobalKey guideWrongWordsStudyKey = GlobalKey();

/// 错词集列表里的第一个词条
final GlobalKey guideWrongWordsFirstKey = GlobalKey();

// ---- 收藏集 ----

/// 收藏集「专项复习」按钮
final GlobalKey guideFavoritesStudyKey = GlobalKey();

/// 收藏集顶部搜索框
final GlobalKey guideFavoritesSearchKey = GlobalKey();

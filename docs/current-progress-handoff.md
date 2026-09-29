# 当前开发进度交接

更新时间：2026-06-01

## 项目背景

项目是 Flutter 桌面/多端应用 `qingmang_weiji`。当前主线已从界面深浅色适配推进到“四阶段增强计划”，阶段一聚焦质量基线与错词学习闭环，阶段二聚焦学习体验增强。

常用工作目录：

```text
d:\edge\qingmang_weiji
```

常用验证命令：

```bash
dart format <文件路径>
flutter analyze <文件路径>
flutter analyze
flutter test <测试文件路径>
flutter build windows --release
```

Windows exe 输出路径：

```text
d:\edge\qingmang_weiji\build\windows\x64\runner\Release\qingmang_weiji.exe
```

运行 exe 时需要保留同目录下的 `data/` 和 `.dll` 文件。

## 阶段一进展

阶段一：质量基线与错词闭环，已完成。

已完成：

- 清理 analyzer 历史问题，当前 `flutter analyze` 全项目通过。
- 新增专项学习来源模型：`StudySource`、`SpecializedStudyRequest`、`WrongWordReviewResult`。
- 扩展错词 DAO 和服务层，支持按 ID 获取错词、降低错词强度、批量应用复习结果。
- 新增 `SpecializedStudyService`，并接入 `DIContainer`。
- 扩展学习进度持久化，支持 `source`、`progressKey`、`title` 等来源元数据。
- `PreStudyScreen` 已支持专项学习入口和继续学习恢复。
- 错词页“复习”已从占位提示改为可用专项复习流程，支持全部错词和选中错词。
- 错词专项复习完成后，会根据答题表现更新错词状态。
- 首页继续学习已能识别错词专项来源，并恢复到专项学习流程。
- 旧版 `StudyScreen` 已统一使用 `DIContainer` 获取错词服务，并使用统一错误处理。

## 关键文件

### 设计与计划

- `docs/superpowers/specs/2026-05-31-four-phase-enhancement-design.md`
- `docs/superpowers/plans/2026-05-31-stage-one-quality-wrong-words-plan.md`
- `docs/current-progress-handoff.md`

### 新增或重点模型

- `lib/models/study_source.dart`
- `lib/models/specialized_study_request.dart`
- `lib/models/wrong_word_review_result.dart`
- `lib/models/models.dart`

### 服务与数据层

- `lib/services/specialized_study_service.dart`
- `lib/services/wrong_word_service.dart`
- `lib/services/daos/wrong_word_dao.dart`
- `lib/services/study_progress_logic.dart`
- `lib/services/daos/study_progress_dao.dart`
- `lib/services/repositories/study_progress_repository.dart`
- `lib/services/database_service.dart`
- `lib/services/di_container.dart`

### 界面层

- `lib/screens/wrong_words_screen.dart`
- `lib/screens/pre_study_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/study_screen.dart`
- `lib/utils/translations.dart`

### 测试

- `test/study_progress_logic_test.dart`
- `test/specialized_study_request_test.dart`
- `test/wrong_word_review_result_test.dart`
- `test/practice_flow_logic_test.dart`
- `test/study_session_summary_test.dart`
- `test/session_mastery_engine_test.dart`

## 已验证命令

```bash
flutter devices
flutter test test/study_progress_logic_test.dart test/specialized_study_request_test.dart test/wrong_word_review_result_test.dart
flutter test test/practice_flow_logic_test.dart test/study_session_summary_test.dart test/session_mastery_engine_test.dart
flutter analyze
flutter build windows --release
```

验证结果：

```text
Windows 桌面设备可用。
All tests passed!
No issues found!
Built build\windows\x64\runner\Release\qingmang_weiji.exe
```

## 阶段一验收状态

阶段一人工验收和打包验收已完成可自动执行部分。

已完成：

- 自动化回归：阶段一相关测试全部通过。
- 静态分析：`flutter analyze` 全项目通过。
- 打包验收：`flutter build windows --release` 成功生成 Windows release exe。
- release 启动冒烟：启动 `qingmang_weiji.exe` 后进程存在，窗口标题正常，`Responding=True`。
- 验收后已关闭测试启动的 release 进程。

release 输出路径：

```text
d:\edge\qingmang_weiji\build\windows\x64\runner\Release\qingmang_weiji.exe
```

验收边界：

- 已确认 release 包可构建、可启动、窗口响应正常。
- 未替代真人逐项点击错词复习流程的主观 UI 体验检查；如需最终产品验收，仍建议人工打开 release 包按错词专项复习流程点一遍。

## 错词专项复习流程

当前流程：

1. 进入错词页。
2. 点击复习按钮，或选择部分错词后进入复习。
3. 选择复习模式：回忆、拼写、听力、测验。
4. `SpecializedStudyService` 构建 `SpecializedStudyRequest`。
5. 进入 `PreStudyScreen.specialized`，复用原学习流程。
6. 学习过程中记录 `WrongWordReviewResult`。
7. 完成学习后批量回写错词状态。
8. 返回错词页时刷新错词列表。

错词回写策略：

- 连续表现达到掌握标准时移出错词本。
- 答错或查看答案时保持强化。
- 普通答对但未达到移出标准时降低错词强度，最低保留为 1。

## 阶段二进展

阶段二：学习体验增强，已完成。

已完成：

- 学习计划系统：`StudyPlan` 模型、`DailyTaskSnapshot` 模型、`StudyPlanDao`、`StudyPlanRepository`、`StudyPlanService`。
- 数据库迁移到版本 9，新增 `study_plans` 和 `daily_task_snapshots` 表。
- 本地通知提醒：升级 `NotificationService` 为真实通知实现，支持每日定时提醒和即时复习提醒。
- 通知设置模型：`NotificationSettings`，支持开关、时间、条件配置，持久化到 SharedPreferences。
- 设置页接入通知设置区块和学习计划入口：`NotificationSettingsSection`。
- 学习计划管理页：`StudyPlanScreen`，支持创建、暂停、恢复、完成、删除计划。
- 首页今日任务中心升级：展示学习计划今日任务进度，含新词/复习进度条。
- 统计页计划进度卡片：展示当前计划名称和今日进度。
- 学习进度回写：`PreStudyScreen` 学习完成后更新今日任务进度。
- 每日任务完成反馈：学习摘要页展示任务完成状态。
- `StudySource` 枚举新增 `studyPlan` 来源。
- 多语言翻译：新增通知设置和学习计划相关中英文翻译。

### 阶段二关键文件

#### 新增模型

- `lib/models/study_plan.dart`
- `lib/models/daily_task_snapshot.dart`
- `lib/models/notification_settings.dart`

#### 服务与数据层

- `lib/services/study_plan_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/repositories/study_plan_repository.dart`
- `lib/services/daos/study_plan_dao.dart`
- `lib/services/database_service.dart`（迁移到版本 9）
- `lib/services/providers/study_settings_provider.dart`（接入通知设置和学习计划服务）

#### 界面层

- `lib/screens/study_plan_screen.dart`（新建）
- `lib/screens/home_screen.dart`（升级今日任务中心）
- `lib/screens/stats_screen.dart`（添加计划进度卡片）
- `lib/screens/pre_study_screen.dart`（添加学习进度回写）
- `lib/widgets/settings_sections.dart`（添加通知设置区块和学习计划入口）
- `lib/utils/translations.dart`（新增翻译）

#### 依赖变更

- `pubspec.yaml`：添加 `timezone` 依赖

## 阶段二验收状态

阶段二开发、自动化回归、全量静态分析、Windows release 打包和 release 启动冒烟均已完成。

已完成：

- 自动化回归：`flutter test` 全部 155 个测试通过。
- 静态分析：`flutter analyze` 全项目通过，No issues found。
- 打包验收：`flutter build windows --release` 成功生成 Windows release exe。
- release 启动冒烟：启动 `qingmang_weiji.exe` 后进程存在，窗口标题正常。

验收边界：

- 已确认 release 包可构建、可启动、窗口响应正常。
- 通知功能在 Windows 平台不支持本地通知，已降级为应用内日志提醒，不会崩溃。
- 如需最终产品验收，建议人工打开 release 包按以下流程点验。

### 阶段二人工验收建议

1. 打开设置页，确认通知提醒设置区块显示正常。
2. 开启每日学习提醒，设置提醒时间，确认保存后重载仍保留。
3. 点击学习计划入口，进入学习计划管理页。
4. 创建一个学习计划，确认列表刷新显示新计划。
5. 返回首页，确认今日任务中心展示计划进度。
6. 完成一次学习，确认首页进度更新。
7. 进入统计页，确认计划进度卡片显示正常。

## 当前未完成事项

阶段一和阶段二开发、自动化回归、全量静态分析、Windows release 打包和 release 启动冒烟均已完成。

仍建议在正式交付前由真人执行一次主观 UI 点验：

1. 打开错词页，确认空状态仍正常。
2. 添加或触发至少一个错词。
3. 从错词页进入全部错词复习。
4. 选择一种复习模式并完成学习。
5. 返回错词页确认列表刷新。
6. 选择部分错词后再次专项复习。
7. 中途退出后返回首页，确认继续学习可恢复错词专项来源。

可直接运行 release 包：

```text
d:\edge\qingmang_weiji\build\windows\x64\runner\Release\qingmang_weiji.exe
```

## 后续阶段建议

建议继续进入阶段三或阶段四。阶段三为"内容与社交增强"，阶段四为"高级功能"。

已接纳的新功能中尚未实现的：

1. 收藏夹专项学习：复用阶段一的 `SpecializedStudyRequest` 和 `SpecializedStudyService`。
2. 自定义词集：复用专项学习入口，新增词集 CRUD 与选词逻辑。
3. 多维统计：使用现有学习记录和新增来源元数据扩展分析。

阶段三可能包含的功能（参考设计文档）：

- 收藏夹系统
- 自定义词集
- 多维统计分析

阶段四可能包含的功能（参考设计文档）：

- 高级功能（如 AI 辅助、云端同步等）

## 2026-08-30 代码审查修复记录

本轮代码审查共修复 6 个问题，计划文档见 `docs/superpowers/plans/2026-07-14-review-fixes-plan.md`：

1. `session_mastery_engine.dart`：删除生产环境未调用的 `recordAttempt` 死代码（约 75 行重复逻辑），测试改用 `recordAttemptWithDuration`；修复 `_retentionWeight` 保持率 <45 时权重非单调问题（1.05 → 1.15）；`loadMultiDaySession` 增加 `_touchedWordIds` 判断，防止异步加载覆盖会话内已作答状态。
2. `pre_study_screen.dart`：新增 `_isFinishing` 标志，修复最后一个词被智能跳过时 `_finishStudy`（清除进度）与 `_saveStudyProgress` 并发执行导致的幽灵进度竞态。
3. `word_import_service.dart`：新增 `_parseCsv` 与 `_splitCsvLine`，支持引号包裹字段、字段内逗号和双引号转义。
4. `settings_screen.dart`：删除备份选择器改用 `StatefulBuilder`，删除后即时移除列表项，全部删完自动关闭。
5. `pubspec.yaml`：移除未使用的 `assets/wordlists/` 资源声明，减小包体积。
6. 清理根目录临时文件（`design-comparison.html`、`splash-preview.html`、`build_log.txt` 等）。

## 2026-08-30 P2 平台适配补齐记录

补齐 `test/android_manifest_test.dart` 中 21 项缺失的平台适配实现（测试先行、实现补齐）：

- `AndroidManifest.xml`：新增 `RECEIVE_BOOT_COMPLETED` 权限；application 标签补 `roundIcon`、`supportsRtl`、`largeHeap`、`enableOnBackInvokedCallback`、`networkSecurityConfig`、`fullBackupContent`、`dataExtractionRules` 属性。
- `android/app/build.gradle.kts`：新增 `key.properties` 正式签名读取（不存在时回退 debug）；release 开启 `isMinifyEnabled`/`isShrinkResources`/proguard；`arm64-v8a` abi 裁剪；新增 `androidx.core:core-splashscreen` 依赖。
- `android/gradle.properties`：开启 `android.enableR8.fullMode=true`、`kotlin.incremental=true`。
- `MainActivity.kt`：`installSplashScreen()` + `WindowCompat.setDecorFitsSystemWindows(false)`（edge-to-edge）。
- `values/styles.xml` 与 `values-night/styles.xml`：LaunchTheme 改用 `Theme.SplashScreen` 父主题，含 `windowSplashScreenBackground`、`windowSplashScreenAnimatedIcon`、`postSplashScreenTheme`。
- `windows/runner/main.cpp`：中文标题改 unicode escape（避免 MSVC C4819）；`GetSystemMetrics` 屏幕居中；`CheckSingleInstance` + `CreateMutexW` 单实例。
- `windows/runner/win32_window.cpp`：`WM_GETMINMAXINFO` 最小尺寸限制（480x360 逻辑像素，按 DPI 缩放）；`DWMWA_SYSTEMBACKDROP_TYPE` Mica 背景。
- 验证：`flutter test test/android_manifest_test.dart` 35/35 通过，全量 `flutter test` 349/349 通过。

## 2026-08-30 背单词体验改造：删除每日限额 + 周报/月报改逐日明细

核心理念：从"对标商业软件"转向"自己真心想用的工具"——学多学少由用户自己决定，软件只记录事实、不审判：

1. 彻底删除每日学习限额：
   - `study_settings_provider.dart`：删除 `dailyNewWords`/`dailyReviewLimit` 字段、持久化与 setter；`settings_sections.dart` 删除"每日学习单词数"设置项。
   - `word_repository.dart`：删除 `getNewWordsWithinDailyRemaining`/`getDueWordsWithinDailyRemaining` 额度取词方法；`wordbook_provider.dart` 删除剩余额度计算。
   - `study_availability.dart`：只描述事实（空词库/无新词/无到期词），删除 `dailyNewCompleted`/`dailyReviewCompleted` 状态与 `remainingNewWords` 等额度字段。
   - `today_advice.dart`：建议只基于词库事实（待复习优先→有新词→等待复习），删除 `doneToday`（今日学完）状态。
   - `pre_study_screen.dart`：学习入口全量开放，不再做额度检查；`home_screen.dart` 今日任务卡片改事实陈述（今日已学 N 词、待复习 N 词、上次学到某词）。
2. 周报/月报统一改"逐日明细表"（每天一行：日期 | 学 | 练 | 记住 | 填错 | 正确率，含汇总行）：
   - 新增 `models/daily_study_detail.dart`（五指标+正确率/错误率推导）、`widgets/daily_details_table.dart`（明细表组件，支持 maxRows 内部滚动）。
   - `stats_dao.dart` 新增 `getDailyDetails`：新词数按 `review_records.first_learned_at` 落在当天统计；练/记住/填错/作答按 `session_mastery_records` 以 `attempt_count`/`wrong_count` 聚合（记住 = 当天至少答对一次的词，填错 = 当天有错误记录的词）；范围内每天都会返回（无数据天为全零）。
   - `weekly_report.dart` 重构：以 `dailyDetails` 为核心，汇总指标（newWords/practicedWords/rememberedWords/wrongWords/attempts/correctRate/studyDays 等）由明细推导；删除趋势对比（trend）、平均质量、会话数等虚荣指标；保留薄弱词 Top10 与 `planCompletedDays`（成就系统用）。
   - `weekly_report_service.dart`：`buildCurrentWeekReport` = 最近 7 天含今天；新增 `buildWeekReport(weekStart)` 供周报详情页翻周；`buildCurrentMonthReport` = 最近 30 天（`MonthlySummary` 仅含逐日明细+汇总）。
   - `stats_screen.dart`：周报卡片直接展示 7 天明细表+薄弱词；月报卡片展示 30 天明细（`maxRows: 10` 内部滚动）+ 学习天数/正确率摘要；删除旧指标网格与趋势 delta。
   - `weekly_report_detail_screen.dart`：删除趋势头部卡与指标网格卡，改为"每日明细"卡（`DailyDetailsTable`），保留翻周导航、薄弱词、高频错词、导出分享。
3. 测试同步重写：删除 `study_limits_test.dart`（额度逻辑不复存在），新增 `study_availability_test.dart`；重写 `today_advice_test.dart`、`weekly_report_service_test.dart`（逐日明细聚合/汇总推导/缓存/翻周）、修正 `repository_error_contract_test.dart` 与 `study_settings_provider_test.dart` 的旧签名。

## 2026-08-30 阅读模式：像看小说一样翻页背单词

新增"阅读模式"入口（`pre_study_screen.dart` 的 chip），核心实现：

- 分页逻辑（`wordbook_reader_screen.dart`）：像小说排版，每页词数由字体大小/粗细自动决定（`TextPainter` 实测词条高度装页），无"每页词数"设置；字体调整后自动重排并跳回当前词（书签/进度存词索引而非页码，重排不失效）。
- 勾记：长按（移动端）或右键（桌面）词条弹出菜单"记住了/取消记住"，存 `reader_marks` 表，词条前显示勾选图标。
- 书签：`reader_bookmarks` 表存词索引+时间戳；列表显示命名+创建时间（yyyy-MM-dd HH:mm）+单词；点击跳转、长按重命名/删除。命名三模式（设置中可选）：
  1. 单词+释义（默认）：`'${w.word} ${w.definition}'` 截断 30 字；
  2. 数字标签：`书签 1`、`书签 2`…；
  3. 自定义：添加时弹输入框命名。
- 阅读设置（`reader_settings_provider.dart`，SharedPreferences 持久化）：字体大小（12-30）、粗细（常规/中等/加粗）、书签命名模式、背景纯色（8 预设+RGB 自定义）、背景图片（桌面/移动选图，压暗蒙层保证可读，失败回退纯色）；`reader_bg_io.dart`/`reader_bg_web.dart` 条件导入区分平台。
- 进度：`reader_progress` 表，翻页 500ms 防抖保存，退出即存，重进续读。
- 数据库迁移到 v16：新增 `reader_marks`/`reader_bookmarks`/`reader_progress` 三表。
- 桌面端：点击窗口左右页边翻页。
- 测试：`reader_dao_test.dart`、`reader_settings_provider_test.dart`、`wordbook_reader_screen_test.dart`（渲染/勾记/书签日期/数字命名/空态），全量回归 358 个测试通过。

## 2026-08-30 阅读模式改为独立底部 Tab

阅读模式入口从学习准备页（`pre_study_screen.dart` chip）移除，改为底部导航独立"阅读"页（位于词库和统计之间）：

- 新增 `reader_home_screen.dart` 阅读书架页：展示词书列表（词数+阅读进度"已读 x/y · 百分比"），点击进入 `WordbookReaderScreen`，返回后自动刷新进度；空词书显示引导提示。
- `home_screen.dart`：`_screens` 插入 `ReaderHomeScreen`（index 2），底部 NavigationDestination 与侧边 NavigationRail 均新增"阅读"项（`Icons.auto_stories`），Ctrl+1~5 快捷键自动覆盖新 tab。
- `translations.dart` 新增 `navReader`（阅读/Read）。
- `reader_dao.dart` 新增 `getProgressMap`：批量查询多本词书阅读进度，避免书架逐本查询。
- 移除 `pre_study_screen.dart` 阅读模式 chip 及 `_selectedStudyMode == 6` 分支。
- 新增 `reader_home_screen_test.dart`（空态/词书卡片/进度显示）；全量回归 360 个测试通过。

## 2026-09-16 上下文引导扩展：学习模式 / 阅读模式的查词典

原有引导（首次引导页、首页主导览、选词页提示）行为保持不变，新增两条跟随具体页面的功能提示：

- `guide_service.dart` 新增 `tipStudyDict` / `tipReaderDict`，与既有 `tipMainTour` / `tipStudy` 互不影响，`resetAll()` 会一并重置。
- `guide_keys.dart` 新增 `guideStudyDictKey`（做题页顶栏查词典按钮）、`guideReaderDictKey`（阅读页当前阅读位置的词条）。
- `coach_mark_overlay.dart` 新增 `maybeShowAfterSplash()`：开屏未结束时放弃本次展示且不标记已看过，避免提示弹在开屏遮罩之上、也避免后续再也看不到；可选的 `onBeforeShow` 用于在弹出前锁定高亮锚点。
- `direct_study_screen.dart`：顶栏「查词典」按钮挂 `guideStudyDictKey`，进入做题页首帧后提示一次（五种题型统一入口）。
- `wordbook_reader_screen.dart`：弹出前把「当前阅读位置的词条」锁定为 `guideReaderDictKey` 锚点（只赋值一次，避免 GlobalKey 在词条间来回搬家），提示「长按/右键单词 → 查词典」。
- `translations.dart` 新增 `coachStudyDictTitle/Msg`、`coachReaderDictTitle/Msg`，并同步更新 `replayTipsDesc` 文案。
- 新增 `test/guide_context_tips_test.dart`（引导状态互不干扰 / 开屏前不弹 / 开屏后弹一次并记录已看过）。

## 注意事项

- 与用户对话一律使用中文（专有名词、代码/命令/报错原文除外）。
- 用户偏好：如果涉及 C++，倾向使用 `using namespace std;`。
- 当前项目是 Flutter/Dart，除非用户要求，不要主动创建额外文档。
- 修改代码后必须尽量运行格式化、定向 analyze 和必要测试。
- 不要自动提交 git，除非用户明确要求。

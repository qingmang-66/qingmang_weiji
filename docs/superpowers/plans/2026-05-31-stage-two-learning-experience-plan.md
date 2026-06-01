# 阶段二：学习体验增强 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在阶段一稳定的学习流程之上，建设“会安排学习”的能力：学习计划系统、真实本地通知提醒、首页今日任务中心和每日任务完成反馈，让应用从“可学习”升级为“会安排学习”。

**Architecture:** 阶段二沿用阶段一的小步推进策略。先沉淀纯逻辑模型与计算（StudyPlan、DailyTaskSnapshot、计划任务量计算、完成率、通知条件判断），用纯单元测试覆盖；再扩展数据库迁移和 DAO/Repository；然后实现 StudyPlanService 跨实体编排；接着把 NotificationService 升级为真实的 flutter_local_notifications 实现；最后改造 Provider、设置页、首页今日任务中心和统计页计划进度。学习流程继续复用阶段一的 `PreStudyScreen` 与 `SpecializedStudyRequest`，计划任务通过 `StudySource.studyPlan` 进入学习流程，避免重写学习页。

**Tech Stack:** Flutter、Dart、Provider、sqflite/sqflite_common_ffi、shared_preferences、flutter_local_notifications 21.0.0、package:test、flutter_lints。

---

## 文件结构与职责

### 新增文件

| 文件 | 职责 |
|---|---|
| `lib/models/study_plan.dart` | 定义学习计划模型 StudyPlan、计划类型 StudyPlanType、计划状态 StudyPlanStatus，及序列化方法。 |
| `lib/models/daily_task_snapshot.dart` | 定义每日任务快照 DailyTaskSnapshot 及完成率计算、是否完成判断等纯逻辑。 |
| `lib/models/notification_settings.dart` | 定义通知设置模型（是否启用、提醒时间、提醒条件枚举）及序列化。 |
| `lib/services/study_plan_logic.dart` | 纯逻辑：根据目标日期/每日量估算每日新词任务、计划进度计算，便于单测。 |
| `lib/services/study_plan_service.dart` | 计划生成、今日任务计算、完成进度回写等跨实体编排。 |
| `lib/services/daos/study_plan_dao.dart` | study_plan 与 daily_task_snapshot 表的增删改查。 |
| `lib/services/repositories/study_plan_repository.dart` | 对页面/Service 暴露计划数据访问。 |
| `test/study_plan_logic_test.dart` | 测试每日任务量计算、计划进度计算等纯逻辑。 |
| `test/daily_task_snapshot_test.dart` | 测试完成率、是否完成、剩余任务等纯逻辑。 |
| `test/notification_condition_test.dart` | 测试通知触发条件判断纯逻辑。 |

### 修改文件

| 文件 | 修改原因 |
|---|---|
| `lib/models/models.dart` | 导出 study_plan、daily_task_snapshot、notification_settings。 |
| `lib/models/study_source.dart` | 确认 studyPlan 来源已存在并补充展示文案键（阶段一已加 studyPlan，复核即可）。 |
| `lib/services/database_service.dart` | 迁移到版本 9，新增 study_plans 和 daily_task_snapshots 表。 |
| `lib/services/notification_service.dart` | 升级为真实 flutter_local_notifications 实现：初始化、每日定时提醒、按条件提醒、取消。 |
| `lib/services/providers/study_settings_provider.dart` | 增加通知设置（启用、提醒时间、提醒条件）和当前计划摘要状态。 |
| `lib/services/repositories/repositories.dart` | 导出 study_plan_repository。 |
| `lib/services/di_container.dart` | 注册 StudyPlanService、StudyPlanRepository，并把 NotificationService 升级后的初始化接入。 |
| `lib/screens/home_screen.dart` | 首页 Dashboard 升级为今日任务中心：今日新词/复习任务、计划进度、错词建议、一键开始、继续未完成任务。 |
| `lib/screens/settings_screen.dart` | 增加通知设置区块和学习计划入口。 |
| `lib/screens/stats_screen.dart` | 增加计划完成度展示。 |
| `lib/screens/pre_study_screen.dart` | 学习完成后回写计划当日完成进度（新词/复习数量）。 |
| `lib/utils/translations.dart` | 新增计划、通知、今日任务、完成反馈相关中英文文案。 |
| `docs/current-progress-handoff.md` | 阶段二完成后更新交接状态。 |

### 新增页面（按需）

| 文件 | 职责 |
|---|---|
| `lib/screens/study_plan_screen.dart` | 学习计划管理页：创建/查看/暂停/恢复/完成计划。 |

---

### Task 1: 确认基线并复核学习来源枚举

**Files:**
- Read: `lib/models/study_source.dart`

- [ ] **Step 1: 运行全项目分析，确认阶段二开始前基线干净**

```powershell
flutter analyze
```

预期：`No issues found!`（阶段一已达成）。

- [ ] **Step 2: 复核 StudySource 已包含 studyPlan**

确认 `StudySource` 枚举含 `studyPlan`，且 `StudySourceKey.key` 扩展覆盖该值。阶段一已添加，无需重复添加；若缺失则补齐。

- [ ] **Step 3: 运行现有测试，确认绿灯基线**

```powershell
flutter test
```

预期：阶段一全部测试通过。

---

### Task 2: 学习计划纯逻辑模型与测试（TDD）

**Files:**
- Create: `lib/models/study_plan.dart`
- Create: `lib/models/daily_task_snapshot.dart`
- Create: `test/study_plan_logic_test.dart`
- Create: `test/daily_task_snapshot_test.dart`
- Create: `lib/services/study_plan_logic.dart`
- Modify: `lib/models/models.dart`

- [ ] **Step 1: 先写失败测试 `test/daily_task_snapshot_test.dart`**

覆盖：
1. 完成率 = (已完成新词 + 已完成复习) / (目标新词 + 目标复习)，目标为 0 时返回 1.0（视为完成）。
2. `isCompleted` 当新词与复习都达到目标时为 true。
3. 剩余新词、剩余复习不为负。

- [ ] **Step 2: 先写失败测试 `test/study_plan_logic_test.dart`**

覆盖：
1. 固定截止日：每日新词量 = ceil(总词数 / 剩余天数)，剩余天数至少为 1。
2. 固定每日量：直接采用用户指定值，预计完成天数 = ceil(总词数 / 每日量)。
3. 计划总体进度 = 已学新词 / 计划总词数，封顶 1.0。
4. 目标日期已过或为今天，剩余天数按 1 计算，避免除零。

- [ ] **Step 3: 实现 `lib/models/study_plan.dart`**

定义：
- `enum StudyPlanType { fixedDaily, fixedDeadline, examTarget }`
- `enum StudyPlanStatus { active, paused, completed }`
- `class StudyPlan`：字段 id、name、wordBookIds(List<int>)、type、targetDate、dailyNewTarget、totalWords、status、createdAt、updatedAt，含 `toMap`/`fromMap`（wordBookIds 用逗号拼接字符串存储）、`copyWith`。

- [ ] **Step 4: 实现 `lib/models/daily_task_snapshot.dart`**

定义 `class DailyTaskSnapshot`：字段 date、planId、targetNewWords、targetReviewWords、completedNewWords、completedReviewWords、completedAt，含 `completionRate`、`isCompleted`、`remainingNewWords`、`remainingReviewWords` 纯逻辑及 `toMap`/`fromMap`。

- [ ] **Step 5: 实现 `lib/services/study_plan_logic.dart`**

提供静态纯函数：
- `estimateDailyNewTarget({required int totalWords, required DateTime targetDate, required DateTime today})`
- `estimateFinishDays({required int totalWords, required int dailyNewTarget})`
- `planProgress({required int learnedNewWords, required int totalWords})`

- [ ] **Step 6: 更新 `lib/models/models.dart` 导出新模型**

- [ ] **Step 7: 运行测试**

```powershell
flutter test test/daily_task_snapshot_test.dart test/study_plan_logic_test.dart
```

预期：全部通过。

---

### Task 3: 数据库迁移与 DAO/Repository

**Files:**
- Modify: `lib/services/database_service.dart`
- Create: `lib/services/daos/study_plan_dao.dart`
- Create: `lib/services/repositories/study_plan_repository.dart`
- Modify: `lib/services/repositories/repositories.dart`

- [ ] **Step 1: 数据库迁移到版本 9**

在 `onCreate` 增加 study_plans、daily_task_snapshots 两张表；在 `onUpgrade` 增加 `if (oldVersion < 9)` 分支用 `CREATE TABLE IF NOT EXISTS` 创建相同表。把 `version: 8` 改为 `version: 9`。

study_plans 字段：id、name、word_book_ids(TEXT)、type(INTEGER)、target_date(TEXT)、daily_new_target(INTEGER)、total_words(INTEGER)、status(INTEGER)、created_at(TEXT)、updated_at(TEXT)。

daily_task_snapshots 字段：id、date(TEXT)、plan_id(INTEGER)、target_new_words、target_review_words、completed_new_words、completed_review_words、completed_at(TEXT)，并建 plan_id+date 唯一索引。

- [ ] **Step 2: 实现 `StudyPlanDao`**

方法：insertPlan、updatePlan、getActivePlan、getAllPlans、deletePlan；upsertTodaySnapshot、getSnapshot(planId, date)、getSnapshotsByPlan。

- [ ] **Step 3: 实现 `StudyPlanRepository`**

封装 DAO，提供 createPlan、updatePlanStatus、getActivePlan、getTodaySnapshot、incrementTodayProgress 等供 Service/页面调用。

- [ ] **Step 4: 导出并通过分析**

更新 `repositories.dart` 导出；运行 `flutter analyze`。

---

### Task 4: StudyPlanService 计划编排

**Files:**
- Create: `lib/services/study_plan_service.dart`
- Modify: `lib/services/di_container.dart`

- [ ] **Step 1: 实现 `StudyPlanService`**

依赖 StudyPlanRepository、WordRepository、ReviewRepository。职责：
1. `createPlan`：根据词库计算 totalWords，按类型估算 dailyNewTarget（调用 study_plan_logic）。
2. `getTodayTask`：返回今日目标新词数、目标复习数（结合到期复习量与计划 dailyNewTarget），生成/读取 DailyTaskSnapshot。
3. `recordProgress`：学习完成后累加今日已完成新词/复习数。
4. `pause/resume/complete`：更新计划状态。

- [ ] **Step 2: 在 DIContainer 注册**

新增 `studyPlanRepository`、`studyPlanService` 字段与初始化，更新 `get<T>()` 分支。

- [ ] **Step 3: 运行分析**

```powershell
flutter analyze
```

---

### Task 5: 本地通知提醒纯逻辑与测试（TDD）

**Files:**
- Create: `lib/models/notification_settings.dart`
- Create: `test/notification_condition_test.dart`
- Modify: `lib/models/models.dart`

- [ ] **Step 1: 先写失败测试 `test/notification_condition_test.dart`**

覆盖 `NotificationSettings.shouldRemind` 纯逻辑：
1. 未启用提醒 → 永不提醒。
2. 条件=有待复习：仅 dueCount > 0 时提醒。
3. 条件=计划未完成：仅今日计划未完成时提醒。
4. 条件=两者：任一满足即提醒。

- [ ] **Step 2: 实现 `NotificationSettings`**

字段：enabled(bool)、reminderHour(int)、reminderMinute(int)、condition(枚举 hasDue/planIncomplete/either)；含 `shouldRemind({required int dueCount, required bool planIncomplete})` 纯逻辑与 SharedPreferences 序列化键约定。

- [ ] **Step 3: 更新 models.dart 导出并运行测试**

```powershell
flutter test test/notification_condition_test.dart
```

---

### Task 6: 升级 NotificationService 为真实通知

**Files:**
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/services/di_container.dart`（init 时调用通知初始化）

- [ ] **Step 1: 用 flutter_local_notifications 实现**

实现：
1. `init()`：初始化插件、Windows/Android/iOS 平台设置、请求权限（移动端）。
2. `scheduleDailyReminder({required int hour, required int minute, required String title, required String body})`：每日定时提醒。
3. `cancelReminder()`：取消提醒。
4. `showReviewReminder(int dueCount)`：立即提醒（保留兼容）。
5. 点击通知回调进入应用。

注意（security_awareness）：通知内容不包含敏感数据；权限请求按平台处理；桌面平台若插件不支持定时通知则降级为应用内提醒并记录日志，不崩溃。

- [ ] **Step 2: 在 DIContainer.init 中调用 `await notificationService.init()`**

- [ ] **Step 3: 运行分析与构建检查**

```powershell
flutter analyze
```

---

### Task 7: 通知设置与计划设置接入 Provider 和设置页

**Files:**
- Modify: `lib/services/providers/study_settings_provider.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/utils/translations.dart`

- [ ] **Step 1: Provider 增加通知设置状态**

增加 NotificationSettings 的加载/保存（启用开关、提醒时间、提醒条件），变更时调用 NotificationService 重新调度或取消。

- [ ] **Step 2: 设置页增加通知设置区块**

开关、时间选择器（TimePicker）、提醒条件单选；变更即生效。

- [ ] **Step 3: 设置页增加“学习计划”入口**

跳转 study_plan_screen。

- [ ] **Step 4: 补充中英文文案并运行分析**

---

### Task 8: 学习计划管理页

**Files:**
- Create: `lib/screens/study_plan_screen.dart`
- Modify: `lib/utils/translations.dart`

- [ ] **Step 1: 实现计划列表与创建表单**

创建表单：选择词库（可多选）、计划类型、目标日期或每日量；提交调用 StudyPlanService.createPlan。

- [ ] **Step 2: 计划详情/操作**

展示进度、剩余天数、每日任务；提供暂停/恢复/完成/删除操作。

- [ ] **Step 3: 复用 Fluid UI 组件，兼容深浅色与中英文，运行分析**

---

### Task 9: 首页今日任务中心升级

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/utils/translations.dart`

- [ ] **Step 1: Dashboard 数据加载**

加载今日任务（StudyPlanService.getTodayTask）、到期复习量、错词量、当前计划进度、可继续的未完成进度。

- [ ] **Step 2: 任务卡片展示**

今日新词任务、今日复习任务、计划进度条、错词强化建议、一键开始今日任务、继续未完成任务。

- [ ] **Step 3: 一键开始**

按今日任务组装学习入口（计划任务用 `StudySource.studyPlan` 的 SpecializedStudyRequest，普通复习走现有复习入口）。

- [ ] **Step 4: 运行分析**

---

### Task 10: 每日任务完成反馈与计划进度回写

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- Modify: `lib/screens/stats_screen.dart`
- Modify: `lib/utils/translations.dart`

- [ ] **Step 1: 学习完成回写计划进度**

在 `_finishStudy` 中，若来源为计划任务或正常学习，调用 StudyPlanService.recordProgress 累加今日完成新词/复习数。

- [ ] **Step 2: 完成反馈展示**

学习总结页或首页展示：今日完成率、新学单词数、复习单词数、错词减少数量、连续学习天数、明日预计复习压力。

- [ ] **Step 3: 统计页计划完成度**

stats_screen 增加计划完成度卡片（计划名、总体进度、今日完成率）。

- [ ] **Step 4: 补充文案并运行分析**

---

### Task 11: 回归、分析与打包验收

- [ ] **Step 1: 全量测试**

```powershell
flutter test
```

- [ ] **Step 2: 全项目分析**

```powershell
flutter analyze
```

预期：`No issues found!`

- [ ] **Step 3: Windows release 打包验证**

```powershell
flutter build windows --release
```

- [ ] **Step 4: release 启动冒烟验收**

启动 exe，确认首页今日任务中心、计划创建、通知设置、统计页计划进度正常，关闭测试进程。

- [ ] **Step 5: 更新交接文档 `docs/current-progress-handoff.md`**

---

## 阶段二验收标准

1. 用户可以创建学习计划（固定每日量 / 固定截止日 / 考试目标）。
2. 首页可以看到今日任务与计划进度，并可一键开始或继续未完成任务。
3. 本地通知可以按设置的时间和条件提醒（桌面不支持时有合理降级）。
4. 完成学习后计划当日进度会更新。
5. 统计页可以展示计划完成度。
6. `flutter analyze` 全项目 No issues found，`flutter test` 全部通过，Windows release 可打包并启动。

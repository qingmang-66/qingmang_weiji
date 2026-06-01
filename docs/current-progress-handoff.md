# 当前开发进度交接

更新时间：2026-06-01

## 项目背景

项目是 Flutter 桌面/多端应用 `qingmang_weiji`。当前主线已从界面深浅色适配推进到“四阶段增强计划”，阶段一聚焦质量基线与错词学习闭环，阶段二聚焦学习体验增强。

常用工作目录：

```text
c:\qingmang_weiji
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
c:\qingmang_weiji\build\windows\x64\runner\Release\qingmang_weiji.exe
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
c:\qingmang_weiji\build\windows\x64\runner\Release\qingmang_weiji.exe
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
c:\qingmang_weiji\build\windows\x64\runner\Release\qingmang_weiji.exe
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

## 注意事项

- 除专有名词外，回复尽量使用中文。
- 用户偏好：如果涉及 C++，倾向使用 `using namespace std;`。
- 当前项目是 Flutter/Dart，除非用户要求，不要主动创建额外文档。
- 修改代码后必须尽量运行格式化、定向 analyze 和必要测试。
- 不要自动提交 git，除非用户明确要求。

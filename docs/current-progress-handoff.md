# 当前开发进度交接

更新时间：2026-05-25

## 项目背景

项目是 Flutter 桌面/多端应用 `qingmang_weiji`，当前主要工作是：

1. 将页面逐步统一为 Fluid / glassmorphism / gradient 风格。
2. 修复深色/浅色模式下文字、卡片、弹窗、输入框、按钮的可读性问题。
3. 清理 `flutter analyze` 历史 warning/info。
4. 必要时构建 Windows release exe 供人工查看。

常用工作目录：

```text
c:\qingmang_weiji
```

常用验证命令：

```bash
dart format <文件路径>
flutter analyze <文件路径>
flutter analyze
flutter build windows --release
```

Windows exe 输出路径：

```text
c:\qingmang_weiji\build\windows\x64\runner\Release\qingmang_weiji.exe
```

运行 exe 时需要保留同目录下的 `data/` 和 `.dll` 文件。

## 已完成的深浅色适配

### 页面

以下页面已经完成 Fluid 深浅色适配，并做过对应单文件 analyze：

- `lib/screens/home_screen.dart`
- `lib/screens/study_screen.dart`
- `lib/screens/pre_study_screen.dart`
- `lib/screens/wordbook_screen.dart`
- `lib/screens/stats_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/search_screen.dart`
- `lib/screens/wrong_words_screen.dart`
- `lib/screens/word_detail_screen.dart`
- `lib/screens/onboarding_screen.dart`

### 组件

以下组件已经适配或修复过：

- `lib/theme/fluid_theme.dart`
- `lib/widgets/fluid_dialog.dart`
- `lib/widgets/fluid_card.dart`
- `lib/widgets/fluid_button.dart`
- `lib/widgets/word_card.dart`
- `lib/widgets/study_components.dart`
- `lib/widgets/settings_sections.dart`

### 重要已修问题

- 词库页内置词库弹窗底部“导入”按钮显示不全。
- 词库页批量导入进度状态恢复。
- 词库页内置词库弹窗、底部 sheet、词库卡片浅色模式可读性。
- 设置页数字输入弹窗、备份弹窗、导入词库弹窗浅色模式可读性。
- 搜索页输入框、空状态、无结果状态、搜索结果卡片 Fluid 化。
- 错词页列表卡片、批量选择、确认弹窗、空状态 Fluid 化。
- 单词详情页头部卡片、释义/例句卡片、标签、音频按钮 Fluid 化。
- 引导页背景、步骤卡片、按钮、指示器 Fluid 化。

## 已完成的 analyzer 清理

### `lib/main.dart`

已完成：

- 删除未使用导入：`screens/ui_showcase_screen.dart`
- 删除未使用导入：`utils/translations.dart`
- 删除未引用的 `_SplashScreen`
- 删除未引用的 `_ErrorScreen`

验证结果：

```bash
flutter analyze lib/main.dart
```

结果：

```text
No issues found!
```

全项目 analyze 从之前约 32 个问题降到 29 个问题。

## 当前未完成事项

### 1. `lib/screens/pre_study_screen.dart`

当前剩余 warning 主要是未使用字段：

- `_spellCorrect`
- `_selectedQuizOption`
- `_correctQuizOption`
- `_quizOptions`
- `_quizOptionsLoading`
- `_recordsPreloaded`

建议下一步优先处理。

处理前需要判断：

1. 如果拼写/测验模式短期不做，删除这些残留字段。
2. 如果要保留功能，则补齐对应 UI/逻辑引用。

当前建议：先清理未使用字段，避免继续污染 analyzer。

### 2. `lib/screens/ui_showcase_screen.dart`

当前主应用不再导入该文件，但文件本身仍被全项目 analyze 扫描。

剩余问题包括：

- 未使用导入：`dart:math`
- 不必要导入：`package:flutter/physics.dart`
- `_selectedCard` 可设为 final
- `_selectedCard` 未使用
- `_bgShimmerAnimation` 未使用
- `_btnSpring` 未使用
- `_cardSpring` 未使用

可选处理方式：

1. 如果展示页还需要保留：清理未使用导入、字段、动画控制器。
2. 如果展示页不再需要：删除文件，并确认没有导出或引用。

### 3. `lib/theme/ui_theme.dart`

剩余 Flutter API 废弃项：

- `background` 已废弃，应改为 `surface`
- `onBackground` 已废弃，应改为 `onSurface`

### 4. `lib/utils/animations/fluid_curves.dart`

剩余：

- `package:flutter/animation.dart` 不必要导入

### 5. `lib/utils/animations/spring_curves.dart`

剩余：

- 局部变量 `simulation` 未使用，两处

### 6. `lib/widgets/fluid_app_bar.dart`

剩余：

- dead code
- dead null-aware expression

### 7. `lib/widgets/stats_cards.dart`

剩余：

- 多处 `if` 语句需要加花括号

属于风格 info，不影响运行。

### 8. `lib/widgets/study_heatmap.dart`

剩余：

- `_getLevel` 未引用

### 9. `lib/widgets/ui_app_bar.dart`

剩余：

- dead code
- dead null-aware expression

### 10. `lib/widgets/ui_gradient.dart`

剩余：

- `scale` 已废弃，应改为新的缩放 API

## 建议下一步顺序

推荐继续按以下顺序清理：

1. `lib/screens/pre_study_screen.dart`
2. `lib/screens/ui_showcase_screen.dart`
3. `lib/theme/ui_theme.dart`
4. `lib/utils/animations/fluid_curves.dart`
5. `lib/utils/animations/spring_curves.dart`
6. `lib/widgets/fluid_app_bar.dart`
7. `lib/widgets/stats_cards.dart`
8. `lib/widgets/study_heatmap.dart`
9. `lib/widgets/ui_app_bar.dart`
10. `lib/widgets/ui_gradient.dart`

每完成一个文件建议执行：

```bash
dart format <文件路径>
flutter analyze <文件路径>
flutter analyze
```

## 新对话继续方式

如果当前对话太长，可以开启新对话，并让助手先读取这个文件：

```text
请先阅读 docs/current-progress-handoff.md，然后继续从“建议下一步顺序”开始处理。
```

当前最推荐的下一句是：

```text
请先阅读 docs/current-progress-handoff.md，然后开始清理 lib/screens/pre_study_screen.dart 的未使用字段。
```

## 注意事项

- 除专有名词外，回复尽量使用中文。
- 用户偏好：如果涉及 C++，倾向使用 `using namespace std;`。
- 当前项目是 Flutter/Dart，除非用户要求，不要主动创建额外文档。
- 但本文件是用户明确要求用于压缩上下文的交接文档。
- 修改代码后必须尽量运行格式化和定向 analyze。
- 不要自动提交 git，除非用户明确要求。

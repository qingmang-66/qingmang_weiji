# 代码检查问题修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复代码检查中发现的问题，统一到 Fluid 设计体系，移除旧版 UI 组件残留

**Architecture:** 分三个阶段执行——先修复现有组件的深色模式/浅色模式兼容问题，再迁移不一致的组件，最后清理死代码。每个阶段独立可验证，不会破坏现有功能。

**Tech Stack:** Flutter 3.x, Provider, FluidTheme 设计系统

---

## 依赖关系分析

```
main.dart ──使用──> UITheme.themeData ──依赖──> DesignTokens
main.dart ──注册──> GlassThemeProvider ──依赖──> DesignTokens
旧版UI组件 ──依赖──> GlassThemeProvider + DesignTokens + UITheme
FluidTheme静态样式 ──硬编码──> 白色文字（浅色模式不可见）
study_heatmap ──硬编码──> 白色背景（深色模式不可用）
dictionary_dialog ──使用──> AlertDialog（与FluidDialog不一致）
```

**关键发现：** 旧版 UI 组件（ui_card/button/dialog/app_bar/gradient/loading/background）没有被任何页面导入，是死代码。

---

## Phase 1: 关键修复（无破坏性变更）

### Task 1: 修复 FluidTheme 静态文本样式的浅色模式兼容性

**问题：** `FluidTheme` 中的 `headingLarge`、`bodyLarge` 等文本样式 getter 硬编码了 `textPrimary`（白色），在浅色模式下文字不可见。

**Files:**
- Modify: `lib/theme/fluid_theme.dart:389-488`

- [ ] **Step 1: 将静态 getter 改为接受 isDark 参数的方法**

将以下 getter 改为方法形式：

```dart
// 修改前（硬编码白色，浅色模式不可见）：
static TextStyle get headingLarge => const TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  color: textPrimary,  // 白色
  letterSpacing: -0.5,
);

// 修改后（根据深浅色动态返回）：
static TextStyle headingLarge(bool isDark) => TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  color: getTextPrimaryColor(isDark),
  letterSpacing: -0.5,
);
```

需要修改的所有样式：
- `headingLarge` → `headingLarge(bool isDark)`
- `headingMedium` → `headingMedium(bool isDark)`
- `headingSmall` → `headingSmall(bool isDark)`
- `bodyLarge` → `bodyLarge(bool isDark)`
- `bodyMedium` → `bodyMedium(bool isDark)`
- `bodySmall` → `bodySmall(bool isDark)`
- `labelLarge` → `labelLarge(bool isDark)`
- `labelMedium` → `labelMedium(bool isDark)`
- `numberLarge` → `numberLarge(bool isDark)`
- `numberMedium` → `numberMedium(bool isDark)`
- `numberSmall` → `numberSmall(bool isDark)`

- [ ] **Step 2: 更新所有使用这些样式的文件**

搜索所有使用 `FluidTheme.headingLarge`、`FluidTheme.bodyLarge` 等的位置，改为 `FluidTheme.headingLarge(isDark)` 形式。

涉及文件（需逐一检查）：
- `lib/widgets/stats_cards.dart`
- `lib/widgets/study_calendar.dart`
- `lib/widgets/review_line_chart.dart`
- `lib/widgets/stage_pie_chart.dart`
- `lib/widgets/settings_sections.dart`
- `lib/screens/onboarding_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/stats_screen.dart`

- [ ] **Step 3: 运行 flutter analyze 验证**

Run: `cd c:\qingmang_weiji && flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/theme/fluid_theme.dart lib/widgets/ lib/screens/
git commit -m "fix: FluidTheme静态文本样式支持浅色模式"
```

---

### Task 2: 修复 study_heatmap.dart 的深色模式支持

**问题：** `StudyHeatmap` 硬编码白色背景和深色文字，在深色模式下完全不可用。

**Files:**
- Modify: `lib/widgets/study_heatmap.dart`

- [ ] **Step 1: 添加 Provider 和 FluidTheme 导入，替换硬编码颜色**

```dart
// 添加导入
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
```

- [ ] **Step 2: 在 build 方法中获取主题状态**

```dart
@override
Widget build(BuildContext context) {
  final isDark = context.watch<ThemeProvider>().isDarkMode;
  final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
  final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
  final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
  // ...
}
```

- [ ] **Step 3: 替换所有硬编码颜色**

需要替换的颜色映射：
- `Colors.white`（背景）→ `FluidTheme.getSurfaceColor(isDark)` 或使用 `FluidTheme.getSurfaceGradientColors(isDark)` 渐变
- `Color(0xFFE5E5EA)`（边框）→ `FluidTheme.getBorderColor(isDark)`
- `Color(0xFF1A1A2E)`（文字）→ `textPrimary`
- `Color(0xFF1A1A2E).withValues(alpha: 0.5)` → `textSecondary`
- `Color(0xFF1A1A2E).withValues(alpha: 0.6)` → `textTertiary`
- `Color(0xFF5B6AFF)`（图标背景）→ `FluidTheme.primaryFluidGradient[0]`

同时将容器装饰从纯色背景改为与其他组件一致的渐变风格：

```dart
// 修改前：
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE5E5EA), width: 1.0),
  ),
  // ...
)

// 修改后：
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: FluidTheme.getSurfaceGradientColors(isDark),
    ),
    borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
    border: Border.all(color: FluidTheme.getBorderColor(isDark), width: 1.0),
  ),
  // ...
)
```

- [ ] **Step 4: 更新热力图颜色方案适配深色模式**

`_getLevelColor` 方法中的颜色需要根据深浅色调整亮度：

```dart
Color _getLevelColor(int level, bool isDark) {
  if (isDark) {
    switch (level) {
      case 0: return Colors.white.withValues(alpha: 0.06);
      case 1: return const Color(0xFF5B6AFF).withValues(alpha: 0.3);
      case 2: return const Color(0xFF5B6AFF).withValues(alpha: 0.5);
      case 3: return const Color(0xFF5B6AFF).withValues(alpha: 0.7);
      case 4: return const Color(0xFF5B6AFF);
      default: return Colors.transparent;
    }
  }
  // 浅色模式保持原有配色
  switch (level) {
    case 0: return const Color(0xFFEBEDF0);
    case 1: return const Color(0xFF9BE9A8);
    case 2: return const Color(0xFF40C463);
    case 3: return const Color(0xFF30A14E);
    case 4: return const Color(0xFF216E39);
    default: return Colors.transparent;
  }
}
```

- [ ] **Step 5: 更新 _HeatmapPainter 接受 isDark 参数**

将 `isDark` 传入 `_HeatmapPainter`，使其在绘制时使用正确的颜色。

- [ ] **Step 6: 运行 flutter analyze 验证**

Run: `cd c:\qingmang_weiji && flutter analyze`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/study_heatmap.dart
git commit -m "fix: StudyHeatmap支持深色模式"
```

---

## Phase 2: 一致性改进

### Task 3: 迁移 DictionaryDialog 到 FluidDialog

**问题：** `DictionaryDialog` 使用标准 `AlertDialog`，与项目其他对话框的 FluidDialog 风格不一致。

**Files:**
- Modify: `lib/widgets/dictionary_dialog.dart`

- [ ] **Step 1: 添加 FluidDialog 和 FluidTheme 导入**

```dart
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import 'fluid_dialog.dart';
```

- [ ] **Step 2: 重写 build 方法使用 FluidDialog**

将 `AlertDialog` 替换为 `FluidDialog`：

```dart
@override
Widget build(BuildContext context) {
  final isDark = context.watch<ThemeProvider>().isDarkMode;
  final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
  final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

  return FluidDialog(
    title: widget.word,
    content: _loading
        ? const Center(
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        : _error != null
            ? _buildErrorState(isDark, textSecondary)
            : _buildContent(isDark, textPrimary, textSecondary),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr.close),
      ),
    ],
  );
}
```

- [ ] **Step 3: 更新内容区域的样式使用 FluidTheme**

将 `colorScheme.primary`、`colorScheme.onSurfaceVariant` 等替换为 `FluidTheme` 对应方法。

- [ ] **Step 4: 运行 flutter analyze 验证**

Run: `cd c:\qingmang_weiji && flutter analyze`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dictionary_dialog.dart
git commit -m "refactor: DictionaryDialog迁移到FluidDialog"
```

---

### Task 4: 创建 FluidTheme.themeData 替换 UITheme.themeData

**问题：** `main.dart` 中 `theme` 和 `darkTheme` 都使用 `UITheme.themeData`（旧版主题），需要迁移到 FluidTheme 体系。

**Files:**
- Modify: `lib/theme/fluid_theme.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 在 FluidTheme 中添加 themeData 和 darkThemeData 工厂方法**

```dart
/// 获取浅色主题数据
static ThemeData get lightThemeData => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: lightBackgroundGradient.first,
  colorScheme: ColorScheme.light(
    primary: primaryFluidGradient[0],
    secondary: primaryFluidGradient[2],
    surface: getSurfaceColor(false),
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: textPrimaryLight,
    onError: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: textPrimaryLight,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: textPrimaryLight),
  ),
  cardTheme: CardThemeData(
    color: getSurfaceColor(false),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardBorderRadius),
    ),
  ),
  // ... 其他主题配置
);

/// 获取深色主题数据
static ThemeData get darkThemeData => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: background,
  colorScheme: ColorScheme.dark(
    primary: primaryFluidGradient[0],
    secondary: primaryFluidGradient[2],
    surface: getSurfaceColor(true),
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: textPrimaryDark,
    onError: Colors.white,
  ),
  // ... 其他主题配置
);
```

- [ ] **Step 2: 更新 main.dart 使用 FluidTheme 主题数据**

```dart
// 修改前：
import 'theme/ui_theme.dart';
// ...
theme: UITheme.themeData,
darkTheme: UITheme.themeData,

// 修改后：
import 'theme/fluid_theme.dart';
// ...
theme: FluidTheme.lightThemeData,
darkTheme: FluidTheme.darkThemeData,
```

- [ ] **Step 3: 运行 flutter analyze 验证**

Run: `cd c:\qingmang_weiji && flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/theme/fluid_theme.dart lib/main.dart
git commit -m "refactor: MaterialApp主题迁移到FluidTheme"
```

---

## Phase 3: 死代码清理

### Task 5: 移除旧版 UI 组件文件

**前提：** Task 1-4 已完成，确认无页面使用旧版组件。

**Files:**
- Delete: `lib/widgets/ui_card.dart`
- Delete: `lib/widgets/ui_button.dart`
- Delete: `lib/widgets/ui_dialog.dart`
- Delete: `lib/widgets/ui_app_bar.dart`
- Delete: `lib/widgets/ui_gradient.dart`
- Delete: `lib/widgets/ui_loading.dart`
- Delete: `lib/widgets/ui_background.dart`
- Delete: `lib/theme/ui_theme.dart`
- Delete: `lib/utils/theme/design_tokens.dart`
- Delete: `lib/utils/theme/theme_provider.dart`
- Modify: `lib/widgets/widgets.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 从 widgets.dart 移除旧版组件导出**

```dart
// 删除以下行：
export 'ui_app_bar.dart';
export 'ui_background.dart';
export 'ui_button.dart';
export 'ui_card.dart';
export 'ui_dialog.dart';
export 'ui_gradient.dart';
export 'ui_loading.dart';
```

- [ ] **Step 2: 从 main.dart 移除 GlassThemeProvider 注册和旧导入**

```dart
// 删除：
import 'utils/theme/theme_provider.dart' as glass_theme;
// 删除 Provider 注册行：
ChangeNotifierProvider(create: (_) => glass_theme.GlassThemeProvider()),
```

- [ ] **Step 3: 删除旧版组件文件**

删除以下文件：
- `lib/widgets/ui_card.dart`
- `lib/widgets/ui_button.dart`
- `lib/widgets/ui_dialog.dart`
- `lib/widgets/ui_app_bar.dart`
- `lib/widgets/ui_gradient.dart`
- `lib/widgets/ui_loading.dart`
- `lib/widgets/ui_background.dart`
- `lib/theme/ui_theme.dart`
- `lib/utils/theme/design_tokens.dart`
- `lib/utils/theme/theme_provider.dart`

- [ ] **Step 4: 检查 utils/theme/ 目录是否为空，若是则删除**

Run: `ls c:\qingmang_weiji\lib\utils\theme\`
如果目录为空，删除整个目录。

- [ ] **Step 5: 运行 flutter analyze 验证**

Run: `cd c:\qingmang_weiji && flutter analyze`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: 移除旧版UI组件和DesignTokens/GlassThemeProvider死代码"
```

---

### Task 6: 补充 widgets.dart 导出

**问题：** `widgets.dart` 未导出部分组件。

**Files:**
- Modify: `lib/widgets/widgets.dart`

- [ ] **Step 1: 补充缺失的组件导出**

```dart
// 添加以下导出：
export 'animated_list_item.dart';
export 'home_components.dart';
export 'stats_cards.dart';
export 'settings_sections.dart';
export 'study_calendar.dart';
```

注意：`study_heatmap.dart` 如果只在 `stats_screen.dart` 中使用，也可以选择性导出。

- [ ] **Step 2: 运行 flutter analyze 验证**

Run: `cd c:\qingmang_weiji && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/widgets.dart
git commit -m "chore: 补充widgets.dart缺失的组件导出"
```

---

## 执行顺序总结

```
Phase 1（关键修复，无破坏性）
  Task 1: FluidTheme 静态文本样式浅色模式 ──> Task 2: StudyHeatmap 深色模式

Phase 2（一致性改进）
  Task 3: DictionaryDialog 迁移 ──> Task 4: FluidTheme.themeData 替换 UITheme

Phase 3（死代码清理，依赖 Phase 2 完成）
  Task 5: 移除旧版组件 ──> Task 6: 补充导出
```

每个 Task 完成后都运行 `flutter analyze` 确保无回归。

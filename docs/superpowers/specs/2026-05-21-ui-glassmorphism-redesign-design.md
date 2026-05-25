# UI 重构设计文档 - iOS 玻璃拟态风格

## 概述

将清茫微记的 UI 全面重构为 iOS 玻璃拟态风格，以参考图片的卡片 + 渐变风格为基础，融入 iOS 系统的毛玻璃效果，打造现代化、精致的学习应用界面。

## 设计目标

1. **视觉统一**：全应用采用统一的设计语言和组件规范
2. **精致感**：通过毛玻璃效果、渐变、阴影等提升视觉品质
3. **易用性**：保持清晰的视觉层次和操作反馈
4. **性能优化**：在保证视觉效果的同时优化渲染性能

## 视觉系统

### 配色方案

| 用途 | 颜色 | 色值 |
|------|------|------|
| 主色调（蓝） | Primary Blue | `#007AFF` |
| 主色调（紫） | Primary Purple | `#9B59B6` |
| 背景渐变起始 | Background Start | `#F5F7FF` |
| 背景渐变结束 | Background End | `#F0E6FF` |
| 卡片背景 | Card Background | `rgba(255, 255, 255, 0.85)` |
| 文字 - 深灰 | Text Primary | `#1D1D1F` |
| 文字 - 中灰 | Text Secondary | `#86868B` |
| 文字 - 浅灰 | Text Tertiary | `#AEAEB2` |
| 成功色 | Success | `#34C759` |
| 警告色 | Warning | `#FF9500` |
| 错误色 | Error | `#FF3B30` |
| 选中态背景 | Selected Background | `rgba(0, 122, 255, 0.08)` |
| 选中态边框 | Selected Border | `#007AFF` |
| 选中态阴影 | Selected Shadow | `rgba(0, 122, 255, 0.15)` |

### 圆角规范

| 组件 | 圆角值 |
|------|--------|
| 卡片 | 20px |
| 按钮 | 16px |
| 图标容器 | 14px |
| 对话框 | 28px |
| 输入框 | 16px |
| 标签/Chip | 12px |

### 阴影规范

| 用途 | 阴影值 |
|------|--------|
| 卡片默认 | `rgba(0, 0, 0, 0.04), blur: 8px, offset: (0, 2)` |
| 卡片选中 | `rgba(0, 122, 255, 0.15), blur: 12px, offset: (0, 2)` |
| 按钮 | `rgba(0, 122, 255, 0.3), blur: 8px, offset: (0, 2)` |
| 对话框 | `rgba(0, 0, 0, 0.1), blur: 20px, offset: (0, 4)` |

### 间距规范

| 用途 | 间距值 |
|------|--------|
| 卡片外边距 | 16px（水平），6px（垂直） |
| 卡片内边距 | 16px |
| 组件间距 | 8px、12px、16px、24px |

## 核心组件

### GlassCard（玻璃卡片）

**功能**：封装毛玻璃效果的卡片组件

**属性**：
- `child`: Widget - 卡片内容
- `padding`: EdgeInsets - 内边距（默认 16px）
- `margin`: EdgeInsets - 外边距（默认 水平 16px，垂直 6px）
- `isSelected`: bool - 是否选中（默认 false）
- `onTap`: VoidCallback? - 点击回调

**效果**：
- 白色半透明背景（85% 透明度）
- BackdropFilter 毛玻璃模糊（sigma: 20）
- 淡阴影
- 20px 圆角
- 选中时：蓝色边框 + 淡蓝背景 + 蓝色阴影

### GlassAppBar（玻璃导航栏）

**功能**：封装毛玻璃效果的导航栏组件

**属性**：
- `title`: Widget - 标题
- `actions`: List<Widget>? - 右侧操作按钮
- `leading`: Widget? - 左侧按钮
- `centerTitle`: bool - 标题是否居中（默认 true）

**效果**：
- 半透明毛玻璃背景
- 滚动时动态模糊效果
- 标题字重 600，字号 18px

### GradientButton（渐变按钮）

**功能**：封装蓝紫渐变胶囊按钮

**属性**：
- `onPressed`: VoidCallback? - 点击回调
- `label`: String - 按钮文字
- `colors`: List<Color> - 渐变颜色（默认 蓝→紫）
- `fontSize`: double - 字号（默认 15）
- `isEnabled`: bool - 是否可用（默认 true）

**效果**：
- 蓝紫渐变背景
- 16px 圆角（胶囊形）
- 内边距：水平 24px，垂直 14px
- 字重 600
- 按下时轻微缩放动画

### GlassDialog（玻璃对话框）

**功能**：封装毛玻璃效果的对话框组件

**属性**：
- `title`: Widget? - 标题
- `content`: Widget - 内容
- `actions`: List<Widget>? - 操作按钮
- `barrierColor`: Color? - 遮罩颜色

**效果**：
- 毛玻璃背景
- 28px 圆角
- 淡阴影
- 半透明遮罩

## 页面重构范围

### 需要重构的页面

1. **首页**（`home_screen.dart`）
2. **词库页**（`wordbook_screen.dart`）
3. **学习页**（`study_screen.dart`）
4. **统计页**（`stats_screen.dart`）
5. **设置页**（`settings_screen.dart`）
6. **搜索页**（`search_screen.dart`）
7. **单词详情页**（`word_detail_screen.dart`）

### 需要重构的组件

1. **对话框**（`dictionary_dialog.dart`）
2. **学习组件**（`study_components.dart`）
3. **首页组件**（`home_components.dart`）
4. **统计卡片**（`stats_cards.dart`）
5. **设置区块**（`settings_sections.dart`）

## 技术实现

### 主题系统改造

在 `theme.dart` 中添加：
- `GlassTheme` 类，定义玻璃拟态风格的 ThemeData
- 全局颜色常量
- 设计令牌（Design Tokens）：圆角、阴影、间距等

### 主题自定义功能

在设置页面添加主题自定义功能，让用户可以个性化调整 UI 风格：

**1. 玻璃效果开关**
- 开关控件：启用/禁用毛玻璃效果
- 禁用时：使用纯色背景，提升性能
- 启用时：使用 BackdropFilter 毛玻璃效果

**2. 圆角风格选择**
- 单选按钮组：圆角 / 直角
- 圆角：使用设计令牌定义的圆角值
- 直角：所有组件使用 0px 圆角

**3. 圆角程度调节**
- 进度条（Slider）：0-100% 调节圆角程度
- 0%：直角（0px）
- 50%：中等圆角（10px）
- 100%：最大圆角（20px）
- 实时预览：拖动进度条时实时显示当前圆角值

**数据存储**：
- 使用 `SharedPreferences` 存储用户偏好设置
- 设置项：
  - `glassEffectEnabled`: bool - 玻璃效果开关
  - `borderRadiusStyle`: String - 圆角风格（'rounded' / 'sharp'）
  - `borderRadiusPercent`: double - 圆角程度（0.0-1.0）

**主题提供者**：
- 在 `ThemeProvider` 中添加主题设置状态管理
- 提供 `setGlassEffectEnabled(bool)` 方法
- 提供 `setBorderRadiusStyle(String)` 方法
- 提供 `setBorderRadiusPercent(double)` 方法
- 提供 `getCurrentBorderRadius()` 方法，根据设置计算当前圆角值

**组件适配**：
- 所有使用圆角的组件改为从 `ThemeProvider` 获取当前圆角值
- 使用 `AnimatedContainer` 实现圆角变化的平滑过渡

### 毛玻璃效果实现

使用 Flutter 的 `BackdropFilter` + `ImageFilter.blur`：
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    ),
  ),
)
```

### 性能优化

1. **毛玻璃效果优化**：
   - 仅在关键区域使用毛玻璃效果
   - 使用 `RepaintBoundary` 隔离重绘区域
   - 避免在列表项中大量使用毛玻璃效果

2. **动画优化**：
   - 使用 `AnimatedContainer` 实现平滑过渡
   - 使用 `ImplicitlyAnimatedWidget` 减少手动动画代码

## 实施顺序

### 第一阶段：基础架构

1. 创建玻璃拟态主题系统
2. 封装核心组件（GlassCard、GlassAppBar、GradientButton、GlassDialog）
3. 定义设计令牌（颜色、圆角、阴影等）

### 第二阶段：词库页面

1. 重构词库列表页
2. 重构内置词库对话框
3. 重构单词列表弹出页

### 第三阶段：主要页面

1. 重构首页
2. 重构学习页
3. 重构统计页

### 第四阶段：辅助页面

1. 重构设置页
2. 重构搜索页
3. 重构单词详情页

### 第五阶段：细节优化

1. 添加过渡动画
2. 优化性能
3. 适配深色模式

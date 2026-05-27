# S-MARS增强功能设计文档

## 概述

本文档描述清茫微记S-MARS会话掌握算法的三项增强功能：答题耗时惩罚、跨天持久化、S-MARS分数分布可视化。

## 功能一：答题耗时惩罚 - 动态阈值

### 设计目标
1. 区分"秒答"和"慢答"，更准确评估掌握程度
2. 采用动态阈值，基于单词历史答题时间自适应调整
3. 秒答答对不扣分（用户已掌握）
4. 秒答答错加重惩罚（可能是猜测）
5. 慢答答对轻微惩罚（记忆模糊）

### 动态阈值计算
```dart
// 基于单词历史答题时间的动态阈值
double fastThreshold = avgTime * 0.3;  // 低于30%平均时间视为秒答
double slowThreshold = avgTime * 2.5;  // 超过2.5倍平均时间视为慢答
```

### 评分调整逻辑
| 场景 | 耗时 | 结果 | 评分调整 |
|---|---|---|---|
| 秒答 | < fastThreshold | 答对 | 正常得分，不扣分 |
| 秒答 | < fastThreshold | 答错 | 额外-15分惩罚 |
| 慢答 | > slowThreshold | 答对 | -5分轻微惩罚 |
| 慢答 | > slowThreshold | 答错 | 正常惩罚 |
| 正常时间 | fastThreshold ~ slowThreshold | 任意 | 现有逻辑不变 |

### 数据持久化
- 新增`word_time_history`表存储每个单词的历史答题时间
- 字段：word_id, attempt_time, duration_ms, created_at

### 代码修改
1. `lib/services/session_mastery_engine.dart`
   - 新增`recordAttemptWithDuration`方法
   - 新增`_calculateTimeThresholds`方法计算动态阈值
   - 新增`_applyTimePenalty`方法应用时间惩罚
   - 新增`_wordTimeHistory`缓存历史答题时间

2. `lib/screens/pre_study_screen.dart`
   - 添加`_wordStartTime`记录开始时间
   - 修改`_checkTypedAnswer`、`_selectQuizOption`、`_onQualitySelected`计算耗时
   - 传递耗时参数到`recordAttemptWithDuration`

## 功能二：跨天持久化 - 会话分片保留

### 设计目标
1. 每天的S-MARS会话独立保存
2. 复习时综合最近7天的会话状态
3. 使用加权平均计算综合掌握度
4. 日期越近权重越高

### 数据结构
```dart
class SessionMasteryRecord {
  final int? id;
  final int wordId;
  final String date; // YYYY-MM-DD
  final double sessionScore;
  final int attemptCount;
  final int wrongCount;
  final int revealCount;
  final int retryCount;
  final int correctStreak;
  final double bestModeWeight;
  final bool hasHighWeightVerification;
  final bool hasOnlyRecallVerification;
  final bool hasOnlyQuizVerification;
  final DateTime createdAt;
}
```

### 跨天综合计算
```dart
// 加载最近7天的会话记录
// 日期权重：当天1.0，前一天0.8，前两天0.6，以此类推
double weight = 1.0 - (daysAgo * 0.2);
综合分数 = Σ(日期权重 × 会话分数) / Σ(日期权重)
```

### 代码修改
1. `lib/models/session_mastery_record.dart` - 新增模型
2. `lib/services/session_mastery_repository.dart` - 新增数据库操作
3. `lib/services/session_mastery_engine.dart`
   - 新增`loadSessionForDate`方法
   - 新增`saveSession`方法
   - 新增`loadMultiDaySession`方法加载多天会话
   - 修改`stateFor`方法支持跨天综合计算

4. 数据库迁移
   - 新增`session_mastery_records`表
   - 新增`word_time_history`表

## 功能三：S-MARS分数分布可视化

### 设计目标
1. 在学习总结页展示分数分布柱状图
2. 展示掌握状态分布饼图
3. 使用fl_chart库绘制图表
4. 支持深色/浅色主题自适应

### UI布局
```
┌─────────────────────────────────┐
│ 📊 分数分布                      │
│ ┌─────────────────────────────┐ │
│ │  [柱状图]                    │ │
│ │  ███  ██  ████  ██  █       │ │
│ │  0-10 20-30 40-50 60-70 80+ │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🎯 掌握状态分布                  │
│ ┌─────────────────────────────┐ │
│ │         [饼图]               │ │
│ │   强掌握 40%                 │ │
│ │   已掌握 25%                 │ │
│ │   学习中 20%                 │ │
│ │   薄弱词 15%                 │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### 代码修改
1. `pubspec.yaml` - 添加`fl_chart: ^0.66.0`依赖
2. `lib/screens/pre_study_screen.dart`
   - `_StudySummaryScreen`添加柱状图和饼图组件
   - 新增`_buildScoreDistributionChart`方法
   - 新增`_buildMasteryPieChart`方法
3. `lib/utils/translations.dart` - 新增翻译键

## 依赖项

```yaml
dependencies:
  fl_chart: ^0.66.0
```

## 代码修改清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `lib/models/session_mastery_record.dart` | 新增 | 会话记录模型 |
| `lib/services/session_mastery_repository.dart` | 新增 | 数据库操作 |
| `lib/services/session_mastery_engine.dart` | 扩展 | 耗时惩罚、跨天加载 |
| `lib/screens/pre_study_screen.dart` | 扩展 | 耗时记录、图表展示 |
| `lib/utils/translations.dart` | 扩展 | 新增翻译键 |
| `pubspec.yaml` | 修改 | 添加fl_chart依赖 |
| `lib/services/database_helper.dart` | 修改 | 数据库迁移 |

## 测试计划

### 单元测试
1. 动态阈值计算测试
2. 时间惩罚逻辑测试
3. 跨天加权平均测试
4. 分数分布计算测试

### 集成测试
1. 学习流程耗时记录测试
2. 跨天会话加载测试
3. 图表渲染测试

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| fl_chart兼容性问题 | 图表渲染失败 | 使用稳定版本，充分测试 |
| 数据库迁移失败 | 数据丢失 | 提供迁移脚本，备份数据 |
| 性能影响 | 加载变慢 | 缓存会话状态，异步加载 |

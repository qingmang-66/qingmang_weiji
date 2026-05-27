# 智能模式切换功能设计文档

## 概述

智能模式切换是清茫微记基于S-MARS会话掌握算法的进阶功能，允许用户在学习开始前选择是否启用动态模式切换。开启后，系统会根据单词的实时掌握状态自动调整学习模式，避免已掌握词的低价值重复，同时加强薄弱词的针对性训练。

## 设计目标

1. **用户可控**：提供明确开关，用户自主选择是否启用
2. **智能调度**：基于S-MARS算法实时判断单词掌握状态
3. **高效学习**：跳过已掌握词，薄弱词切换到高权重模式
4. **向后兼容**：默认关闭，不影响现有用户习惯
5. **低频抽查**：已掌握词以低概率随机抽查，防止过度自信

## 功能设计

### 1. 开关UI

**位置**：`PreStudyScreen`学习模式选择区域下方

**布局**：
```
┌──────────────────────────────────────────┐
│ 🧠 智能模式切换                           │
│                                          │
│ 开启后，系统会根据你的答题表现：           │
│ • 已掌握的单词自动跳过                   │
│ • 薄弱的单词切换到更有效的练习模式       │
│ • 避免低价值重复，提高学习效率           │
│                                          │
│ [开关] 关闭                              │
└──────────────────────────────────────────┘
```

**交互**：
- 默认关闭
- 点击开关切换状态
- 开关状态显示在开关右侧
- 可选：持久化到SharedPreferences

### 2. 智能切换规则

#### 2.1 模式推荐逻辑

在`SessionMasteryEngine`中新增`recommendNextMode`方法：

```dart
/// 根据当前掌握状态推荐下一个学习模式
/// 返回null表示应该跳过该词
int? recommendNextMode({
  required int currentMode,    // 当前模式(1-5)
  required SessionMasteryState state,
  required bool enableSpotCheck, // 是否启用抽查
}) {
  // 强掌握或已掌握 → 默认跳过
  if (state.isStrongMastered || state.isMastered) {
    // 低频抽查：5%概率随机抽查
    if (enableSpotCheck && Random().nextDouble() < 0.05) {
      return 2; // 抽查使用拼写模式(最高权重)
    }
    return null; // 跳过
  }
  
  // 薄弱词 → 切换到高权重模式
  if (state.isWeak) {
    if (currentMode == 1) return 2; // 回忆→拼写
    if (currentMode == 4 || currentMode == 5) return 2; // 测验→拼写
    return currentMode; // 已在高权重模式，保持
  }
  
  // 学习中 → 保持当前模式
  return currentMode;
}
```

#### 2.2 模式切换优先级表

| 当前模式 | S-MARS状态 | 推荐模式 | 说明 |
|---|---|---|---|
| 任意 | 强掌握/已掌握 | null(跳过) | 低频抽查5%→拼写 |
| 回忆(1) | 薄弱 | 拼写(2) | 切换到最高权重 |
| 测验(4/5) | 薄弱 | 拼写(2) | 切换到最高权重 |
| 拼写(2)/听力(3) | 薄弱 | 保持当前 | 已是高权重模式 |
| 任意 | 学习中 | 保持当前 | 继续当前模式 |

### 3. 学习流程改造

#### 3.1 原始流程

```
选择模式 → 遍历所有词 → 学完 → 错词强化
```

#### 3.2 智能模式流程

```
选择模式 + 开启智能切换 → 
  遍历所有词 →
    查询S-MARS状态 →
      已掌握 → 跳过(不计数)
      薄弱 → 切换模式学习
      学习中 → 当前模式学习
  → 学完 → 错词强化(可选)
```

#### 3.3 流程实现要点

在`_DirectStudyScreenState`中：

1. 添加`_enableSmartMode`布尔变量
2. 在`_goToNextWord()`中调用`recommendNextMode`
3. 如果返回null，跳过该词继续下一个
4. 如果返回不同模式，切换模式后学习
5. 记录跳过的词数，用于总结页展示

### 4. 学习总结页增强

展示S-MARS分数分布：

```
本次学习：20词
• 强掌握：8词 (40%)
• 已掌握：5词 (25%)
• 学习中：4词 (20%)
• 薄弱词：3词 (15%) → 已加入错词强化
• 跳过词：5词 (25%) → 智能模式跳过
```

### 5. 持久化设置

在`StudySettingsProvider`中添加：

```dart
bool _enableSmartModeSwitch = false;

bool get enableSmartModeSwitch => _enableSmartModeSwitch;

Future<void> setEnableSmartModeSwitch(bool value) async {
  _enableSmartModeSwitch = value;
  await _savePreference('enableSmartModeSwitch', value);
  notifyListeners();
}
```

## 代码修改清单

### 1. `lib/screens/pre_study_screen.dart`

**修改内容**：
- 添加`_enableSmartMode`状态变量
- 添加智能模式切换开关UI组件
- 修改`_goToNextWord()`方法，集成智能切换逻辑
- 添加跳过词计数和展示

**关键代码位置**：
- 第530行附近：`_goToNextWord()`方法
- 第240-280行：学习模式选择UI区域
- 第618行附近：`_finishStudy()`方法

### 2. `lib/services/session_mastery_engine.dart`

**修改内容**：
- 新增`recommendNextMode()`方法
- 新增`shouldSpotCheck()`方法（低频抽查）

**关键代码位置**：
- 第216行附近：`modeFromStudyMode()`方法后

### 3. `lib/services/providers/study_settings_provider.dart`

**修改内容**：
- 添加`_enableSmartModeSwitch`变量
- 添加getter和setter方法
- 在`loadPreferences()`中加载设置

### 4. `lib/utils/translations.dart`

**新增翻译键**：
```dart
String get smartModeSwitch => t('智能模式切换', 'Smart Mode Switch');
String get smartModeSwitchDesc => t(
  '开启后，系统会根据你的答题表现自动调整学习模式',
  'System will auto-adjust learning mode based on your performance'
);
String get smartModeSkipMastered => t('已掌握词自动跳过', 'Auto-skip mastered words');
String get smartModeSwitchWeak => t('薄弱词切换高效模式', 'Switch weak words to efficient mode');
String get smartModeSpotCheck => t('低频抽查已掌握词', 'Low-frequency spot check');
String get skippedWords => t('跳过词', 'Skipped');
```

### 5. `lib/screens/pre_study_screen.dart` - 总结页

**修改内容**：
- `_StudySummaryScreen`添加跳过词统计
- 展示S-MARS分数分布

## 边界情况处理

### 1. 所有词都跳过

如果开启智能切换后所有词都已掌握：
- 直接显示学习完成总结
- 提示"所有词已掌握，无需学习"

### 2. 模式切换后无词可学

确保至少学习一个词，避免空循环：
- 在`_goToNextWord()`中检查剩余词数
- 如果无词可学，调用`_finishStudy()`

### 3. 用户中途关闭开关

已切换的模式保持，后续词按原模式学习：
- 开关状态在`_DirectStudyScreen`初始化时确定
- 学习过程中不响应外部设置变化

### 4. 低频抽查概率

5%抽查概率可配置：
- 在`SessionMasteryEngine`中定义为常量
- 后续可根据用户反馈调整

## 测试计划

### 单元测试

1. `recommendNextMode()`方法测试
   - 强掌握状态返回null
   - 薄弱状态返回正确模式
   - 低频抽查逻辑测试

2. 开关状态持久化测试
   - 保存和加载设置
   - 默认值为false

### 集成测试

1. 学习流程测试
   - 开启智能切换后跳过已掌握词
   - 薄弱词切换到拼写模式
   - 总结页显示跳过词数

2. UI测试
   - 开关点击切换状态
   - 开关状态正确显示

## 后续优化方向

1. **微批次学习**：8-12词为一组，批次间休息
2. **答题耗时惩罚**：区分"秒答"和"慢答"
3. **跨天持久化**：会话分跨天保留
4. **学习总结页增强**：S-MARS分数分布可视化
5. **抽查概率自适应**：根据遗忘曲线调整抽查频率

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| 用户不理解功能 | 误关闭或误开启 | 添加清晰说明文案 |
| 跳过太多词 | 用户觉得学习量少 | 总结页展示跳过词和原因 |
| 抽查引起困惑 | 为什么已掌握的词又出现 | 提示"低频抽查" |
| 性能影响 | S-MARS计算耗时 | 状态缓存，避免重复计算 |

## 实现记录

### 实现时间
2026-05-27

### 关键实现决策

#### 1. 模式切换逻辑位置
- **初始方案**：在`_goToNextWord()`中实现智能切换
- **最终方案**：在`_prepareModeState()`中实现，因为该方法在每次准备新词时调用，更适合处理模式切换逻辑

#### 2. 有效学习模式获取
- 引入`_effectiveStudyMode` getter，统一处理智能模式开启和关闭时的模式获取
- 智能模式开启且`_currentWordMode > 0`时返回`_currentWordMode`
- 否则返回`widget.studyMode`

#### 3. 跳过词处理
- 使用递归调用`_prepareModeState()`处理跳过词后的下一个词
- 通过`WidgetsBinding.instance.addPostFrameCallback()`确保setState后正确更新UI

#### 4. 代码修改范围
- 替换了21处使用`widget.studyMode`的地方，改为使用`_effectiveStudyMode`
- 确保UI和逻辑都使用当前词的实际学习模式

### 实现问题与解决

#### 问题1：模式切换后UI不更新
- **原因**：UI使用`widget.studyMode`，不会反映模式切换
- **解决**：引入`_currentWordMode`变量存储当前词的实际模式

#### 问题2：跳过词后学习流程中断
- **原因**：直接增加`_currentIndex`后没有重新准备模式状态
- **解决**：递归调用`_prepareModeState()`处理下一个词

#### 问题3：Switch组件废弃警告
- **原因**：使用了废弃的`activeColor`属性
- **解决**：改用`activeThumbColor`属性

### 代码变更统计
- `lib/screens/pre_study_screen.dart`：新增约150行代码，修改约30行
- `lib/services/session_mastery_engine.dart`：新增约40行代码
- `lib/services/providers/study_settings_provider.dart`：新增约15行代码
- `lib/utils/translations.dart`：新增约8个翻译键

### 测试验证
- 运行`flutter analyze`：仅有一个原有测试文件的错误，与本次修改无关
- 运行`flutter test`：82个测试通过，2个原有测试失败（与本次修改无关）
- 代码无新增错误或警告

## 实现优先级

1. **P0（必须）**：开关UI、智能切换逻辑、模式推荐方法 ✅ 已完成
2. **P1（重要）**：持久化设置、多语言翻译、跳过词计数 ✅ 已完成
3. **P2（可选）**：低频抽查、总结页增强 ✅ 已完成

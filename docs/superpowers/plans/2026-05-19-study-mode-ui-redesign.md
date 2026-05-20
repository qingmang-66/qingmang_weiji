# 学习模式UI重构与字典查询功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复测验模式bug，将五种学习模式重构为iOS风格UI，添加答题反馈卡片和快捷字典查询功能。

**Architecture:** 在现有的 `pre_study_screen.dart` 中重构UI组件，添加新的底部弹出式反馈卡片组件和字典查询组件，遵循iOS设计规范（圆角、柔和阴影、系统色、弹性动画）。

**Tech Stack:** Flutter, Material Design (iOS风格定制), sqflite_common_ffi (本地词典), Provider (状态管理)

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/screens/pre_study_screen.dart` | 修改 | 主要修改文件：修复bug、重构UI、添加新组件 |
| `lib/services/local_dictionary_service.dart` | 只读引用 | 本地ECDICT词典查询服务 |
| `lib/services/dictionary_api_service.dart` | 只读引用 | 在线词典API服务 |
| `lib/services/tts_service.dart` | 只读引用 | TTS发音服务 |
| `lib/utils/constants.dart` | 只读引用 | 颜色常量等 |

---

### Task 1: 修复测验模式Bug - 中选英模式缺少英文选项

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`

**问题**：模式5（中选英）调用 `_generateCnQuizOptions` 生成中文释义选项，但应该生成英文单词选项。

- [ ] **Step 1: 修复 `_buildQuizModeCnToEn` 方法**

找到 `_buildQuizModeCnToEn` 方法（约在807行），将 `options: _quizOptions` 改为先初始化英文选项：

```dart
/// 测验模式 - 看中文选英文
Widget _buildQuizModeCnToEn(Word word, ColorScheme colorScheme) {
  // 确保生成英文单词选项
  if (_quizOptions.isEmpty || _showAnswer == false) {
    _quizOptions = _generateQuizOptions(word);
    _correctQuizOption = _quizOptions.indexOf(word.word);
    _selectedQuizOption = null;
  }
  
  return _buildQuizMode(
    word: word,
    colorScheme: colorScheme,
    questionText: word.definition.isNotEmpty ? word.definition : '暂无释义',
    questionLabel: '请选择正确的英文单词',
    options: _quizOptions,
    correctAnswer: word.word,
  );
}
```

- [ ] **Step 2: 修复 `_buildQuizModeEnToCn` 方法**

确保 `_buildQuizModeEnToCn` 方法（约在820行）正确生成中文选项：

```dart
/// 测验模式 - 看英文选中文
Widget _buildQuizModeEnToCn(Word word, ColorScheme colorScheme) {
  // 确保生成中文释义选项
  if (_quizOptions.isEmpty || _showAnswer == false) {
    final cnOptions = _generateCnQuizOptions(word);
    _quizOptions = cnOptions;
    _correctQuizOption = cnOptions.indexOf(word.definition.isNotEmpty ? word.definition : '暂无释义');
    _selectedQuizOption = null;
  }
  
  return _buildQuizMode(
    word: word,
    colorScheme: colorScheme,
    questionText: word.word,
    questionLabel: '请选择正确的中文释义',
    options: _quizOptions,
    correctAnswer: word.definition.isNotEmpty ? word.definition : '暂无释义',
    isEnToCn: true,
  );
}
```

- [ ] **Step 3: 修改 `_buildQuizMode` 方法，移除重复初始化逻辑**

在 `_buildQuizMode` 方法中，移除开头的选项初始化逻辑（因为现在由各模式方法自行初始化）：

```dart
/// 通用测验模式UI
Widget _buildQuizMode({
  required Word word,
  required ColorScheme colorScheme,
  required String questionText,
  required String questionLabel,
  required List<String> options,
  required String correctAnswer,
  bool isEnToCn = false,
}) {
  // 选项已在调用方初始化，这里直接使用
  return Column(
    children: [
      // ... 保持原有UI代码不变
    ],
  );
}
```

- [ ] **Step 4: 运行应用验证**

```bash
flutter run -d windows
```

测试两种测验模式：
- 模式4（英选中）：显示英文单词，选项为中文释义
- 模式5（中选英）：显示中文释义，选项为英文单词

---

### Task 2: 添加iOS风格常量定义

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`（在文件顶部添加常量）

- [ ] **Step 1: 添加iOS风格颜色常量**

在 `pre_study_screen.dart` 文件顶部（import语句之后，类定义之前）添加：

```dart
/// iOS 风格颜色常量
class _IOSColors {
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray5 = Color(0xFFF2F2F7);
  static const Color systemGray6 = Color(0xFFF8F8FA);
}

/// iOS 风格阴影
BoxShadow _iosShadow = BoxShadow(
  color: Colors.black.withValues(alpha: 0.08),
  blurRadius: 12,
  offset: const Offset(0, 4),
);
```

---

### Task 3: 重构回忆模式为iOS风格

**Files:**
- Modify: `lib/screens/pre_study_screen.dart` - `_buildRecallMode` 方法

- [ ] **Step 1: 重构 `_buildRecallMode` 方法**

替换现有的 `_buildRecallMode` 方法（约在517行）：

```dart
/// 回忆模式 - iOS风格
Widget _buildRecallMode(Word word, ColorScheme colorScheme) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 单词卡片
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _IOSColors.systemGray6,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [_iosShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.word,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: Colors.black87,
                        ),
                      ),
                      if (word.phonetic.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          word.phonetic,
                          style: const TextStyle(
                            fontSize: 18,
                            color: _IOSColors.systemBlue,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StudyAudioButton(word: word.word),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // 显示释义按钮
      if (!_showAnswer) ...[
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _showAnswer = true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _IOSColors.systemBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, size: 20),
                SizedBox(width: 8),
                Text(
                  '显示释义',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],

      // 释义区域 - 使用动画展开
      if (_showAnswer) ...[
        const SizedBox(height: 8),
        _DefinitionSection(word: word, colorScheme: colorScheme),
      ],
    ],
  );
}
```

---

### Task 4: 重构拼写模式为iOS风格

**Files:**
- Modify: `lib/screens/pre_study_screen.dart` - `_buildSpellMode` 方法

- [ ] **Step 1: 重构 `_buildSpellMode` 方法**

替换现有的 `_buildSpellMode` 方法：

```dart
/// 拼写模式 - iOS风格
Widget _buildSpellMode(Word word, ColorScheme colorScheme) {
  return Column(
    children: [
      // 中文提示卡片
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _IOSColors.systemGray6,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [_iosShadow],
        ),
        child: Column(
          children: [
            const Text(
              '请拼写以下单词',
              style: TextStyle(
                fontSize: 15,
                color: _IOSColors.systemGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              word.definition.isNotEmpty ? word.definition : '请拼写单词',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),

      // 输入框
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _spellController.text.isNotEmpty
                ? _IOSColors.systemBlue
                : _IOSColors.systemGray2,
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _spellController,
          enabled: !_showAnswer,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
          decoration: InputDecoration(
            hintText: '输入英文单词...',
            hintStyle: const TextStyle(
              color: _IOSColors.systemGray2,
              fontSize: 17,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            suffixIcon: _spellController.text.isNotEmpty && !_showAnswer
                ? IconButton(
                    icon: const Icon(Icons.clear, color: _IOSColors.systemGray),
                    onPressed: () => setState(() => _spellController.clear()),
                  )
                : null,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _checkSpell(word),
        ),
      ),
      const SizedBox(height: 24),

      // 提交按钮
      if (!_showAnswer) ...[
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _spellController.text.trim().isNotEmpty
                ? () => _checkSpell(word)
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _IOSColors.systemBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '提交',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
```

---

### Task 5: 重构听力模式为iOS风格

**Files:**
- Modify: `lib/screens/pre_study_screen.dart` - `_buildListenMode` 方法

- [ ] **Step 1: 重构 `_buildListenMode` 方法**

替换现有的 `_buildListenMode` 方法：

```dart
/// 听力模式 - iOS风格
Widget _buildListenMode(Word word, ColorScheme colorScheme) {
  return Column(
    children: [
      // 播放按钮区域
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: _IOSColors.systemGray6,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [_iosShadow],
        ),
        child: Column(
          children: [
            const Text(
              '听发音，猜单词',
              style: TextStyle(
                fontSize: 15,
                color: _IOSColors.systemGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            // 大圆形播放按钮
            GestureDetector(
              onTap: _isPlaying ? null : () => _playAudio(word.word),
              child: AnimatedScale(
                scale: _isPlaying ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _IOSColors.systemBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _IOSColors.systemBlue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isPlaying
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.play_arrow,
                            size: 56,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isPlaying ? '正在播放...' : '点击播放发音',
              style: const TextStyle(
                fontSize: 15,
                color: _IOSColors.systemGray,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),

      // 显示答案按钮
      if (!_showAnswer) ...[
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _showAnswer = true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _IOSColors.systemBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, size: 20),
                SizedBox(width: 8),
                Text(
                  '显示答案',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}
```

---

### Task 6: 重构测验模式为iOS风格

**Files:**
- Modify: `lib/screens/pre_study_screen.dart` - `_buildQuizMode` 方法

- [ ] **Step 1: 重构 `_buildQuizMode` 方法**

替换现有的 `_buildQuizMode` 方法：

```dart
/// 通用测验模式UI - iOS风格
Widget _buildQuizMode({
  required Word word,
  required ColorScheme colorScheme,
  required String questionText,
  required String questionLabel,
  required List<String> options,
  required String correctAnswer,
  bool isEnToCn = false,
}) {
  // 选项字母标签
  const optionLabels = ['A', 'B', 'C', 'D'];

  return Column(
    children: [
      // 题目卡片
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _IOSColors.systemBlue,
              _IOSColors.systemBlue.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _IOSColors.systemBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              questionLabel,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              questionText,
              style: TextStyle(
                fontSize: isEnToCn ? 32 : 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: isEnToCn ? -0.5 : 0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // 选项列表
      ...List.generate(_quizOptions.length, (index) {
        final option = _quizOptions[index];
        final isSelected = _selectedQuizOption == index;
        final isCorrect = index == _correctQuizOption;

        // 计算选项样式
        Color backgroundColor = Colors.white;
        Color borderColor = _IOSColors.systemGray5;
        Color labelColor = _IOSColors.systemGray;
        Color textColor = Colors.black87;
        IconData? trailingIcon;
        Color? trailingIconColor;

        if (_showAnswer) {
          if (isCorrect) {
            backgroundColor = _IOSColors.systemGreen.withValues(alpha: 0.1);
            borderColor = _IOSColors.systemGreen;
            labelColor = _IOSColors.systemGreen;
            textColor = _IOSColors.systemGreen;
            trailingIcon = Icons.check_circle;
            trailingIconColor = _IOSColors.systemGreen;
          } else if (isSelected && !isCorrect) {
            backgroundColor = _IOSColors.systemRed.withValues(alpha: 0.1);
            borderColor = _IOSColors.systemRed;
            labelColor = _IOSColors.systemRed;
            textColor = _IOSColors.systemRed;
            trailingIcon = Icons.cancel;
            trailingIconColor = _IOSColors.systemRed;
          } else {
            backgroundColor = _IOSColors.systemGray5;
            textColor = _IOSColors.systemGray;
          }
        } else if (isSelected) {
          backgroundColor = _IOSColors.systemBlue.withValues(alpha: 0.1);
          borderColor = _IOSColors.systemBlue;
          labelColor = _IOSColors.systemBlue;
          textColor = _IOSColors.systemBlue;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAnswer ? null : () => _checkQuizAnswer(index),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || (_showAnswer && (isCorrect || (isSelected && !isCorrect))) ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 选项字母标签
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: labelColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          optionLabels[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 选项文本
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: isSelected || (_showAnswer && isCorrect)
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: textColor,
                        ),
                      ),
                    ),
                    // 右侧状态图标
                    if (trailingIcon != null)
                      Icon(
                        trailingIcon,
                        color: trailingIconColor,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ],
  );
}
```

---

### Task 7: 添加答题反馈卡片组件

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- 在文件末尾添加 `_AnswerFeedbackSheet` 组件类

- [ ] **Step 1: 添加 `_AnswerFeedbackSheet` 组件**

在文件末尾（`_StudyModeChip` 类之后）添加：

```dart
/// 答题反馈卡片 - iOS风格底部弹出式
class _AnswerFeedbackSheet extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String? userAnswer;
  final Word word;
  final VoidCallback onNext;
  final VoidCallback onExit;

  const _AnswerFeedbackSheet({
    required this.isCorrect,
    required this.correctAnswer,
    this.userAnswer,
    required this.word,
    required this.onNext,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: isCorrect ? _IOSColors.systemGreen : _IOSColors.systemRed,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isCorrect ? '回答正确！' : '回答错误',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 正确答案
                Row(
                  children: [
                    const Text(
                      '正确答案：',
                      style: TextStyle(
                        fontSize: 15,
                        color: _IOSColors.systemGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        correctAnswer,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // 用户答案（错误时显示）
                if (!isCorrect && userAnswer != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        '你的答案：',
                        style: TextStyle(
                          fontSize: 15,
                          color: _IOSColors.systemGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          userAnswer!,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _IOSColors.systemRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // 单词详情
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            word.word,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (word.phonetic.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              word.phonetic,
                              style: const TextStyle(
                                fontSize: 16,
                                color: _IOSColors.systemBlue,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            word.definition,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 发音按钮
                    _StudyAudioButton(word: word.word),
                  ],
                ),

                const SizedBox(height: 24),

                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onExit,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: _IOSColors.systemGray2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '退出学习',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _IOSColors.systemGray,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: onNext,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: _IOSColors.systemBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '下一题',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 修改 `_onQuizNext` 方法，调用反馈卡片**

找到 `_onQuizNext` 方法，修改为：

```dart
/// 测验模式：显示反馈卡片
void _showQuizFeedback() {
  final word = _words[_currentIndex];
  final isCorrect = _selectedQuizOption == _correctQuizOption;
  final userAnswer = _selectedQuizOption != null ? _quizOptions[_selectedQuizOption!] : null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AnswerFeedbackSheet(
      isCorrect: isCorrect,
      correctAnswer: isCorrect
          ? (widget.studyMode == 4 ? word.definition : word.word)
          : (widget.studyMode == 4 ? word.definition : word.word),
      userAnswer: userAnswer,
      word: word,
      onNext: () {
        Navigator.pop(ctx);
        _onQuizNext();
      },
      onExit: () {
        Navigator.pop(ctx);
        Navigator.pop(context);
      },
    ),
  );
}
```

- [ ] **Step 3: 修改 `_checkQuizAnswer` 方法，自动弹出反馈卡片**

```dart
/// 检查测验答案
void _checkQuizAnswer(int selectedIndex) {
  setState(() {
    _showAnswer = true;
    _selectedQuizOption = selectedIndex;
  });
  
  // 延迟弹出反馈卡片，等待UI更新
  Future.delayed(const Duration(milliseconds: 300), () {
    if (mounted) {
      _showQuizFeedback();
    }
  });
}
```

---

### Task 8: 为拼写模式和听力模式添加反馈卡片

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`

- [ ] **Step 1: 修改 `_checkSpell` 方法**

```dart
void _checkSpell(Word word) {
  final input = _spellController.text.trim().toLowerCase();
  final correct = word.word.toLowerCase();
  final isCorrect = input == correct;
  
  setState(() {
    _showAnswer = true;
    _spellCorrect = isCorrect;
  });
  
  // 弹出反馈卡片
  Future.delayed(const Duration(milliseconds: 300), () {
    if (mounted) {
      _showSpellFeedback(word, input);
    }
  });
}

/// 拼写模式反馈卡片
void _showSpellFeedback(Word word, String userAnswer) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AnswerFeedbackSheet(
      isCorrect: _spellCorrect,
      correctAnswer: word.word,
      userAnswer: userAnswer,
      word: word,
      onNext: () {
        Navigator.pop(ctx);
        _onSpellNext();
      },
      onExit: () {
        Navigator.pop(ctx);
        Navigator.pop(context);
      },
    ),
  );
}
```

- [ ] **Step 2: 修改听力模式的反馈**

在听力模式显示答案后，添加类似的反馈卡片逻辑。找到听力模式中显示答案后的处理代码，添加：

```dart
/// 听力模式反馈卡片
void _showListenFeedback(Word word) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AnswerFeedbackSheet(
      isCorrect: true, // 听力模式查看答案后统一视为需要复习
      correctAnswer: word.word,
      word: word,
      onNext: () {
        Navigator.pop(ctx);
        _onQualitySelected(1); // 标记为需要复习
      },
      onExit: () {
        Navigator.pop(ctx);
        Navigator.pop(context);
      },
    ),
  );
}
```

---

### Task 9: 添加快捷字典查询功能

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- 添加 `_DictionarySearchSheet` 组件
- 修改 AppBar 添加搜索按钮

- [ ] **Step 1: 添加字典查询状态**

在 `_DirectStudyScreenState` 类中添加：

```dart
// 字典查询相关
final TextEditingController _searchController = TextEditingController();
List<Map<String, dynamic>> _searchResults = [];
bool _isSearching = false;
Map<String, dynamic>? _selectedWordDetail;
```

在 `dispose` 方法中添加：

```dart
@override
void dispose() {
  _spellController.dispose();
  _searchController.dispose();
  super.dispose();
}
```

- [ ] **Step 2: 修改 AppBar 添加搜索按钮**

找到 `_DirectStudyScreen` 的 `build` 方法中的 AppBar，修改为：

```dart
appBar: AppBar(
  title: Text(widget.isReview ? '复习单词' : '学习新词'),
  actions: [
    // 字典查询按钮
    IconButton(
      icon: const Icon(Icons.search),
      tooltip: '查询字典',
      onPressed: _showDictionarySearch,
    ),
    if (_words.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: Text(
            '${_currentIndex + 1} / ${_words.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
  ],
),
```

- [ ] **Step 3: 添加字典查询方法**

```dart
/// 显示字典查询弹窗
void _showDictionarySearch() {
  _searchController.clear();
  _searchResults = [];
  _selectedWordDetail = null;
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => _buildDictionarySheet(setModalState),
    ),
  );
}

/// 构建字典查询界面
Widget _buildDictionarySheet(StateSetter setModalState) {
  return Container(
    height: MediaQuery.of(context).size.height * 0.7,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Column(
      children: [
        // 搜索栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: _IOSColors.systemGray),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '输入单词查询...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: _IOSColors.systemGray2,
                      fontSize: 17,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                  onChanged: (value) {
                    if (value.length >= 2) {
                      _performSearch(value, setModalState);
                    }
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: _IOSColors.systemGray),
                  onPressed: () {
                    _searchController.clear();
                    setModalState(() {
                      _searchResults = [];
                      _selectedWordDetail = null;
                    });
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // 搜索结果或详情
        Expanded(
          child: _selectedWordDetail != null
              ? _buildWordDetail(_selectedWordDetail!)
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 64,
                            color: _IOSColors.systemGray2,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '输入单词开始查询',
                            style: TextStyle(
                              fontSize: 17,
                              color: _IOSColors.systemGray,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(
                            result['word'] ?? '',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            result['translation'] ?? result['definition'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _IOSColors.systemGray,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: _IOSColors.systemGray2),
                          onTap: () async {
                            setModalState(() => _isSearching = true);
                            final detail = await LocalDictionaryService.lookup(result['word']);
                            setModalState(() {
                              _selectedWordDetail = detail;
                              _isSearching = false;
                            });
                          },
                        );
                      },
                    ),
        ),
      ],
    ),
  );
}

/// 防抖定时器
Timer? _searchDebounce;

/// 执行搜索
void _performSearch(String query, StateSetter setModalState) {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
    setModalState(() => _isSearching = true);
    
    final results = await LocalDictionaryService.search(query, limit: 20);
    
    setModalState(() {
      _searchResults = results;
      _isSearching = false;
    });
  });
}

/// 构建单词详情
Widget _buildWordDetail(Map<String, dynamic> detail) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 单词和音标
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail['word'] ?? '',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (detail['phonetic'] != null && detail['phonetic'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail['phonetic'],
                      style: const TextStyle(
                        fontSize: 16,
                        color: _IOSColors.systemBlue,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 发音按钮
            IconButton.filled(
              onPressed: () => TtsService().playWord(detail['word']),
              icon: const Icon(Icons.volume_up, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: _IOSColors.systemBlue.withValues(alpha: 0.1),
                foregroundColor: _IOSColors.systemBlue,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),
        
        // 释义
        if (detail['translation'] != null) ...[
          const Text(
            '释义',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _IOSColors.systemGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail['translation'],
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Collins 星级
        if (detail['collins'] != null) ...[
          Row(
            children: [
              const Text(
                'Collins: ',
                style: TextStyle(
                  fontSize: 14,
                  color: _IOSColors.systemGray,
                ),
              ),
              ...List.generate(5, (index) {
                return Icon(
                  index < (detail['collins'] as int) ? Icons.star : Icons.star_border,
                  size: 18,
                  color: _IOSColors.systemOrange,
                );
              }),
            ],
          ),
        ],
      ],
    ),
  );
}
```

---

### Task 10: 重构底部控制区为iOS风格

**Files:**
- Modify: `lib/screens/pre_study_screen.dart` - `_buildBottomControls` 方法

- [ ] **Step 1: 重构 `_buildBottomControls` 方法**

替换现有的 `_buildBottomControls` 方法：

```dart
/// 底部操作区 - iOS风格
Widget _buildBottomControls(ColorScheme colorScheme) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(
        top: BorderSide(
          color: _IOSColors.systemGray5,
          width: 0.5,
        ),
      ),
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 上一题/下一题按钮（非测验模式）
          if (!_showAnswer || (widget.studyMode != 4 && widget.studyMode != 5)) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex > 0
                        ? () {
                            setState(() {
                              _currentIndex--;
                              _showAnswer = false;
                              _spellController.clear();
                              _quizOptions = [];
                              _selectedQuizOption = null;
                              _correctQuizOption = null;
                            });
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: _IOSColors.systemGray2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, size: 18),
                        SizedBox(width: 4),
                        Text(
                          '上一题',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex < _words.length - 1
                        ? () {
                            setState(() {
                              _currentIndex++;
                              _showAnswer = false;
                              _spellController.clear();
                              _quizOptions = [];
                              _selectedQuizOption = null;
                              _correctQuizOption = null;
                            });
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: _IOSColors.systemGray2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '下一题',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // 回忆模式评分条
          if (_showAnswer && widget.studyMode == 1) ...[
            const SizedBox(height: 16),
            _QualityRatingBar(onSelected: _onQualitySelected),
          ],

          // 拼写模式下一个按钮
          if (_showAnswer && widget.studyMode == 2) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _onSpellNext(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: _IOSColors.systemBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '下一题',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 听力模式进入下一个按钮
          if (_showAnswer && widget.studyMode == 3) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _onQualitySelected(1),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: _IOSColors.systemRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '进入下一个',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

---

### Task 11: 重构评分条为iOS风格

**Files:**
- Modify: `lib/screens/pre_study_screen.dart` - `_QualityRatingBar` 和 `_RatingChip` 组件

- [ ] **Step 1: 重构 `_QualityRatingBar` 为iOS分段控制器样式**

```dart
/// 回忆质量评分条 - iOS风格分段控制器
class _QualityRatingBar extends StatelessWidget {
  final void Function(int quality) onSelected;

  const _QualityRatingBar({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '回忆质量如何？',
          style: TextStyle(
            fontSize: 15,
            color: _IOSColors.systemGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _RatingChip(
              label: '忘记',
              color: _IOSColors.systemRed,
              onTap: () => onSelected(1),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '困难',
              color: _IOSColors.systemOrange,
              onTap: () => onSelected(2),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '模糊',
              color: _IOSColors.systemPurple,
              onTap: () => onSelected(3),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '容易',
              color: _IOSColors.systemGreen,
              onTap: () => onSelected(4),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '简单',
              color: _IOSColors.systemBlue,
              onTap: () => onSelected(5),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RatingChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### Task 12: 运行测试与验证

**Files:**
- 无

- [ ] **Step 1: 运行应用**

```bash
flutter run -d windows
```

- [ ] **Step 2: 测试清单**

逐项测试以下功能：

1. **回忆模式**：
   - 单词卡片显示正常，iOS风格
   - 点击"显示释义"后释义区域展开
   - 评分条正常显示，点击有效

2. **拼写模式**：
   - 中文提示卡片显示正常
   - 输入框可以正常输入
   - 提交后弹出反馈卡片
   - 反馈卡片显示正确答案和用户答案对比

3. **听力模式**：
   - 播放按钮有脉冲动画
   - 点击播放发音正常
   - 显示答案后弹出反馈卡片

4. **测验模式(英选中)**：
   - 显示英文单词，选项为中文释义
   - 选择答案后弹出反馈卡片
   - 正确/错误状态显示正确

5. **测验模式(中选英)**：
   - 显示中文释义，选项为英文单词
   - 选择答案后弹出反馈卡片
   - 正确/错误状态显示正确

6. **字典查询**：
   - AppBar搜索按钮可见
   - 点击弹出底部搜索框
   - 输入单词后显示搜索结果
   - 点击结果显示单词详情
   - 发音按钮正常

- [ ] **Step 3: 修复发现的问题**

根据测试结果修复任何UI或功能问题。

---

## 自审检查

1. **规范覆盖**：所有设计文档中的需求都有对应任务实现
   - 测验模式bug修复 ✓ (Task 1)
   - iOS风格UI ✓ (Task 2-11)
   - 答题反馈卡片 ✓ (Task 7-8)
   - 字典查询功能 ✓ (Task 9)

2. **占位符扫描**：无TBD/TODO，所有代码步骤都包含完整实现代码

3. **类型一致性**：所有方法签名、参数类型在各任务中保持一致

4. **iOS风格一致性**：
   - 颜色使用 `_IOSColors` 常量
   - 圆角统一使用 12px/20px
   - 动画使用 `Curves.easeOutCubic`
   - 字体使用 `FontWeight.w600` 标题，`FontWeight.w400` 正文

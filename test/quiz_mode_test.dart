import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/models.dart';

/// 测验模式单元测试 - 验证干扰项生成和评分逻辑
/// 测试 _generateQuizOptions 和 _onQuizNext 的核心逻辑

void main() {
  group('测验模式测试', () {
    // 模拟单词列表
    final words = [
      Word(id: 1, word: 'apple', definition: '苹果', wordBookId: 1),
      Word(id: 2, word: 'banana', definition: '香蕉', wordBookId: 1),
      Word(id: 3, word: 'cherry', definition: '樱桃', wordBookId: 1),
      Word(id: 4, word: 'date', definition: '日期', wordBookId: 1),
      Word(id: 5, word: 'elderberry', definition: '接骨木果', wordBookId: 1),
      Word(id: 6, word: 'fig', definition: '无花果', wordBookId: 1),
      Word(id: 7, word: 'grape', definition: '葡萄', wordBookId: 1),
      Word(id: 8, word: 'honeydew', definition: '哈密瓜', wordBookId: 1),
    ];

    group('干扰项生成测试', () {
      test('应该生成4个选项', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);

        expect(options.length, equals(4));
      });

      test('必须包含正确答案', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);

        expect(options.contains(correctWord.word), isTrue);
      });

      test('选项不能重复', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);
        final uniqueOptions = options.toSet();

        expect(uniqueOptions.length, equals(4));
      });

      test('干扰项应该从其他单词中选取', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);

        // 除了正确答案，其他3个应该都是来自单词列表
        final otherWords = words
            .where((w) => w.id != correctWord.id)
            .map((w) => w.word)
            .toList();
        final distractors = options
            .where((o) => o != correctWord.word)
            .toList();

        for (final distractor in distractors) {
          expect(
            otherWords.contains(distractor),
            isTrue,
            reason: '干扰项 $distractor 应该来自单词列表',
          );
        }
      });

      test('单词不足4个时应该用占位符填充', () {
        final shortList = [
          Word(id: 1, word: 'apple', definition: '苹果', wordBookId: 1),
          Word(id: 2, word: 'banana', definition: '香蕉', wordBookId: 1),
        ];
        final correctWord = shortList[0];
        final options = generateQuizOptions(correctWord, shortList);

        expect(options.length, equals(4));
        // 应该有占位符
        final hasPlaceholder = options.any((o) => o.startsWith('option_'));
        expect(hasPlaceholder, isTrue);
      });
    });

    group('评分逻辑测试', () {
      test('回答正确应该评分4（容易）', () {
        final selectedOption = 1;
        final correctOption = 1;
        final quality = calculateQuizQuality(selectedOption, correctOption);

        expect(quality, equals(4));
      });

      test('回答错误应该评分2（困难）', () {
        final selectedOption = 2;
        final correctOption = 1;
        final quality = calculateQuizQuality(selectedOption, correctOption);

        expect(quality, equals(2));
      });

      test('不同选项索引的评分', () {
        // 各种组合测试
        expect(calculateQuizQuality(0, 0), equals(4));
        expect(calculateQuizQuality(1, 1), equals(4));
        expect(calculateQuizQuality(2, 2), equals(4));
        expect(calculateQuizQuality(3, 3), equals(4));
        expect(calculateQuizQuality(0, 1), equals(2));
        expect(calculateQuizQuality(1, 0), equals(2));
        expect(calculateQuizQuality(2, 3), equals(2));
        expect(calculateQuizQuality(3, 0), equals(2));
      });
    });

    group('正确答案索引测试', () {
      test('正确答案索引应该在0-3范围内', () {
        final correctWord = words[3];
        final options = generateQuizOptions(correctWord, words);
        final correctIndex = options.indexOf(correctWord.word);

        expect(correctIndex, greaterThanOrEqualTo(0));
        expect(correctIndex, lessThanOrEqualTo(3));
      });

      test('多次生成应该随机分布正确答案位置', () {
        final correctWord = words[0];
        final positions = <int>[];

        // 生成100次，统计正确答案位置分布
        for (var i = 0; i < 100; i++) {
          final options = generateQuizOptions(correctWord, words);
          positions.add(options.indexOf(correctWord.word));
        }

        // 每个位置都应该至少出现几次（随机性测试）
        for (var pos = 0; pos < 4; pos++) {
          final count = positions.where((p) => p == pos).length;
          expect(count, greaterThan(0), reason: '位置 $pos 应该至少出现一次');
        }
      });
    });

    group('快捷键逻辑测试', () {
      test('回忆模式响应 Enter 显示释义，但不直接下一题', () {
        final state = RecallKeyboardFlowState(isAnswerVisible: false);

        final nextState = handleRecallShortcut(state, shortcut: 'enter');

        expect(shouldHandleEnterShortcut(studyMode: 1), isTrue);
        expect(nextState.isAnswerVisible, isTrue);
        expect(nextState.shouldGoNext, isFalse);
      });

      test('回忆模式 Space 会触发发音', () {
        final state = RecallKeyboardFlowState(isAnswerVisible: false);

        final nextState = handleRecallShortcut(state, shortcut: 'space');

        expect(nextState.shouldPlayAudio, isTrue);
      });

      test('非输入模式进入题目后应主动聚焦快捷键监听', () {
        expect(
          shouldRequestShortcutFocusOnPrepare(studyMode: 1, isMounted: true),
          isTrue,
        );
        expect(
          shouldRequestShortcutFocusOnPrepare(studyMode: 4, isMounted: true),
          isTrue,
        );
        expect(
          shouldRequestShortcutFocusOnPrepare(studyMode: 5, isMounted: true),
          isTrue,
        );
      });

      test('输入模式进入题目后不抢输入框焦点', () {
        expect(
          shouldRequestShortcutFocusOnPrepare(studyMode: 2, isMounted: true),
          isFalse,
        );
        expect(
          shouldRequestShortcutFocusOnPrepare(studyMode: 3, isMounted: true),
          isFalse,
        );
      });

      test('拼写、听力和测验模式响应 Enter 下一题快捷键', () {
        expect(shouldHandleEnterShortcut(studyMode: 2), isTrue);
        expect(shouldHandleEnterShortcut(studyMode: 3), isTrue);
        expect(shouldHandleEnterShortcut(studyMode: 4), isTrue);
        expect(shouldHandleEnterShortcut(studyMode: 5), isTrue);
      });

      test('拼写错误后 Enter 应继续允许输入，不显示答案也不进入下一题', () {
        final state = TypedAnswerFlowState(
          answer: 'applf',
          correctAnswer: 'apple',
        );

        final nextState = handleTypedEnter(state);

        expect(nextState.canKeepTyping, isTrue);
        expect(nextState.isAnswerRevealed, isFalse);
        expect(nextState.shouldGoNext, isFalse);
      });

      test('拼写正确后 Enter 可以进入下一题', () {
        final state = TypedAnswerFlowState(
          answer: 'apple',
          correctAnswer: 'apple',
          isCorrect: true,
        );

        final nextState = handleTypedEnter(state);

        expect(nextState.shouldGoNext, isTrue);
      });

      test('拼写错误后修改答案再按 Enter 会再次检查', () {
        final state = TypedAnswerFlowState(
          answer: 'apple',
          correctAnswer: 'apple',
          hasChecked: true,
          isCorrect: false,
        );

        final nextState = handleTypedEnter(state);

        expect(nextState.isCorrect, isTrue);
        expect(nextState.canKeepTyping, isFalse);
        expect(nextState.shouldGoNext, isFalse);
      });

      test('用户明确查看答案后 Enter 可以进入下一题', () {
        final state = TypedAnswerFlowState(
          answer: 'applf',
          correctAnswer: 'apple',
          isAnswerRevealed: true,
        );

        final nextState = handleTypedEnter(state);

        expect(nextState.shouldGoNext, isTrue);
      });

      test('答对后输入框失焦时 Enter 也可以进入下一题', () {
        final state = TypedAnswerFlowState(
          answer: 'ability',
          correctAnswer: 'ability',
          hasChecked: true,
          isCorrect: true,
          isTextFieldFocused: false,
        );

        final nextState = handleTypedEnter(state);

        expect(nextState.shouldGoNext, isTrue);
      });

      test('错误后 Enter 不下一题，Ctrl+Enter 可以主动查看答案', () {
        final state = TypedAnswerFlowState(
          answer: 'applf',
          correctAnswer: 'apple',
          hasChecked: true,
        );

        final enterState = handleTypedEnter(state);
        final revealState = handleTypedShortcut(state, shortcut: 'ctrlEnter');

        expect(enterState.shouldGoNext, isFalse);
        expect(enterState.isAnswerRevealed, isFalse);
        expect(revealState.isAnswerRevealed, isTrue);
        expect(revealState.shouldGoNext, isFalse);
      });

      test('输入模式首次 Ctrl+Enter 直接查看答案，不先提交检查', () {
        final state = TypedAnswerFlowState(
          answer: '',
          correctAnswer: 'apple',
          hasChecked: false,
        );

        final revealState = handleTypedShortcut(state, shortcut: 'ctrlEnter');

        expect(revealState.hasChecked, isTrue);
        expect(revealState.isCorrect, isFalse);
        expect(revealState.isAnswerRevealed, isTrue);
        expect(revealState.shouldGoNext, isFalse);
      });

      test('测验模式数字键选择答案后 Enter 进入下一题', () {
        final quizState = QuizKeyboardFlowState(optionCount: 4);

        final answeredState = handleQuizShortcut(quizState, shortcut: '2');
        final nextState = handleQuizShortcut(answeredState, shortcut: 'enter');

        expect(answeredState.selectedIndex, equals(1));
        expect(answeredState.hasAnswered, isTrue);
        expect(nextState.shouldGoNext, isTrue);
      });

      test('输入模式不使用 AnimatedSwitcher 避免下一题时复用输入框焦点', () {
        expect(shouldUseAnimatedModeSwitcher(isTypedMode: true), isFalse);
        expect(shouldUseAnimatedModeSwitcher(isTypedMode: false), isTrue);
      });

      test('页面快捷键 Focus 不应自动抢占输入框焦点', () {
        expect(shouldShortcutFocusAutofocus(), isFalse);
      });

      test('组件销毁后不再请求快捷键焦点', () {
        final focusAction = resolveShortcutFocusAction(
          isMounted: false,
          canRequestFocus: true,
        );

        expect(focusAction.shouldUnfocusAnswer, isFalse);
        expect(focusAction.shouldRequestShortcutFocus, isFalse);
      });

      test('组件存活且焦点可请求时才切换到快捷键焦点', () {
        final focusAction = resolveShortcutFocusAction(
          isMounted: true,
          canRequestFocus: true,
        );

        expect(focusAction.shouldUnfocusAnswer, isTrue);
        expect(focusAction.shouldRequestShortcutFocus, isTrue);
      });

      test('组件销毁后 Esc 不再触发返回导航', () {
        expect(shouldPopOnEscape(isMounted: false), isFalse);
        expect(shouldPopOnEscape(isMounted: true), isTrue);
      });
    });
  });
}

/// 模拟 _DirectStudyScreen 的 Enter 快捷键启用逻辑
bool shouldHandleEnterShortcut({required int studyMode}) =>
    studyMode >= 1 && studyMode <= 5;

bool shouldRequestShortcutFocusOnPrepare({
  required int studyMode,
  required bool isMounted,
}) {
  return isMounted && studyMode != 2 && studyMode != 3;
}

bool shouldUseAnimatedModeSwitcher({required bool isTypedMode}) => !isTypedMode;

bool shouldShortcutFocusAutofocus() => false;

bool shouldPopOnEscape({required bool isMounted}) => isMounted;

class ShortcutFocusAction {
  final bool shouldUnfocusAnswer;
  final bool shouldRequestShortcutFocus;

  const ShortcutFocusAction({
    required this.shouldUnfocusAnswer,
    required this.shouldRequestShortcutFocus,
  });
}

ShortcutFocusAction resolveShortcutFocusAction({
  required bool isMounted,
  required bool canRequestFocus,
}) {
  if (!isMounted) {
    return const ShortcutFocusAction(
      shouldUnfocusAnswer: false,
      shouldRequestShortcutFocus: false,
    );
  }
  return ShortcutFocusAction(
    shouldUnfocusAnswer: true,
    shouldRequestShortcutFocus: canRequestFocus,
  );
}

class RecallKeyboardFlowState {
  final bool isAnswerVisible;
  final bool shouldGoNext;
  final bool shouldPlayAudio;

  const RecallKeyboardFlowState({
    required this.isAnswerVisible,
    this.shouldGoNext = false,
    this.shouldPlayAudio = false,
  });
}

RecallKeyboardFlowState handleRecallShortcut(
  RecallKeyboardFlowState state, {
  required String shortcut,
}) {
  if (shortcut == 'enter' && !state.isAnswerVisible) {
    return const RecallKeyboardFlowState(isAnswerVisible: true);
  }
  if (shortcut == 'space') {
    return RecallKeyboardFlowState(
      isAnswerVisible: state.isAnswerVisible,
      shouldPlayAudio: true,
    );
  }
  return state;
}

class TypedAnswerFlowState {
  final String answer;
  final String correctAnswer;
  final bool hasChecked;
  final bool isCorrect;
  final bool isAnswerRevealed;
  final bool canKeepTyping;
  final bool shouldGoNext;
  final bool isTextFieldFocused;

  const TypedAnswerFlowState({
    required this.answer,
    required this.correctAnswer,
    this.hasChecked = false,
    this.isCorrect = false,
    this.isAnswerRevealed = false,
    this.canKeepTyping = true,
    this.shouldGoNext = false,
    this.isTextFieldFocused = true,
  });
}

TypedAnswerFlowState handleTypedEnter(TypedAnswerFlowState state) {
  if (state.isCorrect || state.isAnswerRevealed) {
    return TypedAnswerFlowState(
      answer: state.answer,
      correctAnswer: state.correctAnswer,
      hasChecked: true,
      isCorrect: state.isCorrect,
      isAnswerRevealed: state.isAnswerRevealed,
      canKeepTyping: false,
      shouldGoNext: true,
    );
  }

  final isCorrect = state.answer.trim().toLowerCase() == state.correctAnswer;
  return TypedAnswerFlowState(
    answer: state.answer,
    correctAnswer: state.correctAnswer,
    hasChecked: true,
    isCorrect: isCorrect,
    isAnswerRevealed: false,
    canKeepTyping: !isCorrect,
    shouldGoNext: false,
  );
}

TypedAnswerFlowState handleTypedShortcut(
  TypedAnswerFlowState state, {
  required String shortcut,
}) {
  if (shortcut != 'ctrlEnter') return handleTypedEnter(state);
  return TypedAnswerFlowState(
    answer: state.answer,
    correctAnswer: state.correctAnswer,
    hasChecked: true,
    isCorrect: false,
    isAnswerRevealed: true,
    canKeepTyping: false,
  );
}

class QuizKeyboardFlowState {
  final int optionCount;
  final int? selectedIndex;
  final bool shouldGoNext;

  const QuizKeyboardFlowState({
    required this.optionCount,
    this.selectedIndex,
    this.shouldGoNext = false,
  });

  bool get hasAnswered => selectedIndex != null;
}

QuizKeyboardFlowState handleQuizShortcut(
  QuizKeyboardFlowState state, {
  required String shortcut,
}) {
  if (shortcut == 'enter' && state.hasAnswered) {
    return QuizKeyboardFlowState(
      optionCount: state.optionCount,
      selectedIndex: state.selectedIndex,
      shouldGoNext: true,
    );
  }

  final number = int.tryParse(shortcut);
  if (number != null && number >= 1 && number <= state.optionCount) {
    return QuizKeyboardFlowState(
      optionCount: state.optionCount,
      selectedIndex: number - 1,
    );
  }

  return state;
}

List<String> generateQuizOptions(Word correctWord, List<Word> allWords) {
  final options = <String>[correctWord.word];

  // 从当前词库中随机选择3个干扰项
  final otherWords = allWords.where((w) => w.id != correctWord.id).toList();
  otherWords.shuffle();

  for (var i = 0; i < 3 && i < otherWords.length; i++) {
    options.add(otherWords[i].word);
  }

  // 如果词库中单词不足4个，用占位符填充
  while (options.length < 4) {
    options.add('option_${options.length}');
  }

  options.shuffle();
  return options;
}

/// 模拟 _onQuizNext 评分逻辑
int calculateQuizQuality(int selectedOption, int correctOption) {
  final isCorrect = selectedOption == correctOption;
  return isCorrect ? 4 : 2;
}

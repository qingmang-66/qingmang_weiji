# 学习统计、每日限制、复习、语速与输入法完成键修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复新词/待复习统计、每日新词与每日复习上限、复习调度、TTS 语速同步，以及 Android 输入法完成键触发检查答案的问题，并保证 Windows 与 Android 逻辑一致。

**Architecture:** 先把“今天已学习/已复习”和“剩余可加载数量”从 DAO 层统一定义，再让首页统计、选词页加载、学习完成后的刷新都使用同一套口径。TTS 语速通过 `TtsService` 保存当前语速并在本地/在线切换后保持；输入法完成键使用 `TextInputAction.done` 与提交回调共同触发现有 `_handleEnterShortcut()`。

**Tech Stack:** Flutter/Dart、sqflite/sqflite_common_ffi、Provider、flutter_tts、flutter_test/test。

---

## File Map

- Modify: `lib/services/daos/word_dao.dart`
  - 统一新词、待复习、今日新学、今日复习计数 SQL 口径。
  - 新增按今日剩余额度加载新词/复习词需要的查询辅助方法。
- Modify: `lib/services/database_service.dart`
  - 暴露 DAO 新方法，保持 repository 不直接依赖 DAO。
- Modify: `lib/services/repositories/word_repository.dart`
  - 新增 `getAvailableNewWordsForToday`、`getAvailableDueWordsForToday` 或等价方法。
- Modify: `lib/services/repositories/review_repository.dart`
  - 修正统计缓存失效问题；保存复习记录后清理计数缓存。
- Modify: `lib/services/providers/wordbook_provider.dart`
  - 首页“新词 / 待复习”显示改为剩余额度或明确统计口径，确保学习返回后刷新。
- Modify: `lib/screens/pre_study_screen.dart`
  - 选词页加载时使用“今日剩余数量”，避免完成 20 个后再次进入直接加载下一批 20 个。
  - Android 输入法完成键触发检查答案。
- Modify: `lib/screens/home_screen.dart`
  - 返回首页/学习模式选择页后刷新统计，必要时刷新继续学习状态。
- Modify: `lib/services/review_scheduler.dart`
  - 校验初学和复习的 repetitions、quality、nextReview 规则，不正确时修正。
- Modify: `lib/services/tts_service.dart`
  - 保存当前语速，`updateSettings` 未传 speechRate 时不重置为 0.45。
  - 在线切回本地时继续使用最近一次设置的语速。
- Modify: `lib/screens/settings_screen.dart`
  - 确认语速弹窗保存后能触发运行时 TTS 同步；必要时等待 provider 保存。
- Test: `test/study_limits_test.dart`
  - 覆盖每日新词/复习剩余额度和统计口径。
- Test: `test/review_scheduler_test.dart`
  - 增补复习调度边界行为。
- Test: `test/tts_service_test.dart`
  - 覆盖语速保存、更新、切换发音源后的行为。
- Test: `test/quiz_mode_test.dart`
  - 覆盖输入法 done/submit 与 Enter 一致触发检查答案。

---

### Task 1: 明确统计口径并写失败测试

**Files:**
- Create: `test/study_limits_test.dart`
- Read: `lib/services/daos/word_dao.dart`
- Read: `lib/models/review_record.dart`

- [ ] **Step 1: 写每日新词剩余额度失败测试**

Create `test/study_limits_test.dart` with:

```dart
import 'package:test/test.dart';

int remainingDailyNewWords({required int dailyLimit, required int todayNewLearned}) {
  final remaining = dailyLimit - todayNewLearned;
  return remaining < 0 ? 0 : remaining;
}

int remainingDailyReviews({required int dailyLimit, required int todayReviewed}) {
  final remaining = dailyLimit - todayReviewed;
  return remaining < 0 ? 0 : remaining;
}

void main() {
  group('每日学习额度', () {
    test('学完每日新词上限后，当天不再加载下一批新词', () {
      expect(
        remainingDailyNewWords(dailyLimit: 20, todayNewLearned: 20),
        0,
      );
    });

    test('只学完部分新词时，只加载今天剩余额度', () {
      expect(
        remainingDailyNewWords(dailyLimit: 20, todayNewLearned: 12),
        8,
      );
    });

    test('复习达到每日上限后，当天不再加载更多待复习词', () {
      expect(
        remainingDailyReviews(dailyLimit: 50, todayReviewed: 50),
        0,
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试确认当前业务尚未接入该口径**

Run:

```bash
flutter test test/study_limits_test.dart
```

Expected: PASS for pure helper tests. This establishes exact expected formula before wiring into production.

- [ ] **Step 3: 补充 DAO 集成测试骨架**

Extend `test/database_service_test.dart` or create focused DAO test using in-memory sqlite. The test data must include:

```dart
final today = DateTime.now();
final todayStart = DateTime(today.year, today.month, today.day);
final tomorrow = today.add(const Duration(days: 1));
final yesterday = today.subtract(const Duration(days: 1));
```

Assertions:

```dart
expect(todayNewCount, 20);
expect(unlearnedCount, greaterThan(0));
expect(remainingDailyNewWords(dailyLimit: 20, todayNewLearned: todayNewCount), 0);
```

- [ ] **Step 4: 提交测试**

```bash
git add test/study_limits_test.dart test/database_service_test.dart
git commit -m "test: define daily study limit behavior"
```

---

### Task 2: 修复 DAO 统计和每日限制加载

**Files:**
- Modify: `lib/services/daos/word_dao.dart`
- Modify: `lib/services/database_service.dart`
- Modify: `lib/services/repositories/word_repository.dart`
- Test: `test/study_limits_test.dart`

- [ ] **Step 1: 修正今日新学计数 SQL**

In `lib/services/daos/word_dao.dart`, replace `getTodayNewWordCount` with logic equivalent to:

```dart
Future<int> getTodayNewWordCount(int bookId) async {
  final db = await _dbFuture;
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();
  final tomorrowStart = DateTime(today.year, today.month, today.day + 1).toIso8601String();
  final result = await db.rawQuery(
    '''
    SELECT COUNT(*) as count FROM review_records r
    INNER JOIN words w ON r.word_id = w.id
    WHERE w.word_book_id = ?
      AND r.last_review >= ?
      AND r.last_review < ?
      AND r.repetitions = 1
    ''',
    [bookId, todayStart, tomorrowStart],
  );
  return (result.first['count'] as int?) ?? 0;
}
```

- [ ] **Step 2: 新增今日已复习计数 SQL**

Add to `WordDao`:

```dart
Future<int> getTodayReviewedWordCount(int bookId) async {
  final db = await _dbFuture;
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();
  final tomorrowStart = DateTime(today.year, today.month, today.day + 1).toIso8601String();
  final result = await db.rawQuery(
    '''
    SELECT COUNT(*) as count FROM review_records r
    INNER JOIN words w ON r.word_id = w.id
    WHERE w.word_book_id = ?
      AND r.last_review >= ?
      AND r.last_review < ?
      AND r.repetitions > 1
    ''',
    [bookId, todayStart, tomorrowStart],
  );
  return (result.first['count'] as int?) ?? 0;
}
```

- [ ] **Step 3: 暴露 DatabaseService 方法**

In `lib/services/database_service.dart`, add:

```dart
static Future<int> getTodayReviewedWordCount(int bookId) =>
    wordDao.getTodayReviewedWordCount(bookId);
```

- [ ] **Step 4: Repository 增加今日剩余额度加载方法**

In `lib/services/repositories/word_repository.dart`, add:

```dart
Future<List<Word>> getNewWordsWithinDailyRemaining(
  int bookId, {
  required int dailyLimit,
}) async {
  final todayNewCount = await DatabaseService.getTodayNewWordCount(bookId);
  final remaining = (dailyLimit - todayNewCount).clamp(0, dailyLimit);
  if (remaining == 0) return [];
  return getNewWords(bookId, remaining);
}

Future<List<Word>> getDueWordsWithinDailyRemaining(
  int bookId, {
  required int dailyLimit,
}) async {
  final todayReviewedCount = await DatabaseService.getTodayReviewedWordCount(bookId);
  final remaining = (dailyLimit - todayReviewedCount).clamp(0, dailyLimit);
  if (remaining == 0) return [];
  return getDueWords(bookId, limit: remaining);
}
```

- [ ] **Step 5: 运行测试**

```bash
flutter test test/study_limits_test.dart test/database_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: 提交**

```bash
git add lib/services/daos/word_dao.dart lib/services/database_service.dart lib/services/repositories/word_repository.dart test/study_limits_test.dart test/database_service_test.dart
git commit -m "fix: enforce daily study remaining limits"
```

---

### Task 3: 修复选词页加载和首页统计刷新

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- Modify: `lib/services/providers/wordbook_provider.dart`
- Modify: `lib/services/repositories/review_repository.dart`
- Modify: `lib/screens/home_screen.dart`
- Test: `test/study_limits_test.dart`

- [ ] **Step 1: 让选词页使用剩余额度加载**

In `lib/screens/pre_study_screen.dart`, replace `_loadWords` branch calls:

```dart
if (widget.isReview) {
  _allWords = await di.wordRepository.getDueWordsWithinDailyRemaining(
    widget.wordBookId,
    dailyLimit: settings.dailyReviewWords,
  );
} else {
  _allWords = await di.wordRepository.getNewWordsWithinDailyRemaining(
    widget.wordBookId,
    dailyLimit: settings.dailyNewWords,
  );
}
```

- [ ] **Step 2: 保存复习记录后清空统计缓存**

In `lib/services/repositories/review_repository.dart`, after successful `saveReviewRecord`, call:

```dart
_countCache.clear();
```

If `saveReviewRecord` currently delegates directly, update it so successful writes invalidate due/today counts.

- [ ] **Step 3: 首页统计使用明确口径**

In `WordBookProvider.refreshDueCount`, keep:

```dart
_dueCount = await _reviewRepository.getDueWordCount(bookId);
_todayNewCount = await _reviewRepository.getTodayNewWordCount(bookId);
```

Then add a new getter if UI needs remaining new words:

```dart
int remainingNewWords(int dailyLimit) =>
    (dailyLimit - _todayNewCount).clamp(0, dailyLimit);
```

Use this only if home card displays“今天还能学多少”；如果 home card displays“今天已学多少”， keep `_todayNewCount`.

- [ ] **Step 4: 学习返回后刷新统计和继续学习状态**

In `lib/screens/home_screen.dart`, after `wordBookProvider.refreshDueCount()`, call the local refresh method where available:

```dart
.then((_) {
  wordBookProvider.refreshDueCount();
  refreshData();
});
```

- [ ] **Step 5: 运行测试和手工路径**

```bash
flutter test test/study_limits_test.dart
flutter analyze
```

Manual expected:
- 设置每日新词 20。
- 学完 20 个。
- 返回再进入学习模式选择页。
- 新词列表为空或提示今日额度已用完，不再直接加载下一轮 20 个。

- [ ] **Step 6: 提交**

```bash
git add lib/screens/pre_study_screen.dart lib/services/providers/wordbook_provider.dart lib/services/repositories/review_repository.dart lib/screens/home_screen.dart
git commit -m "fix: refresh study counts and respect daily remaining quota"
```

---

### Task 4: 校验并修复复习调度逻辑

**Files:**
- Modify: `lib/services/review_scheduler.dart`
- Test: `test/review_scheduler_test.dart`

- [ ] **Step 1: 增补首次学习行为测试**

Add to `test/review_scheduler_test.dart`:

```dart
test('首次新学单词保存后 repetitions 应进入 1，明天开始复习', () {
  final initial = ReviewScheduler.createInitialRecord(1);
  final scheduled = ReviewScheduler.scheduleNextReview(initial, 4);

  expect(scheduled.repetitions, 1);
  expect(scheduled.quality, 4);
  expect(scheduled.interval, greaterThanOrEqualTo(1));
  expect(scheduled.nextReview.isAfter(DateTime.now()), isTrue);
});
```

- [ ] **Step 2: 增补忘记行为测试**

```dart
test('复习忘记后重置 repetitions 并安排 1 天后复习', () {
  final record = ReviewRecord(
    wordId: 1,
    repetitions: 3,
    interval: 7,
    easeFactor: 2.5,
    nextReview: DateTime.now(),
    lastReview: DateTime.now().subtract(const Duration(days: 7)),
  );

  final scheduled = ReviewScheduler.scheduleNextReview(record, 1);

  expect(scheduled.repetitions, 0);
  expect(scheduled.interval, 1);
  expect(scheduled.quality, 1);
});
```

- [ ] **Step 3: 增补 due 查询口径测试**

In DAO/database test, insert three records:
- `next_review <= now`: due
- `next_review > now`: not due
- no record: new word, not due

Expected:

```dart
expect(dueWords.map((w) => w.word), contains('due_word'));
expect(dueWords.map((w) => w.word), isNot(contains('future_word')));
expect(dueWords.map((w) => w.word), isNot(contains('new_word')));
```

- [ ] **Step 4: 只在测试失败时修 ReviewScheduler**

If current `ReviewScheduler` passes all tests, do not change it. If it fails, adjust `scheduleNextReview` minimally to satisfy tests.

- [ ] **Step 5: 运行测试**

```bash
flutter test test/review_scheduler_test.dart test/database_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: 提交**

```bash
git add lib/services/review_scheduler.dart test/review_scheduler_test.dart test/database_service_test.dart
git commit -m "test: verify review scheduling rules"
```

---

### Task 5: 修复 TTS 语速同步与回退

**Files:**
- Modify: `lib/services/tts_service.dart`
- Modify: `lib/screens/settings_screen.dart`
- Test: `test/tts_service_test.dart`

- [ ] **Step 1: 写语速保持测试**

Add to `test/tts_service_test.dart`:

```dart
test('更新发音源但未传 speechRate 时保留最近一次语速', () async {
  final configuredRates = <double>[];
  final service = TtsService.test(
    configureLocal: (rate) async => configuredRates.add(rate),
  );

  await service.init(isOnline: false, speechRate: 0.7);
  await service.updateSettings(isOnline: true);
  await service.updateSettings(isOnline: false);

  expect(configuredRates, [0.7, 0.7]);
});
```

Expected before fix: FAIL because current `updateSettings` uses `speechRate ?? 0.45`.

- [ ] **Step 2: 在 TtsService 保存当前语速**

In `lib/services/tts_service.dart`, add field:

```dart
double _speechRate = 0.45;
```

Update `init`:

```dart
_speechRate = speechRate;
```

Update `updateSettings`:

```dart
if (speechRate != null) _speechRate = speechRate;
if (!_isOnline) {
  await _configureLocalTts(speechRate: _speechRate);
}
```

- [ ] **Step 3: 设置页确认保存等待 provider**

In `lib/screens/settings_screen.dart`, change confirm handler to async:

```dart
onPressed: () async {
  await provider.setSpeechRate(selected);
  if (context.mounted) Navigator.pop(context);
},
```

- [ ] **Step 4: 运行测试**

```bash
flutter test test/tts_service_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 5: 提交**

```bash
git add lib/services/tts_service.dart lib/screens/settings_screen.dart test/tts_service_test.dart
git commit -m "fix: preserve local tts speech rate"
```

---

### Task 6: 修复 Android 输入法完成键检查答案

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- Test: `test/quiz_mode_test.dart`

- [ ] **Step 1: 增补输入法提交等价测试**

In `test/quiz_mode_test.dart`, add a pure flow test:

```dart
test('Android 输入法完成键提交等价于 Enter 检查答案', () {
  final state = TypedAnswerFlowState(
    answer: 'apple',
    correctAnswer: 'apple',
  );

  final nextState = handleTypedEnter(state);

  expect(nextState.hasChecked, isTrue);
  expect(nextState.isCorrect, isTrue);
  expect(nextState.shouldGoNext, isFalse);
});
```

- [ ] **Step 2: TextField 配置完成动作**

In `lib/screens/pre_study_screen.dart` typed answer `TextField`, add:

```dart
textInputAction: TextInputAction.done,
onEditingComplete: _handleEnterShortcut,
onSubmitted: (_) => _handleEnterShortcut(),
```

Keep `onSubmitted` because desktop Enter and some Android IME submit paths use it.

- [ ] **Step 3: 避免重复提交**

If both `onEditingComplete` and `onSubmitted` fire on the same IME, add a small guard field:

```dart
bool _isHandlingTextSubmit = false;

void _handleTextSubmit() {
  if (_isHandlingTextSubmit) return;
  _isHandlingTextSubmit = true;
  _handleEnterShortcut();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _isHandlingTextSubmit = false;
  });
}
```

Then wire:

```dart
onEditingComplete: _handleTextSubmit,
onSubmitted: (_) => _handleTextSubmit(),
```

- [ ] **Step 4: 运行测试**

```bash
flutter test test/quiz_mode_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 5: 提交**

```bash
git add lib/screens/pre_study_screen.dart test/quiz_mode_test.dart
git commit -m "fix: handle android ime done for typed answers"
```

---

### Task 7: 全量回归与平台核查

**Files:**
- No production files unless tests reveal failures.

- [ ] **Step 1: 运行核心测试集**

```bash
flutter test test/study_limits_test.dart test/database_service_test.dart test/review_scheduler_test.dart test/tts_service_test.dart test/quiz_mode_test.dart test/widget_test.dart
```

Expected: All tests passed.

- [ ] **Step 2: 静态检查**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 3: Windows 手动验证**

Manual checklist:
- 首页新词/待复习数字与当前词库一致。
- 设置每日新词 20，完成 20 个后再次进入学习模式选择，不再加载下一批 20 个。
- 设置每日复习上限 N，完成 N 个复习后当天不再继续加载额外复习词。
- 修改语速后，本地 TTS 发音速度变化；切在线再切本地后语速仍保持。
- 拼写/听力模式按 Enter 能检查答案。

- [ ] **Step 4: Android 手动验证**

Manual checklist:
- 首页新词/待复习统计与 Windows 相同口径。
- Android 输入法点“完成/Done”能检查答案。
- 达到每日新词/复习上限后不会继续进入下一批。
- 本地 TTS 语速设置生效；本地失败时在线兜底仍工作。

- [ ] **Step 5: 最终提交**

```bash
git status --short
git add .
git commit -m "fix: stabilize study limits review counts and typed input"
```

---

## Self-Review

- Spec coverage: 覆盖用户列出的 5 项：新词/待复习统计、每日新词/复习上限、复习逻辑、语速、Android 输入法完成键。
- Placeholder scan: 无 TBD/TODO；每个任务都有文件、代码片段、命令和预期结果。
- Type consistency: 使用现有 `WordDao`、`DatabaseService`、`WordRepository`、`ReviewRepository`、`TtsService`、`PreStudyScreen` 命名；新增方法在 DAO → DatabaseService → Repository 分层中保持一致。

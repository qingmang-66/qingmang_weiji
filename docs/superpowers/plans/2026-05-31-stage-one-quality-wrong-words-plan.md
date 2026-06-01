# 阶段一：质量基线与错词闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 清理当前 analyzer 历史问题，并完成错词专项复习基础闭环，让错词本可以进入专项学习、按表现更新错词状态，并为后续收藏夹和自定义词集复用学习入口打基础。

**Architecture:** 阶段一采用小步重构：先清理静态问题，再增加纯逻辑模型和测试，然后把 WrongWordService、SpecializedStudyService 接入 DIContainer，最后改造错词页和 PreStudyScreen。学习流程继续复用现有 `PreStudyScreen` / `_DirectStudyScreen`，通过新增 `SpecializedStudyRequest` 描述错词来源，避免重写学习页。

**Tech Stack:** Flutter、Dart、Provider、sqflite/sqflite_common_ffi、package:test、flutter_lints。

---

## 文件结构与职责

### 新增文件

| 文件 | 职责 |
|---|---|
| `lib/models/study_source.dart` | 定义学习来源枚举和来源展示文案键的基础扩展。 |
| `lib/models/specialized_study_request.dart` | 描述专项学习请求，包含来源、标题、单词列表、模式和进度键。 |
| `lib/models/wrong_word_review_result.dart` | 描述单个错词专项复习后的表现，用于更新错词强度。 |
| `lib/services/specialized_study_service.dart` | 将错词等来源转换为专项学习请求，并处理专项学习完成后的回写。 |
| `test/wrong_word_review_result_test.dart` | 测试错词连续掌握、仍需强化等纯逻辑。 |
| `test/specialized_study_request_test.dart` | 测试学习来源、进度键、请求字段的纯逻辑。 |

### 修改文件

| 文件 | 修改原因 |
|---|---|
| `lib/screens/pre_study_screen.dart` | 清理未使用字段；增加专项学习构造入口；在完成页回调错词结果；保存多来源进度。 |
| `lib/screens/wrong_words_screen.dart` | 替换“功能开发中”为真实专项复习；支持全部/选中错词；使用 DIContainer。 |
| `lib/screens/home_screen.dart` | 使用 DIContainer 获取 WrongWordService；继续学习时显示来源标题并支持多来源进度。 |
| `lib/screens/study_screen.dart` | 使用 DIContainer 获取 WrongWordService；统一错误处理。 |
| `lib/services/di_container.dart` | 注册 WrongWordService、SpecializedStudyService、NotificationService。 |
| `lib/services/services.dart` | 导出新增服务和模型依赖。 |
| `lib/services/wrong_word_service.dart` | 增加按 ID 获取错词、排序、复习结果回写能力。 |
| `lib/services/daos/wrong_word_dao.dart` | 增加按 ID 查询错词和降低错词强度能力。 |
| `lib/services/study_progress_logic.dart` | 增加 progressKey/sourceTitle 等多来源进度纯逻辑。 |
| `lib/services/daos/study_progress_dao.dart` | 在现有表兼容基础上读写 source/progressKey/title 字段。 |
| `lib/services/repositories/study_progress_repository.dart` | 暴露多来源进度参数并保持旧调用兼容。 |
| `lib/services/database_service.dart` | 迁移 study_progress 表新增 source、progress_key、title 字段。 |
| `lib/utils/error_handler.dart` | 如果需要，补充统一浮动提示辅助方法。 |
| `lib/utils/translations.dart` | 新增错词专项复习、专项学习完成、继续来源标题等文案。 |
| `docs/current-progress-handoff.md` | 阶段一完成后更新 analyzer 和错词专项复习状态。 |

---

### Task 1: 清理 analyzer 历史问题

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- Modify or Delete: `lib/screens/ui_showcase_screen.dart` if it exists and is unused
- Modify: `lib/theme/ui_theme.dart` if it exists
- Modify: `lib/utils/animations/fluid_curves.dart`
- Modify: `lib/utils/animations/spring_curves.dart`
- Modify: `lib/widgets/fluid_app_bar.dart`
- Modify: `lib/widgets/stats_cards.dart`
- Modify: `lib/widgets/study_heatmap.dart`
- Modify: `lib/widgets/ui_app_bar.dart` if it exists
- Modify: `lib/widgets/ui_gradient.dart` if it exists

- [ ] **Step 1: Run full analyzer to capture the real current baseline**

Run:

```powershell
flutter analyze
```

Expected: Analyzer reports the current warning/info list. Compare with `docs/current-progress-handoff.md` because some files may already be removed or renamed.

- [ ] **Step 2: Remove unused fields in `lib/screens/pre_study_screen.dart`**

Remove fields only if analyzer confirms they are unused. The likely fields are:

```dart
bool _spellCorrect = false;
int? _selectedQuizOption;
int? _correctQuizOption;
List<String> _quizOptions = [];
bool _quizOptionsLoading = false;
bool _recordsPreloaded = false;
```

If `_selectedQuizOption` or `_quizOptions` are now used in the current file, keep them and only remove analyzer-confirmed unused fields.

- [ ] **Step 3: Clean or delete unused UI showcase file**

Check references:

```powershell
Select-String -Path lib\**\*.dart -Pattern "ui_showcase_screen|UiShowcase|UIShowcase"
```

If there are no references except the file itself, delete it:

```powershell
Remove-Item lib\screens\ui_showcase_screen.dart
```

If it is referenced, keep the file and remove analyzer-confirmed unused imports and fields.

- [ ] **Step 4: Replace deprecated ColorScheme fields**

In `lib/theme/ui_theme.dart`, replace deprecated fields:

```dart
background: someColor,
onBackground: someTextColor,
```

with:

```dart
surface: someColor,
onSurface: someTextColor,
```

Only edit this file if it exists.

- [ ] **Step 5: Remove unnecessary imports and unused locals**

Apply analyzer-confirmed fixes:

```dart
// Remove if analyzer says unnecessary:
import 'package:flutter/animation.dart';
```

For unused `simulation` variables in `spring_curves.dart`, replace:

```dart
final simulation = SpringSimulation(...);
return someExpression;
```

with direct code that keeps behavior unchanged, or remove the variable if it has no side effect.

- [ ] **Step 6: Fix style-only lints without behavior changes**

For `curly_braces_in_flow_control_structures`, change:

```dart
if (condition) return value;
```

into:

```dart
if (condition) {
  return value;
}
```

- [ ] **Step 7: Format and analyze touched files**

Run:

```powershell
dart format lib\screens\pre_study_screen.dart lib\utils\animations\fluid_curves.dart lib\utils\animations\spring_curves.dart lib\widgets\fluid_app_bar.dart lib\widgets\stats_cards.dart lib\widgets\study_heatmap.dart
flutter analyze
```

Expected: Historical analyzer issues are gone or reduced to documented items that are unrelated to files touched in this task.

---

### Task 2: Add pure models for specialized study and wrong-word review results

**Files:**
- Create: `lib/models/study_source.dart`
- Create: `lib/models/specialized_study_request.dart`
- Create: `lib/models/wrong_word_review_result.dart`
- Modify: `lib/models/models.dart`
- Test: `test/specialized_study_request_test.dart`
- Test: `test/wrong_word_review_result_test.dart`

- [ ] **Step 1: Write failing test for specialized study request**

Create `test/specialized_study_request_test.dart`:

```dart
import 'package:qingmang_weiji/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('SpecializedStudyRequest', () {
    test('为错词专项复习生成稳定进度键', () {
      const request = SpecializedStudyRequest(
        source: StudySource.wrongWords,
        title: '错词专项复习',
        wordBookId: 1,
        wordIds: [3, 2, 1],
        studyMode: 2,
        isReview: true,
        allowProgressSave: true,
      );

      expect(request.progressKey, 'wrongWords:1');
      expect(request.hasWords, isTrue);
    });

    test('空单词列表不可开始学习', () {
      const request = SpecializedStudyRequest(
        source: StudySource.wrongWords,
        title: '错词专项复习',
        wordBookId: null,
        wordIds: [],
        studyMode: 1,
        isReview: true,
      );

      expect(request.hasWords, isFalse);
    });
  });
}
```

- [ ] **Step 2: Write failing test for wrong-word review result**

Create `test/wrong_word_review_result_test.dart`:

```dart
import 'package:qingmang_weiji/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('WrongWordReviewResult', () {
    test('连续三次答对建议移出错词本', () {
      const result = WrongWordReviewResult(
        wordId: 12,
        wasCorrect: true,
        revealedAnswer: false,
        previousCorrectStreak: 2,
      );

      expect(result.nextCorrectStreak, 3);
      expect(result.shouldSuggestMastered, isTrue);
      expect(result.shouldStrengthen, isFalse);
    });

    test('答错会重置连续答对并保持强化', () {
      const result = WrongWordReviewResult(
        wordId: 12,
        wasCorrect: false,
        revealedAnswer: false,
        previousCorrectStreak: 2,
      );

      expect(result.nextCorrectStreak, 0);
      expect(result.shouldSuggestMastered, isFalse);
      expect(result.shouldStrengthen, isTrue);
    });

    test('查看答案即使最终答对也保持强化', () {
      const result = WrongWordReviewResult(
        wordId: 12,
        wasCorrect: true,
        revealedAnswer: true,
        previousCorrectStreak: 2,
      );

      expect(result.nextCorrectStreak, 0);
      expect(result.shouldSuggestMastered, isFalse);
      expect(result.shouldStrengthen, isTrue);
    });
  });
}
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```powershell
dart test test\specialized_study_request_test.dart test\wrong_word_review_result_test.dart
```

Expected: FAIL because the new model files and classes do not exist yet.

- [ ] **Step 4: Implement `StudySource`**

Create `lib/models/study_source.dart`:

```dart
enum StudySource {
  normal,
  review,
  wrongWords,
  favorites,
  customWordSet,
  searchResults,
  studyPlan,
}

extension StudySourceKey on StudySource {
  String get key {
    return switch (this) {
      StudySource.normal => 'normal',
      StudySource.review => 'review',
      StudySource.wrongWords => 'wrongWords',
      StudySource.favorites => 'favorites',
      StudySource.customWordSet => 'customWordSet',
      StudySource.searchResults => 'searchResults',
      StudySource.studyPlan => 'studyPlan',
    };
  }
}
```

- [ ] **Step 5: Implement `SpecializedStudyRequest`**

Create `lib/models/specialized_study_request.dart`:

```dart
import 'study_source.dart';

class SpecializedStudyRequest {
  final StudySource source;
  final String title;
  final int? wordBookId;
  final List<int> wordIds;
  final int studyMode;
  final bool isReview;
  final bool allowProgressSave;
  final String? explicitProgressKey;

  const SpecializedStudyRequest({
    required this.source,
    required this.title,
    required this.wordBookId,
    required this.wordIds,
    required this.studyMode,
    required this.isReview,
    this.allowProgressSave = true,
    this.explicitProgressKey,
  });

  bool get hasWords => wordIds.isNotEmpty;

  String get progressKey {
    if (explicitProgressKey != null && explicitProgressKey!.isNotEmpty) {
      return explicitProgressKey!;
    }
    return '${source.key}:${wordBookId ?? 'global'}';
  }
}
```

- [ ] **Step 6: Implement `WrongWordReviewResult`**

Create `lib/models/wrong_word_review_result.dart`:

```dart
class WrongWordReviewResult {
  static const int masteredStreakThreshold = 3;

  final int wordId;
  final bool wasCorrect;
  final bool revealedAnswer;
  final int previousCorrectStreak;

  const WrongWordReviewResult({
    required this.wordId,
    required this.wasCorrect,
    required this.revealedAnswer,
    required this.previousCorrectStreak,
  });

  bool get shouldStrengthen => !wasCorrect || revealedAnswer;

  int get nextCorrectStreak {
    if (shouldStrengthen) return 0;
    return previousCorrectStreak + 1;
  }

  bool get shouldSuggestMastered {
    return nextCorrectStreak >= masteredStreakThreshold;
  }
}
```

- [ ] **Step 7: Export new models**

Modify `lib/models/models.dart` and add:

```dart
export 'study_source.dart';
export 'specialized_study_request.dart';
export 'wrong_word_review_result.dart';
```

- [ ] **Step 8: Run tests and format**

Run:

```powershell
dart format lib\models\study_source.dart lib\models\specialized_study_request.dart lib\models\wrong_word_review_result.dart lib\models\models.dart test\specialized_study_request_test.dart test\wrong_word_review_result_test.dart
dart test test\specialized_study_request_test.dart test\wrong_word_review_result_test.dart
```

Expected: PASS.

---

### Task 3: Extend wrong-word data access and service behavior

**Files:**
- Modify: `lib/services/daos/wrong_word_dao.dart`
- Modify: `lib/services/wrong_word_service.dart`
- Test: `test/wrong_word_review_result_test.dart`

- [ ] **Step 1: Add pure helper tests for wrong count reduction**

Extend `test/wrong_word_review_result_test.dart`:

```dart
  group('WrongWordStrength', () {
    test('答对后错误强度最低降到一', () {
      expect(WrongWordStrength.nextWrongCountAfterCorrect(5), 4);
      expect(WrongWordStrength.nextWrongCountAfterCorrect(1), 1);
      expect(WrongWordStrength.nextWrongCountAfterCorrect(0), 1);
    });
  });
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```powershell
dart test test\wrong_word_review_result_test.dart
```

Expected: FAIL because `WrongWordStrength` does not exist.

- [ ] **Step 3: Add `WrongWordStrength` helper**

Append to `lib/models/wrong_word_review_result.dart`:

```dart
class WrongWordStrength {
  const WrongWordStrength._();

  static int nextWrongCountAfterCorrect(int currentWrongCount) {
    if (currentWrongCount <= 1) return 1;
    return currentWrongCount - 1;
  }
}
```

- [ ] **Step 4: Add DAO methods**

Modify `lib/services/daos/wrong_word_dao.dart` and add these methods inside `WrongWordDao`:

```dart
  Future<List<Word>> getWrongWordsByIds(List<int> wordIds) async {
    if (wordIds.isEmpty) return [];
    final db = await _dbFuture;
    final placeholders = wordIds.map((_) => '?').join(',');
    final result = await db.rawQuery('''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      WHERE w.id IN ($placeholders)
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
    ''', wordIds);

    return result
        .map((row) => Word.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> reduceWrongCount(int wordId) async {
    final db = await _dbFuture;
    final current = await getWrongCount(wordId);
    final next = current <= 1 ? 1 : current - 1;
    await db.update(
      'wrong_words',
      {'wrong_count': next},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }
```

- [ ] **Step 5: Add service methods**

Modify `lib/services/wrong_word_service.dart` imports:

```dart
import '../models/models.dart';
```

Replace existing `import '../models/word.dart';` with the models barrel import.

Add methods inside `WrongWordService`:

```dart
  Future<List<Word>> getWrongWordsByIds(List<int> wordIds) =>
      DatabaseService.wrongWordDao.getWrongWordsByIds(wordIds);

  Future<void> applyReviewResult(WrongWordReviewResult result) async {
    if (result.shouldSuggestMastered) {
      await removeWrongWord(result.wordId);
      return;
    }

    if (result.shouldStrengthen) {
      await addWrongWord(result.wordId);
      return;
    }

    await DatabaseService.wrongWordDao.reduceWrongCount(result.wordId);
  }
```

- [ ] **Step 6: Run tests and analyze service files**

Run:

```powershell
dart format lib\models\wrong_word_review_result.dart lib\services\daos\wrong_word_dao.dart lib\services\wrong_word_service.dart test\wrong_word_review_result_test.dart
dart test test\wrong_word_review_result_test.dart
flutter analyze lib\services\daos\wrong_word_dao.dart lib\services\wrong_word_service.dart
```

Expected: PASS and no issues found for these files.

---

### Task 4: Add specialized study service and DI registration

**Files:**
- Create: `lib/services/specialized_study_service.dart`
- Modify: `lib/services/di_container.dart`
- Modify: `lib/services/services.dart`
- Test: `test/specialized_study_request_test.dart`

- [ ] **Step 1: Extend request test with selected wrong words behavior**

Append to `test/specialized_study_request_test.dart`:

```dart
    test('显式进度键优先于默认进度键', () {
      const request = SpecializedStudyRequest(
        source: StudySource.wrongWords,
        title: '选中错词复习',
        wordBookId: 1,
        wordIds: [8, 9],
        studyMode: 3,
        isReview: true,
        explicitProgressKey: 'wrongWords:selected',
      );

      expect(request.progressKey, 'wrongWords:selected');
    });
```

- [ ] **Step 2: Run test**

Run:

```powershell
dart test test\specialized_study_request_test.dart
```

Expected: PASS. This locks the model behavior before the service uses it.

- [ ] **Step 3: Implement specialized study service**

Create `lib/services/specialized_study_service.dart`:

```dart
import '../models/models.dart';
import 'wrong_word_service.dart';

class SpecializedStudyService {
  final WrongWordService wrongWordService;

  const SpecializedStudyService({required this.wrongWordService});

  Future<SpecializedStudyRequest?> buildWrongWordsRequest({
    required int? wordBookId,
    required List<int> selectedWordIds,
    required int studyMode,
  }) async {
    final words = selectedWordIds.isEmpty
        ? await wrongWordService.getWrongWords()
        : await wrongWordService.getWrongWordsByIds(selectedWordIds);
    final wordIds = words.map((word) => word.id).whereType<int>().toList();
    if (wordIds.isEmpty) return null;

    return SpecializedStudyRequest(
      source: StudySource.wrongWords,
      title: selectedWordIds.isEmpty ? '错词专项复习' : '选中错词复习',
      wordBookId: wordBookId,
      wordIds: wordIds,
      studyMode: studyMode,
      isReview: true,
      explicitProgressKey: selectedWordIds.isEmpty
          ? null
          : 'wrongWords:selected:${wordIds.join('-')}',
    );
  }
}
```

- [ ] **Step 4: Register services in DIContainer**

Modify `lib/services/di_container.dart` imports:

```dart
import 'notification_service.dart';
import 'specialized_study_service.dart';
import 'wrong_word_service.dart';
```

Add service fields:

```dart
  late final NotificationService notificationService;
  late final WrongWordService wrongWordService;
  late final SpecializedStudyService specializedStudyService;
```

Initialize them in `init()` after existing service initialization:

```dart
    notificationService = NotificationService();
    wrongWordService = WrongWordService();
    specializedStudyService = SpecializedStudyService(
      wrongWordService: wrongWordService,
    );
```

Add to `get<T>()`:

```dart
    if (T == NotificationService) return notificationService as T;
    if (T == WrongWordService) return wrongWordService as T;
    if (T == SpecializedStudyService) return specializedStudyService as T;
```

- [ ] **Step 5: Export service**

Modify `lib/services/services.dart` and add exports if missing:

```dart
export 'notification_service.dart';
export 'specialized_study_service.dart';
export 'wrong_word_service.dart';
```

- [ ] **Step 6: Format and analyze**

Run:

```powershell
dart format lib\services\specialized_study_service.dart lib\services\di_container.dart lib\services\services.dart
flutter analyze lib\services\specialized_study_service.dart lib\services\di_container.dart lib\services\services.dart
```

Expected: No issues found for these files.

---

### Task 5: Extend study progress for source metadata while keeping compatibility

**Files:**
- Modify: `lib/services/study_progress_logic.dart`
- Modify: `lib/services/daos/study_progress_dao.dart`
- Modify: `lib/services/repositories/study_progress_repository.dart`
- Modify: `lib/services/database_service.dart`
- Test: `test/study_progress_logic_test.dart`

- [ ] **Step 1: Add pure tests for source metadata defaults**

Append to `test/study_progress_logic_test.dart`:

```dart
    test('普通学习进度使用稳定默认来源键', () {
      final key = StudyProgressLogic.defaultProgressKey(
        source: 'normal',
        wordBookId: 7,
      );

      expect(key, 'normal:7');
    });

    test('空标题回退为继续学习', () {
      final title = StudyProgressLogic.safeProgressTitle('');

      expect(title, '继续学习');
    });
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
dart test test\study_progress_logic_test.dart
```

Expected: FAIL because new methods do not exist.

- [ ] **Step 3: Implement pure logic helpers**

Modify `lib/services/study_progress_logic.dart`:

```dart
class StudyProgressLogic {
  const StudyProgressLogic._();

  static List<int> remainingWordIds({
    required List<int> wordIds,
    required int currentIndex,
  }) {
    final safeIndex = currentIndex.clamp(0, wordIds.length);
    return wordIds.skip(safeIndex).toList(growable: false);
  }

  static int? nextProgressIndex({
    required int currentIndex,
    required int totalWords,
  }) {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= totalWords) return null;
    return nextIndex;
  }

  static String defaultProgressKey({
    required String source,
    required int? wordBookId,
  }) {
    return '$source:${wordBookId ?? 'global'}';
  }

  static String safeProgressTitle(String? title) {
    final value = title?.trim() ?? '';
    if (value.isEmpty) return '继续学习';
    return value;
  }
}
```

- [ ] **Step 4: Add database migration columns**

Modify `lib/services/database_service.dart` in `onUpgrade` with a new version block after the latest existing version:

```dart
        if (oldVersion < 7) {
          await _addColumnIfMissing(
            db,
            table: 'study_progress',
            column: 'source',
            definition: 'TEXT DEFAULT "normal"',
          );
          await _addColumnIfMissing(
            db,
            table: 'study_progress',
            column: 'progress_key',
            definition: 'TEXT DEFAULT "normal:global"',
          );
          await _addColumnIfMissing(
            db,
            table: 'study_progress',
            column: 'title',
            definition: 'TEXT DEFAULT "继续学习"',
          );
        }
```

If there is no `_addColumnIfMissing` helper, add this private static method to `DatabaseService`:

```dart
  static Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
```

Also update the database version constant/openDatabase version to `7` if current version is lower.

- [ ] **Step 5: Extend DAO save/get methods**

Modify `lib/services/daos/study_progress_dao.dart` method signature:

```dart
  Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
    String source = 'normal',
    String progressKey = 'normal:global',
    String title = '继续学习',
  }) async {
```

Add fields to insert map:

```dart
      'source': source,
      'progress_key': progressKey,
      'title': title,
```

Add fields to return map in `getStudyProgress()`:

```dart
      'source': row['source'] as String? ?? 'normal',
      'progressKey': row['progress_key'] as String? ?? 'normal:global',
      'title': row['title'] as String? ?? '继续学习',
```

- [ ] **Step 6: Extend repository and DatabaseService signatures**

Modify `lib/services/repositories/study_progress_repository.dart` `saveStudyProgress` signature:

```dart
  Future<void> saveStudyProgress({
    required int wordBookId,
    required int studyMode,
    required bool isReview,
    required int currentIndex,
    required List<int> wordIds,
    String source = 'normal',
    String? progressKey,
    String? title,
  }) async {
```

Before calling DatabaseService, compute:

```dart
      final safeProgressKey = progressKey ??
          StudyProgressLogic.defaultProgressKey(
            source: source,
            wordBookId: wordBookId,
          );
      final safeTitle = StudyProgressLogic.safeProgressTitle(title);
```

Pass these into DatabaseService:

```dart
        source: source,
        progressKey: safeProgressKey,
        title: safeTitle,
```

Make the same optional parameters available in `DatabaseService.saveStudyProgress` and forward to `studyProgressDao.saveStudyProgress`.

- [ ] **Step 7: Run tests and analyze**

Run:

```powershell
dart format lib\services\study_progress_logic.dart lib\services\daos\study_progress_dao.dart lib\services\repositories\study_progress_repository.dart lib\services\database_service.dart test\study_progress_logic_test.dart
dart test test\study_progress_logic_test.dart
flutter analyze lib\services\study_progress_logic.dart lib\services\daos\study_progress_dao.dart lib\services\repositories\study_progress_repository.dart lib\services\database_service.dart
```

Expected: PASS and no issues in touched files.

---

### Task 6: Add specialized-study entry to PreStudyScreen

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- Modify: `lib/utils/translations.dart`

- [ ] **Step 1: Add factory constructor for specialized study**

Modify `PreStudyScreen` fields to add request support:

```dart
  final SpecializedStudyRequest? specializedRequest;
```

Update constructor:

```dart
  const PreStudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
    this.presetWords,
    this.presetStudyMode,
    this.specializedRequest,
  });
```

Add factory:

```dart
  factory PreStudyScreen.specialized({
    required SpecializedStudyRequest request,
    required List<Word> words,
  }) {
    return PreStudyScreen(
      wordBookId: request.wordBookId ?? 0,
      isReview: request.isReview,
      presetWords: words,
      presetStudyMode: request.studyMode,
      specializedRequest: request,
    );
  }
```

- [ ] **Step 2: Pass specialized request into direct study screen**

In the build/navigation logic that creates `_DirectStudyScreen`, pass:

```dart
specializedRequest: widget.specializedRequest,
```

Update `_DirectStudyScreen`:

```dart
  final SpecializedStudyRequest? specializedRequest;
```

Constructor:

```dart
    this.specializedRequest,
```

- [ ] **Step 3: Save progress with source metadata**

Where `_DirectStudyScreenState` saves progress, pass metadata:

```dart
await studyProgressRepository.saveStudyProgress(
  wordBookId: widget.wordBookId,
  studyMode: _effectiveStudyMode,
  isReview: widget.isReview,
  currentIndex: nextIndex,
  wordIds: _words.map((word) => word.id).whereType<int>().toList(),
  source: widget.specializedRequest?.source.key ??
      (widget.isReview ? StudySource.review.key : StudySource.normal.key),
  progressKey: widget.specializedRequest?.progressKey,
  title: widget.specializedRequest?.title,
);
```

If the current save code is in a helper, adapt the helper rather than duplicating logic.

- [ ] **Step 4: Use ErrorHandler for save failure in direct study**

Replace direct SnackBar in `_saveCurrentQuality` catch block:

```dart
if (mounted) {
  ErrorHandler.handleException(
    context,
    e,
    fallbackMessage: context.tr.saveRecordFailed,
  );
}
```

Add import if missing:

```dart
import '../utils/error_handler.dart';
```

- [ ] **Step 5: Format and analyze**

Run:

```powershell
dart format lib\screens\pre_study_screen.dart lib\utils\translations.dart
flutter analyze lib\screens\pre_study_screen.dart
```

Expected: No issues for `pre_study_screen.dart`.

---

### Task 7: Implement wrong-words special review navigation

**Files:**
- Modify: `lib/screens/wrong_words_screen.dart`
- Modify: `lib/utils/translations.dart`

- [ ] **Step 1: Add translations**

Modify `lib/utils/translations.dart` around wrong-word strings and add:

```dart
  String get wrongWordsReviewTitle => t('错词专项复习', 'Wrong Words Review');
  String get selectedWrongWordsReviewTitle =>
      t('选中错词复习', 'Selected Wrong Words Review');
  String get noWrongWordsToReview =>
      t('没有可复习的错词', 'No wrong words to review');
  String get chooseWrongWordsReviewMode =>
      t('选择错词复习模式', 'Choose wrong words review mode');
```

- [ ] **Step 2: Replace direct service construction with DIContainer**

In `wrong_words_screen.dart`, add import:

```dart
import '../services/di_container.dart';
import '../utils/page_transitions.dart';
import 'pre_study_screen.dart';
```

Replace:

```dart
final service = WrongWordService();
await service.init();
```

with:

```dart
final service = context.read<DIContainer>().wrongWordService;
```

Only use this when `context.mounted` or inside State methods where context is valid.

- [ ] **Step 3: Implement review mode picker**

Add method inside `_WrongWordsScreenState`:

```dart
  Future<int?> _pickReviewMode() async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FluidTheme.getDialogSurfaceColor(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: FluidTheme.getBorderColor(isDark)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr.chooseWrongWordsReviewMode,
                style: FluidTheme.headingSmall(isDark).copyWith(
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildModeTile(ctx, Icons.visibility, context.tr.recallMode, 1),
              _buildModeTile(ctx, Icons.edit, context.tr.spellingMode, 2),
              _buildModeTile(ctx, Icons.headphones, context.tr.listeningMode, 3),
              _buildModeTile(ctx, Icons.quiz, context.tr.quizMode, 4),
            ],
          ),
        ),
      ),
    );
  }
```

Add helper:

```dart
  Widget _buildModeTile(
    BuildContext sheetContext,
    IconData icon,
    String title,
    int mode,
  ) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return ListTile(
      leading: Icon(icon, color: FluidTheme.primaryFluidGradient[0]),
      title: Text(
        title,
        style: TextStyle(color: FluidTheme.getTextPrimaryColor(isDark)),
      ),
      onTap: () => Navigator.pop(sheetContext, mode),
    );
  }
```

If translation keys for `spellingMode`, `listeningMode`, or `quizMode` have different names, use the existing names in `Translations`.

- [ ] **Step 4: Implement `_studyWrongWords`**

Replace the current placeholder method:

```dart
  Future<void> _studyWrongWords() async {
    if (_wrongWords.isEmpty) return;

    final mode = await _pickReviewMode();
    if (mode == null || !mounted) return;

    final di = context.read<DIContainer>();
    final selectedIds = _isSelecting ? _selectedWords.toList() : <int>[];
    final request = await di.specializedStudyService.buildWrongWordsRequest(
      wordBookId: null,
      selectedWordIds: selectedIds,
      studyMode: mode,
    );

    if (!mounted) return;
    if (request == null) {
      ErrorHandler.showError(context, context.tr.noWrongWordsToReview);
      return;
    }

    final words = await di.wrongWordService.getWrongWordsByIds(request.wordIds);
    if (!mounted) return;
    if (words.isEmpty) {
      ErrorHandler.showError(context, context.tr.noWrongWordsToReview);
      return;
    }

    Navigator.of(context)
        .push(
          PageTransitions.slideFromRight(
            page: PreStudyScreen.specialized(
              request: request,
              words: words,
            ),
          ),
        )
        .then((_) => _loadWrongWords());
  }
```

- [ ] **Step 5: Make selected-review button use selected words**

Keep the existing app bar school icon. If `_isSelecting` and `_selectedWords` is not empty, `_studyWrongWords` should use selected IDs through the code above. No separate button is required.

- [ ] **Step 6: Format and analyze**

Run:

```powershell
dart format lib\screens\wrong_words_screen.dart lib\utils\translations.dart
flutter analyze lib\screens\wrong_words_screen.dart
```

Expected: No issues for wrong words screen.

---

### Task 8: Apply wrong-word review results after specialized study

**Files:**
- Modify: `lib/screens/pre_study_screen.dart`
- Modify: `lib/widgets` only if summary UI component extraction is needed

- [ ] **Step 1: Track wrong-word review results in direct study state**

In `_DirectStudyScreenState`, add:

```dart
  final Map<int, WrongWordReviewResult> _wrongWordReviewResults = {};
  final Map<int, int> _wrongWordCorrectStreaks = {};
```

- [ ] **Step 2: Record result when current source is wrong words**

Add helper:

```dart
  void _recordWrongWordReviewResult({
    required Word word,
    required bool wasCorrect,
    required bool revealedAnswer,
  }) {
    if (widget.specializedRequest?.source != StudySource.wrongWords) return;
    final wordId = word.id;
    if (wordId == null) return;

    final previous = _wrongWordCorrectStreaks[wordId] ?? 0;
    final result = WrongWordReviewResult(
      wordId: wordId,
      wasCorrect: wasCorrect,
      revealedAnswer: revealedAnswer,
      previousCorrectStreak: previous,
    );
    _wrongWordCorrectStreaks[wordId] = result.nextCorrectStreak;
    _wrongWordReviewResults[wordId] = result;
  }
```

Call it after each answer outcome is known:

```dart
_recordWrongWordReviewResult(
  word: word,
  wasCorrect: _isAnswerCorrect,
  revealedAnswer: _hasRevealedTypedAnswer,
);
```

For recall mode, map quality >= 3 to `wasCorrect: true`, quality < 3 to `wasCorrect: false`, and `revealedAnswer: _showAnswer` only if reveal means the user viewed the answer before grading.

- [ ] **Step 3: Apply results before finish navigation**

In `_finishStudy`, before clearing progress and navigating to summary, add:

```dart
    if (widget.specializedRequest?.source == StudySource.wrongWords &&
        _wrongWordReviewResults.isNotEmpty) {
      final wrongWordService = context.read<DIContainer>().wrongWordService;
      for (final result in _wrongWordReviewResults.values) {
        await wrongWordService.applyReviewResult(result);
      }
    }
```

- [ ] **Step 4: Include wrong-word specialized title in summary if available**

When creating `_StudySummaryScreen`, pass an optional title if the widget supports it. If it does not support it, add:

```dart
final String? title;
```

and use:

```dart
widget.title ?? (widget.isReview ? context.tr.reviewComplete : context.tr.studyComplete)
```

Pass:

```dart
title: widget.specializedRequest?.title,
```

- [ ] **Step 5: Format and analyze**

Run:

```powershell
dart format lib\screens\pre_study_screen.dart
flutter analyze lib\screens\pre_study_screen.dart
```

Expected: No issues for `pre_study_screen.dart`.

---

### Task 9: Update home continue-study and service usage

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/study_screen.dart`
- Modify: `lib/utils/translations.dart`

- [ ] **Step 1: Replace WrongWordService direct construction in home**

In `home_screen.dart`, replace:

```dart
final service = WrongWordService();
await service.init();
return await service.getWrongWordCount();
```

with:

```dart
final service = DIContainer.instance.wrongWordService;
return await service.getWrongWordCount();
```

- [ ] **Step 2: Use progress title for continue unavailable/success context**

In `continueStudy`, read:

```dart
final title = progress['title'] as String?;
final source = progress['source'] as String?;
```

If `source == StudySource.wrongWords.key`, construct request:

```dart
final request = SpecializedStudyRequest(
  source: StudySource.wrongWords,
  title: title ?? context.tr.wrongWordsReviewTitle,
  wordBookId: wordBookId == 0 ? null : wordBookId,
  wordIds: wordIds,
  studyMode: studyMode,
  isReview: isReview,
  explicitProgressKey: progress['progressKey'] as String?,
);
```

Then navigate using:

```dart
page: PreStudyScreen.specialized(
  request: request,
  words: words,
),
```

Otherwise keep existing `PreStudyScreen.continueStudy` navigation.

- [ ] **Step 3: Replace WrongWordService direct construction in study screen**

In `study_screen.dart`, replace `_addToWrongWords` internals:

```dart
final service = context.read<DIContainer>().wrongWordService;
await service.addWrongWord(wordId);
```

- [ ] **Step 4: Use ErrorHandler for save record failure in StudyScreen**

Add import:

```dart
import '../utils/error_handler.dart';
```

Replace SnackBar in `_onQualitySelected` catch block with:

```dart
if (mounted) {
  ErrorHandler.handleException(
    context,
    e,
    fallbackMessage: context.tr.saveRecordFailedHint,
  );
}
```

- [ ] **Step 5: Format and analyze**

Run:

```powershell
dart format lib\screens\home_screen.dart lib\screens\study_screen.dart lib\utils\translations.dart
flutter analyze lib\screens\home_screen.dart lib\screens\study_screen.dart
```

Expected: No issues in both screens.

---

### Task 10: Final validation and handoff update

**Files:**
- Modify: `docs/current-progress-handoff.md`
- No code changes unless validation reveals issues

- [ ] **Step 1: Run targeted pure tests**

Run:

```powershell
dart test test\study_progress_logic_test.dart test\specialized_study_request_test.dart test\wrong_word_review_result_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run existing related tests**

Run:

```powershell
dart test test\practice_flow_logic_test.dart test\study_session_summary_test.dart test\session_mastery_engine_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run full analyzer**

Run:

```powershell
flutter analyze
```

Expected: No analyzer issues, or only documented issues unrelated to stage-one changes.

- [ ] **Step 4: Manually verify wrong-word review flow**

Run the app:

```powershell
flutter run -d windows
```

Manual checks:

1. Open wrong words page.
2. If there are no wrong words, confirm empty state still works.
3. Add or trigger at least one wrong word through learning.
4. Return to wrong words page.
5. Click special review.
6. Select a mode.
7. Confirm learning screen opens with wrong words.
8. Complete the session.
9. Confirm wrong words page refreshes.
10. Confirm no crash when selecting a subset and reviewing only selected words.

- [ ] **Step 5: Update handoff document**

Update `docs/current-progress-handoff.md` sections:

```markdown
## 阶段一进展

已完成：
- 清理 analyzer 历史问题。
- 新增专项学习请求模型。
- WrongWordService 已接入 DIContainer。
- 错词专项复习入口已从占位改为可用流程。
- 学习进度已支持来源标题和 progressKey。

验证命令：
```bash
dart test test/study_progress_logic_test.dart test/specialized_study_request_test.dart test/wrong_word_review_result_test.dart
flutter analyze
```
```

- [ ] **Step 6: Do not commit unless explicitly requested**

Do not run `git commit` unless the user explicitly asks. If the user asks to commit, use a conventional commit message such as:

```bash
git add .
git commit -m "feat: add wrong words specialized review"
```

---

## Plan Self-Review

### Spec coverage

| 阶段一需求 | Covered by |
|---|---|
| 清理 analyzer 剩余问题 | Task 1, Task 10 |
| 完成错词专项复习 | Task 4, Task 6, Task 7 |
| 全部/选中错词复习 | Task 4, Task 7 |
| 高频错词优先 | Existing DAO order, Task 3 |
| 错词强化训练基础版 | Task 2, Task 3, Task 8 |
| 统一错误处理 | Task 6, Task 9 |
| 减少 UI 直接创建 Service | Task 4, Task 7, Task 9 |
| 增强学习进度保存 | Task 5, Task 6, Task 9 |
| 测试和 analyzer 验证 | Task 2, Task 3, Task 5, Task 10 |

### Placeholder scan

The plan contains no TBD placeholders. Steps include exact files, code snippets, commands, and expected outcomes.

### Type consistency

The plan consistently uses `StudySource`, `SpecializedStudyRequest`, `WrongWordReviewResult`, `WrongWordStrength`, `SpecializedStudyService`, and existing `StudyProgressLogic` names across tasks.

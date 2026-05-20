# Architecture Notes

This document describes the current architecture boundaries for QingMang Weiji.

## Layers

### UI Layer

Location: `lib/screens/`, `lib/widgets/`

Responsibilities:

- Build Flutter UI.
- Read state from Providers.
- Trigger user actions.
- Show dialogs, navigation, and lightweight feedback.

Rules:

- Do not call `DatabaseService` directly for normal entity operations.
- Prefer Repository methods for data access.
- Keep business logic out of widgets when it can live in a Provider or Service.
- Use `ErrorHandler` for repeated success/error feedback patterns.

Allowed direct service calls:

- UI-specific interactions such as file picking or confirmation dialogs.
- Coarse-grained data operations exposed by a Service, such as `BackupService.backupData()`.

## Provider Layer

Location: `lib/services/providers/`

Providers own app state that affects widgets.

Current providers:

- `ThemeProvider`: theme mode and locale preference.
- `WordBookProvider`: word book list, current book, due count, daily new count, notification setting.
- `StudySettingsProvider`: study limits, audio settings, dictionary settings, streak data.

Responsibilities:

- Store UI-observable state.
- Load and persist preferences.
- Coordinate repository calls needed to update state.
- Notify listeners after state changes.

Rules:

- Providers may use repositories from `DIContainer.instance`.
- Providers should not contain low-level database SQL or file I/O.
- Providers should expose intent-focused methods, for example `loadWordBooks()` or `setDailyNewWords()`.

## Repository Layer

Location: `lib/services/repositories/`

Repositories wrap entity-oriented data access.

Current repositories:

- `WordRepository`
- `WordBookRepository`
- `ReviewRepository`
- `StatsRepository`

Responsibilities:

- Provide a stable API for data access.
- Hide `DatabaseService` from screens and providers.
- Normalize error handling for data access methods.
- Return safe fallback values where appropriate.

Rules:

- Repositories are instance-based and supplied by `DIContainer`.
- Screens should access repositories through `context.read<DIContainer>()`.
- New repository methods should be instance methods, not `static` methods.

Example:

```dart
final wordRepository = context.read<DIContainer>().wordRepository;
final words = await wordRepository.getWordsByBook(bookId);
```

## Service Layer

Location: `lib/services/`

Services handle cross-cutting or domain-specific operations that are not simply entity CRUD.

Examples:

- `DatabaseService`: low-level SQLite access and schema management.
- `BackupService`: backup, restore, and clear-data orchestration.
- `DefinitionService`: local/online definition enrichment.
- `TtsService`: pronunciation playback.
- `WrongWordService`: wrong-word collection operations.
- `SeedService`: built-in word book initialization.

Rules:

- `DatabaseService` should remain the low-level persistence boundary.
- UI should avoid direct `DatabaseService` calls unless there is a clear low-level operation with no service/repository wrapper yet.
- New cross-entity workflows should usually be added to a Service, not a screen.

## Dependency Injection

Location: `lib/services/di_container.dart`

`DIContainer` owns shared service and repository instances.

Responsibilities:

- Initialize shared services.
- Provide repository instances.
- Make dependencies available through Provider in `main.dart`.

Usage from widgets:

```dart
final di = context.read<DIContainer>();
final stats = await di.statsRepository.getStudyStats();
```

Usage from providers:

```dart
final _wordBookRepository = DIContainer.instance.wordBookRepository;
```

Rules:

- Add new long-lived repositories or services to `DIContainer`.
- Avoid creating repeated service instances in screens if a shared instance exists.
- Prefer constructor or container access over static method calls for testability.

## Testing Strategy

Pure Dart tests:

- Use `package:test/test.dart`.
- Run with `dart test` to avoid Flutter/native SQLite asset setup.
- Current pure tests cover models, translations, and review scheduling.

Flutter or database tests:

- May require native SQLite setup on desktop.
- Keep them isolated from pure logic tests when possible.

Recommended commands:

```bash
dart test test/review_scheduler_test.dart test/word_model_test.dart test/translations_test.dart
flutter analyze
```

## Current Migration Status

Completed:

- Split the old `AppProvider` into focused providers.
- Removed the obsolete `AppProvider` file.
- Added Repository layer.
- Converted Repository APIs from static calls to instance usage through `DIContainer`.
- Extracted large UI components from study, home, stats, and settings screens.
- Moved backup/restore orchestration into `BackupService`.

Still worth improving later:

- Move more repeated SnackBar usage to `ErrorHandler`.
- Add more Provider and Repository tests.
- Isolate database tests from default test commands.
- Move more file import/export UI workflows out of screens if they grow further.

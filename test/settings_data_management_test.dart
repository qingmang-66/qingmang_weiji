import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qingmang_weiji/services/backup_service.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('数据库刷新信号由首页和计划页消费', () {
    final home = [
      'lib/screens/home_screen.dart',
      'lib/screens/home_screen/dashboard.dart',
    ].map((p) => File(p).readAsStringSync()).join('\n');
    final plans = File('lib/screens/study_plan_screen.dart').readAsStringSync();

    expect(home, contains('databaseRefreshSignal.addListener'));
    expect(home, contains('databaseRefreshSignal.removeListener'));
    expect(plans, contains('databaseRefreshSignal.addListener'));
    expect(plans, contains('databaseRefreshSignal.removeListener'));
  });

  test('删除备份成功后当前选择器即时移除文件', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, contains('StatefulBuilder'));
    expect(source, contains('files.removeWhere'));
    expect(source, contains('setPickerState'));
  });

  test('设置页备份/导入兼容 Android SAF 与分享', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(source, contains('PickedFileHelper.pickSingleFile'));
    expect(source, contains('backupAndShare'));
    expect(source, contains('_restoreFromExternalFile'));
    expect(source, contains('pickExternalBackup'));
  });

  test('初始化应用会清空、刷新并触发引导信号', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(source, contains('DatabaseService.clearAllData()'));
    expect(source, contains("prefs.setBool('hasSeenOnboarding', false)"));
    expect(source, contains('themeProvider.loadPreferences()'));
    expect(source, contains('studySettingsProvider.loadPreferences()'));
    // 初始化要重置**全部**偏好：词库（含通知开关/排序）、阅读设置、词集设置
    // 都走 _refreshAfterDataSwap 重新载入，否则当场看"没重置"、重启后突变
    expect(source, contains('_refreshAfterDataSwap'));
    expect(source, contains('ReaderSettingsProvider'));
    expect(source, contains('WordCollectionSettingsProvider'));
    expect(source, contains('WordBookProvider'));
    expect(source, contains('notifyDatabaseRefreshed()'));
    expect(source, contains('showOnboardingAfterInitialization()'));
    // 成功后直接进引导，不依赖可能被覆盖的成功弹窗
    expect(source, isNot(contains('initializeSuccess')));
  });

  /// 「初始化应用」= 回到全新状态：数据清空、引导重看（含各页功能提示）。
  /// 此前用例断言"保留已看标记"（快照/恢复），但实现与该设置项文案
  /// （"清空数据并重新显示首次引导页"）的意图是重新展示整套引导——
  /// 该断言编码了一个未采用的方案，用例长期失败。
  /// 现按实现意图断言：初始化会清空教学标记，且显式重置在 prefs.clear 之前
  /// 执行（放 clear 之后会因标记已被清空而成为 no-op）。
  test('初始化应用清空教学提示的已看标记（引导重播）', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();
    final guide = File('lib/services/guide_service.dart').readAsStringSync();

    expect(source, contains('GuideService.resetAll()'));
    expect(source, contains('prefs.clear()'));
    expect(guide, contains('static Future<void> resetAll()'));
    // 显式重置必须在 clear 之前：clear 之后调用只会是 no-op
    expect(
      source.indexOf('GuideService.resetAll()') <
          source.indexOf('prefs.clear()'),
      isTrue,
    );
  });

  test('错误处理保留真实异常详情', () {
    final source = File('lib/utils/error_handler.dart').readAsStringSync();
    expect(source, contains(r'${fallbackMessage ?? tr.dbError}\n$detail'));
    expect(source, contains('no such table'));
  });

  group('备份与清空对缺失表容错', () {
    late Database db;
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          // 故意只建部分表，模拟旧库缺表
          await database.execute(
            'CREATE TABLE word_books (id INTEGER PRIMARY KEY, name TEXT)',
          );
          await database.execute(
            'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, word_book_id INTEGER)',
          );
        },
      );
      tempDir = await Directory.systemTemp.createTemp('settings_backup_');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('exportAll 跳过缺失表仍可导出', () async {
      await db.insert('word_books', {'id': 1, 'name': 't'});
      final exported = await DatabaseService.exportAllFrom(db);
      expect(exported['schemaVersion'], DatabaseService.schemaVersion);
      final tables = exported['tables'] as Map;
      expect(tables['word_books'], isNotEmpty);
      expect(tables['wrong_words_strength'], isEmpty);
    });

    test('backupData 写入应用备份目录且可被列表发现', () async {
      BackupService.configureForTesting(
        backupDirectoryLoader: () async => tempDir.path,
        exportLoader: () => DatabaseService.exportAllFrom(db),
        importLoader: (_) async {},
      );
      final path = await BackupService.backupData();
      expect(File(path).parent.path, tempDir.path);
      expect(await File(path).exists(), isTrue);
      final files = await BackupService.getBackupFiles();
      expect(files.map((f) => p.basename(f.path)), contains(p.basename(path)));
    });
  });
}

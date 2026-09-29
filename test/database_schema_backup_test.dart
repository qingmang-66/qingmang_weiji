import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/backup_service.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:qingmang_weiji/utils/file_compat.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: DatabaseService.databaseVersion,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: DatabaseService.createSchema,
    );
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('生产schema包含全部备份表及关键模型字段', () async {
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name']).toSet();
    expect(tables, containsAll(DatabaseService.backupTables));

    final wrongColumns = (await db.rawQuery(
      'PRAGMA table_info(wrong_words)',
    )).map((row) => row['name']).toSet();
    expect(wrongColumns, contains('strength'));
  });

  test('全新安装的schema包含DAO会写入的全部列（防止onCreate与onUpgrade漂移）', () async {
    // 这里列的是"DAO 写入但历史上只在 upgradeSchema 里补过"的列：
    // 新库只走 onCreate、不走 onUpgrade，漏在 createSchema 上会让
    // 全新安装的相关功能直接报 "has no column named xxx"。
    const daoTouchedColumns = <String, List<String>>{
      'reader_bookmarks': ['word_text', 'custom_name', 'word_index'],
      'wrong_words': ['strength', 'correct_streak', 'note'],
      'review_records': ['first_learned_at', 'ease_factor', 'repetitions'],
      'study_progress': ['source', 'progress_key', 'title'],
      'word_books': ['version', 'sort_order'],
    };
    for (final entry in daoTouchedColumns.entries) {
      final columns = (await db.rawQuery(
        'PRAGMA table_info(${entry.key})',
      )).map((row) => row['name']).toSet();
      expect(
        columns,
        containsAll(entry.value),
        reason: '全新安装的表 ${entry.key} 缺少列 ${entry.value}',
      );
    }
  });

  test('已下线的收藏夹与自定义单词集表不再存在', () async {
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name']).toSet();
    expect(tables, isNot(contains('favorites')));
    expect(tables, isNot(contains('custom_word_sets')));
    expect(tables, isNot(contains('custom_word_set_items')));
  });

  test('v8到v12升级至当前版本后补齐字段和唯一索引', () async {
    for (final oldVersion in [8, 9, 10, 11, 12]) {
      final path = '${tempDir.path}/v$oldVersion.db';
      final oldDb = await openDatabase(
        path,
        version: 1,
        onCreate: DatabaseService.createSchema,
      );
      await oldDb.execute('DROP INDEX IF EXISTS idx_review_word_id');
      await oldDb.execute('DROP INDEX IF EXISTS idx_wrong_word_id');
      await oldDb.close();
      final upgraded = await openDatabase(path);
      await DatabaseService.upgradeSchema(
        upgraded,
        oldVersion,
        DatabaseService.databaseVersion,
      );
      final indexes = (await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      )).map((row) => row['name']).toSet();
      expect(indexes, containsAll(['idx_review_word_id', 'idx_wrong_word_id']));
      await upgraded.close();
    }
  });

  test('导出包含结构版本且恢复忽略未知字段', () async {
    await db.insert('word_books', {'id': 1, 'name': '测试词库'});
    await db.insert('words', {'id': 1, 'word': 'hello', 'word_book_id': 1});
    final exported = await DatabaseService.exportAllFrom(db);
    expect(exported['schemaVersion'], DatabaseService.schemaVersion);
    expect(exported['tables'], isA<Map>());

    final tables = Map<String, dynamic>.from(exported['tables'] as Map);
    final words = List<Map<String, dynamic>>.from(
      (tables['words'] as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      ),
    );
    words.first['future_field'] = 'ignored';
    tables['words'] = words;
    await DatabaseService.importAllInto(db, tables);
    expect((await db.query('words')).single['word'], 'hello');
  });

  test('恢复按父子顺序且外键失败时完整回滚', () async {
    await db.insert('word_books', {'id': 7, 'name': '原数据'});
    final tables = <String, dynamic>{
      for (final table in DatabaseService.backupTables) table: <dynamic>[],
    };
    tables['word_books'] = [
      <String, dynamic>{'id': 1, 'name': '新数据'},
    ];
    tables['words'] = [
      <String, dynamic>{'id': 1, 'word': 'bad', 'word_book_id': 999},
    ];

    await expectLater(
      DatabaseService.importAllInto(db, tables),
      throwsA(anything),
    );
    expect((await db.query('word_books')).single['name'], '原数据');
  });

  test('恢复备份保留阅读模式数据（勾记/书签/阅读进度）', () async {
    await db.insert('word_books', {'id': 1, 'name': '书'});
    await db.insert('words', {'id': 1, 'word': 'hello', 'word_book_id': 1});
    final now = DateTime.now().toIso8601String();
    await db.insert('reader_marks', {'word_id': 1, 'created_at': now});
    await db.insert('reader_bookmarks', {
      'word_book_id': 1,
      'word_index': 3,
      'created_at': now,
    });
    await db.insert('reader_progress', {
      'word_book_id': 1,
      'word_index': 7,
      'updated_at': now,
    });

    final exported = await DatabaseService.exportAllFrom(db);
    final tables = Map<String, dynamic>.from(exported['tables'] as Map);

    // 恢复会先清空再回填：三张 reader 表若不在回填列表里，数据会被永久清掉
    await DatabaseService.importAllInto(db, tables);

    expect((await db.query('reader_marks')).length, 1);
    expect((await db.query('reader_bookmarks')).length, 1);
    final progress = (await db.query('reader_progress')).single;
    expect(progress['word_index'], 7);
  });

  test('词库升级迁移：记录随单词文本迁移，未匹配与已占用的保持原样', () async {
    final now = DateTime.now().toIso8601String();
    await db.insert('word_books', {'id': 1, 'name': '旧库', 'version': '1.0'});
    await db.insert('word_books', {'id': 2, 'name': '新库', 'version': '2.0'});
    // 11 -> 21 大小写不敏感匹配；12 在新库中不存在
    await db.insert('words', {'id': 11, 'word': 'apple', 'word_book_id': 1});
    await db.insert('words', {'id': 21, 'word': 'Apple', 'word_book_id': 2});
    await db.insert('words', {'id': 12, 'word': 'gone', 'word_book_id': 1});
    // 新库上该词已有一条更近的记录（22 占用目标），迁移时必须跳过而不是覆盖
    await db.insert('words', {'id': 22, 'word': 'pear', 'word_book_id': 1});
    await db.insert('words', {'id': 23, 'word': 'pear', 'word_book_id': 2});

    for (final wordId in [11, 12, 22, 23]) {
      await db.insert('review_records', {
        'word_id': wordId,
        'next_review': now,
        'last_review': now,
        'first_learned_at': now,
      });
    }

    await DatabaseService.migrateWordBookReferences(
      fromBookId: 1,
      toBookId: 2,
      databaseOverride: db,
    );

    // 匹配到的词：旧记录迁移到新词 id
    expect((await db.query('review_records', where: 'word_id = 21')).length, 1);
    expect((await db.query('review_records', where: 'word_id = 11')).length, 0);
    // 未匹配到的词：记录保持原样（随后随旧词库清理）
    expect((await db.query('review_records', where: 'word_id = 12')).length, 1);
    // 目标已被占用：两边记录都保留，不做覆盖
    expect((await db.query('review_records', where: 'word_id = 23')).length, 1);
    expect((await db.query('review_records', where: 'word_id = 22')).length, 1);
    expect((await db.query('review_records')).length, 4);
  });

  test('备份校验拒绝无效结构和不支持的schemaVersion', () async {
    BackupService.configureForTesting(
      backupDirectoryLoader: () async => tempDir.path,
      exportLoader: () => DatabaseService.exportAllFrom(db),
      importLoader: (tables) => DatabaseService.importAllInto(db, tables),
    );
    Future<void> expectInvalid(dynamic value, String message) async {
      final file = File('${tempDir.path}/${message.hashCode}.json');
      await file.writeAsString(jsonEncode(value));
      await expectLater(
        BackupService.restoreData(file.path),
        throwsA(predicate((e) => e.toString().contains(message))),
      );
    }

    await expectInvalid([], '根节点必须是对象');
    await expectInvalid({
      'appVersion': '2.0.1',
      'tables': {},
    }, '缺少schemaVersion');
    await expectInvalid({
      'appVersion': '2.0.1',
      'schemaVersion': 999,
      'tables': {},
    }, '不支持的schemaVersion');
    await expectInvalid({
      'appVersion': '2.0.1',
      'schemaVersion': 1,
      'tables': [],
    }, 'tables必须是对象');
    await expectInvalid({
      'appVersion': '2.0.1',
      'schemaVersion': 1,
      'tables': {'words': {}},
    }, 'words必须是数组');
    await expectInvalid({
      'appVersion': '2.0.1',
      'schemaVersion': 1,
      'tables': {
        'words': [1],
      },
    }, 'words中包含无效记录');
  });

  test('备份使用紧凑JSON且保持现有schema兼容', () async {
    await db.insert('word_books', {'id': 1, 'name': '兼容词库'});
    BackupService.configureForTesting(
      backupDirectoryLoader: () async => tempDir.path,
      exportLoader: () => DatabaseService.exportAllFrom(db),
      importLoader: (tables) => DatabaseService.importAllInto(db, tables),
    );

    final path = await BackupService.backupData();
    final raw = await File(path).readAsString();
    expect(raw, isNot(contains('\n')));
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], DatabaseService.schemaVersion);

    await db.delete('word_books');
    await BackupService.restoreData(path);
    expect((await db.query('word_books')).single['name'], '兼容词库');
  });

  test('备份默认写入应用备份目录且使用临时文件原子替换', () async {
    BackupService.configureForTesting(
      backupDirectoryLoader: () async => tempDir.path,
      exportLoader: () => DatabaseService.exportAllFrom(db),
      importLoader: (tables) => DatabaseService.importAllInto(db, tables),
    );
    final path = await BackupService.backupData();
    expect(File(path).parent.path, tempDir.path);
    expect(await File(path).exists(), isTrue);
    expect(await File('$path.tmp').exists(), isFalse);
  });

  test('替换已有备份失败时保留旧文件', () async {
    final target = File('${tempDir.path}/backup.json');
    await target.writeAsString('old-backup');
    BackupService.configureForTesting(
      backupDirectoryLoader: () async => tempDir.path,
      exportLoader: () => DatabaseService.exportAllFrom(db),
      importLoader: (tables) => DatabaseService.importAllInto(db, tables),
      fileReplacer: ({required temp, required target}) async {
        throw const FileSystemException('replace failed');
      },
    );

    await expectLater(
      BackupService.backupData(filePath: target.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.exists(), isTrue);
    expect(await target.readAsString(), 'old-backup');
    expect(await File('${target.path}.tmp').exists(), isFalse);
    expect(await File('${target.path}.bak').exists(), isFalse);
  });

  test('atomicReplaceTarget失败时从bak恢复旧文件', () async {
    final target = File('${tempDir.path}/restore.json');
    final temp = File('${tempDir.path}/restore.json.tmp');
    await target.writeAsString('old-backup');
    //temp不存在，rename与copy都会失败，应自动从.bak还原

    await expectLater(
      BackupService.atomicReplaceTarget(
        temp: AppFile(temp.path),
        target: AppFile(target.path),
      ),
      throwsA(anything),
    );
    expect(await target.exists(), isTrue);
    expect(await target.readAsString(), 'old-backup');
    expect(await File('${target.path}.bak').exists(), isFalse);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:qingmang_weiji/services/import_service.dart';
import 'package:qingmang_weiji/services/word_import_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('word_import_test_');
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseService.createSchema(db, DatabaseService.databaseVersion);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<File> file(String name, String content) async {
    final result = File('${tempDir.path}${Platform.pathSeparator}$name');
    await result.writeAsString(content);
    return result;
  }

  test('TXT按行导入且创建用户词库', () async {
    final source = await file('words.txt', 'hello\nworld\n');
    final result = await WordImportService.importWordsFromFile(
      source.path,
      'TXT词库',
      database: db,
    );

    expect(result.count, 2);
    final books = await db.query('word_books');
    expect(books.single['is_built_in'], 0);
    expect((await db.query('words', orderBy: 'id')).map((row) => row['word']), [
      'hello',
      'world',
    ]);
  });

  test('CSV保留引号字段中的逗号并解码双引号', () async {
    final source = await file(
      'words.csv',
      'word,phonetic,definition,example,example_translation\n'
          '"hello","həˈləʊ","你好,问候","He said ""hello""","他说你好"\n',
    );
    await WordImportService.importWordsFromFile(
      source.path,
      'CSV词库',
      database: db,
    );

    final word = (await db.query('words')).single;
    expect(word['word'], 'hello');
    expect(word['definition'], '你好,问候');
    expect(word['example'], 'He said "hello"');
  });

  test('JSON对象数组映射单词字段', () async {
    final source = await file(
      'words.json',
      jsonEncode([
        {
          'word': 'apple',
          'phonetic': 'ˈæpl',
          'definition': '苹果',
          'example': 'An apple.',
          'exampleTranslation': '一个苹果。',
        },
      ]),
    );
    final result = await WordImportService.importWordsFromFile(
      source.path,
      'JSON词库',
      database: db,
    );

    expect(result.count, 1);
    final word = (await db.query('words')).single;
    expect(word['phonetic'], 'ˈæpl');
    expect(word['example_translation'], '一个苹果。');
  });

  test('ImportService显式CSV路径按CSV解析', () async {
    final source = await file(
      'explicit.csv',
      'word,phonetic,definition\nexplicit_csv,/csv/,CSV释义\n',
    );
    final serviceDb = await DatabaseService.database;
    final bookId = await serviceDb.insert('word_books', {
      'name': '显式CSV-${DateTime.now().microsecondsSinceEpoch}',
      'description': '',
      'is_built_in': 0,
      'total_words': 0,
    });

    final result = await ImportService.importFromFile(
      bookId,
      filePath: source.path,
    );

    expect(result.success, isTrue);
    expect(result.count, 1);
    final rows = await serviceDb.query(
      'words',
      where: 'word_book_id = ?',
      whereArgs: [bookId],
    );
    expect(rows.single['word'], 'explicit_csv');
    expect(rows.single['definition'], 'CSV释义');
    await serviceDb.delete('word_books', where: 'id = ?', whereArgs: [bookId]);
  });

  test('ImportService显式JSON路径按JSON解析', () async {
    final source = await file(
      'explicit.json',
      jsonEncode([
        {'word': 'explicit_json', 'phonetic': '/json/', 'definition': 'JSON释义'},
      ]),
    );
    final serviceDb = await DatabaseService.database;
    final bookId = await serviceDb.insert('word_books', {
      'name': '显式JSON-${DateTime.now().microsecondsSinceEpoch}',
      'description': '',
      'is_built_in': 0,
      'total_words': 0,
    });

    final result = await ImportService.importFromFile(
      bookId,
      filePath: source.path,
    );

    expect(result.success, isTrue);
    expect(result.count, 1);
    final rows = await serviceDb.query(
      'words',
      where: 'word_book_id = ?',
      whereArgs: [bookId],
    );
    expect(rows.single['word'], 'explicit_json');
    expect(rows.single['definition'], 'JSON释义');
    await serviceDb.delete('word_books', where: 'id = ?', whereArgs: [bookId]);
  });

  test('同名词库冲突明确失败且不写入任何数据', () async {
    await db.insert('word_books', {
      'name': '重复词库',
      'description': '',
      'is_built_in': 0,
      'total_words': 0,
    });
    final source = await file('words.txt', 'hello\n');

    await expectLater(
      WordImportService.importWordsFromFile(source.path, '重复词库', database: db),
      throwsA(predicate((e) => e.toString().contains('词库名称已存在'))),
    );
    expect((await db.query('word_books')).length, 1);
    expect(await db.query('words'), isEmpty);
  });

  test('CSV未闭合引号失败且事务不留下空词库', () async {
    final source = await file('broken.csv', 'word,definition\n"hello,你好\n');

    await expectLater(
      WordImportService.importWordsFromFile(source.path, '损坏词库', database: db),
      throwsA(predicate((e) => e.toString().contains('CSV 引号未闭合'))),
    );
    expect(await db.query('word_books'), isEmpty);
  });
}

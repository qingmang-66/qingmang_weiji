import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/word_book.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:qingmang_weiji/services/import_service.dart';
import 'package:qingmang_weiji/services/wrong_word_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await DatabaseService.database;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_service_test_');
    await db.delete('words');
    await db.delete('word_books');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<File> file(String name, String content) async {
    final result = File('${tempDir.path}${Platform.pathSeparator}$name');
    await result.writeAsString(content);
    return result;
  }

  test('显式CSV路径按CSV格式导入', () async {
    final bookId = await DatabaseService.insertWordBook(WordBook(name: 'CSV词库'));
    final source = await file(
      'words.csv',
      'word,phonetic,definition\nhello,həˈləʊ,你好\n',
    );

    final result = await ImportService.importFromFile(
      bookId,
      filePath: source.path,
    );

    expect(result.success, isTrue);
    expect(result.count, 1);
    final word = (await db.query('words')).single;
    expect(word['word'], 'hello');
    expect(word['definition'], '你好');
  });

  test('显式JSON路径按JSON格式导入', () async {
    final bookId = await DatabaseService.insertWordBook(WordBook(name: 'JSON词库'));
    final source = await file(
      'words.json',
      jsonEncode([
        {'word': 'apple', 'phonetic': 'ˈæpl', 'definition': '苹果'},
      ]),
    );

    final result = await ImportService.importFromFile(
      bookId,
      filePath: source.path,
    );

    expect(result.success, isTrue);
    expect(result.count, 1);
    final word = (await db.query('words')).single;
    expect(word['word'], 'apple');
    expect(word['definition'], '苹果');
  });

  test('addWrongWord写入失败时向调用方传播异常', () async {
    await expectLater(
      WrongWordService().addWrongWord(-1),
      throwsA(isA<DatabaseException>()),
    );
  });
}

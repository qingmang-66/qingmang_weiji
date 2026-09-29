import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../utils/import_text.dart';
import '../utils/json_guard.dart';
import 'import_io.dart' if (dart.library.html) 'import_web.dart' as io;
import 'database_service.dart';

class ImportResult {
  final int count;
  final int wordBookId;
  const ImportResult(this.count, this.wordBookId);
}

/// isolate 入口：必须是顶层函数才能传给 compute
List<Map<String, String?>> _parseEntry((String, String) args) {
  final (content, ext) = args;
  return WordImportService._parse(content, ext);
}

class WordImportService {
  static const int _maxImportBytes = 10 * 1024 * 1024;

  /// CSV 首行视为表头时第一列允许的列名（精确匹配，避免子串误判）
  static const Set<String> _csvHeaderNames = {'word', '单词', '词汇'};

  static Future<ImportResult> importWordsFromFile(
    String filePath,
    String wordBookName, {
    String? description,
    Database? database,
  }) async {
    // 与 ImportService 保持一致的大小上限，防止误选超大文件导致内存暴涨
    final size = await io.fileSize(filePath);
    if (size != null && size > _maxImportBytes) {
      throw Exception('文件过大，请选择小于 ${_maxImportBytes ~/ (1024 * 1024)}MB 的词库文件');
    }
    final content = await io.readText(filePath);
    if (content == null) throw Exception('文件不存在：$filePath');
    final ext = path.extension(filePath.split('|').last).toLowerCase();
    final rows = await _parseAsync(content, ext);
    if (rows.isEmpty) throw Exception('文件中没有有效的单词');
    final db = database ?? await DatabaseService.database;
    return db.transaction((txn) async {
      final duplicate = await txn.query(
        'word_books',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [wordBookName],
        limit: 1,
      );
      if (duplicate.isNotEmpty) throw Exception('词库名称已存在');
      final bookId = await txn.insert('word_books', {
        'name': wordBookName,
        'description': description ?? '从文件导入的单词列表',
        'is_built_in': 0,
        'total_words': rows.length,
      });
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert('words', {
          'word': row['word']!,
          'phonetic': row['phonetic'] ?? '',
          'definition': row['definition'] ?? '',
          'example': row['example'],
          'example_translation': row['exampleTranslation'],
          'word_book_id': bookId,
        });
      }
      await batch.commit(noResult: true);
      return ImportResult(rows.length, bookId);
    });
  }

  /// 超过该字符数时改用 isolate 解析（小文件直接同步解析，省掉 isolate 启动开销）
  static const int _isolateParseThreshold = 256 * 1024;

  /// 解析文件内容，大文件在后台 isolate 中执行
  static Future<List<Map<String, String?>>> _parseAsync(
    String content,
    String ext,
  ) async {
    if (kIsWeb || content.length < _isolateParseThreshold) {
      return _parse(content, ext);
    }
    return compute(_parseEntry, (content, ext));
  }

  static List<Map<String, String?>> _parse(String content, String ext) {
    // 统一剥掉 UTF-8 BOM：jsonDecode 遇到它会直接报错，TXT 路径则会把
    // BOM 当成第一个单词的首字符入库（永远查不到的乱码词）
    final text = stripBom(content);
    if (ext == '.json') return _dedupeByWord(_parseJson(text));
    if (ext == '.csv') return _dedupeByWord(_parseCsv(text));
    return _dedupeByWord(_parseLines(text));
  }

  /// 按 word 归一化（trim + 小写）去重，保留首次出现的行。
  ///
  /// words 表没有 (word, word_book_id) 唯一约束：文件内的重复行会各插一条，
  /// 同一份文件反复导入也会让词条成倍膨胀。这里在解析出口统一去重，
  /// 返回条数即写入条数（total_words 与 ImportResult.count 都取自它）。
  static List<Map<String, String?>> _dedupeByWord(
    List<Map<String, String?>> rows,
  ) {
    final seen = <String>{};
    final result = <Map<String, String?>>[];
    for (final row in rows) {
      final key = (row['word'] ?? '').trim().toLowerCase();
      if (key.isEmpty) continue;
      if (seen.add(key)) result.add(row);
    }
    return result;
  }

  // CSV 解析：支持引号包裹字段、字段内逗号、**字段内换行**、双引号转义；
  // 首行为表头时跳过。未闭合引号仍然抛异常（保持原有行为与事务回滚）。
  static List<Map<String, String?>> _parseCsv(String content) {
    final records = _splitCsvRecords(content);
    if (records.isEmpty) return [];
    //表头识别用精确列名白名单：旧实现是 contains('word') 的子串匹配，
    //无表头 CSV 的首词若是 word/password/sword/keyword 会被当成表头跳过
    final first = records.first;
    final startIndex =
        first.isNotEmpty &&
            _csvHeaderNames.contains(first.first.trim().toLowerCase())
        ? 1
        : 0;
    final rows = <Map<String, String?>>[];
    for (var i = startIndex; i < records.length; i++) {
      final parts = records[i];
      if (parts.isEmpty) continue;
      if (parts.length == 1 && parts.first.trim().isEmpty) continue;
      rows.add({
        'word': parts[0].trim(),
        'phonetic': parts.length > 1 ? parts[1].trim() : null,
        'definition': parts.length > 2 ? parts[2].trim() : null,
        'example': parts.length > 3 ? parts[3].trim() : null,
        'exampleTranslation': parts.length > 4 ? parts[4].trim() : null,
      });
    }
    return rows.where((r) => (r['word'] ?? '').isNotEmpty).toList();
  }

  /// 按 CSV 规则把整段文本拆成"记录 × 字段"。
  ///
  /// 逐行 split 的实现在遇到"释义/例句里带换行"的引号字段（Excel、Google
  /// Sheets 导出的常见形态）时会报"引号未闭合"并让整份文件导入失败；
  /// 这里改成一趟字符状态机，引号内的换行属于字段内容。
  static List<List<String>> _splitCsvRecords(String content) {
    final records = <List<String>>[];
    var fields = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    var fieldStarted = false;

    void endField() {
      fields.add(current.toString());
      current.clear();
      fieldStarted = false;
    }

    void endRecord() {
      endField();
      records.add(fields);
      fields = <String>[];
    }

    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            current.write('"'); // 转义的双引号
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          current.write(char);
        }
        continue;
      }
      if (char == '"') {
        inQuotes = true;
        fieldStarted = true;
      } else if (char == ',') {
        endField();
      } else if (char == '\n') {
        endRecord();
      } else if (char == '\r') {
        // \r\n 当作一次换行；单独的 \r 也按换行处理
        if (i + 1 < content.length && content[i + 1] == '\n') i++;
        endRecord();
      } else {
        current.write(char);
      }
    }
    if (inQuotes) throw const FormatException('CSV 引号未闭合');
    // 结尾没有换行时补最后一条记录（纯空白不补）
    if (current.isNotEmpty || fields.isNotEmpty || fieldStarted) {
      endRecord();
    }
    return records;
  }

  static List<Map<String, String?>> _parseLines(String content) {
    final rows = <Map<String, String?>>[];
    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.contains(',')) {
        final parts = trimmed.split(',');
        rows.add({
          'word': parts[0].trim(),
          'phonetic': parts.length > 1 ? parts[1].trim() : null,
          //释义内含逗号时旧实现只取第 2 段会被截断：把第 2 段及之后的字段
          //重新拼回（本分支不解析 example，故一并并入释义）
          'definition': parts.length > 2
              ? parts.sublist(2).map((s) => s.trim()).join(',')
              : null,
        });
      } else if (trimmed.contains('\t')) {
        final parts = trimmed.split('\t');
        rows.add({
          'word': parts[0].trim(),
          'definition': parts.length > 1 ? parts[1].trim() : null,
        });
      } else {
        rows.add({'word': trimmed});
      }
    }
    return rows.where((r) => (r['word'] ?? '').isNotEmpty).toList();
  }

  static List<Map<String, String?>> _parseJson(String content) {
    //JsonGuard：深嵌套 JSON 不会以 StackOverflowError 杀死导入 isolate
    var decoded = JsonGuard.decode(content);
    // 兼容 {"words": [...]}：本项目**自己的内置词库资产**就是这个结构，
    // 用户拿内置词库当模板导出自带词库时不该失败
    if (decoded is Map && decoded['words'] is List) {
      decoded = decoded['words'];
    }
    if (decoded is! List) {
      throw const FormatException('JSON 必须是数组，或形如 {"words": [...]} 的对象');
    }
    final rows = <Map<String, String?>>[];
    for (final item in decoded) {
      // 单项不合规只跳过该条，不再让整份文件导入失败（末尾的"没有有效单词"
      // 兜底仍然生效，避免全空文件静默成功）
      if (item is! Map) continue;
      final word = item['word']?.toString().trim() ?? '';
      if (word.isEmpty) continue;
      rows.add(<String, String?>{
        'word': word,
        'phonetic': item['phonetic']?.toString(),
        'definition': item['definition']?.toString(),
        'example': item['example']?.toString(),
        'exampleTranslation':
            (item['exampleTranslation'] ?? item['example_translation'])
                ?.toString(),
      });
    }
    return rows;
  }

  static Future<void> importAllWordBooks() async {
    if (kIsWeb) return;
    // 桌面/移动端批量导入逻辑由调用方触发，Web 跳过
  }
}

import '../models/word.dart';
import 'database_service.dart';

/// 错词本服务
/// 自动收集学习时标记为"忘记"或"模糊"的单词
/// 
/// 注意：数据库表由 DatabaseService 统一管理，此服务仅负责业务逻辑
class WrongWordService {
  // 私有构造函数，防止实例化
  WrongWordService._();
  
  // 单例实例
  static final WrongWordService _instance = WrongWordService._();
  
  // 工厂构造函数
  factory WrongWordService() => _instance;
  
  /// 初始化服务
  Future<void> init() async {
    // 初始化逻辑（如需要）
  }

  /// 添加错词
  Future<void> addWrongWord(int wordId, {String? note}) async {
    final db = await DatabaseService.database;
    
    // 检查是否已存在
    final existing = await db.query(
      'wrong_words',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    
    if (existing.isNotEmpty) {
      // 增加错误次数
      await db.update(
        'wrong_words',
        {
          'wrong_count': (existing[0]['wrong_count'] as int) + 1,
          'last_wrong_time': DateTime.now().toIso8601String(),
          'note': note ?? existing[0]['note'],
        },
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
    } else {
      // 新增记录
      await db.insert('wrong_words', {
        'word_id': wordId,
        'wrong_count': 1,
        'first_wrong_time': DateTime.now().toIso8601String(),
        'last_wrong_time': DateTime.now().toIso8601String(),
        'note': note,
      });
    }
  }

  /// 获取所有错词
  Future<List<Word>> getWrongWords({int? limit}) async {
    final db = await DatabaseService.database;
    
    String query = '''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      ORDER BY ww.wrong_count DESC, ww.last_wrong_time DESC
    ''';
    
    if (limit != null) {
      query += ' LIMIT $limit';
    }
    
    final result = await db.rawQuery(query);
    return result.map((row) => Word.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  /// 获取错词数量
  Future<int> getWrongWordCount() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM wrong_words');
    return (result[0]['count'] as int? ?? 0);
  }

  /// 获取错词错误次数
  Future<int> getWrongCount(int wordId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'wrong_words',
      columns: ['wrong_count'],
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    
    if (result.isNotEmpty) {
      return result[0]['wrong_count'] as int;
    }
    return 0;
  }

  /// 从错词本移除（标记为已掌握）
  Future<void> removeWrongWord(int wordId) async {
    final db = await DatabaseService.database;
    await db.delete(
      'wrong_words',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 批量移除错词
  Future<void> removeWrongWords(List<int> wordIds) async {
    final db = await DatabaseService.database;
    if (wordIds.isEmpty) return;
    
    final placeholders = wordIds.map((_) => '?').join(',');
    await db.delete(
      'wrong_words',
      where: 'word_id IN ($placeholders)',
      whereArgs: wordIds,
    );
  }

  /// 更新错词备注
  Future<void> updateNote(int wordId, String note) async {
    final db = await DatabaseService.database;
    await db.update(
      'wrong_words',
      {'note': note},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 获取错词统计
  Future<Map<String, dynamic>> getWrongWordStats() async {
    final db = await DatabaseService.database;
    
    final totalCount = await db.rawQuery('SELECT COUNT(*) as count FROM wrong_words');
    final totalWrongCount = await db.rawQuery('SELECT SUM(wrong_count) as sum FROM wrong_words');
    
    final highWrongWords = await db.rawQuery('''
      SELECT COUNT(*) as count FROM wrong_words WHERE wrong_count >= 5
    ''');
    
    return {
      'totalWrongWords': totalCount.first['count'] as int? ?? 0,
      'totalWrongTimes': totalWrongCount.first['sum'] as int? ?? 0,
      'highWrongWords': highWrongWords.first['count'] as int? ?? 0,
    };
  }

  /// 获取今日新增错词
  Future<List<Word>> getTodayWrongWords() async {
    final db = await DatabaseService.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final result = await db.rawQuery('''
      SELECT w.* FROM words w
      INNER JOIN wrong_words ww ON w.id = ww.word_id
      WHERE DATE(ww.last_wrong_time) = DATE(?)
      ORDER BY ww.last_wrong_time DESC
    ''', [startOfDay.toIso8601String()]);
    
    return result.map((row) => Word.fromMap(Map<String, dynamic>.from(row))).toList();
  }
}

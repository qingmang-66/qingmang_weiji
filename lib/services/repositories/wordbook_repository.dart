import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../models/word_book.dart';

/// 词库数据访问层
class WordBookRepository {
  /// 插入词库
  Future<int> insertWordBook(WordBook book) async {
    try {
      return await DatabaseService.insertWordBook(book);
    } catch (e) {
      debugPrint('WordBookRepository.insertWordBook error: $e');
      rethrow;
    }
  }

  /// 获取所有词库
  Future<List<WordBook>> getAllWordBooks() async {
    try {
      return await DatabaseService.getAllWordBooks();
    } catch (e) {
      debugPrint('WordBookRepository.getAllWordBooks error: $e');
      return [];
    }
  }

  /// 获取单个词库
  Future<WordBook?> getWordBook(int id) async {
    try {
      return await DatabaseService.getWordBook(id);
    } catch (e) {
      debugPrint('WordBookRepository.getWordBook error: $e');
      return null;
    }
  }

  /// 更新词库总词数
  Future<void> updateWordBookTotalWords(int bookId) async {
    try {
      await DatabaseService.updateWordBookTotalWords(bookId);
    } catch (e) {
      debugPrint('WordBookRepository.updateWordBookTotalWords error: $e');
      rethrow;
    }
  }

  /// 删除词库
  Future<void> deleteWordBook(int id) async {
    try {
      await DatabaseService.deleteWordBook(id);
    } catch (e) {
      debugPrint('WordBookRepository.deleteWordBook error: $e');
      rethrow;
    }
  }

  /// 批量删除词库
  Future<void> deleteWordBooksBatch(List<int> ids) async {
    try {
      await DatabaseService.deleteWordBooksBatch(ids);
    } catch (e) {
      debugPrint('WordBookRepository.deleteWordBooksBatch error: $e');
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../models/word_book.dart';

/// 词库数据访问层（带内存缓存）
class WordBookRepository {
  // 内存缓存：词库列表
  List<WordBook>? _cachedWordBooks;
  DateTime? _cacheTime;
  static const _cacheValidDuration = Duration(seconds: 30);

  bool get _cacheValid =>
      _cachedWordBooks != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheValidDuration;

  /// 使缓存失效（在增删改操作后调用）
  void invalidateCache() {
    _cachedWordBooks = null;
    _cacheTime = null;
  }

  /// 插入词库
  Future<int> insertWordBook(WordBook book) async {
    try {
      final id = await DatabaseService.insertWordBook(book);
      invalidateCache();
      return id;
    } catch (e) {
      debugPrint('WordBookRepository.insertWordBook error: $e');
      rethrow;
    }
  }

  /// 获取所有词库（带缓存）
  Future<List<WordBook>> getAllWordBooks() async {
    if (_cacheValid) {
      return _cachedWordBooks!;
    }
    try {
      _cachedWordBooks = await DatabaseService.getAllWordBooks();
      _cacheTime = DateTime.now();
      return _cachedWordBooks!;
    } catch (e) {
      debugPrint('WordBookRepository.getAllWordBooks error: $e');
      return [];
    }
  }

  /// 获取单个词库（优先从缓存查找，未命中则更新缓存）
  Future<WordBook?> getWordBook(int id) async {
    if (_cacheValid) {
      final cached = _cachedWordBooks!.cast<WordBook?>().firstWhere(
        (b) => b!.id == id,
        orElse: () => null,
      );
      if (cached != null) return cached;
    }
    try {
      final book = await DatabaseService.getWordBook(id);
      //仅在缓存新鲜且列表中不存在时补录，否则会向共享列表追加重复项
      if (book != null &&
          _cacheValid &&
          !_cachedWordBooks!.any((b) => b.id == book.id)) {
        _cachedWordBooks!.add(book);
      }
      return book;
    } catch (e) {
      debugPrint('WordBookRepository.getWordBook error: $e');
      return null;
    }
  }

  /// 更新词库总词数
  Future<void> updateWordBookTotalWords(int bookId) async {
    try {
      await DatabaseService.updateWordBookTotalWords(bookId);
      invalidateCache();
    } catch (e) {
      debugPrint('WordBookRepository.updateWordBookTotalWords error: $e');
      rethrow;
    }
  }

  /// 删除词库
  Future<void> deleteWordBook(int id) async {
    try {
      await DatabaseService.deleteWordBook(id);
      invalidateCache();
    } catch (e) {
      debugPrint('WordBookRepository.deleteWordBook error: $e');
      rethrow;
    }
  }

  /// 批量删除词库
  Future<void> deleteWordBooksBatch(List<int> ids) async {
    try {
      await DatabaseService.deleteWordBooksBatch(ids);
      invalidateCache();
    } catch (e) {
      debugPrint('WordBookRepository.deleteWordBooksBatch error: $e');
      rethrow;
    }
  }

  /// 重置词库学习进度（保留单词）
  Future<void> resetWordBookProgress(int id) async {
    try {
      await DatabaseService.resetWordBookProgress(id);
      invalidateCache();
    } catch (e) {
      debugPrint('WordBookRepository.resetWordBookProgress error: $e');
      rethrow;
    }
  }

  /// 更新词库排序顺序
  Future<void> updateSortOrder(int bookId, int sortOrder) async {
    try {
      await DatabaseService.updateSortOrder(bookId, sortOrder);
      invalidateCache();
    } catch (e) {
      debugPrint('WordBookRepository.updateSortOrder error: $e');
      rethrow;
    }
  }

  /// 批量更新排序顺序
  Future<void> updateSortOrders(Map<int, int> sortOrderMap) async {
    try {
      await DatabaseService.updateSortOrders(sortOrderMap);
      invalidateCache();
    } catch (e) {
      debugPrint('WordBookRepository.updateSortOrders error: $e');
      rethrow;
    }
  }
}

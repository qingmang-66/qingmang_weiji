import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di_container.dart';
import '../asset_wordbook_service.dart';
import '../repositories/wordbook_repository.dart';
import '../repositories/review_repository.dart';
import '../../models/word_book.dart';
import '../../models/word.dart';
import '../../models/wordbook_progress.dart';

/// 词库状态管理
class WordBookProvider extends ChangeNotifier {
  // 惰性解析 + 允许重复赋值：init() 会被首页错误页的"重试"再次调用，
  // 而 late final 二次赋值会抛 LateInitializationError —— 重试按钮点了没反应，
  // 错误页永久停留（异常还被丢进无人 await 的 Future 里）。
  WordBookRepository? _wordBookRepositoryOverride;
  ReviewRepository? _reviewRepositoryOverride;
  WordBookRepository get _wordBookRepository =>
      _wordBookRepositoryOverride ??= DIContainer.instance.wordBookRepository;
  ReviewRepository get _reviewRepository =>
      _reviewRepositoryOverride ??= DIContainer.instance.reviewRepository;

  List<WordBook> _wordBooks = [];
  WordBook? _currentBook;
  int _dueCount = 0;
  int _todayNewCount = 0;
  WordBookProgress? _currentBookProgress;
  // streak 统一由 StudySettingsProvider 管理，此处仅作缓存引用
  int _streak = 0;
  bool _isLoading = true;
  bool _hasInitError = false;
  String? _errorMessage;
  bool _disposed = false;

  // 通知设置
  bool _notificationsEnabled = true;

  // ============ 词库排序方式（正序 / 乱序） ============
  // 乱序不再需要单独导入一本"（乱序）"词库：每本词库自带排序开关，
  // 学习取词时按词库 id 做种子做确定性打乱（同库每次顺序一致）。
  static const String _keyShuffledOrderIds = 'wordBookShuffledOrderIds';

  /// 开启了乱序排序的词库 id 集合
  Set<int> _shuffledOrderIds = <int>{};

  /// 该词库是否为乱序排序
  bool isShuffledOrder(int? bookId) =>
      bookId != null && _shuffledOrderIds.contains(bookId);

  /// 切换词库的单词排序方式（正序 / 乱序）
  Future<void> setShuffledOrder(WordBook book, bool value) async {
    final id = book.id;
    if (id == null || isShuffledOrder(id) == value) return;
    final next = Set<int>.of(_shuffledOrderIds);
    if (value) {
      next.add(id);
    } else {
      next.remove(id);
    }
    _shuffledOrderIds = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _keyShuffledOrderIds,
        next.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      debugPrint('保存词库排序方式失败：$e');
    }
  }

  /// 恢复各词库的排序方式
  Future<void> _loadShuffledOrderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_keyShuffledOrderIds) ?? const [];
      _shuffledOrderIds = raw
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toSet();
    } catch (e) {
      debugPrint('加载词库排序方式失败：$e');
    }
  }

  /// 名字是否为「（乱序）」独立词库（旧版内置词库的变体，现合并进排序开关）
  static bool _isShuffledVariantName(String name) =>
      AssetWordBookService.isShuffledVariantName(name);

  /// 词库列表（只读视图）。
  ///
  /// 返回不可变视图：内部 reorderWordBooks 会就地增删同一个 List，
  /// 直接暴露对象会让外部（页面）在不触发 notifyListeners 的情况下改到状态。
  List<WordBook> get wordBooks => List.unmodifiable(_wordBooks);
  WordBook? get currentBook => _currentBook;
  int get dueCount => _dueCount;
  int get todayNewCount => _todayNewCount;
  WordBookProgress? get currentBookProgress => _currentBookProgress;
  int get streak => _streak;
  bool get isLoading => _isLoading;
  bool get hasInitError => _hasInitError;
  String? get errorMessage => _errorMessage;
  bool get notificationsEnabled => _notificationsEnabled;

  /// 设置通知开关（落盘失败要回滚，否则内存显示已改、磁盘还是旧值，
  /// 重启后开关"自己变回去"，用户只会认为设置不保存）
  Future<void> setNotificationsEnabled(bool enabled) async {
    final previous = _notificationsEnabled;
    _notificationsEnabled = enabled;
    notifyListeners();
    final saved = await _saveNotificationSetting(enabled);
    if (!saved) {
      _notificationsEnabled = previous;
      notifyListeners();
    }
  }

  /// 兼容旧调用点的写法（内部同样回滚）
  set notificationsEnabled(bool enabled) {
    unawaited(setNotificationsEnabled(enabled));
  }

  /// 从 StudySettingsProvider 同步 streak 值（由外部调用）
  void syncStreak(int newStreak) {
    if (_streak != newStreak) {
      _streak = newStreak;
      notifyListeners();
    }
  }

  int _loadSeq = 0; //词库列表加载序号（single-flight，丢弃过期结果）
  int _dueSeq = 0; //待复习计数刷新序号，丢弃过期请求结果

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 初始化加载词库（可重复调用：首页错误页的"重试"会再次进来）
  Future<void> init() async {
    //恢复上次保存的通知开关，否则重启后会回到默认值
    await _loadNotificationSetting();
    //恢复各词库的排序方式（正序/乱序）
    await _loadShuffledOrderIds();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await loadWordBooks();
      _hasInitError = false;
    } catch (e) {
      _hasInitError = true;
      _errorMessage = '加载词库失败：$e';
      _isLoading = false;
      debugPrint('WordBookProvider.init error: $e');
      notifyListeners();
    }
  }

  /// 加载所有词库。
  ///
  /// 用序号做 single-flight：并发调用（导入中再触发刷新、首页重试）时，
  /// 只有最后一次的结果会写状态，先完成的那个不再把 `_isLoading` 提前关掉、
  /// 也不会用旧列表覆盖新列表。
  Future<void> loadWordBooks() async {
    final seq = ++_loadSeq;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      //复制一份，避免与仓储缓存共享同一列表对象被外部修改
      final loaded = List.of(await _wordBookRepository.getAllWordBooks());
      if (seq != _loadSeq) return; //已有更新的加载在进行，丢弃本次结果
      //「（乱序）」变体词库不再展示：与正序版同词同量，排序方式已合并为
      //每本词库自己的开关（setShuffledOrder）。已导入的乱序词库保留在
      //数据库里（学习记录不丢），只是不再出现在列表与切换入口中
      loaded.removeWhere((book) => _isShuffledVariantName(book.name));
      _wordBooks = loaded;
      final currentId = _currentBook?.id;
      final currentIndex = _wordBooks.indexWhere(
        (book) => book.id == currentId,
      );
      _currentBook = currentIndex >= 0
          ? _wordBooks[currentIndex]
          : (_wordBooks.isEmpty ? null : _wordBooks.first);
      if (_currentBook == null) {
        // 词库被删空：计数必须一并清零，否则首页会继续显示上一本词库的
        // "今日学习/待复习/未学习"数字，用户在空库上做出错误判断
        _dueCount = 0;
        _todayNewCount = 0;
        _currentBookProgress = null;
      } else {
        await refreshDueCount();
      }
    } catch (e) {
      if (seq != _loadSeq) return;
      _errorMessage = '加载词库失败：$e';
      _safeLog('loadWordBooks error: $e');
    }
    if (seq != _loadSeq) return;
    _isLoading = false;
    notifyListeners();
  }

  /// 日志兜底：单元测试等没有 Flutter Binding 的环境里 debugPrint 自身会抛
  static void _safeLog(String message) {
    try {
      debugPrint(message);
    } catch (_) {
      // 忽略
    }
  }

  /// 选择当前词库
  Future<void> selectWordBook(WordBook book) async {
    _currentBook = book;
    //refreshDueCount 内部已 notify，不再重复通知
    await refreshDueCount();
  }

  /// 创建新词库
  Future<int> createWordBook(String name, String description) async {
    final id = await createWordBookSilent(name, description);
    await loadWordBooks();
    return id;
  }

  /// 创建新词库（不刷新列表，用于导入后手动刷新）
  Future<int> createWordBookSilent(
    String name,
    String description, {
    bool isBuiltIn = false,
  }) async {
    // 新词库排到列表末尾：sort_order 默认 0 会与"重排后被赋为 0 的第一本"
    // 并列，排序退化成按 id 升序，新词库会插在第一本之后而不是末尾
    var nextOrder = 1;
    try {
      final all = await _wordBookRepository.getAllWordBooks();
      for (final book in all) {
        if (book.sortOrder >= nextOrder) nextOrder = book.sortOrder + 1;
      }
    } catch (e) {
      _safeLog('计算词库排序位失败（按 1 处理）：$e');
    }
    return await _wordBookRepository.insertWordBook(
      WordBook(
        name: name,
        description: description,
        isBuiltIn: isBuiltIn,
        sortOrder: nextOrder,
      ),
    );
  }

  /// 检查词库名称是否已存在
  bool isBookNameExists(String name) {
    return _wordBooks.any((book) => book.name == name);
  }

  /// 删除词库
  Future<void> deleteWordBook(int id) async {
    final wasCurrentBook = _currentBook?.id == id;
    await _wordBookRepository.deleteWordBook(id);
    if (wasCurrentBook) _currentBook = null;
    await loadWordBooks();
  }

  /// 重置词库学习进度（保留单词，清复习记录/错词/会话/阅读进度）
  Future<void> resetWordBookProgress(int id) async {
    await _wordBookRepository.resetWordBookProgress(id);
    _reviewRepository.invalidateCountCache(id);
    if (_currentBook?.id == id) await refreshDueCount();
    notifyListeners();
  }

  /// 刷新待复习数量
  Future<void> refreshDueCount() async {
    final book = _currentBook;
    if (book != null) {
      //独立序号：loadWordBooks 的 single-flight 也用 _loadSeq，
      //共用会让"loadWordBooks → refreshDueCount"把自己的序号顶掉
      final seq = ++_dueSeq; //本次刷新序号
      final bookId = book.id;
      if (bookId != null) {
        try {
          //三个查询互不依赖，并行发出：此前串行 await 等于把三次
          //「词表 × 复习记录」扫描排成一队，而这个方法在启动、下拉刷新、
          //每次学习返回、切词库时都会跑一遍
          final results = await Future.wait([
            _reviewRepository.getDueWordCount(bookId),
            _reviewRepository.getTodayNewWordCount(bookId),
            _reviewRepository.getWordBookProgress(bookId),
          ]);
          final due = results[0] as int;
          final todayNew = results[1] as int;
          final progress = results[2] as WordBookProgress;
          //过期请求（已切到别的词库或有更新的刷新）直接丢弃，避免旧结果覆盖新词库
          if (seq != _dueSeq || _currentBook?.id != bookId) return;
          _dueCount = due;
          _todayNewCount = todayNew;
          _currentBookProgress = progress;
        } catch (e) {
          if (seq != _dueSeq || _currentBook?.id != bookId) return;
          _safeLog('refreshDueCount error: $e');
          //整体按"加载失败"处理：三个计数必须一起归零，只清两个会让首页
          //出现"待复习 0 / 未学习 旧值"这种自相矛盾的画面
          _dueCount = 0;
          _todayNewCount = 0;
          _currentBookProgress = null;
        }
      }
    }
    notifyListeners();
  }

  Future<bool> _saveNotificationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool('notificationsEnabled', enabled);
    } catch (e) {
      _safeLog('保存通知设置失败：$e');
      return false;
    }
  }

  /// 读取持久化的通知开关（与 [notificationsEnabled] 的写入端配对）
  Future<void> _loadNotificationSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    } catch (e) {
      debugPrint('读取通知设置失败：$e');
    }
  }

  /// 批量删除词库
  Future<void> deleteWordBooksBatch(List<int> ids) async {
    final wasCurrentBook =
        _currentBook != null && ids.contains(_currentBook!.id);
    await _wordBookRepository.deleteWordBooksBatch(ids);
    if (wasCurrentBook) _currentBook = null;
    await loadWordBooks();
  }

  /// 批量删除单词
  Future<void> deleteWordsBatch(List<int> wordIds) async {
    await DIContainer.instance.wordRepository.deleteWordsBatch(wordIds);
    await loadWordBooks();
  }

  /// 导入内置词库（完整词表）；若同名空词库存在则重导。
  ///
  /// 返回是否**真的写入了数据**：同名且已有词的词库会被跳过，调用方
  /// 必须据此统计"成功导入 N 个词库"，否则会出现"提示导入成功、实际什么
  /// 都没发生"（用户在词库页看不到任何变化）。
  Future<bool> importBuiltInBook(
    String name,
    String description,
    List<Map<String, String>> words, {
    Function(int completed, int total)? onProgress,
  }) async {
    if (words.isEmpty) {
      throw Exception('词库「$name」单词数据为空，无法导入');
    }
    final wordRepository = DIContainer.instance.wordRepository;
    final existing = _wordBooks.where((book) => book.name == name).toList();
    int bookId;
    if (existing.isNotEmpty) {
      final book = existing.first;
      bookId = book.id!;
      final count = await wordRepository.getWordCountInBook(bookId);
      if (count > 0) {
        // 已有完整词库，跳过（返回 false 让调用方不要计入"已导入"）
        return false;
      }
      // 空壳词库：删除后重建，避免脏数据
      await _wordBookRepository.deleteWordBook(bookId);
    }
    bookId = await createWordBookSilent(name, description, isBuiltIn: true);
    if (bookId <= 0) {
      throw Exception('创建词库失败：$name');
    }
    final wordList = words
        .where((w) => (w['word'] ?? '').trim().isNotEmpty)
        .map(
          (wordData) => Word(
            word: wordData['word'] ?? '',
            phonetic: wordData['phonetic'] ?? '',
            definition: wordData['definition'] ?? '',
            example: (wordData['example'] ?? '').isEmpty
                ? null
                : wordData['example'],
            exampleTranslation: (wordData['exampleTranslation'] ?? '').isEmpty
                ? null
                : wordData['exampleTranslation'],
            wordBookId: bookId,
          ),
        )
        .toList();
    if (wordList.isEmpty) {
      await _wordBookRepository.deleteWordBook(bookId);
      throw Exception('词库「$name」无有效单词');
    }
    await wordRepository.insertWordsBatchFast(wordList, onProgress: onProgress);
    await _wordBookRepository.updateWordBookTotalWords(bookId);
    await loadWordBooks();
    return true;
  }

  /// 重排序词库（拖拽排序后调用）
  Future<void> reorderWordBooks(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    // 在列表中移动
    final book = _wordBooks.removeAt(oldIndex);
    if (newIndex > oldIndex) {
      _wordBooks.insert(newIndex - 1, book);
    } else {
      _wordBooks.insert(newIndex, book);
    }

    // 更新所有词库的sortOrder
    final sortOrderMap = <int, int>{};
    for (int i = 0; i < _wordBooks.length; i++) {
      if (_wordBooks[i].id != null) {
        sortOrderMap[_wordBooks[i].id!] = i;
      }
    }

    // 保存到数据库
    try {
      await _wordBookRepository.updateSortOrders(sortOrderMap);
    } catch (e) {
      //持久化失败回滚内存顺序，避免 UI 与 DB 永久不一致
      debugPrint('reorderWordBooks 保存失败：$e');
      await loadWordBooks();
      return;
    }
    notifyListeners();
  }
}

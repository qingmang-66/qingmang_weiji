import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_card.dart';
import '../utils/guide_keys.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/report_dashboard_card.dart';
import '../widgets/reader_stats_card.dart';
import '../widgets/today_advice_card.dart';

class StatsLoadController<T> {
  StatsLoadController({
    required this.load,
    required this.apply,
  });

  final Future<T> Function(int? bookId) load;
  final void Function(T result) apply;
  int? _bookId;
  bool _initialized = false;
  int _generation = 0;
  Future<void>? _inFlight;
  bool _disposed = false;

  Future<void> updateBook(int? bookId) {
    if (_initialized && _bookId == bookId) {
      return _inFlight ?? Future<void>.value();
    }
    _initialized = true;
    _bookId = bookId;
    return _start();
  }

  Future<void> refresh() => _inFlight ?? _start();

  Future<void> _start() {
    final generation = ++_generation;
    // load 失败不在此吞掉：错误随返回的 future 传播给调用方，
    // 由调用方决定如何展示错误态（成功路径 apply 与错误路径天然互斥）
    final future = load(_bookId)
        .then((result) {
          if (!_disposed && generation == _generation) apply(result);
        })
        .whenComplete(() {
          if (generation == _generation) _inFlight = null;
        });
    _inFlight = future;
    return future;
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _inFlight = null;
  }
}

/// 统计页面 - 流体渐变风格
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  TodayAdvice _todayAdvice = const TodayAdvice(
    type: TodayAdviceType.waitForReview,
    dueWords: 0,
    todayNewWords: 0,
    unlearnedWords: 0,
  );
  WordBookProvider? _wordBookProvider;
  late final StatsLoadController<TodayAdvice> _loader;
  final ScrollController _scrollController = ScrollController();
  bool _loadFailed = false;
  int _reportReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _loader = StatsLoadController(
      load: _loadStats,
      apply: _applyStats,
    );
  }

  /// 统一处理 loader 返回的 future：错误向上传播后在此转为错误态展示，
  /// 避免未捕获的异步异常
  void _trackLoad(Future<void> task) {
    task.catchError((Object error) {
      _applyLoadError(error);
    });
  }

  Future<TodayAdvice> _loadStats(int? bookId) async {
    try {
      if (bookId == null) return _todayAdvice;
      final progress = await DIContainer.instance.reviewRepository
          .getWordBookProgress(bookId);
      return TodayAdvice.fromCounts(
        dueWords: progress.dueWords,
        todayNewWords: _wordBookProvider?.todayNewCount ?? 0,
        unlearnedWords: progress.unlearnedWords,
      );
    } catch (e) {
      // rethrow 由 StatsLoadController 传播给调用方，调用方经 _trackLoad
      // 走 _applyLoadError 展示错误态。
      // 此前这里 return _todayAdvice 会让 Future 正常完成、随后 apply 把
      // _loadFailed 又置回 false，错误卡片永远显示不出来。
      rethrow;
    }
  }

  void _applyStats(TodayAdvice advice) {
    if (!mounted) return;
    setState(() {
      _loadFailed = false;
      _todayAdvice = advice;
      //学习报告卡自行查询明细，下拉刷新时通过 token 触发重查
      _reportReloadToken++;
    });
  }

  void _applyLoadError(Object error) {
    debugPrint('统计加载失败: $error');
    if (!mounted) return;
    setState(() => _loadFailed = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<WordBookProvider>(context, listen: false);
    if (newProvider != _wordBookProvider) {
      _wordBookProvider?.removeListener(_onProviderChanged);
      _wordBookProvider = newProvider;
      _wordBookProvider?.addListener(_onProviderChanged);
      _trackLoad(_loader.updateBook(newProvider.currentBook?.id));
    }
  }

  void _onProviderChanged() {
    if (mounted) _trackLoad(_loader.updateBook(_wordBookProvider?.currentBook?.id));
  }

  @override
  void dispose() {
    _wordBookProvider?.removeListener(_onProviderChanged);
    _loader.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final padding = isWideScreen ? 24.0 : 16.0;
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    // 首页 Tab 外层已有顶部 SafeArea；
    // bottom 必须关掉：外壳 extendBody 会把导航条高度注入 MediaQuery.padding.bottom，
    // SafeArea 若消费它会把滚动区整体裁到玻璃条上方，导航条身后永远只剩背景，
    // 玻璃模糊无从折射（首页是手动 padding 避让，卡片能从玻璃条下滑过）
    return FluidPage(
      top: false,
      bottom: false,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding,
              padding,
              padding,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            // 顶部不再保留占位的 pinned SliverAppBar：它没有标题也没有按钮，
            // 只会在页面最上方压出一条空白（沉浸式下尤其明显）
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_loadFailed) ...[
                  FluidCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr.statsLoadFailed,
                          style: FluidTheme.headingSmall(
                            isDark,
                          ).copyWith(color: textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr.statsLoadFailedDesc,
                          style: FluidTheme.bodyMedium(isDark),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _trackLoad(_loader.refresh()),
                            child: Text(context.tr.retry),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                //今日建议（上下文引导高亮目标）
                KeyedSubtree(
                  key: guideStatsAdviceKey,
                  child: TodayAdviceCard(advice: _todayAdvice),
                ),
                const SizedBox(height: 12),
                //学习模式报告（上下文引导高亮目标）
                KeyedSubtree(
                  key: guideStatsReportKey,
                  child: ReportDashboardCard(reloadToken: _reportReloadToken),
                ),
                const SizedBox(height: 12),
                //阅读模式统计
                ReaderStatsCard(reloadToken: _reportReloadToken),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

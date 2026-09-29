part of '../home_screen.dart';

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard();

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  late Future<int> _wrongWordCountFuture;
  late Future<int> _favoriteCountFuture;
  late Future<bool> _hasStudyProgressFuture;
  int? _lastLearnedBookId;
  Future<Word?>? _lastLearnedFuture;

  @override
  void initState() {
    super.initState();
    _wrongWordCountFuture = _getWrongWordCount();
    _favoriteCountFuture = _getFavoriteCount();
    _hasStudyProgressFuture = DIContainer.instance.studyProgressRepository
        .hasStudyProgress();
    AppInitializationService.databaseRefreshSignal.addListener(refreshData);
  }

  @override
  void dispose() {
    AppInitializationService.databaseRefreshSignal.removeListener(refreshData);
    super.dispose();
  }

  Future<int> _getWrongWordCount() async {
    try {
      final service = DIContainer.instance.wrongWordService;
      return await service.getWrongWordCount();
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getFavoriteCount() async {
    try {
      return await DIContainer.instance.favoriteService.getCount();
    } catch (e) {
      return 0;
    }
  }

  //按词库缓存"上次学到的词"，词库变化或刷新时重新查询
  Future<Word?> _getLastLearned(int? bookId) {
    if (bookId == null) return Future.value(null);
    if (_lastLearnedBookId != bookId || _lastLearnedFuture == null) {
      _lastLearnedBookId = bookId;
      _lastLearnedFuture = DIContainer.instance.wordRepository
          .getLastLearnedWord(bookId);
    }
    return _lastLearnedFuture!;
  }

  void refreshData() {
    //本方法同时挂着 databaseRefreshSignal 监听与 Navigator.push(...).then 回调，
    //两者都可能在页面已销毁后到达（例如"设置 → 初始化应用"会用引导页替换首页）
    if (!mounted) return;
    setState(() {
      _wrongWordCountFuture = _getWrongWordCount();
      _favoriteCountFuture = _getFavoriteCount();
      _hasStudyProgressFuture = DIContainer.instance.studyProgressRepository
          .hasStudyProgress();
      //强制下次重新查询上次学到的词
      _lastLearnedBookId = null;
      _lastLearnedFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordBookProvider = context.watch<WordBookProvider>();
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    Future<void> navigateToStudy({required bool isReview}) async {
      final currentBook = wordBookProvider.currentBook;
      if (currentBook == null || currentBook.id == null) return;

      final availability = await context
          .read<DIContainer>()
          .reviewRepository
          .getStudyAvailability(currentBook.id!, isReview: isReview);

      if (!context.mounted) return;
      if (!availability.canStart) {
        _showStudyUnavailableDialog(availability);
        return;
      }

      Navigator.of(context)
          .push(
            PageTransitions.bouncyScale(
              page: PreStudyScreen(
                isReview: isReview,
                wordBookId: currentBook.id!,
              ),
            ),
          )
          .then((_) {
            if (!mounted) return;
            wordBookProvider.refreshDueCount();
            refreshData();
          });
    }

    Future<void> continueStudy(BuildContext context) async {
      final di = context.read<DIContainer>();
      final Map<String, dynamic>? progress;
      try {
        progress = await di.studyProgressRepository
            .getResumableStudyProgress();
      } catch (e) {
        //脏数据（word_ids 非法、字段类型不符）会让解析抛 TypeError ——
        //此前没有兜底，表现是"点继续学习毫无反应"
        if (context.mounted) {
          ErrorHandler.handleException(
            context,
            e,
            fallbackMessage: context.tr.continueStudyUnavailable,
          );
        }
        return;
      }
      if (progress == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr.continueStudyUnavailable),
              behavior: SnackBarBehavior.floating,
            ),
          );
          refreshData();
        }
        return;
      }

      //字段缺失/类型不符（旧版或损坏的进度）会让强转抛 TypeError，必须兜住，
      //否则"点继续学习"会变成未处理异步异常、界面毫无反应
      final int wordBookId;
      final int studyMode;
      final bool isReview;
      final List<int> wordIds;
      final String? source;
      final String? title;
      final String? progressKey;
      try {
        wordBookId = progress['wordBookId'] as int;
        studyMode = progress['studyMode'] as int;
        isReview = progress['isReview'] as bool;
        wordIds = progress['wordIds'] as List<int>;
        source = progress['source'] as String?;
        title = progress['title'] as String?;
        progressKey = progress['progressKey'] as String?;
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.handleException(
            context,
            e,
            fallbackMessage: context.tr.continueStudyUnavailable,
          );
        }
        return;
      }

      //词集（错题集 / 收藏夹）的"继续学习"要重建专项复习请求（词表固定），
      //普通学习 / 计划学习走 continueStudy
      final isWrongWords = source == StudySource.wrongWords.key;
      final isFavorites = source == StudySource.favorites.key;

      final List<Word> words;
      try {
        words = isWrongWords
            ? await di.wrongWordService.getWrongWordsByIds(wordIds)
            : await di.wordRepository.getWordsByIds(wordIds);
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.handleException(
            context,
            e,
            fallbackMessage: context.tr.loadingError,
          );
        }
        return;
      }
      if (words.isEmpty) {
        //进度里的词已被删除（词库重导/删词）：清掉这条无效进度并给出提示，
        //不能静默返回让用户以为按钮坏了
        unawaited(
          di.studyProgressRepository.clearStudyProgress(
            progressKey: progressKey,
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr.continueStudyUnavailable),
              behavior: SnackBarBehavior.floating,
            ),
          );
          refreshData();
        }
        return;
      }

      if (context.mounted) {
        final Widget page;
        if (isWrongWords || isFavorites) {
          final request = SpecializedStudyRequest(
            source: isFavorites
                ? StudySource.favorites
                : StudySource.wrongWords,
            title:
                title ??
                (isFavorites
                    ? context.tr.favoriteReviewTitle
                    : context.tr.wrongWordsReviewTitle),
            wordBookId: wordBookId == 0 ? null : wordBookId,
            wordIds: wordIds,
            studyMode: studyMode,
            isReview: isReview,
            explicitProgressKey: progressKey,
          );
          page = PreStudyScreen.specialized(request: request, words: words);
        } else {
          page = PreStudyScreen.continueStudy(
            wordBookId: wordBookId,
            words: words,
            studyMode: studyMode,
            isReview: isReview,
          );
        }

        Navigator.of(
          context,
        ).push(PageTransitions.bouncyScale(page: page)).then((_) {
          wordBookProvider.refreshDueCount();
          refreshData();
        });
      }
    }

    void switchToWordBook() {
      homeState?.switchToTab(1);
    }

    // SafeArea 已在 HomeScreen 外层处理
    return FluidBackground(
      child: wordBookProvider.isLoading
          ? Center(child: FluidLoading(message: context.tr.loading))
          : wordBookProvider.errorMessage != null
          ? _buildErrorState(context, wordBookProvider)
          : ListView(
              //底部动态避让悬浮导航条（extendBody 注入的 padding.bottom），
              //固定 16 会让"词集"区最后一排卡片被导航条盖住
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              children: [
                _buildAppBar(wordBookProvider),
                const SizedBox(height: 20),
                _buildTodayCard(wordBookProvider),
                const SizedBox(height: 16),
                if (wordBookProvider.currentBook != null) ...[
                  _buildCurrentBookCard(wordBookProvider),
                  const SizedBox(height: 16),
                ],
                if (wordBookProvider.currentBook == null)
                  _buildEmptyState(switchToWordBook)
                else ...[
                  _buildContinueButton(context, continueStudy),
                  _buildStartButton(wordBookProvider, navigateToStudy),
                  const SizedBox(height: 28),
                  _buildCollectionsTitle(),
                  const SizedBox(height: 12),
                  _buildCollectionEntries(),
                ],
              ],
            ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildAppBar(WordBookProvider provider) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textColor = FluidTheme.getTextPrimaryColor(isDark);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/app_icon_source_760.png',
              // 原图 760px：这里只显示 44dp，按 3x 密度限制解码尺寸，
              // 避免为一个小图标解码出 2MB+ 的位图常驻内存
              cacheWidth: 132,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 应用名在窄屏 + 大字体 + 打卡徽章（三位数）时会与右侧图标挤在一起，
        // 允许收缩省略，保证搜索入口与打卡徽章完整可见
        Expanded(
          child: Text(
            context.tr.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluidTheme.headingMedium(isDark).copyWith(color: textColor),
          ),
        ),
        const SizedBox(width: 8),
        if (provider.streak > 0) _buildStreakBadge(provider.streak),
        // 顶栏搜索图标是首页唯一的搜索入口（原本下方还并列一条长条搜索框，
        // 两个入口功能完全重复，已删除长条那个）
        KeyedSubtree(
          key: guideHomeSearchKey,
          child: IconButton(
            icon: Icon(Icons.search, color: textColor.withValues(alpha: 0.8)),
            tooltip: context.tr.searchHint,
            onPressed: () => showQuickWordSearchSheet(context),
          ),
        ),
      ],
    );
  }

  /// 构建连续打卡徽章
  Widget _buildStreakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: FluidTheme.warningFluidGradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FluidTheme.warningFluidGradient[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: FluidTheme.numberStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              //连续打卡胶囊底是琥珀渐变（#F59E0B），白字仅约 2.1:1，改用深色前景
              color: FluidTheme.onGradientForeground,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建今日学习事实卡片：只陈述已发生的事实，不设置目标
  Widget _buildTodayCard(WordBookProvider provider) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: context.tr.todayStudyTitle,
            icon: Icons.wb_sunny_outlined,
            gradientColors: FluidTheme.primaryFluidGradient,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFactItem(
                  icon: Icons.add_circle_outline,
                  label: context.tr.todayLearnedLabel,
                  value: '${provider.todayNewCount}${context.tr.wordsSuffix}',
                  colors: [
                    FluidTheme.accentSecondary,
                    FluidTheme.accentSecondary,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFactItem(
                  icon: Icons.replay_outlined,
                  label: context.tr.dueReviewsLabel,
                  value: '${provider.dueCount}${context.tr.wordsSuffix}',
                  colors: FluidTheme.primaryFluidGradient.sublist(1, 3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFactItem(
                  icon: Icons.school_outlined,
                  label: context.tr.remainingUnlearned,
                  value:
                      '${provider.currentBookProgress?.unlearnedWords ?? 0}${context.tr.wordsSuffix}',
                  colors: [
                    FluidTheme.warningFluidGradient[0],
                    FluidTheme.warningFluidGradient[0],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<Word?>(
            future: _getLastLearned(provider.currentBook?.id),
            builder: (context, snapshot) {
              final word = snapshot.data;
              if (word == null) return const SizedBox.shrink();
              return Row(
                children: [
                  Icon(
                    Icons.history_edu,
                    size: 16,
                    color: textSecondary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${context.tr.lastLearnedLabel}：${word.word}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textSecondary),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建事实指标项
  Widget _buildFactItem({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> colors,
  }) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textColor = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x00ffffff).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0x00ffffff).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors[0], size: 28),
          const SizedBox(height: 8),
          FluidCardNumber(value: value, gradientColors: colors, fontSize: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: textColor, fontSize: 13)),
        ],
      ),
    );
  }

  /// 构建当前词库卡片
  Widget _buildCurrentBookCard(WordBookProvider provider) {
    final currentBook = provider.currentBook!;
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

    return FluidCard(
      // 关闭常驻 shimmer：首页是最常停留的页面，卡片流光会让这里永远
      // 保持 60fps 重绘（且卡片在 BackdropFilter 内，每帧都要重新模糊采样），
      // 是后台发热与掉电的稳定来源。流光保留给选中/强调等瞬时状态。
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: context.tr.currentBook,
            icon: Icons.menu_book,
            gradientColors: [
              FluidTheme.accentSecondary,
              FluidTheme.accentSecondary,
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.wordBookName(currentBook.name),
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          const SizedBox(height: 6),
          Text(
            context.wordBookDescription(currentBook.description),
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(VoidCallback onSwitchToWordBook) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          FluidGradientContainer(
            colors: FluidTheme.primaryFluidGradient,
            borderRadius: 50,
            padding: const EdgeInsets.all(20),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr.emptyWordBook,
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.emptyWordBookDesc,
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
          const SizedBox(height: 20),
          //上下文引导高亮目标（未选择词库时指向这里）
          KeyedSubtree(
            key: guideHomeEmptyKey,
            child: FluidButton(
              text: context.tr.goToWordBooks,
              icon: Icons.add,
              onPressed: onSwitchToWordBook,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建继续学习按钮
  Widget _buildContinueButton(
    BuildContext context,
    Future<void> Function(BuildContext) continueStudy,
  ) {
    return FutureBuilder<bool>(
      future: _hasStudyProgressFuture,
      builder: (context, snapshot) {
        final hasProgress = snapshot.data ?? false;
        if (!hasProgress) return const SizedBox.shrink();

        return Column(
          children: [
            FluidButton(
              text: context.tr.continueStudy,
              icon: Icons.play_arrow,
              colors: FluidTheme.warningFluidGradient,
              expanded: true,
              onPressed: () => continueStudy(context),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  /// 构建开始学习按钮
  Widget _buildStartButton(
    WordBookProvider provider,
    Future<void> Function({required bool isReview}) navigateToStudy,
  ) {
    final button = provider.dueCount > 0
        ? FluidButton(
            text: '${context.tr.startStudy} (${provider.dueCount})',
            icon: Icons.replay,
            expanded: true,
            onPressed: () => navigateToStudy(isReview: true),
          )
        : FluidButton(
            text: context.tr.startNewWords,
            icon: Icons.school_outlined,
            expanded: true,
            onPressed: () => navigateToStudy(isReview: false),
          );
    //上下文引导高亮目标
    return KeyedSubtree(key: guideHomePrimaryKey, child: button);
  }

  void _showStudyUnavailableDialog(StudyAvailability availability) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final title = _availabilityTitle(availability.status);
    final description = _availabilityDescription(availability.status);

    showFluidDialog(
      context: context,
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: FluidTheme.bodyMedium(isDark).copyWith(
              color: FluidTheme.getTextSecondaryColor(isDark),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${context.tr.remainingUnlearned}：${availability.unlearnedWords}',
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
        ],
      ),
      actions: [
        FluidTextButton(
          text: context.tr.gotIt,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  String _availabilityTitle(StudyAvailabilityStatus status) {
    return switch (status) {
      StudyAvailabilityStatus.allNewWordsLearned =>
        context.tr.allNewWordsLearnedTitle,
      StudyAvailabilityStatus.noDueReviews => context.tr.noDueReviewsTitle,
      StudyAvailabilityStatus.emptyBook => context.tr.emptyWordBook,
      StudyAvailabilityStatus.available => context.tr.study,
    };
  }

  String _availabilityDescription(StudyAvailabilityStatus status) {
    return switch (status) {
      StudyAvailabilityStatus.allNewWordsLearned =>
        context.tr.allNewWordsLearnedDesc,
      StudyAvailabilityStatus.noDueReviews => context.tr.noDueReviewsDesc,
      StudyAvailabilityStatus.emptyBook => context.tr.emptyBookDesc,
      StudyAvailabilityStatus.available => context.tr.studyAdvice,
    };
  }

  /// 构建「词集」段标题
  Widget _buildCollectionsTitle() {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

    return Text(
      context.tr.wordCollections,
      style: FluidTheme.headingSmall(
        isDark,
      ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
    );
  }

  /// 词集段：错题集 + 收藏夹 两个并列入口
  ///
  /// 数量为 0 也**常显**。旧实现是"错词为 0 就整段消失"，结果没背错过单词的
  /// 用户完全不知道存在这个功能；而且收藏夹为空时更需要一个引导入口。
  /// 数量徽标是否显示由词集设置控制（各自设置面板里的开关）。
  Widget _buildCollectionEntries() {
    final settings = context.watch<WordCollectionSettingsProvider>();

    return Row(
      children: [
        Expanded(
          child: _buildCollectionEntry(
            icon: Icons.error_outline,
            label: context.tr.wrongWordCollection,
            color: FluidTheme.error,
            countFuture: _wrongWordCountFuture,
            showCount: settings.showWrongWordsBadge,
            onTap: () {
              Navigator.push(
                context,
                PageTransitions.bouncyScale(page: const WrongWordsScreen()),
              ).then((_) => refreshData());
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCollectionEntry(
            icon: Icons.star_border,
            label: context.tr.favorites,
            color: FluidTheme.favorite,
            countFuture: _favoriteCountFuture,
            showCount: settings.showFavoritesBadge,
            onTap: () {
              Navigator.push(
                context,
                PageTransitions.bouncyScale(page: const FavoritesScreen()),
              ).then((_) => refreshData());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionEntry({
    required IconData icon,
    required String label,
    required Color color,
    required Future<int> countFuture,
    required bool showCount,
    required VoidCallback onTap,
  }) {
    return FutureBuilder<int>(
      future: countFuture,
      builder: (context, snapshot) => QuickAction(
        icon: icon,
        label: label,
        color: color,
        count: snapshot.data,
        showCount: showCount,
        onTap: onTap,
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(BuildContext context, WordBookProvider provider) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: FluidTheme.error),
            const SizedBox(height: 24),
            Text(
              context.tr.initFailed,
              style: FluidTheme.headingMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
            ),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage ?? context.tr.unknownError,
              textAlign: TextAlign.center,
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
            const SizedBox(height: 32),
            FluidButton(
              text: context.tr.retry,
              icon: Icons.refresh,
              //必须 await + 捕获：provider.init() 是 async，签名里抛出的异常
              //会进到无人 await 的 Future 里 —— 表现为"点重试毫无反应"
              onPressed: () async {
                try {
                  await provider.init();
                } catch (e) {
                  if (context.mounted) {
                    ErrorHandler.handleException(context, e);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

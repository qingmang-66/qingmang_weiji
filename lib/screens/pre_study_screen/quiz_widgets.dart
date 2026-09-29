part of '../pre_study_screen.dart';

class _QuizOptionButton extends StatelessWidget {
  final String text;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final bool hasAnswered;
  final bool isDark;
  final VoidCallback onTap;

  const _QuizOptionButton({
    required this.text,
    required this.index,
    required this.isSelected,
    required this.isCorrect,
    required this.hasAnswered,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final Color borderColor;
    final Color backgroundColor;
    final IconData icon;

    if (hasAnswered && isCorrect) {
      borderColor = FluidTheme.success;
      backgroundColor = FluidTheme.success.withValues(
        alpha: isDark ? 0.18 : 0.10,
      );
      icon = Icons.check_circle;
    } else if (hasAnswered && isSelected) {
      borderColor = FluidTheme.error;
      backgroundColor = FluidTheme.error.withValues(
        alpha: isDark ? 0.18 : 0.10,
      );
      icon = Icons.cancel;
    } else {
      borderColor = FluidTheme.getBorderColor(isDark);
      backgroundColor = FluidTheme.getMutedOverlayColor(isDark);
      icon = Icons.radio_button_unchecked;
    }

    final content = Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: FluidTheme.primaryFluidGradient[0].withValues(
            alpha: 0.16,
          ),
          child: Text(
            String.fromCharCode(65 + index),
            style: TextStyle(
              //选项字母是文字，主色在浅色玻璃上仅 1.91:1，改用可读版主色
              color: FluidTheme.primaryAccessible(isDark),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
        //仅作答后显示 ✓/✗：作答前那圈 ○ 只是重复表达"这是个选项"，
        //在每行右侧排成一列反而像一堆未选中的单选钮，视觉噪音大。
        //出场仍走缩放+淡入，避免图标突然出现。
        if (hasAnswered)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey(icon),
              color: borderColor,
              size: 22,
            ),
          ),
      ],
    );

    //玻璃模式：选项为果冻玻璃片，选中/正误态强调发光
    if (context.isLiquidGlass) {
      final Color? glowColor;
      if (hasAnswered && isCorrect) {
        glowColor = FluidTheme.success;
      } else if (hasAnswered && isSelected) {
        glowColor = FluidTheme.error;
      } else if (isSelected) {
        glowColor = FluidTheme.primaryFluidGradient[0];
      } else {
        glowColor = null;
      }
      return InkWell(
        onTap: hasAnswered ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        // 关掉 Material 默认水波：它在半透明玻璃片下方会透出一块蓝色方形
        // （用户反馈"选中方框那里有蓝色正方形在闪"）。点击反馈由选中态、
        // 发光与正误配色承担，不需要水波。
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: GlassSurface(
          borderRadius: 14,
          padding: const EdgeInsets.all(14),
          emphasized: glowColor != null,
          glowColor: glowColor,
          tint: glowColor != null
              ? LiquidGlass.accentTint(glowColor, isDark)
              : null,
          child: content,
        ),
      );
    }

    return InkWell(
      onTap: hasAnswered ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      // 同上：选项右侧的 ○ 图标处不允许出现默认水波的蓝色方块
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      //跳出正误结果时，底色与描边平滑过渡到成功/失败色
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: content,
      ),
    );
  }
}

/// 学习结束总结页
class _StudySummaryScreen extends StatelessWidget {
  final bool isReview;
  final int totalWords;
  final int correctCount;
  final int wrongCount;
  final int revealedCount;
  final List<Word> wrongWords;
  final List<Word> revealedWords;
  final int wordBookId;
  final int studyMode;
  final int skippedCount; // 智能模式跳过的词数
  final StudySessionSummary sessionSummary;
  final bool enableSmartMode; // 是否启用了智能模式
  final Map<int, SessionMasteryState> masteryStates; // S-MARS状态分布
  final bool dailyTaskCompleted; // 今日学习计划任务是否完成

  const _StudySummaryScreen({
    required this.isReview,
    required this.totalWords,
    required this.correctCount,
    required this.wrongCount,
    required this.revealedCount,
    required this.wrongWords,
    required this.revealedWords,
    required this.wordBookId,
    required this.studyMode,
    required this.sessionSummary,
    this.skippedCount = 0,
    this.enableSmartMode = false,
    this.masteryStates = const {},
    this.dailyTaskCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final accuracy = sessionSummary.masteryPercent;

    return Scaffold(
      backgroundColor: context.isLiquidGlass
          ? Colors.transparent
          : FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          context.tr.studySummaryTitle,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: FluidTheme.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isReview
                        ? context.tr.reviewComplete
                        : context.tr.studyComplete,
                    style: FluidTheme.headingMedium(
                      isDark,
                    ).copyWith(color: textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr.totalLearned}$totalWords${context.tr.wordsLearnedSuffix}',
                    style: FluidTheme.bodyLarge(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (dailyTaskCompleted) ...[
              FluidCard(
                enableShimmer: false,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: FluidTheme.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.taskCompleted,
                            style: FluidTheme.labelLarge(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr.taskCompletedDesc,
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 统计卡片
            FluidCard(
              enableShimmer: false,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildStatRow(
                    Icons.check_circle,
                    FluidTheme.success,
                    context.tr.correctCount,
                    '$correctCount',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.cancel,
                    FluidTheme.error,
                    context.tr.wrongCount,
                    '$wrongCount',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.visibility,
                    FluidTheme.warning,
                    context.tr.revealedCount,
                    '$revealedCount',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  // 智能模式跳过词统计
                  if (enableSmartMode && skippedCount > 0) ...[
                    const SizedBox(height: 16),
                    _buildStatRow(
                      Icons.auto_awesome,
                      FluidTheme.primaryFluidGradient[0],
                      context.tr.skippedWords,
                      '$skippedCount',
                      textPrimary,
                      textSecondary,
                      isDark: isDark,
                    ),
                  ],
                  const Divider(height: 32),
                  _buildStatRow(
                    Icons.psychology_outlined,
                    FluidTheme.success,
                    context.tr.masteredCount,
                    '${sessionSummary.masteredWords}',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.trending_up,
                    FluidTheme.primaryFluidGradient[0],
                    context.tr.masteryRate,
                    '$accuracy%',
                    textPrimary,
                    textSecondary,
                    isLarge: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // S-MARS分数分布图表
            if (masteryStates.isNotEmpty) ...[
              _buildScoreDistributionChart(
                context,
                masteryStates,
                textPrimary,
                textSecondary,
                isDark,
              ),
              const SizedBox(height: 24),
              _buildMasteryPieChart(
                context,
                masteryStates,
                textPrimary,
                textSecondary,
                isDark,
              ),
              const SizedBox(height: 24),
            ],

            // 错词列表
            if (wrongWords.isNotEmpty) ...[
              Text(
                context.tr.wrongWordsList,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
              const SizedBox(height: 12),
              FluidCard(
                enableShimmer: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: wrongWords.map((word) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 16, color: FluidTheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              word.word,
                              style: FluidTheme.bodyMedium(isDark).copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            word.phonetic,
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 查看答案列表
            if (revealedWords.isNotEmpty) ...[
              Text(
                context.tr.revealedWordsList,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
              const SizedBox(height: 12),
              FluidCard(
                enableShimmer: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: revealedWords.map((word) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: FluidTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              word.word,
                              style: FluidTheme.bodyMedium(isDark).copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            word.phonetic,
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 操作按钮
            FluidButton(
              text: context.tr.backToHome,
              icon: Icons.home,
              expanded: true,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            const SizedBox(height: 12),
            if (wrongWords.isNotEmpty)
              FluidButton(
                text: context.tr.reviewWrongWords,
                icon: Icons.refresh,
                expanded: true,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    PageTransitions.fade(
                      page: PreStudyScreen.continueStudy(
                        wordBookId: wordBookId,
                        words: wrongWords,
                        studyMode: studyMode,
                        isReview: true,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 构建分数分布柱状图
  Widget _buildScoreDistributionChart(
    BuildContext context,
    Map<int, SessionMasteryState> states,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    // 计算分数段分布（每10分一段：0-9, 10-19, ..., 90-100）
    final scoreBuckets = List<int>.filled(10, 0);
    for (final state in states.values) {
      final score = state.sessionScore.round();
      // 100分放在索引9（90-100桶），0-9分放在索引0
      final bucketIndex = (score ~/ 10).clamp(0, 9);
      scoreBuckets[bucketIndex]++;
    }

    // 保护：如果所有桶都是0（无数据），显示空图表
    final maxBucketValue = scoreBuckets.isEmpty
        ? 1.0
        : scoreBuckets.reduce(math.max).toDouble();
    final maxY = maxBucketValue > 0 ? maxBucketValue + 2 : 2.0;

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: FluidTheme.primaryFluidGradient[0]),
              const SizedBox(width: 8),
              Text(
                context.tr.scoreDistribution,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${index * 10}',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: textSecondary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.white24 : Colors.black12,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(10, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: scoreBuckets[index].toDouble(),
                        color: _getBucketColor(index),
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建掌握状态饼图
  Widget _buildMasteryPieChart(
    BuildContext context,
    Map<int, SessionMasteryState> states,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    // 统计各状态数量（互斥分类：强掌握 > 已掌握 > 薄弱 > 学习中）
    int strongMastered = 0;
    int mastered = 0;
    int learning = 0;
    int weak = 0;

    for (final state in states.values) {
      // 按优先级判断，确保每个词只计入一个状态
      if (state.isStrongMastered) {
        strongMastered++; // 强掌握：sessionScore >= 82 && bestModeWeight >= 0.92
      } else if (state.isMastered) {
        mastered++; // 已掌握：sessionScore >= 76 && wrongCount == 0 && revealCount == 0
      } else if (state.isWeak) {
        weak++; // 薄弱词：sessionScore < 55 || wrongCount >= 2 || revealCount > 0
      } else {
        learning++; // 学习中：其他情况
      }
    }

    final total = states.length;
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];

    // 强掌握
    if (strongMastered > 0) {
      sections.add(
        PieChartSectionData(
          value: strongMastered.toDouble(),
          title: '${(strongMastered / total * 100).round()}%',
          color: FluidTheme.success,
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    // 已掌握
    if (mastered > 0) {
      sections.add(
        PieChartSectionData(
          value: mastered.toDouble(),
          title: '${(mastered / total * 100).round()}%',
          color: FluidTheme.primaryFluidGradient[0],
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    // 学习中
    if (learning > 0) {
      sections.add(
        PieChartSectionData(
          value: learning.toDouble(),
          title: '${(learning / total * 100).round()}%',
          color: FluidTheme.warning,
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    // 薄弱词
    if (weak > 0) {
      sections.add(
        PieChartSectionData(
          value: weak.toDouble(),
          title: '${(weak / total * 100).round()}%',
          color: FluidTheme.error,
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: FluidTheme.primaryFluidGradient[0]),
              const SizedBox(width: 8),
              Text(
                context.tr.masteryStatus,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 图例
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (strongMastered > 0)
                _buildLegendItem(
                  context.tr.strongMastered,
                  FluidTheme.success,
                  strongMastered,
                  textSecondary,
                ),
              if (mastered > 0)
                _buildLegendItem(
                  context.tr.mastered,
                  FluidTheme.primaryFluidGradient[0],
                  mastered,
                  textSecondary,
                ),
              if (learning > 0)
                _buildLegendItem(
                  context.tr.learning,
                  FluidTheme.warning,
                  learning,
                  textSecondary,
                ),
              if (weak > 0)
                _buildLegendItem(
                  context.tr.weakWords,
                  FluidTheme.error,
                  weak,
                  textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建图例项
  Widget _buildLegendItem(
    String label,
    Color color,
    int count,
    Color textSecondary,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// 分数段颜色（从低分到高分：红→橙→黄→绿→蓝）。
  /// 提升为静态常量，避免每次调用（build 中会调用 10 次）都新建列表。
  static const List<Color> _bucketColors = [
    Color(0xFFE74C3C), // 0-10: 红
    Color(0xFFE67E22), // 10-20: 橙
    Color(0xFFF39C12), // 20-30: 黄橙
    Color(0xFFF1C40F), // 30-40: 黄
    Color(0xFF2ECC71), // 40-50: 绿
    Color(0xFF1ABC9C), // 50-60: 青绿
    Color(0xFF3498DB), // 60-70: 蓝
    Color(0xFF2980B9), // 70-80: 深蓝
    Color(0xFF8E44AD), // 80-90: 紫
    Color(0xFF9B59B6), // 90-100: 浅紫
  ];

  /// 获取分数段颜色
  Color _getBucketColor(int bucketIndex) =>
      _bucketColors[bucketIndex.clamp(0, 9)];

  Widget _buildStatRow(
    IconData icon,
    Color color,
    String label,
    String value,
    Color textPrimary,
    Color textSecondary, {
    bool isLarge = false,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: isLarge ? 28 : 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: isLarge
                ? FluidTheme.bodyLarge(isDark).copyWith(color: textSecondary)
                : FluidTheme.bodyMedium(isDark).copyWith(color: textSecondary),
          ),
        ),
        Text(
          value,
          style: isLarge
              ? FluidTheme.numberMedium(isDark, color: textPrimary)
              : FluidTheme.numberSmall(isDark, color: textPrimary),
        ),
      ],
    );
  }
}

/// 评分按钮已抽到 lib/widgets/recall_quality_action_bar.dart 的
/// RecallQualityButton：学习页与「自定义按键位置」编辑器共用同一个外观，
/// 预览才能真正等于实机。

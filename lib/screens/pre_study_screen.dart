import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/di_container.dart';
import '../services/review_scheduler.dart';
import '../services/study_progress_logic.dart';
import '../services/repositories/review_repository.dart';
import '../services/session_mastery_engine.dart';
import '../services/tts_service.dart';
import '../services/guide_service.dart';
import '../services/keyboard_language_service.dart';
import '../services/providers/theme_provider.dart';
import '../services/providers/study_settings_provider.dart';
import '../services/providers/wordbook_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/guide_keys.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/page_transitions.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/fluid_background.dart';
import '../widgets/dictionary_dialog.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/fluid_loading.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/recall_quality_action_bar.dart';
import '../widgets/study_card_transition.dart';
//学习页顶栏的「设置」按钮直接打开设置里的三级页面（回忆模式 · 释义显示）
import 'settings_screen.dart';

part 'pre_study_screen/study_mode_chip.dart';
part 'pre_study_screen/direct_study_screen.dart';
part 'pre_study_screen/quiz_widgets.dart';

/// 集中记录学习流程中的非致命错误
///
/// 当前行为：仅 debugPrint，保留与改动前一致的用户感知；
/// 后续若需要给用户可见提示（如 SnackBar / Toast），
/// 改本函数一处即可覆盖所有调用点。
void _logScreenError(String tag, Object error) {
  debugPrint('PreStudyScreen.$tag: $error');
}

/// 学习前置选词界面 - 流体渐变风格
class PreStudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;
  final List<Word>? presetWords;
  final int? presetStudyMode;
  final SpecializedStudyRequest? specializedRequest;

  const PreStudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
    this.presetWords,
    this.presetStudyMode,
    this.specializedRequest,
  });

  factory PreStudyScreen.continueStudy({
    required int wordBookId,
    required List<Word> words,
    required int studyMode,
    required bool isReview,
  }) {
    return PreStudyScreen(
      wordBookId: wordBookId,
      isReview: isReview,
      presetWords: words,
      presetStudyMode: studyMode,
    );
  }

  factory PreStudyScreen.specialized({
    required SpecializedStudyRequest request,
    required List<Word> words,
  }) {
    return PreStudyScreen(
      wordBookId: request.wordBookId ?? 0,
      isReview: request.isReview,
      presetWords: words,
      presetStudyMode: request.studyMode,
      specializedRequest: request,
    );
  }

  @override
  State<PreStudyScreen> createState() => _PreStudyScreenState();
}

class _PreStudyScreenState extends State<PreStudyScreen> {
  List<Word> _allWords = [];
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  int _selectedStudyMode = 1;
  bool _enableSmartMode = false; // 智能模式切换开关状态

  /// 是否已经该显示转圈。
  ///
  /// 词表查询通常只要几十毫秒：此前先等 380ms 转场、再把加载态整页画出来，
  /// 用户看到的就是"点开始学习 → 先转一个圈 → 才进选词页"。现在查询立刻发起，
  /// 只有超过 [_loadingIndicatorDelay] 还没回来时才画转圈，
  /// 正常情况下页面是"直接进去"的。
  bool _showLoadingIndicator = false;
  Timer? _loadingIndicatorTimer;
  static const Duration _loadingIndicatorDelay = Duration(milliseconds: 260);

  /// 是否带着预设词进入（继续学习 / 词集专项复习）：这类入口直接渲染学习页
  bool get _hasPresetWords =>
      widget.presetWords != null && widget.presetWords!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 从设置中加载智能模式偏好
    final settings = context.read<StudySettingsProvider>();
    _enableSmartMode = settings.enableSmartModeSwitch;

    if (_hasPresetWords) {
      _selectedStudyMode = widget.presetStudyMode ?? 1;
    } else {
      _loadingIndicatorTimer = Timer(_loadingIndicatorDelay, () {
        if (mounted && _isLoading) {
          setState(() => _showLoadingIndicator = true);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _loadWords();
        if (!mounted) return;
        // 数据到齐后再引导：锚点（模式卡片 / 开始按钮）此时才真正在树上
        await _showStudyGuide();
      });
    }
  }

  @override
  void dispose() {
    _loadingIndicatorTimer?.cancel();
    super.dispose();
  }

  /// 首次进入选词页：衔接主导览，逐个介绍五种练习模式、智能模式与开始按钮。
  ///
  /// 预设词路径会直接跳转到学习页，没有选词界面，因此不触发该引导；
  /// 词库为空时步骤为空，[CoachMarkOverlay] 会直接跳过，留待下次再引导。
  Future<void> _showStudyGuide() async {
    //选词页是长页面，智能模式与开始按钮在手机上往往落在屏幕之外。
    //每一步都先把它滚进可视范围，高亮才不会指着屏幕外。
    CoachMarkStep step(
      GlobalKey anchor,
      String title,
      String message,
      IconData icon,
    ) => CoachMarkStep(
      targetKey: anchor,
      title: title,
      message: message,
      icon: icon,
      onEnter: () => _revealAnchor(anchor),
    );

    await CoachMarkOverlay.maybeShow(
      context,
      guideId: GuideService.tipStudyModes,
      steps: () => _allWords.isEmpty
          ? const <CoachMarkStep>[]
          : [
              step(
                guideStudyModeKey,
                context.tr.coachStudyModeTitle,
                context.tr.coachStudyModeMsg,
                Icons.tune,
              ),
              step(
                guideStudyModeRecallKey,
                context.tr.coachModeRecallTitle,
                context.tr.coachModeRecallMsg,
                Icons.visibility_outlined,
              ),
              step(
                guideStudyModeSpellingKey,
                context.tr.coachModeSpellingTitle,
                context.tr.coachModeSpellingMsg,
                Icons.edit_outlined,
              ),
              step(
                guideStudyModeListeningKey,
                context.tr.coachModeListeningTitle,
                context.tr.coachModeListeningMsg,
                Icons.headphones_outlined,
              ),
              step(
                guideStudyModeEnCnKey,
                context.tr.coachModeEnCnTitle,
                context.tr.coachModeEnCnMsg,
                Icons.quiz_outlined,
              ),
              step(
                guideStudyModeCnEnKey,
                context.tr.coachModeCnEnTitle,
                context.tr.coachModeCnEnMsg,
                Icons.translate,
              ),
              step(
                guideStudySmartModeKey,
                context.tr.coachSmartModeTitle,
                context.tr.coachSmartModeMsg,
                Icons.auto_awesome,
              ),
              step(
                guideStudyStartKey,
                context.tr.coachStudyStartTitle,
                context.tr.coachStudyStartMsg,
                Icons.play_circle_outline,
              ),
            ],
    );
  }

  /// 锚点不在可视范围内时才滚动。
  ///
  /// 不用裸的 `Scrollable.ensureVisible`：它按 alignment 对齐，目标即使已经
  /// 完整可见也会再滚一次，引导每翻一步页面都跟着抖一下。
  void _revealAnchor(GlobalKey anchor) {
    final targetContext = anchor.currentContext;
    if (targetContext == null) return;
    final targetBox = targetContext.findRenderObject();
    final scrollable = Scrollable.maybeOf(targetContext);
    final viewportBox = scrollable?.context.findRenderObject();
    if (targetBox is! RenderBox ||
        !targetBox.hasSize ||
        viewportBox is! RenderBox ||
        !viewportBox.hasSize) {
      return;
    }

    final targetRect = targetBox.localToGlobal(Offset.zero) & targetBox.size;
    final viewportRect =
        viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    //上下各留 8px 余量，避免"刚好贴边"看起来像被裁掉
    final alreadyVisible =
        targetRect.top >= viewportRect.top + 8 &&
        targetRect.bottom <= viewportRect.bottom - 8;
    if (alreadyVisible) return;

    final isBelow = targetRect.top > viewportRect.top;
    unawaited(
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignmentPolicy: isBelow
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ),
    );
  }

  /// 预设词（继续学习 / 词集专项复习）直接构建学习页。
  ///
  /// 旧实现是本页先 push 进来、再 `pushReplacement` 换成学习页：
  /// 用户会看到"学习页标题 + 转圈"先滑进来，紧接着又被学习页顶掉，
  /// 一次点击看两段转场。直接在当前路由内构建学习页后只有一段转场，
  /// 退出时 `Navigator.pop` 依旧回到上一页，路由栈深度与旧实现一致。
  Widget _buildDirectStudy() {
    return DirectStudyScreen(
      isReview: widget.isReview,
      wordBookId: widget.wordBookId,
      presetWords: widget.presetWords!,
      studyMode: _selectedStudyMode,
      enableSmartMode: _enableSmartMode,
      specializedRequest: widget.specializedRequest,
    );
  }

  Future<void> _loadWords() async {
    final di = context.read<DIContainer>();

    try {
      List<Word> words;
      // 每日可选上限：产品语义是"加载全部词，学多学少自己决定"，
      // 但导入型大词库（数万词）一次性构造全部 Word 对象会在低端机上
      // 造成明显卡顿；按一天绝对学不完的量封顶（含 shuffle 与
      // _selectedIds 全选构造的内存峰值也随之收敛）
      const maxCandidateWords = 10000;
      if (widget.isReview) {
        //复习模式：加载全部到期词，学多学少由自己决定
        words = await di.wordRepository.getDueWords(
          widget.wordBookId,
          limit: maxCandidateWords,
        );
      } else {
        //学习新模式：加载全部未学词，学多学少由自己决定
        words = await di.wordRepository.getNewWords(
          widget.wordBookId,
          maxCandidateWords,
        );
      }
      if (!mounted) return;
      //词库开了「乱序」排序：按词库 id 作种子做确定性打乱——
      //同一本词库每次进入学习顺序都一致（替代旧的"（乱序）"独立词库）
      if (context.read<WordBookProvider>().isShuffledOrder(widget.wordBookId)) {
        words.shuffle(math.Random(widget.wordBookId));
      }
      _allWords = words;
      //id 为 null 的词（数据库查询正常不会出现，防御脏数据）不进入选中集，
      //避免 w.id! 在 null 上崩溃；_startStudy 里 contains(null) 也会自然跳过它们
      _selectedIds = words
          .where((w) => w.id != null)
          .map((w) => w.id!)
          .toSet();
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allWords = [];
        _selectedIds = {};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr.loadingError}：$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startStudy() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.selectAtLeastOne),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedList = <Word>[];
    for (int i = 0; i < _allWords.length; i++) {
      if (_selectedIds.contains(_allWords[i].id)) {
        selectedList.add(_allWords[i]);
      }
    }

    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.noSelectedWords),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageTransitions.slideFromRight(
        page: DirectStudyScreen(
          isReview: widget.isReview,
          wordBookId: widget.wordBookId,
          presetWords: selectedList,
          studyMode: _selectedStudyMode,
          enableSmartMode: _enableSmartMode,
          specializedRequest: widget.specializedRequest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //预设词入口不存在"选词"这一步：当前路由直接渲染学习页
    //（不再 pushReplacement，避免"加载页滑入 → 被学习页顶掉"的双段转场）
    if (_hasPresetWords) return _buildDirectStudy();

    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Scaffold(
      backgroundColor: context.isLiquidGlass
          ? Colors.transparent
          : FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          widget.isReview ? context.tr.reviewMode : context.tr.study,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? (_showLoadingIndicator
                ? Center(child: FluidLoading(message: context.tr.loading))
                // 加载很快时留白即可：画转圈反而让"进页面"多出一段闪烁
                : const SizedBox.shrink())
          : _allWords.isEmpty
          ? Center(
              child: Text(
                context.tr.emptyBookHint,
                style: FluidTheme.bodyMedium(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
            )
          : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 学习模式选择
          Text(
            context.tr.selectStudyMode,
            style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
          ),
          const SizedBox(height: 16),
          FluidCard(
            key: guideStudyModeKey,
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FluidGradientContainer(
                      colors: FluidTheme.primaryFluidGradient,
                      borderRadius: 12,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.library_books,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isReview
                                ? context.tr.reviewWordsTitle
                                : context.tr.studyNewWords,
                            style: FluidTheme.labelLarge(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          Text(
                            //本页没有选词 UI，_selectedIds 始终等于全部已加载词；
                            //语义上"已加载"应对应已加载词表本身，勿用勾选集合
                            '${context.tr.loaded}${_allWords.length}${context.tr.wordsSuffix}',
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr.modeSelection,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StudyModeChip(
                      key: guideStudyModeRecallKey,
                      icon: Icons.visibility_outlined,
                      label: context.tr.recallMode,
                      isSelected: _selectedStudyMode == 1,
                      onTap: () => setState(() => _selectedStudyMode = 1),
                    ),
                    StudyModeChip(
                      key: guideStudyModeSpellingKey,
                      icon: Icons.edit_outlined,
                      label: context.tr.spellingMode,
                      isSelected: _selectedStudyMode == 2,
                      onTap: () => setState(() => _selectedStudyMode = 2),
                    ),
                    StudyModeChip(
                      key: guideStudyModeListeningKey,
                      icon: Icons.headphones_outlined,
                      label: context.tr.listeningMode,
                      isSelected: _selectedStudyMode == 3,
                      onTap: () => setState(() => _selectedStudyMode = 3),
                    ),
                    StudyModeChip(
                      key: guideStudyModeEnCnKey,
                      icon: Icons.quiz_outlined,
                      label: context.tr.quizModeEnToCn,
                      isSelected: _selectedStudyMode == 4,
                      onTap: () => setState(() => _selectedStudyMode = 4),
                    ),
                    StudyModeChip(
                      key: guideStudyModeCnEnKey,
                      icon: Icons.translate,
                      label: context.tr.quizModeCnToEn,
                      isSelected: _selectedStudyMode == 5,
                      onTap: () => setState(() => _selectedStudyMode = 5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 智能模式切换开关
          FluidCard(
            key: guideStudySmartModeKey,
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: FluidTheme.primaryFluidGradient[0],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSwitch,
                        style: FluidTheme.labelLarge(
                          isDark,
                        ).copyWith(color: textPrimary),
                      ),
                    ),
                    LiquidSwitch(
                      value: _enableSmartMode,
                      onChanged: (value) {
                        setState(() => _enableSmartMode = value);
                        // 持久化设置
                        context
                            .read<StudySettingsProvider>()
                            .setEnableSmartModeSwitch(value);
                      },
                      activeColor: FluidTheme.primaryFluidGradient[0],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.smartModeSwitchDesc,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSkipMastered,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSwitchWeak,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.find_in_page, size: 16, color: textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSpotCheck,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: FluidTheme.primaryFluidGradient[0],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isReview
                        ? context.tr.reviewAdvice
                        : context.tr.studyAdvice,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FluidButton(
            key: guideStudyStartKey,
            text: context.tr.startLearningBtn,
            icon: Icons.play_arrow,
            expanded: true,
            isEnabled: _selectedIds.isNotEmpty,
            onPressed: _selectedIds.isEmpty ? null : _startStudy,
          ),
          const SizedBox(height: 12),
          //退出自动保存提示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 16, color: textSecondary),
              const SizedBox(width: 6),
              Text(
                context.tr.exitAutoSaveHint,
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

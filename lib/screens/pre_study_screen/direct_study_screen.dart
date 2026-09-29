part of '../pre_study_screen.dart';

/// 直接进入学习（使用预设词列表）
class DirectStudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;
  final List<Word> presetWords;
  final int studyMode;
  final bool enableSmartMode;
  final SpecializedStudyRequest? specializedRequest;
  final ReviewRepository? reviewRepository;

  const DirectStudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
    required this.presetWords,
    required this.studyMode,
    this.enableSmartMode = false,
    this.specializedRequest,
    this.reviewRepository,
  });

  @override
  State<DirectStudyScreen> createState() => _DirectStudyScreenState();
}

enum StudyInitializationState { loading, ready, empty, error }

class _DirectStudyScreenState extends State<DirectStudyScreen>
    with WidgetsBindingObserver {
  late List<Word> _words;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();

  /// 输入法"调不起来"的自愈闸门：请求焦点后若键盘迟迟未上屏，
  /// 只允许重建一次输入连接，避免与坏掉的 IME 无限对拉
  bool _imeRecoveryPending = false;

  ///换题内容区滚动控制器：换题后回到顶部，避免新题停留在上一题的滚动位置
  final ScrollController _contentScrollController = ScrollController();
  final SessionMasteryEngine _masteryEngine = SessionMasteryEngine();
  final Map<int, ReviewRecord?> _cachedRecords = {};
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isPlaying = false;
  bool _isSavingQuality = false;
  bool _hasCheckedAnswer = false;
  bool _isAnswerCorrect = false;
  bool _hasCompletedTypedAnswer = false;
  bool _hasRecordedTypedWrongAttempt = false;
  bool _hasRecordedTypedRevealAttempt = false;
  bool _hasRecordedTypedRetryCorrect = false;
  bool _qualityAttemptRecorded = false; //当前词是否已记录质量作答，防止保存失败重试时重复计数
  /// 当前题的复习记录是否已落库（含退出/切后台的提前结算）：
  /// 防止"结算两次"让 SM-2 的 interval/repetitions 白白多推进一档
  bool _currentQuestionSaved = false;
  int? _selectedQuizOption;
  List<String> _quizOptions = [];
  StudyInitializationState _initializationState =
      StudyInitializationState.loading;
  String? _initializationError;

  // 学习统计
  int _correctCount = 0;
  int _wrongCount = 0;
  int _revealedCount = 0;
  int _skippedCount = 0;
  int _completedOriginalWords = 0;
  int _totalOriginalWords = 0;
  int _totalOriginalCorrect = 0;
  int _totalOriginalWrong = 0;
  int _totalOriginalRevealed = 0;
  final List<Word> _wrongWords = [];
  final List<Word> _revealedWords = [];
  final List<Word> _sessionWrongWords = [];
  final Set<int> _sessionWeakWordIds = {};

  // 错词强化队列
  bool _isStrengtheningMode = false;
  bool _isFinishing = false; // 学习结束流程已启动，防止再保存进度
  List<Word> _strengthenWords = [];

  // 智能模式切换：当前词的实际学习模式（可能与widget.studyMode不同）
  int _currentWordMode = 0;

  // 答题耗时记录
  DateTime? _wordStartTime;

  // 错词专项复习结果跟踪
  final Map<int, WrongWordReviewResult> _wrongWordReviewResults = {};
  final Map<int, int> _wrongWordCorrectStreaks = {};

  // 本批词里已收藏的单词 id（进页面时一次性取回，顶栏星标据此变化）
  Set<int> _favoriteIds = <int>{};

  /// 是否为了拼写 / 听力模式把系统输入法切到了英文
  ///
  /// 智能模式会逐词换模式，只有记住"现在切着英文呢"，下一题变成
  /// 回忆/测验时才知道要把它还回去。
  bool _imeSwitchedForTyping = false;

  /// 本轮拼写/听力会话里是否已经切过一次英文输入法。
  ///
  /// Android 上切换输入法子类型会让 IME 进程重启（键盘闪一下），
  /// 每道题都切一次是"键盘不断被调起"的另一个来源，所以整轮只切一次。
  bool _imeEnglishEnsured = false;

  // 获取当前有效的学习模式（智能模式开启时使用_currentWordMode，否则使用widget.studyMode）
  int get _effectiveStudyMode => widget.enableSmartMode && _currentWordMode > 0
      ? _currentWordMode
      : widget.studyMode;

  /// 当前模式在错词强度事件表里的标识
  ///
  /// 错题集的"错因标签"就是按这个字段聚合出来的（1 回忆 / 2 拼写 / 3 听写 /
  /// 4 英选中 / 5 中选英）。
  String get _reviewModeKey => switch (_effectiveStudyMode) {
    2 => 'spelling',
    3 => 'listening',
    4 => 'quizEnCn',
    5 => 'quizCnEn',
    _ => 'recall',
  };

  /// 本轮普通学习进度在 study_progress 里的键。
  ///
  /// 保存与清理必须用同一个键：该表按 progress_key 多来源并存，
  /// 无 where 的全表清理会把其它词库/其它来源的"继续学习"一起删掉。
  String get _progressKey => StudyProgressLogic.defaultProgressKey(
    source: 'normal',
    wordBookId: widget.wordBookId,
  );

  @override
  void initState() {
    super.initState();
    //学习页同样要监听生命周期：Android 上切到后台后进程可能被系统直接回收，
    //那时 dispose 不保证执行，本次会话的掌握度与"继续学习"进度就丢了
    WidgetsBinding.instance.addObserver(this);
    _words = widget.presetWords
        .where((word) => word.id != null)
        .toList(growable: false);

    _initializeStudy();
  }

  /// 退到后台立刻落盘（与阅读器同一套处理）。
  ///
  /// 每道题的复习记录本身是即时写库的、不会丢；这里补的是本次会话的
  /// 掌握度状态（影响次日智能模式判定）与剩余学习进度。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 后台期间不计入答题耗时：否则切出去几分钟再作答会被当成"慢答"，
      // 并把这个异常样本写进该词的耗时历史，永久污染快/慢答阈值
      _wordStartTime = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    // 切后台前把当前题结算掉（尽力而为：进程可能被系统直接回收）
    unawaited(_flushCurrentQuestionIfNeeded());
    // 异常必须消费：saveSession 落库失败若无人监听，会变成未捕获异步异常
    // （debug 污染 Zone / release 静默丢数据）
    unawaited(
      _masteryEngine.saveSession().catchError(
        (Object e) => debugPrint('保存掌握度会话失败：$e'),
      ),
    );
    _queueProgressSave();
  }

  /// 学习进度落盘的串行链。
  ///
  /// 换题（unawaited）、退后台、退出三路都会写同一条 study_progress 记录，
  /// 并发 upsert 的落盘顺序不确定：先发起（含更早 _currentIndex）、
  /// 后完成的写会覆盖新进度，导致"继续学习"恢复到错误的位置
  Future<void> _progressSaveChain = Future.value();

  void _queueProgressSave() {
    _progressSaveChain = _progressSaveChain
        .then((_) => _saveStudyProgress())
        .catchError((Object e) => debugPrint('保存学习进度失败：$e'));
  }

  Future<void> _initializeStudy() async {
    if (_words.isEmpty) {
      if (mounted) {
        setState(() => _initializationState = StudyInitializationState.empty);
      }
      return;
    }
    // 先取出依赖，避免 await 之后再碰 context
    final di = context.read<DIContainer>();
    try {
      await _preloadRecords();

      // 错词专项复习：把落库的"连续答对次数"载入内存基准。
      // 不载入的话每次都从 0 起算，"连续答对 3 次移出错词本"几乎不可能达成。
      //进度载入失败不该挡住开始学习，单独兜住异常
      if (widget.specializedRequest?.source == StudySource.wrongWords) {
        try {
          final streaks = await di.wrongWordService.getCorrectStreaks();
          for (final word in _words) {
            final id = word.id;
            if (id == null) continue;
            _wrongWordCorrectStreaks[id] = streaks[id] ?? 0;
          }
        } catch (e) {
          debugPrint('载入错词连续答对进度失败：$e');
        }
      }

      //异步加载近7天 S-MARS 会话状态，让智能模式跨会话生效（不阻塞进入学习）
      unawaited(
        _masteryEngine.loadMultiDaySession(days: 7).catchError((e) {
          debugPrint('加载 S-MARS 会话状态失败: $e');
        }),
      );

      if (!mounted) return;
      _totalOriginalWords = _words.length;

      _prepareModeState(playListeningAudio: true);

      setState(() => _initializationState = StudyInitializationState.ready);

      //收藏状态异步补上：一次查完整批词，慢一点或失败都不该拖住开始学习
      unawaited(_loadFavoriteIds());

      //首帧之后再提示顶栏按钮：此时按钮刚挂上，位置才是最终位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStudyActionsGuide();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializationState = StudyInitializationState.error;
        _initializationError = e.toString();
      });
    }
  }

  /// 把输入法还原成用户原来用的那个（没切过就是空操作）
  ///
  /// 平台侧没记录过原始状态时是空操作，所以重复调用也不会有副作用。
  void _restoreImeIfNeeded() {
    if (!_imeSwitchedForTyping) return;
    _imeSwitchedForTyping = false;
    //还回去之后，下一轮再进拼写/听力要允许重新切一次英文
    _imeEnglishEnsured = false;
    unawaited(KeyboardLanguageService.restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    //离开学习页无条件还原：智能模式中途换题会把 _imeSwitchedForTyping 清掉，
    //若只认标志，dispose 时就可能漏掉还原。平台侧没记录状态时是空操作，
    //重复调用安全，所以这里不判断标志，直接还。
    _imeSwitchedForTyping = false;
    _imeEnglishEnsured = false;
    unawaited(KeyboardLanguageService.restore());
    _revealTimer?.cancel();
    _shortcutFocusNode.dispose();
    _answerFocusNode.dispose();
    _answerController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  ///换题后把内容区滚回顶部
  ///
  ///新旧题目高度不同，保留上一题的滚动偏移会让新题一出现就停在中间，
  /// 看起来像"动画跳了一下"。
  ///
  /// 用 180ms 平滑滚动而不是 jumpTo：回忆模式在"已展开答案"状态下换题时
  /// 内容高度会骤降几百 dp，瞬时归零会看到一次生硬的跳动（测验模式高度
  /// 稳定，所以同样的 jumpTo 在那边几乎察觉不到）。
  void _resetContentScroll() {
    if (!_contentScrollController.hasClients) return;
    if (_contentScrollController.offset <= 0.5) return;
    _contentScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  /// 载入本批词的收藏状态（整批一次查询，避免每题一次）
  Future<void> _loadFavoriteIds() async {
    try {
      final ids = await context
          .read<DIContainer>()
          .favoriteService
          .filterFavorited(_words.map((w) => w.id).whereType<int>());
      if (!mounted) return;
      setState(() => _favoriteIds = ids);
    } catch (e) {
      debugPrint('加载收藏状态失败：$e');
    }
  }

  /// 顶栏星标：收藏/取消收藏当前单词
  ///
  /// 收藏是单词级的（跨词库、跨模式全局唯一），所以同一个词在阅读模式里
  /// 收藏过，这里会直接显示为已收藏。
  Future<void> _toggleCurrentFavorite() async {
    if (_words.isEmpty) return;
    final wordId = _words[_currentIndex].id;
    if (wordId == null) return;

    try {
      final nowFavorite = await context
          .read<DIContainer>()
          .favoriteService
          .toggleWord(wordId, source: FavoriteSource.study);
      if (!mounted) return;
      setState(() {
        nowFavorite ? _favoriteIds.add(wordId) : _favoriteIds.remove(wordId);
      });
      ErrorHandler.showSuccess(
        context,
        nowFavorite ? context.tr.favoriteAdded : context.tr.favoriteRemoved,
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.operationFailed,
      );
    }
  }

  Future<void> _preloadRecords() async {
    final reviewRepository =
        widget.reviewRepository ?? context.read<DIContainer>().reviewRepository;
    final wordIds = _words
        .map((w) => w.id)
        .whereType<int>()
        .toList(growable: false);
    final loaded = await reviewRepository.getReviewRecordsByWordIds(wordIds);
    _cachedRecords.addAll(loaded);
  }

  /// 回忆模式「延时自动显示释义」的定时器
  Timer? _revealTimer;

  /// 换题时重置释义计时。
  ///
  /// 只有回忆模式 + 设置里启用了延时才计时；其余情况一律取消，
  /// 否则上一题残留的计时器会在新题上"提前"把释义弹出来。
  void _scheduleRecallAutoReveal(int effectiveMode) {
    _revealTimer?.cancel();
    _revealTimer = null;
    if (effectiveMode != 1 || _showAnswer) return;
    final settings = context.read<StudySettingsProvider>();
    if (!settings.recallAutoReveal) return;
    _revealTimer = Timer(
      Duration(seconds: settings.recallRevealDelaySeconds),
      () {
        if (!mounted || _showAnswer) return;
        //弹窗/二级页（快捷键速查、释义设置）还开着时不能揭晓：那不是"用户在
        //想这个单词"的时间，到点揭晓会让用户关掉弹窗后突然发现释义已经显示
        //（反馈"点了操作提示后单词释义自动显示出来了"）。改到下次再计
        if (ModalRoute.of(context)?.isCurrent != true) {
          _scheduleRecallAutoReveal(effectiveMode);
          return;
        }
        _revealAnswer();
      },
    );
  }

  /// 回忆模式下是否已记录过"用户主动看释义"
  bool _hasRecordedRecallReveal = false;

  /// 显示释义。
  ///
  /// [userInitiated] 为 true 表示用户主动点开（点击空白处）——这要记一次
  /// "看答案"事件，否则错题集的"看答案次数/看答案错因"在回忆模式下恒为 0；
  /// 延时到点自动显示不算（那是应用自己弹的，不该给用户记错因）。
  void _revealAnswer({bool userInitiated = false}) {
    _revealTimer?.cancel();
    _revealTimer = null;
    if (_showAnswer) return;
    setState(() => _showAnswer = true);
    if (!userInitiated || _effectiveStudyMode != 1) return;
    final wordId = _words[_currentIndex].id;
    if (wordId == null || _hasRecordedRecallReveal) return;
    _hasRecordedRecallReveal = true;
    _recordStrengthEvent(wordId, StudyAttemptOutcome.revealed);
  }

  /// 是否允许"点击题面空白处显示释义"
  bool get _tapBlankRevealEnabled {
    if (_effectiveStudyMode != 1 || _showAnswer) return false;
    return context.read<StudySettingsProvider>().recallTapToReveal;
  }

  void _prepareModeState({bool playListeningAudio = false}) {
    _showAnswer = false;
    _hasCheckedAnswer = false;
    _isAnswerCorrect = false;
    _hasCompletedTypedAnswer = false;
    _hasRecordedTypedWrongAttempt = false;
    _hasRecordedTypedRevealAttempt = false;
    _hasRecordedTypedRetryCorrect = false;
    _hasRecordedRecallReveal = false;
    _qualityAttemptRecorded = false;
    _currentQuestionSaved = false;
    _selectedQuizOption = null;
    _answerController.clear();

    // 智能模式切换：确定当前词的学习模式
    int effectiveMode = widget.studyMode;
    if (widget.enableSmartMode) {
      final word = _words[_currentIndex];
      final wordId = word.id;
      // 用 hasState 而不是 states.containsKey：后者每次访问都会复制整张
      // 掌握度表（跨天会话可达数千条），而这里每道题都会走一次
      if (wordId != null && _masteryEngine.hasState(wordId)) {
        final state = _masteryEngine.stateFor(wordId);
        final recommendedMode = _masteryEngine.recommendNextMode(
          currentMode: widget.studyMode,
          state: state,
          enableSpotCheck: true,
        );

        if (recommendedMode == null) {
          // 跳过已掌握的词
          _skippedCount++;
          // 继续下一个词
          if (_currentIndex < _words.length - 1) {
            setState(() {
              _currentIndex++;
            });
            _resetContentScroll();
            // 使用循环代替递归，防止栈溢出。
            // 必须判 mounted：跳过一个词就要多等一帧，跳过 N 个词期间用户
            // 完全可能按返回键退出本页，帧回调会在已 dispose 的 State 上
            // 继续读 context / setState
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _prepareModeState(playListeningAudio: playListeningAudio);
            });
            return;
          } else {
            _finishStudy();
            return;
          }
        } else {
          effectiveMode = recommendedMode;
        }
      }
    }

    _currentWordMode = effectiveMode;

    // 记录开始答题时间
    _wordStartTime = DateTime.now();

    if (effectiveMode == 4 || effectiveMode == 5) {
      _quizOptions = _generateQuizOptions(_words[_currentIndex]);
      // 干扰项不足（含自身不到 4 个）时，测验会退化成二选一甚至无意义。
      // 临时 fallback 到回忆模式：用户仍能看见题目并主动回忆，避免乱选。
      if (_quizOptions.length < 4) {
        effectiveMode = 1;
        _currentWordMode = 1;
        _quizOptions = [];
      }
    } else {
      _quizOptions = [];
    }

    if (effectiveMode == 2 || effectiveMode == 3) {
      //拼写 / 听力输入的是英文单词：先把系统输入法切到英文，再聚焦输入框。
      //桌面端由此可以"进入即打字"，不用先手动切输入法；两个调用都不阻塞答题。
      _imeSwitchedForTyping = true;
      //整轮只切一次英文：Android 上切换输入法子类型会重启 IME，
      //每题都调用会让键盘反复闪断
      if (!_imeEnglishEnsured) {
        _imeEnglishEnsured = true;
        unawaited(KeyboardLanguageService.ensureEnglish());
      }
      //只在输入框还没焦点时请求一次：反复 requestFocus 会让 Android 输入法
      //"收起又弹出"，连续几十次后 IME 服务可能进入异常状态，
      //之后手动点输入框也弹不出来（用户实际反馈）
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestAnswerFocus());
    } else {
      //智能模式逐词换模式：上一题是拼写（切了英文）、这一题不是，
      //得把输入法还回去，否则用户得自己手动切回中文。
      _restoreImeIfNeeded();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            PlatformAdapt.showKeyboardShortcuts(context) &&
            _shortcutFocusNode.canRequestFocus) {
          _shortcutFocusNode.requestFocus();
        }
      });
    }
    //回忆模式：登记"延时自动显示释义"（换题即重新计时）
    _scheduleRecallAutoReveal(effectiveMode);

    final settings = context.read<StudySettingsProvider>();
    if (playListeningAudio && effectiveMode == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playWord());
    } else if (playListeningAudio && settings.autoPlayAudio) {
      //自动发音只在回忆模式下触发：拼写/测验模式先听到发音等于直接给答案
      if (effectiveMode == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _playWord());
      }
    }
  }

  Future<bool> _saveCurrentQuality(int quality) async {
    if (_isSavingQuality) return false;
    //同一题只结算一次（退出/切后台可能已经提前结算过）：重复结算会让
    //SM-2 的 repetitions/interval 白白多推进一档
    if (_currentQuestionSaved) return true;
    //忙碌态要上屏：点击评分/下一题后按钮立刻给出"已收到"的反馈，
    //否则保存期间界面毫无动静，用户会感觉"点了没反应然后突然跳题"
    _isSavingQuality = true;
    if (mounted) setState(() {});

    final word = _words[_currentIndex];
    //统一在此解包：同文件其他地方都把 word.id 当可空处理，这里若用 id!
    //强解包，id 为空时会抛 Null check operator 崩溃且该题不落库
    final wordId = word.id;
    if (wordId == null) {
      debugPrint('DirectStudyScreen._saveCurrentQuality: word.id 为空，跳过保存');
      _isSavingQuality = false;
      if (mounted) setState(() {});
      return false;
    }
    final record = _cachedRecords.containsKey(wordId)
        ? (_cachedRecords[wordId] ??
              ReviewScheduler.createInitialRecord(wordId))
        : ReviewScheduler.createInitialRecord(wordId);
    final reviewQuality = _masteryEngine.hasState(wordId)
        ? _masteryEngine.calculateReviewQuality(wordId)
        : quality;

    try {
      if (_isStrengtheningMode) {
        // 强化阶段是本轮的"加练"：原始阶段已经推进过一次调度，
        // 这里再 scheduleNextReview 会让 repetitions 多推一档、next_review 更远，
        // 与"错词应该更快再见"相反。强化阶段只更新错词本，不写调度。
        if (reviewQuality < 3) await _addCurrentWordToWrongWords(word);
      } else {
        final nextRecord = ReviewScheduler.scheduleNextReview(
          record,
          reviewQuality,
        );
        final reviewRepository =
            widget.reviewRepository ??
            context.read<DIContainer>().reviewRepository;
        await reviewRepository.saveReviewRecord(nextRecord);
        _cachedRecords[wordId] = nextRecord;
        _completedOriginalWords++;
        if (reviewQuality < 3) await _addCurrentWordToWrongWords(word);
      }
      _currentQuestionSaved = true;
    } catch (e) {
      debugPrint('保存复习记录失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr.saveRecordFailed)));
      }
      _isSavingQuality = false;
      if (mounted) setState(() {}); //恢复可点击，让用户能重试
      return false;
    }

    //成功路径紧接着就是换题（内部会 setState），这里不再单独重建
    _isSavingQuality = false;
    return true;
  }

  /// 结算"已经作答但还没落库"的当前题（退出 / 切后台时调用）。
  ///
  /// 不结算的话，错因事件（wrong_words_strength）与掌握度
  /// （session_mastery_records）已经写库、而复习记录（review_records）
  /// 与错词本没有 —— 同一个词在三处存储里互相矛盾。
  /// 回忆模式未点评分按钮时视为"用户没给结论"，不结算。
  Future<void> _flushCurrentQuestionIfNeeded() async {
    if (!mounted || _isSavingQuality || _currentQuestionSaved) return;
    final mode = _effectiveStudyMode;
    final answeredTyped = (mode == 2 || mode == 3) && _hasCheckedAnswer;
    final answeredQuiz =
        (mode == 4 || mode == 5) &&
        (_selectedQuizOption != null || _hasCheckedAnswer);
    if (!answeredTyped && !answeredQuiz) return;
    await _saveCurrentQuality(_isAnswerCorrect ? 4 : 1);
  }

  Future<void> _addCurrentWordToWrongWords(Word word) async {
    if (widget.specializedRequest?.source == StudySource.wrongWords) return;
    final wordId = word.id;
    if (wordId == null) return;
    //保存复习记录后可能已退出学习页，跨 async gap 用 context 前必须校验
    if (!mounted) return;
    try {
      await context.read<DIContainer>().wrongWordService.addWrongWord(wordId);
    } catch (e) {
      _logScreenError('addCurrentWordToWrongWords', e);
    }
  }

  void _goToNextWord() {
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _prepareModeState(playListeningAudio: true);
      });
      _resetContentScroll();
      // _prepareModeState 可能因智能跳过最后一个词而触发结束流程，此时不能再保存进度
      if (!_isFinishing) {
        _queueProgressSave();
      }
    } else {
      _finishStudy();
    }
  }

  //保存剩余学习进度，供主页"继续学习"恢复（仅普通学习流程）
  Future<void> _saveStudyProgress() async {
    if (_isFinishing ||
        _isStrengtheningMode ||
        widget.specializedRequest != null) {
      return;
    }
    final wordIds = _words
        .skip(_currentIndex)
        .map((w) => w.id)
        .whereType<int>()
        .toList(growable: false);
    if (wordIds.isEmpty) return;
    try {
      await DIContainer.instance.studyProgressRepository
          .saveStudyProgress(
            wordBookId: widget.wordBookId,
            studyMode: widget.studyMode,
            isReview: widget.isReview,
            currentIndex: 0,
            wordIds: wordIds,
            //显式给出 key，与 clearStudyProgress 用同一个（见 _progressKey）
            progressKey: _progressKey,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => debugPrint('保存学习进度超时'),
          );
    } catch (e) {
      debugPrint('保存学习进度失败: $e');
    }
  }

  bool _isExiting = false; //退出保存已启动（防重入；不再显示遮罩）

  //退出学习：先返回上一页，S-MARS 会话与剩余进度在后台保存。
  //
  //此前是"保存完才 pop"，保存阻塞期间盖一层转圈遮罩（最坏 10 秒超时），
  //观感就是"退出时闪一下加载圈"。保存是纯落库操作，不依赖页面 UI
  //（引擎与仓库都是脱离页面生命周期的对象），先 pop 再保存体验更顺。
  Future<void> _confirmExitStudy() async {
    if (_isExiting || _isFinishing) return; //保存中/结束流程已启动时屏蔽，防止重复保存或误 pop 总结页
    _isExiting = true;
    // 退出前先结算"已作答但未落库"的当前题（写 review_records / 错词本）。
    // 必须在 pop 之前：pop 之后 context 失效，保存会失败。
    await _flushCurrentQuestionIfNeeded();
    if (mounted) Navigator.pop(context);
    try {
      // 先把"当前状态"排进串行队列，再等队列与 S-MARS 保存一起完成；
      // 直接并发调用会与排队中的旧保存竞争落盘顺序
      _queueProgressSave();
      //整体保存超时保护，防止无限等待
      await Future.wait([
        _masteryEngine.saveSession().timeout(
          const Duration(seconds: 8),
          onTimeout: () => debugPrint('保存S-MARS会话超时'),
        ),
        _progressSaveChain,
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('退出保存整体超时');
          return <void>[];
        },
      );
    } catch (e) {
      debugPrint('退出保存失败: $e');
    }
  }

  void _recordMasteryAttempt(StudyAttemptOutcome outcome) {
    final word = _words[_currentIndex];
    final wordId = word.id;
    if (wordId == null) return;

    // 保护：确保当前模式已初始化
    if (_currentWordMode == 0) {
      debugPrint('警告：_currentWordMode未初始化，使用默认模式');
    }

    // 计算答题耗时（如果_wordStartTime为null，使用默认值3000ms）
    int durationMs = 3000; // 默认3秒
    if (_wordStartTime != null) {
      durationMs = DateTime.now().difference(_wordStartTime!).inMilliseconds;
      // 保护：如果耗时异常（小于100ms或大于5分钟），使用默认值
      if (durationMs < 100 || durationMs > 300000) {
        debugPrint('警告：答题耗时异常($durationMs ms)，使用默认值');
        durationMs = 3000;
      }
    }

    // 使用带耗时的记录方法
    final state = _masteryEngine.recordAttemptWithDuration(
      wordId: wordId,
      mode: SessionMasteryEngine.modeFromStudyMode(
        _currentWordMode > 0 ? _currentWordMode : widget.studyMode,
      ),
      outcome: outcome,
      reviewRecord: _cachedRecords[wordId],
      durationMs: durationMs,
    );
    if (state.isMastered) {
      _wrongWords.removeWhere((wrongWord) => wrongWord.id == wordId);
    }

    _recordStrengthEvent(wordId, outcome);
  }

  /// 把本次作答写入错词强度事件表（wrong_words_strength）
  ///
  /// 弱词评分里的"近期错误次数 / 查看答案次数"两维、以及错题集的错因标签，
  /// 全部只依赖这张事件表。此前项目里**只有单测**会写它，生产流程从未写入，
  /// 导致这些维度恒为 0、错因也无从统计。
  void _recordStrengthEvent(int wordId, StudyAttemptOutcome outcome) {
    // is_wrong 的语义是"这次作答没能独立回忆起来"，口径必须和引擎的
    // _isWrong（wrong / recallForgot / recallVague）一致，并额外包含"看答案"：
    // 错题集的错因聚合是按 is_wrong = 1 过滤后再统计 viewed_answer 的，
    // 此前"模糊"与"看答案"都写成 is_wrong = 0，导致这两类错因永远统计不到。
    final isWrong = switch (outcome) {
      StudyAttemptOutcome.wrong ||
      StudyAttemptOutcome.recallForgot ||
      StudyAttemptOutcome.recallVague ||
      StudyAttemptOutcome.revealed => true,
      _ => false,
    };
    //直接走 DAO：WrongWordService 只是它的透传壳，且事件写入属于"尽力而为"，
    //不该因为 DI 未就绪（单测环境）而打断答题主流程
    unawaited(
      DatabaseService.wrongWordDao
          .addStrengthEvent(
            wordId: wordId,
            isWrong: isWrong,
            viewedAnswer: outcome == StudyAttemptOutcome.revealed,
            reviewMode: _reviewModeKey,
          )
          .catchError((Object e) {
            debugPrint('记录错词强度事件失败：$e');
          }),
    );
  }

  void _recordCorrectProgress(Word word) {
    _correctCount++;
    _wrongWords.removeWhere((wrongWord) => wrongWord.id == word.id);
  }

  void _recordWeakProgress(Word word, {bool revealed = false}) {
    final wordId = word.id;
    if (wordId != null) {
      _sessionWeakWordIds.add(wordId);
      if (!_sessionWrongWords.any((wrongWord) => wrongWord.id == wordId)) {
        _sessionWrongWords.add(word);
      }
    }
    if (revealed) {
      _revealedCount++;
      if (!_revealedWords.contains(word)) {
        _revealedWords.add(word);
      }
    } else {
      _wrongCount++;
    }
    if (!_wrongWords.contains(word)) {
      _wrongWords.add(word);
    }
  }

  void _recordWrongWordReviewResult({
    required Word word,
    required bool wasCorrect,
    required bool revealedAnswer,
  }) {
    if (widget.specializedRequest?.source != StudySource.wrongWords) return;
    final wordId = word.id;
    if (wordId == null) return;

    final previous = _wrongWordCorrectStreaks[wordId] ?? 0;
    final result = WrongWordReviewResult(
      wordId: wordId,
      wasCorrect: wasCorrect,
      revealedAnswer: revealedAnswer,
      previousCorrectStreak: previous,
    );
    _wrongWordCorrectStreaks[wordId] = result.nextCorrectStreak;
    _wrongWordReviewResults[wordId] = result;
  }

  /// 结算后把焦点交还给快捷键节点（桌面端：回车/空格/数字键继续可用）。
  ///
  /// 移动端**绝不能**这样做：焦点一离开输入框，Android 输入法立刻收起，
  /// 下一题又请求焦点把它弹起来 —— 用户看到的就是键盘"下去又上来"，
  /// 反复几十次后 IME 服务还会进入异常状态（之后手点输入框也弹不出来）。
  void _focusStudyShortcuts() {
    if (!mounted) return;
    if (!PlatformAdapt.showKeyboardShortcuts(context)) return;
    if (_isTypedMode) {
      _answerFocusNode.unfocus();
    }
    if (_shortcutFocusNode.canRequestFocus) {
      _shortcutFocusNode.requestFocus();
    }
  }

  /// 回忆模式三档评分
  ///
  /// | 按钮   | 传入 quality | 掌握度事件            | 调度效果                     |
  /// |--------|--------------|----------------------|------------------------------|
  /// | 不认识 | 1            | recallForgot(15)     | 间隔重置为 1 天 + 进错词本    |
  /// | 模糊   | 3            | recallVague(38)      | 间隔按基础序列推进（不缩短）   |
  /// | 记住   | 4            | recallRemembered(72) | 间隔 ×1.2，难度因子上调       |
  ///
  /// 「非常熟悉」那一档不再由用户手点：掌握度引擎会按整轮表现
  /// （见 SessionMasteryEngine.calculateReviewQuality）自动给出 quality 5，
  /// 自评只保留"没想起来 / 想起来但虚 / 想起来了"三档，避免自评偏乐观。
  Future<void> _onQualitySelected(int quality) async {
    //入口互斥：防止双击/连点导致重复计数（保存互斥锁在计数之后才生效）
    if (_isSavingQuality) return;
    final word = _words[_currentIndex];
    //同词重复作答（保存失败后重点）时跳过计数，避免统计虚高
    if (!_qualityAttemptRecorded) {
      _qualityAttemptRecorded = true;
      final outcome = switch (quality) {
        4 || 5 => StudyAttemptOutcome.recallRemembered,
        3 => StudyAttemptOutcome.recallVague,
        _ => StudyAttemptOutcome.recallForgot,
      };
      setState(() {
        _recordMasteryAttempt(outcome);
        if (quality >= 4) {
          _recordCorrectProgress(word);
        } else {
          _recordWeakProgress(word);
        }
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: quality >= 4,
          //与拼写/听写模式口径一致：看过释义再点"记住"要重置连续答对，
          //否则"看答案+记住"连续 3 轮就能把词误判移出错词本
          revealedAnswer: _hasRecordedRecallReveal,
        );
      });
    }
    final saved = await _saveCurrentQuality(quality);
    if (!saved || !mounted) return;
    _goToNextWord();
  }

  Future<void> _onPracticeNext() async {
    if (!_hasCheckedAnswer) return;
    //与评分入口一致：保存期间再点无效，避免连点重复写入
    if (_isSavingQuality) return;
    if ((_effectiveStudyMode == 2 || _effectiveStudyMode == 3) &&
        !_isAnswerCorrect &&
        !_hasCompletedTypedAnswer) {
      return;
    }
    final saved = await _saveCurrentQuality(_isAnswerCorrect ? 4 : 1);
    if (!saved || !mounted) return;
    _goToNextWord();
  }

  Future<void> _finishStudy() async {
    // 重入守卫：收尾有多步 await（保存会话 / 清进度 / 回写计划 / 读今日任务），
    // 这个窗口里再点一次「完成」会让 SM-2 二次推进、计划进度虚高、
    // 总结页被 push 两次
    if (_isFinishing) return;
    _isFinishing = true;
    // 如果有错词且不在强化模式中，进入错词强化队列
    if (!_isStrengtheningMode && _wrongWords.isNotEmpty) {
      await _startStrengthenMode();
      return;
    }

    // 保存会话状态到数据库（跨天持久化）
    final di = context.read<DIContainer>();
    final studySettingsProvider = context.read<StudySettingsProvider>();
    final studyProgressRepository = di.studyProgressRepository;
    final wrongWordService = di.wrongWordService;

    // 收尾的每一步独立兜底：此前任一步抛错都会中断整个流程，而
    // _isFinishing=true + PopScope(canPop:false) 同时屏蔽了退出入口，
    // 用户会永久卡在最后一题（既进不了总结页也退不出去）
    Future<void> runStep(String label, Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        debugPrint('学习收尾步骤失败（$label）：$e');
      }
    }

    await runStep('保存S-MARS会话', _masteryEngine.saveSession);
    // 先等在途的换题保存落盘再清进度：在途保存带着"还剩最后一题"的非空
    // wordIds，若它在 clearStudyProgress 之后落盘，已完成的会话会以
    // "继续学习"复活（退出路径 _confirmExitStudy 已特意等了这条链，
    // 结束路径此前漏掉了）
    await runStep('等待在途进度保存', () => _progressSaveChain);
    await runStep(
      '清除学习进度',
      () =>
          studyProgressRepository.clearStudyProgress(progressKey: _progressKey),
    );

    // 应用错词专项复习结果
    if (widget.specializedRequest?.source == StudySource.wrongWords &&
        _wrongWordReviewResults.isNotEmpty) {
      await runStep(
        '应用错词复习结果',
        () => wrongWordService.applyReviewResults(
          _wrongWordReviewResults.values.toList(),
        ),
      );
    }

    // 收集S-MARS状态分布
    final masteryStates = Map<int, SessionMasteryState>.from(
      _masteryEngine.states,
    );

    // 合并原始阶段和强化阶段的统计数据
    final finalCorrectCount = _totalOriginalCorrect + _correctCount;
    final finalWrongCount = _totalOriginalWrong + _wrongCount;
    final finalRevealedCount = _totalOriginalRevealed + _revealedCount;

    // 回写学习计划今日任务进度：普通学习/计划学习计入任务，错词等专项不计入新词/复习目标
    final source = widget.specializedRequest?.source;
    if (source == null || source == StudySource.studyPlan) {
      await runStep(
        '回写学习计划进度',
        () => di.studyPlanService.recordProgress(
          newWords: widget.isReview ? 0 : _completedOriginalWords,
          reviewWords: widget.isReview ? _completedOriginalWords : 0,
        ),
      );
    }
    await runStep('更新连续学习天数', studySettingsProvider.updateStreak);

    // 学习数据已变：让薄弱词/周报的内存缓存失效，否则用户学完回到首页，
    // "薄弱词"和"本周报告"最长 5min/60s 才更新，以为"练了没效果"。
    unawaited(
      runStep('刷新薄弱词缓存', () async {
        di.weakVocabularyService.invalidate();
      }),
    );
    unawaited(
      runStep('刷新周报缓存', () async {
        di.weeklyReportService.invalidate();
      }),
    );

    // 今日任务读取失败不阻断总结页：按未完成展示即可
    var dailyTaskCompleted = false;
    await runStep('读取今日任务', () async {
      final todayTask = await di.studyPlanService.getTodayTask();
      dailyTaskCompleted = todayTask.isCompleted;
    });

    final sessionSummary = StudySessionSummary(
      totalWords: _totalOriginalWords,
      weakWords: _sessionWeakWordIds.length,
      revealedWords: finalRevealedCount,
      skippedWords: _skippedCount,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageTransitions.fade(
        page: _StudySummaryScreen(
          isReview: widget.isReview,
          totalWords: _totalOriginalWords, // 使用原始总词数
          correctCount: finalCorrectCount, // 合并统计
          wrongCount: finalWrongCount,
          revealedCount: finalRevealedCount,
          wrongWords: _sessionWrongWords,
          revealedWords: _revealedWords,
          wordBookId: widget.wordBookId,
          studyMode: widget.studyMode,
          skippedCount: _skippedCount,
          sessionSummary: sessionSummary,
          enableSmartMode: widget.enableSmartMode,
          masteryStates: masteryStates, // 传递S-MARS状态
          dailyTaskCompleted: dailyTaskCompleted,
        ),
      ),
    );
  }

  Future<void> _startStrengthenMode() async {
    // 保存原始阶段的统计数据（用于总结页显示）
    _totalOriginalCorrect = _correctCount;
    _totalOriginalWrong = _wrongCount;
    _totalOriginalRevealed = _revealedCount;

    //原始队列已完成，清除其学习进度（只清本轮这个 key，别动别的来源/词库）。
    //先等在途的换题保存落盘，否则它可能在清理之后写入、复活已完成会话
    await _progressSaveChain;
    if (!mounted) return;
    unawaited(
      DIContainer.instance.studyProgressRepository.clearStudyProgress(
        progressKey: _progressKey,
      ),
    );

    setState(() {
      _isStrengtheningMode = true;
      //强化阶段仍可中途退出，复位结束标志，否则退出确认被 _isFinishing 屏蔽
      _isFinishing = false;
      _strengthenWords = List.from(_wrongWords);
      _words = _strengthenWords;
      _currentIndex = 0;
      _correctCount = 0;
      _wrongCount = 0;
      _revealedCount = 0;
      _wrongWords.clear();
      _revealedWords.clear();
      _prepareModeState(playListeningAudio: true);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.strengthenModeStart),
        behavior: SnackBarBehavior.floating,
        backgroundColor: FluidTheme.warning,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _playWord() async {
    //本方法由 addPostFrameCallback 延迟调度，回调抵达时页面可能已退出
    if (!mounted) return;
    final ttsService = context.read<TtsService>();
    // 上一题的朗读可能还在播：先停掉再播新词。此前直接 return，
    // 结果听力模式换题后的自动发音被静默吞掉（界面没声音也没提示）
    if (_isPlaying) {
      await ttsService.stop();
      if (!mounted) return;
      setState(() => _isPlaying = false);
    }
    setState(() => _isPlaying = true);
    try {
      await ttsService.playWord(_words[_currentIndex].word);
    } catch (e) {
      _logScreenError('ttsPlayWord', e);
    }
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  /// 首次进入做题页：介绍顶栏的收藏、查词典与操作提示入口。
  ///
  /// 与选词页的 [GuideService.tipStudyModes] 相互独立，各自只提示一次；
  /// 若这次没能弹出（开屏未结束），下次再做题时会补上。
  Future<void> _showStudyActionsGuide() async {
    if (!mounted) return;
    await CoachMarkOverlay.maybeShowAfterSplash(
      context,
      guideId: GuideService.tipStudyActions,
      steps: () => _words.isEmpty
          ? const <CoachMarkStep>[]
          : [
              CoachMarkStep(
                targetKey: guideStudyFavoriteKey,
                title: context.tr.coachStudyFavoriteTitle,
                message: context.tr.coachStudyFavoriteMsg,
                icon: Icons.star_border,
              ),
              CoachMarkStep(
                targetKey: guideStudyDictKey,
                title: context.tr.coachStudyDictTitle,
                message: context.tr.coachStudyDictMsg,
                icon: Icons.menu_book_outlined,
              ),
              //快捷键入口只在桌面端存在，移动端连引导步骤一起跳过：
              //高亮一个不存在的控件没有任何意义
              if (PlatformAdapt.showKeyboardShortcuts(context))
                CoachMarkStep(
                  targetKey: guideStudyShortcutKey,
                  title: context.tr.coachStudyTipsTitle,
                  message: context.tr.coachStudyShortcutMsg,
                  icon: Icons.help_outline,
                ),
            ],
    );
  }

  /// 学习模式查词典：先确认（避免误查泄题），确认后弹词典弹窗
  Future<void> _lookupCurrentWord() async {
    final word = _words[_currentIndex].word;
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final ok = await showFluidDialog<bool>(
      context: context,
      maxWidth: 340,
      title: context.tr.lookupDictionary,
      content: Builder(
        builder: (ctx) => Text(
          context.tr.dictLookupConfirmHint,
          style: FluidTheme.bodyMedium(isDark),
        ),
      ),
      actions: [
        Builder(
          //actions 用对话框自身 context pop，避免连点时第二次误弹学习页
          builder: (ctx) => FluidTextButton(
            text: context.tr.cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
        ),
        Builder(
          builder: (ctx) => FluidButton(
            text: context.tr.confirm,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    await showDictionaryLookupDialog(context: context, word: word);
  }

  void _checkTypedAnswer() {
    final word = _words[_currentIndex];
    final userAnswer = _answerController.text;
    // 空输入不判错：桌面端回车 / 「检查」按钮很容易被误触，判错一次就等于
    // 凭空多一个错词（还叠加"秒答答错"的时间惩罚）
    if (_normalizeAnswer(userAnswer).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.pleaseInputAnswer),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final isCorrect =
        _normalizeAnswer(userAnswer) == _normalizeAnswer(word.word);

    // 拼写容错提示：如果接近正确答案，显示提示但不计为正确
    final isClose = !isCorrect && _isCloseAnswer(userAnswer, word.word);

    setState(() {
      _hasCheckedAnswer = true;
      _isAnswerCorrect = isCorrect;
      if (isCorrect) {
        _hasCompletedTypedAnswer = true;
        if (!_hasRecordedTypedRevealAttempt && !_hasRecordedTypedWrongAttempt) {
          _recordMasteryAttempt(StudyAttemptOutcome.firstCorrect);
          _recordCorrectProgress(word);
        } else if (!_hasRecordedTypedRetryCorrect &&
            !_hasRecordedTypedRevealAttempt) {
          // 先答错、看过提示后重试答对：仍按"重试答对"计入正确，
          // 否则该词会一直留在错词/强化队列里（_recordCorrectProgress 才会移除）
          _hasRecordedTypedRetryCorrect = true;
          _recordMasteryAttempt(StudyAttemptOutcome.retryCorrect);
          _recordCorrectProgress(word);
        }
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: true,
          revealedAnswer: false,
        );
      } else {
        if (!_hasRecordedTypedWrongAttempt) {
          _hasRecordedTypedWrongAttempt = true;
          _recordMasteryAttempt(StudyAttemptOutcome.wrong);
          _recordWeakProgress(word);
        }
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: false,
          revealedAnswer: false,
        );
      }
    });

    // 显示拼写容错提示
    if (isClose && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.spellingCloseHint),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FluidTheme.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (isCorrect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusStudyShortcuts();
      });
    }
    if (!isCorrect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        //已有焦点就不要再请求：重复 requestFocus 会反复触发 IME 显示
        if (mounted &&
            _answerFocusNode.canRequestFocus &&
            !_answerFocusNode.hasFocus) {
          _answerFocusNode.requestFocus();
        }
      });
    }
  }

  void _revealTypedAnswer() {
    final word = _words[_currentIndex];
    setState(() {
      _hasCheckedAnswer = true;
      _isAnswerCorrect = false;
      _hasCompletedTypedAnswer = true;
      if (!_hasRecordedTypedRevealAttempt) {
        _hasRecordedTypedRevealAttempt = true;
        _recordMasteryAttempt(StudyAttemptOutcome.revealed);
        _recordWeakProgress(word, revealed: true);
      }
      _recordWrongWordReviewResult(
        word: word,
        wasCorrect: false,
        revealedAnswer: true,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusStudyShortcuts();
    });
  }

  /// 点击输入框时确保系统键盘真的弹出来。
  ///
  /// Android 上存在"焦点还在输入框、输入法却被系统收起"的状态：按返回键收起键盘、
  /// 切换输入法子类型导致 IME 重启、从后台回到前台都会走到这里。此时焦点没有变化，
  /// 框架不会重新 `show()` 输入法，用户看到的就是"点输入框没反应、打不了字"。
  /// 这里以键盘内边距为准判断键盘是否在屏：不在屏就主动重建一次焦点。
  void _ensureTypedInputFocus() {
    if (!mounted || !_isTypedMode) return;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return; // 键盘已在
    _requestAnswerFocus();
  }

  /// 请求输入框焦点 + 键盘未上屏的自愈。
  ///
  /// 微信等第三方 IME 偶发"焦点在、连接断"：requestFocus 因焦点未变化而是
  /// 空操作，键盘永远不出来（重进 App 也不恢复）。这里在请求焦点 700ms 后
  /// 检查一次：焦点还在而键盘没上屏，就显式关连接再重聚焦点；每轮请求只
  /// 自愈一次，避免与彻底坏掉的 IME 形成新的收起/弹起循环。
  void _requestAnswerFocus() {
    if (!mounted || !_answerFocusNode.canRequestFocus) return;
    if (!_answerFocusNode.hasFocus) {
      _answerFocusNode.requestFocus();
    }
    if (_imeRecoveryPending) return;
    _imeRecoveryPending = true;
    Future.delayed(const Duration(milliseconds: 700), () async {
      _imeRecoveryPending = false;
      if (!mounted || !_isTypedMode) return;
      if (!_answerFocusNode.hasFocus) return;
      if (!_answerFocusNode.canRequestFocus) return;
      if (MediaQuery.viewInsetsOf(context).bottom > 0) return; // 键盘已上屏
      _answerFocusNode.unfocus();
      try {
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      } catch (_) {
        // 通道失败不影响后面的重聚焦
      }
      if (!mounted || !_answerFocusNode.canRequestFocus) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _answerFocusNode.canRequestFocus) {
          _answerFocusNode.requestFocus();
        }
      });
    });
  }

  /// 键盘上屏后把行动按钮滚进可视区：内容没溢出时是空操作
  void _scrollActionsIntoViewAfterKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_contentScrollController.hasClients) return;
      final pos = _contentScrollController.position;
      if (pos.maxScrollExtent <= 0) return;
      if (pos.maxScrollExtent - pos.pixels < 8) return;
      _contentScrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _retryTypedAnswer() {
    setState(() {
      _hasCheckedAnswer = false;
      _isAnswerCorrect = false;
      _hasCompletedTypedAnswer = false;
      _answerController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestAnswerFocus();
    });
  }

  void _selectQuizOption(int index) {
    if (_selectedQuizOption != null) return;
    final word = _words[_currentIndex];
    setState(() {
      _selectedQuizOption = index;
      _hasCheckedAnswer = true;
      _isAnswerCorrect = _quizOptions[index] == _correctQuizAnswer(word);
      _showAnswer = true;
      if (_isAnswerCorrect) {
        _recordMasteryAttempt(StudyAttemptOutcome.firstCorrect);
        _recordCorrectProgress(word);
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: true,
          revealedAnswer: false,
        );
      } else {
        _recordMasteryAttempt(StudyAttemptOutcome.wrong);
        _recordWeakProgress(word);
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: false,
          revealedAnswer: false,
        );
      }
    });
  }

  /// 测验干扰项取样/洗牌的随机源：复用单个 Random，避免每题新建对象
  static final math.Random _random = math.Random();

  /// 连续空白：判卷时每个答案都会用到（见 [_normalizeAnswer] / [_isCloseAnswer]），
  /// 正则提到类级别只编译一次
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// 英文字母 / 非英文字母：拼写与听力输入框的过滤器与 onChanged 清洗
  /// 每敲一个键都会走一次，此前每次 build 都重新编译正则并新建 Formatter
  static final RegExp _asciiLetters = RegExp(r'[a-zA-Z]');
  static final RegExp _nonAsciiLetters = RegExp(r'[^a-zA-Z]');
  static final List<TextInputFormatter> _lettersOnlyFormatter = [
    FilteringTextInputFormatter.allow(_asciiLetters),
  ];

  String _normalizeAnswer(String value) {
    return value.trim().toLowerCase().replaceAll(_whitespaceRun, ' ');
  }

  /// 计算两个字符串的编辑距离（Levenshtein Distance）
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final List<List<int>> dp = List.generate(
      s1.length + 1,
      (_) => List<int>.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[s1.length][s2.length];
  }

  /// 判断用户输入是否接近正确答案（用于拼写容错提示）
  bool _isCloseAnswer(String input, String correct) {
    final normalizedInput = _normalizeAnswer(input);
    final normalizedCorrect = _normalizeAnswer(correct);

    if (normalizedInput.isEmpty || normalizedCorrect.isEmpty) return false;
    if (normalizedInput == normalizedCorrect) return false; // 已经是正确答案

    final distance = _levenshteinDistance(normalizedInput, normalizedCorrect);
    final maxLen = normalizedInput.length > normalizedCorrect.length
        ? normalizedInput.length
        : normalizedCorrect.length;

    // 如果编辑距离小于等于单词长度的 30% 且最多差 2 个字符，认为是接近答案
    final threshold = (maxLen * 0.3).ceil();
    return distance <= threshold && distance <= 2;
  }

  String _correctQuizAnswer(Word word) {
    return _effectiveStudyMode == 4 ? _definitionText(word) : word.word;
  }

  String _definitionText(Word word) {
    return word.definition.trim().isNotEmpty
        ? word.definition.trim()
        : context.tr.noDefinition;
  }

  List<String> _generateQuizOptions(Word word) {
    final correct = _correctQuizAnswer(word);
    final options = <String>{correct};
    final isDefinitionMode = _effectiveStudyMode == 4;
    //只需要 3 个干扰项：改为随机取样，避免对可能上万条的 _words
    //做全量 map/filter/shuffle（每道题都会执行一次）
    const needed = 3;
    final poolSize = _words.length;
    if (poolSize > 0) {
      //取样次数上限：词库很小或有效样本稀少时保证收敛
      final maxAttempts = math.min(poolSize * 2, 400);
      var attempts = 0;
      while (options.length <= needed && attempts < maxAttempts) {
        attempts++;
        final item = _words[_random.nextInt(poolSize)];
        if (item.id == word.id) continue;
        final value = isDefinitionMode ? _definitionText(item) : item.word;
        if (value.trim().isEmpty || value == correct) continue;
        options.add(value);
      }
    }
    var fallbackIndex = 1;
    while (options.length < math.min(4, math.max(_words.length, 2))) {
      options.add(
        _effectiveStudyMode == 4
            ? '${context.tr.noDefinition} $fallbackIndex'
            : '${context.tr.quizFallbackOption} $fallbackIndex',
      );
      fallbackIndex++;
    }
    final result = options.toList()..shuffle(_random);
    return result;
  }

  bool get _handlesEnterShortcut =>
      _effectiveStudyMode >= 1 && _effectiveStudyMode <= 5;

  bool get _isTypedMode => _effectiveStudyMode == 2 || _effectiveStudyMode == 3;

  bool get _isQuizMode => _effectiveStudyMode == 4 || _effectiveStudyMode == 5;

  void _handleEnterShortcut({bool revealAnswer = false}) {
    if (!_handlesEnterShortcut || _isSavingQuality) return;

    if (_effectiveStudyMode == 1) {
      if (!_showAnswer) {
        setState(() => _showAnswer = true);
      }
      return;
    }

    if (_isTypedMode) {
      if (revealAnswer && !_isAnswerCorrect && !_hasCompletedTypedAnswer) {
        _revealTypedAnswer();
      } else if (!_hasCheckedAnswer ||
          (!_isAnswerCorrect && !_hasCompletedTypedAnswer)) {
        _checkTypedAnswer();
      } else if (_isAnswerCorrect || _hasCompletedTypedAnswer) {
        _onPracticeNext();
      }
      return;
    }

    if (_isQuizMode && _hasCheckedAnswer) {
      _onPracticeNext();
    }
  }

  void _handleNumberShortcut(int number) {
    if (_isSavingQuality) return;
    if (_isQuizMode && !_hasCheckedAnswer) {
      final index = number - 1;
      if (index >= 0 && index < _quizOptions.length) {
        _selectQuizOption(index);
      }
      return;
    }
    if (_effectiveStudyMode == 1) {
      //1/2/3 = 不认识 / 模糊 / 记住（与底部三档评分一一对应）
      const qualities = [1, 3, 4];
      final index = number - 1;
      if (index >= 0 && index < qualities.length) {
        _onQualitySelected(qualities[index]);
      }
    }
  }

  bool _isNumberKey(LogicalKeyboardKey key, int number) {
    return key ==
            LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + number - 1) ||
        key ==
            LogicalKeyboardKey(LogicalKeyboardKey.numpad1.keyId + number - 1);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (_isExiting) return KeyEventResult.handled; //保存中屏蔽
      _confirmExitStudy();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space) {
      if (_effectiveStudyMode == 1) {
        //回忆模式：启用了「Space 键显示释义」时空格先用来揭晓释义；
        //已揭晓后回落为播放发音，避免这个键变成死键
        if (context.read<StudySettingsProvider>().recallSpaceToReveal &&
            !_showAnswer) {
          _revealAnswer(userInitiated: true);
          return KeyEventResult.handled;
        }
        _playWord();
        return KeyEventResult.handled;
      }
      //听写模式：空格只负责播放发音
      if (_effectiveStudyMode == 3) {
        _playWord();
        return KeyEventResult.handled;
      }
    }

    for (var number = 1; number <= 5; number++) {
      if (_isNumberKey(key, number)) {
        _handleNumberShortcut(number);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _handleEnterShortcut(
        revealAnswer:
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isAltPressed,
      );
      return _handlesEnterShortcut
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  String get _modeTitle {
    final baseMode = switch (_effectiveStudyMode) {
      2 => context.tr.spellingMode,
      3 => context.tr.listeningMode,
      4 => context.tr.quizModeEnToCn,
      5 => context.tr.quizModeCnToEn,
      _ => context.tr.recallMode,
    };
    return _isStrengtheningMode
        ? '$baseMode · ${context.tr.strengthenMode}'
        : baseMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final isFavorite =
        _words.isNotEmpty && _favoriteIds.contains(_words[_currentIndex].id);
    if (_initializationState != StudyInitializationState.ready) {
      return _buildInitializationScaffold(isDark, textPrimary);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitStudy();
      },
      child: Scaffold(
        backgroundColor: context.isLiquidGlass
            ? Colors.transparent
            : FluidTheme.getBackgroundColor(isDark),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
          title: Text(
            '${_currentIndex + 1} / ${_words.length} · $_modeTitle',
            style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: textPrimary),
            onPressed: () => _confirmExitStudy(),
          ),
          actions: [
            IconButton(
              key: guideStudyFavoriteKey,
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? FluidTheme.favorite : textPrimary,
              ),
              tooltip: isFavorite
                  ? context.tr.removeFromFavorites
                  : context.tr.addToFavorites,
              onPressed: _words.isEmpty ? null : _toggleCurrentFavorite,
            ),
            IconButton(
              key: guideStudyDictKey,
              icon: Icon(Icons.menu_book_outlined, color: textPrimary),
              tooltip: context.tr.lookupDictionary,
              onPressed: _words.isEmpty ? null : _lookupCurrentWord,
            ),
            //仅回忆模式与两个测验模式保留设置入口：回忆模式调释义显示/
            //键位，测验模式调选项区垂直位置；拼写/听力没有模式专属设置，
            //放按钮只会让用户点进去发现一片空白或无关项。
            if (_effectiveStudyMode == 1 || _isQuizMode)
              IconButton(
                icon: Icon(Icons.settings_outlined, color: textPrimary),
                tooltip: context.tr.learningSettings,
                onPressed: () => _effectiveStudyMode == 1
                    ? openRecallRevealSettings(context)
                    : openQuizSettings(context),
              ),
            //快捷键入口只在桌面端存在：移动端没有物理键盘，连"操作提示"这个
            //概念都不该出现 —— 触屏操作（滑动评分、点选项）都是可见的按钮，
            //不需要额外的说明入口。这是平台隔离的 UI 部分：
            //不只是让快捷键失效，而是移动端根本看不到这个功能。
            if (PlatformAdapt.showKeyboardShortcuts(context))
              IconButton(
                key: guideStudyShortcutKey,
                icon: Icon(Icons.help_outline, color: textPrimary),
                tooltip: context.tr.operationTips,
                onPressed: () => _showKeyboardShortcuts(context),
              ),
          ],
        ),
        body: SafeArea(
          child: Focus(
            focusNode: _shortcutFocusNode,
            // 键盘快捷键（Esc/空格/数字键作答）只挂在桌面端：
            // 移动端没有物理键盘，挂上也永远不会触发，只会白白参与焦点竞争。
            // 触屏的对应操作（滑动评分、点选项、点按钮）在内容区里都有。
            onKeyEvent: PlatformAdapt.showKeyboardShortcuts(context)
                ? _handleKeyEvent
                : null,
            child: _buildStudyContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildInitializationScaffold(bool isDark, Color textPrimary) {
    final isLoading = _initializationState == StudyInitializationState.loading;
    final isEmpty = _initializationState == StudyInitializationState.empty;
    return Scaffold(
      backgroundColor: context.isLiquidGlass
          ? Colors.transparent
          : FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isLoading
              //初始化只等本地 DB 一瞬，留白等待即可：转圈反而像"卡住加载"
              //（进页转场动画 bouncyScale 还没播完，初始化多半已经就绪）
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEmpty
                          ? context.tr.noWordsToStudy
                          : context.tr.studyInitializationFailed,
                      textAlign: TextAlign.center,
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
                    ),
                    if (!isEmpty && _initializationError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _initializationError!,
                        textAlign: TextAlign.center,
                        style: FluidTheme.bodyMedium(isDark).copyWith(
                          color: FluidTheme.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FluidButton(
                      text: context.tr.back,
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 长按题面单词复制到剪贴板。
  ///
  /// 题面区域外层只注册了拖动手势（滑动评分/翻题），长按是空闲的，
  /// 这里占用长按做复制不会与任何已有手势冲突；阅读器词条那种
  /// 长按已被菜单占用的场景则走菜单项复制。
  Future<void> _copyCurrentWord(String word) async {
    if (word.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: word));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.copiedToClipboard),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildStudyContent() {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    //进度条轨道色需要区分玻璃/流体两种材质
    final isGlass = context.isLiquidGlass;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _words.length,
          backgroundColor: FluidTheme.getProgressTrackColor(isDark, isGlass),
          valueColor: AlwaysStoppedAnimation<Color>(
            FluidTheme.primaryFluidGradient[0],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              _buildStudyBody(isDark),
              //评分键覆盖在整个内容区上：用户可以自定义摆到任意空白处，
              //Stack 本身不吃命中测试，空白处的点击仍然落到下面的手势层
              if (_effectiveStudyMode == 1) _buildRecallActionBar(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudyBody(bool isDark) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        //五种模式统一走换题过渡：新题自下而上推入，位移带弹簧回弹
        child: AnimatedSwitcher(
          // 时长对所有风格统一为 400ms：弹簧曲线需要足够的采样窗口，
          // 之前流体风格只给 260ms，回弹还没跑出来动画就结束了
          duration: const Duration(milliseconds: 400),
          //线性喂给 SpringMotionCurve，物理感来自真实弹簧采样
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          //上一题立即从屏幕上移除，只保留新题的入场动画：
          //回忆/测验模式题面差异很大，旧内容哪怕只留 100ms 也会被
          //看成"上一题没走干净"；（拼写/听写模式还必须这样做，否则
          //两个 TextField 会同时持有同一个 controller 与 focusNode）
          layoutBuilder: (currentChild, previousChildren) =>
              currentChild ?? const SizedBox.shrink(),
          transitionBuilder: (child, animation) =>
              StudyCardTransition(animation: animation, child: child),
          child: _buildModeContent(isDark, key: ValueKey(_currentIndex)),
        ),
      ),
    );
    // 测验模式不走外层滚动容器：选项区要在「屏幕剩余区域」里做垂直
    // 对齐（见 _buildQuizMode 的 Expanded + Align），滚动容器里高度
    // 无界、对齐没有参照系；内容溢出时对齐区内自带滚动。
    if (_isQuizMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: content,
      );
    }
    // 回忆模式：点击题面空白处显示释义。
    // 用 translucent（而不是 opaque）：手势只在"没有被更深层控件消费"时生效，
    // 卡片上的播放按钮、长按复制都不受影响；同时它覆盖整块内容区，
    // 卡片下方那片真正的"空白"也点得到。
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _tapBlankRevealEnabled
          ? () => _revealAnswer(userInitiated: true)
          : null,
      //滑动评分/翻题手势已整体移除：上下/左右滑在手机上极易与
      //内容滚动抢手势（误触率高，用户反馈"经常滚着滚着就跳题"），
      //评分与翻题统一交给按钮，滚动区恢复默认物理
      child: SingleChildScrollView(
        controller: _contentScrollController,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: content,
      ),
    );
  }

  /// 顶栏问号：键盘键位速查（回车检查、Ctrl+回车看答案…）。
  ///
  /// 入口只在桌面端存在（见 AppBar），所以这里不需要任何移动端分支 ——
  /// 移动端的触屏操作都是可见按钮与滑动手势，不存在需要速查的隐藏键位。
  /// 五种学习模式的实际键位并不相同（见 _handleKeyEvent），速查表必须跟着
  /// 模式走：此前统一显示回忆版说明，其它四个模式照着按大多没反应。
  void _showKeyboardShortcuts(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    final spaceReveals = context
        .read<StudySettingsProvider>()
        .recallSpaceToReveal;
    final shortcuts = switch (_effectiveStudyMode) {
      //回忆：回车揭晓释义，空格按设置是揭晓还是发音，1-3 打评分
      1 => <(String, String)>[
        (context.tr.shortcutEnter, context.tr.showDefinition),
        (
          context.tr.shortcutSpace,
          spaceReveals
              ? context.tr.showDefinition
              : context.tr.shortcutSpaceDesc,
        ),
        (context.tr.shortcutNumber, context.tr.shortcutNumberDesc),
        (context.tr.shortcutExit, context.tr.shortcutExitDesc),
      ],
      //拼写：回车检查/下一题，Ctrl+回车看答案
      2 => <(String, String)>[
        (context.tr.shortcutEnter, context.tr.shortcutEnterDesc),
        (context.tr.shortcutCtrlEnter, context.tr.shortcutCtrlEnterDesc),
        (context.tr.shortcutExit, context.tr.shortcutExitDesc),
      ],
      //听写：比拼写多一个空格播放发音
      3 => <(String, String)>[
        (context.tr.shortcutEnter, context.tr.shortcutEnterDesc),
        (context.tr.shortcutCtrlEnter, context.tr.shortcutCtrlEnterDesc),
        (context.tr.shortcutSpace, context.tr.shortcutSpaceDesc),
        (context.tr.shortcutExit, context.tr.shortcutExitDesc),
      ],
      //测验（英选中 / 中选英）：1-4 选选项，回车在判定后进下一题
      _ => <(String, String)>[
        (context.tr.shortcutQuizNumber, context.tr.shortcutQuizNumberDesc),
        (context.tr.shortcutEnter, context.tr.shortcutEnterDesc),
        (context.tr.shortcutExit, context.tr.shortcutExitDesc),
      ],
    };

    showFluidDialog(
      context: context,
      title: context.tr.keyboardShortcuts,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: shortcuts.map((s) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FluidTheme.getMutedOverlayColor(isDark),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: FluidTheme.getBorderColor(isDark),
                      ),
                    ),
                    child: Text(
                      s.$1,
                      style: FluidTheme.labelLarge(isDark).copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      s.$2,
                      style: FluidTheme.bodyMedium(
                        isDark,
                      ).copyWith(color: textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        FluidTextButton(
          text: context.tr.confirm,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildModeContent(bool isDark, {required Key key}) {
    switch (_effectiveStudyMode) {
      case 2:
        return _buildTypedMode(isDark, key: key, isListening: false);
      case 3:
        return _buildTypedMode(isDark, key: key, isListening: true);
      case 4:
      case 5:
        return _buildQuizMode(isDark, key: key);
      default:
        return _buildRecallMode(isDark, key: key);
    }
  }

  Widget _buildRecallMode(bool isDark, {required Key key}) {
    final word = _words[_currentIndex];
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //长按复制单词（外层只有拖动手势，长按空闲；点按/滑动不受影响）
              GestureDetector(
                onLongPress: () => _copyCurrentWord(word.word),
                child: Text(
                  word.word,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 52,
                    height: 1.08,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              if (word.phonetic.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  word.phonetic,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, color: textSecondary),
                ),
              ],
              const SizedBox(height: 20),
              _buildPlayButton(),
              //「上滑 = 记住 · 下滑 = 不认识」等滑动提示已随滑动手势一并移除；
              //释义触发方式在设置里可选，不再占用题面空间做常驻提示
              //答案随高度展开：用 easeOutBack 让高度轻微过冲再回落，
              //展开过程有一次回弹（此前是纯 easeOutCubic，是"硬边揭开"，
              //这是回忆模式手感不如测验模式的原因之一）
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                alignment: Alignment.topCenter,
                child: _showAnswer
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Divider(
                            color: FluidTheme.getBorderColor(isDark),
                            thickness: 1,
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.tr.definitionLabel,
                              style: FluidTheme.labelLarge(
                                isDark,
                              ).copyWith(color: textSecondary, fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _definitionText(word),
                            textAlign: TextAlign.left,
                            style: FluidTheme.bodyMedium(isDark).copyWith(
                              color: textPrimary,
                              fontSize: 20,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 回忆模式评分键：覆盖在整个内容区上的浮层（不认识 / 模糊 / 认识）。
  ///
  /// 「显示释义」整键已删除：释义改由"停留一段时间自动出现"或"点击题面空白处"
  /// 呈现（设置里可选，见 RecallRevealTrigger）。
  /// 三键任何状态都可点（无需先看释义），仅保存中临时禁用。
  /// 渲染、几何与布局订阅全部交给 [RecallQualityActionBar]——编辑器预览用的
  /// 是同一个 widget，不会再出现两套换算公式；订阅下移到那个 widget 里，
  /// 无关设置变更也就不会重建整个学习页。
  Widget _buildRecallActionBar(bool isDark) {
    return Positioned.fill(
      child: SafeArea(
        child: RecallQualityActionBar(
          isDark: isDark,
          enabled: !_isSavingQuality,
          onTapQuality: _onQualitySelected,
        ),
      ),
    );
  }

  Widget _buildTypedMode(
    bool isDark, {
    required Key key,
    required bool isListening,
  }) {
    final word = _words[_currentIndex];
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final resultColor = _isAnswerCorrect
        ? FluidTheme.success
        : FluidTheme.error;
    //键盘是否占住底部：上屏后压缩题面卡，让输入框与行动按钮
    //都能落进键盘上方的可视区（否则按钮被挤到折叠线外"被键盘挡住"）
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardUp) _scrollActionsIntoViewAfterKeyboard();

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluidCard(
          enableShimmer: false,
          padding: keyboardUp
              ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
              : const EdgeInsets.symmetric(horizontal: 34, vertical: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isListening ? Icons.headphones : Icons.edit_outlined,
                size: keyboardUp ? 30 : 56,
                color: FluidTheme.primaryFluidGradient[0],
              ),
              SizedBox(height: keyboardUp ? 8 : 18),
              Text(
                isListening
                    ? context.tr.listeningPrompt
                    : context.tr.spellingPrompt,
                textAlign: TextAlign.center,
                style: FluidTheme.headingSmall(isDark).copyWith(
                  color: textPrimary,
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              //「直接输入答案 / 听发音后输入答案」副标题提示已移除：
              //输入框 placeholder（请输入英文单词）已足够说明操作
              const SizedBox(height: 20),
              if (isListening)
                _buildLargePlayButton(compact: keyboardUp)
              else
                Container(
                  width: double.infinity,
                  padding: keyboardUp
                      ? const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        )
                      : const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                  decoration: BoxDecoration(
                    color: FluidTheme.getMutedOverlayColor(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FluidTheme.getBorderColor(isDark),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.tr.definitionLabel,
                        style: FluidTheme.labelLarge(
                          isDark,
                        ).copyWith(color: textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _definitionText(word),
                        textAlign: TextAlign.center,
                        maxLines: keyboardUp ? 3 : null,
                        overflow: TextOverflow.ellipsis,
                        style: FluidTheme.bodyMedium(isDark).copyWith(
                          color: textPrimary,
                          fontSize: keyboardUp ? 16 : 22,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _answerController,
          focusNode: _answerFocusNode,
          autofocus: true,
          enabled: !_isAnswerCorrect && !_hasCompletedTypedAnswer,
          //移动端用 visiblePassword：多数中文输入法对"可见密码"类型只给纯英文
          //键盘，即使子类型切换失败也不会吐中文候选；桌面端保持 url 类型，
          //真正的英文输入靠键盘布局切换（见 KeyboardLanguageService）。
          keyboardType: PlatformAdapt.isMobile
              ? TextInputType.visiblePassword
              : TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          textCapitalization: TextCapitalization.none,
          inputFormatters: _lettersOnlyFormatter,
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: FluidTheme.primaryFluidGradient[0],
          decoration: InputDecoration(
            filled: true,
            fillColor: FluidTheme.getInputFillColor(isDark),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            hintText: context.tr.enterEnglishWord,
            hintStyle: TextStyle(
              color: FluidTheme.getTextTertiaryColor(isDark),
              fontSize: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: FluidTheme.getBorderColor(isDark)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: FluidTheme.primaryFluidGradient[0]),
            ),
          ),
          // 点击输入框时：① 确认英文输入法（不能用 force，强制切换子类型会重启
          // IME，配合换题自动聚焦会出现"键盘下去又上来"的死循环）；
          // ② 键盘被系统收起时重建焦点，保证"点一下就能打字"。
          // 输入法切换与自动聚焦共用同一防抖：每次点击都调用 ensureEnglish
          // 会让 Android 上 IME 子类型反复重启、键盘闪断
          onTap: () {
            if (!_imeEnglishEnsured) {
              _imeEnglishEnsured = true;
              unawaited(KeyboardLanguageService.ensureEnglish());
            }
            _ensureTypedInputFocus();
          },
          onChanged: (v) {
            //过滤中文输入法意外提交的非ASCII字符，防止重复内容
            final filtered = v.replaceAll(_nonAsciiLetters, '');
            if (filtered != v) {
              _answerController.text = filtered;
              _answerController.selection = TextSelection.fromPosition(
                TextPosition(offset: filtered.length),
              );
            }
          },
          onSubmitted: (_) {
            _handleEnterShortcut();
            //微信等输入法点「完成」后期望编辑器收起连接：若继续持有焦点，
            //框架与输入法会在"收/show"上互相拉扯，键盘反复闪跳；
            //桌面端回车是快捷键语义，焦点保留给快捷键节点链。
            if (PlatformAdapt.isMobile) _answerFocusNode.unfocus();
          },
        ),
        const SizedBox(height: 16),
        //三种答题状态互斥（检查 / 答错可重试 / 已完成），用 AnimatedSize
        //统一高度过渡，避免按钮与结果卡突然换位
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_hasCheckedAnswer ||
                  (!_isAnswerCorrect && !_hasCompletedTypedAnswer))
                FluidButton(
                  text: _hasCheckedAnswer
                      ? context.tr.recheck
                      : context.tr.checkAnswer,
                  icon: Icons.check,
                  expanded: true,
                  onPressed: _checkTypedAnswer,
                ),
              if (_hasCheckedAnswer &&
                  !_isAnswerCorrect &&
                  !_hasCompletedTypedAnswer) ...[
                const SizedBox(height: 12),
                FluidCard(
                  enableShimmer: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr.answerWrong,
                        style: FluidTheme.labelLarge(
                          isDark,
                        ).copyWith(color: resultColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr.viewAnswerHint,
                        style: FluidTheme.bodyMedium(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FluidButton(
                        text: context.tr.clearRetry,
                        icon: Icons.refresh,
                        onPressed: _retryTypedAnswer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FluidButton(
                        text: context.tr.viewAnswer,
                        icon: Icons.visibility_outlined,
                        onPressed: _revealTypedAnswer,
                      ),
                    ),
                  ],
                ),
              ],
              if (_hasCheckedAnswer &&
                  (_isAnswerCorrect || _hasCompletedTypedAnswer)) ...[
                FluidCard(
                  enableShimmer: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAnswerCorrect
                            ? context.tr.answerCorrect
                            : context.tr.answerRevealed,
                        style: FluidTheme.labelLarge(
                          isDark,
                        ).copyWith(color: resultColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${context.tr.correctAnswer}${word.word}',
                        style: FluidTheme.bodyMedium(
                          isDark,
                        ).copyWith(color: textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _definitionText(word),
                        style: FluidTheme.bodyMedium(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildNextButton(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizMode(bool isDark, {required Key key}) {
    final word = _words[_currentIndex];
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final prompt = _effectiveStudyMode == 4 ? word.word : _definitionText(word);
    // 选项区垂直位置（设置滑块 0~100 → Align 的 y -1~1）：四个选项与
    // 答题结果卡作为一个整体，在题面下方的屏幕剩余区域里上下摆
    final optionsAlignY = -1.0 +
        2.0 *
            (context.select<StudySettingsProvider, int>(
                  (p) => p.quizOptionsVertical,
                ) /
                100);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          _effectiveStudyMode == 4
              ? context.tr.quizPromptEn
              : context.tr.quizPromptCn,
          textAlign: TextAlign.center,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        //「点击选项作答，也可左右滑动切题」提示已随滑动手势一并移除
        const SizedBox(height: 16),
        FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              //英选中（mode 4）题面就是单词，长按复制；中选英题面是中文释义，不提供
              GestureDetector(
                onLongPress: _effectiveStudyMode == 4
                    ? () => _copyCurrentWord(word.word)
                    : null,
                child: Text(
                  prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _effectiveStudyMode == 4 ? 30 : 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              if (_effectiveStudyMode == 4 && word.phonetic.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(word.phonetic, style: TextStyle(color: textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                // 撑满剩余高度：内容比区域矮时 Align 才有空间做垂直摆位
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment(0, optionsAlignY),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...List.generate(_quizOptions.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _QuizOptionButton(
                            text: _quizOptions[index],
                            index: index,
                            isSelected: _selectedQuizOption == index,
                            isCorrect:
                                _quizOptions[index] == _correctQuizAnswer(word),
                            hasAnswered: _selectedQuizOption != null,
                            isDark: isDark,
                            onTap: () => _selectQuizOption(index),
                          ),
                        );
                      }),
                      //答完才出现的释义卡 + 下一题按钮：随高度展开，而不是突然弹出
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _hasCheckedAnswer
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  _buildDefinitionCard(word, isDark),
                                  const SizedBox(height: 16),
                                  _buildNextButton(),
                                ],
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return IconButton(
      icon: Icon(
        _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
        color: FluidTheme.primaryFluidGradient[0],
        size: 36,
      ),
      onPressed: _playWord,
    );
  }

  Widget _buildLargePlayButton({bool compact = false}) {
    final size = compact ? 56.0 : 80.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _playWord,
        borderRadius: BorderRadius.circular(60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: FluidTheme.primaryFluidGradient[0].withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
            color: FluidTheme.primaryFluidGradient[0],
            size: compact ? 28 : 40,
          ),
        ),
      ),
    );
  }

  Widget _buildDefinitionCard(Word word, bool isDark, {bool large = false}) {
    return FluidCard(
      enableShimmer: false,
      padding: EdgeInsets.all(large ? 22 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.definitionLabel,
            style: FluidTheme.labelLarge(isDark).copyWith(
              color: FluidTheme.getTextPrimaryColor(isDark),
              fontSize: large ? 17 : null,
            ),
          ),
          SizedBox(height: large ? 12 : 8),
          Text(
            _definitionText(word),
            style: FluidTheme.bodyMedium(isDark).copyWith(
              color: large
                  ? FluidTheme.getTextPrimaryColor(isDark)
                  : FluidTheme.getTextSecondaryColor(isDark),
              fontSize: large ? 19 : null,
              height: large ? 1.55 : null,
              fontWeight: large ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return FluidButton(
      text: _currentIndex < _words.length - 1
          ? context.tr.nextQuestion
          : context.tr.finish,
      icon: _currentIndex < _words.length - 1
          ? Icons.arrow_forward
          : Icons.check,
      expanded: true,
      //保存中按钮转为禁用态，点击立刻有响应，不会像"点了没反应"
      isEnabled: !_isSavingQuality,
      onPressed: _onPracticeNext,
    );
  }
}

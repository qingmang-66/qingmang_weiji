import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/study_plan.dart';
import '../models/word_book.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../services/study_plan_service.dart';
import '../services/app_initialization_service.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/liquid_glass.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/wordbook_localization.dart';

/// 学习计划管理页
///
/// 支持创建、查看、暂停、恢复、完成、删除学习计划。
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  /// 学习计划服务
  final _service = DIContainer.instance.studyPlanService;

  /// 计划列表
  List<StudyPlan> _plans = [];

  /// 是否加载中
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    AppInitializationService.databaseRefreshSignal.addListener(_loadPlans);
  }

  @override
  void dispose() {
    AppInitializationService.databaseRefreshSignal.removeListener(_loadPlans);
    super.dispose();
  }

  /// 加载全部计划
  Future<void> _loadPlans() async {
    //plan 操作（暂停/完成/删除）await 之后本页可能已被关闭
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final plans = await _service.getAllPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${context.tr.loadingError}：$e')));
    }
  }

  /// 计划状态文案
  String _statusLabel(BuildContext context, StudyPlanStatus status) {
    switch (status) {
      case StudyPlanStatus.active:
        return context.tr.planStatusActive;
      case StudyPlanStatus.paused:
        return context.tr.planStatusPaused;
      case StudyPlanStatus.completed:
        return context.tr.planStatusCompleted;
    }
  }

  /// 计划类型文案
  String _typeLabel(BuildContext context, StudyPlanType type) {
    switch (type) {
      case StudyPlanType.fixedDaily:
        return context.tr.planTypeFixedDaily;
      case StudyPlanType.fixedDeadline:
        return context.tr.planTypeFixedDeadline;
      case StudyPlanType.examTarget:
        return context.tr.planTypeExamTarget;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            context.tr.studyPlan,
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateDialog,
          backgroundColor: FluidTheme.primaryFluidGradient[0],
          //底色是主色实底 #F093FB，白字/白图标仅 2.04:1，改用深色前景（8.34:1）
          icon: Icon(Icons.add, color: FluidTheme.onGradientForeground),
          label: Text(
            context.tr.createPlan,
            style: TextStyle(color: FluidTheme.onGradientForeground),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _plans.isEmpty
            ? _buildEmpty(context, isDark)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: _plans.length,
                itemBuilder: (_, i) =>
                    _buildPlanCard(context, _plans[i], isDark),
              ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmpty(BuildContext context, bool isDark) {
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note, size: 64, color: textSecondary),
          const SizedBox(height: 16),
          Text(
            context.tr.noPlanYet,
            style: FluidTheme.bodyMedium(isDark).copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }

  /// 单个计划卡片
  Widget _buildPlanCard(BuildContext context, StudyPlan plan, bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FluidCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textPrimary),
                  ),
                ),
                _statusChip(context, plan.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_typeLabel(context, plan.type)} · '
              '${context.tr.planDailyNewTarget}: ${plan.dailyNewTarget}',
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${context.tr.totalWords}: ${plan.totalWords}',
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            const SizedBox(height: 12),
            // 操作按钮区
            Wrap(spacing: 8, children: _buildActions(context, plan)),
          ],
        ),
      ),
    );
  }

  /// 状态标签
  Widget _statusChip(BuildContext context, StudyPlanStatus status) {
    Color color;
    switch (status) {
      case StudyPlanStatus.active:
        color = Colors.green;
        break;
      case StudyPlanStatus.paused:
        color = Colors.orange;
        break;
      case StudyPlanStatus.completed:
        color = Colors.blueGrey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(context, status),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  /// 操作按钮列表
  List<Widget> _buildActions(BuildContext context, StudyPlan plan) {
    final actions = <Widget>[];
    if (plan.status == StudyPlanStatus.active) {
      actions.add(
        _textAction(context.tr.pausePlan, () async {
          await _service.pausePlan(plan);
          await _loadPlans();
        }),
      );
      actions.add(
        _textAction(context.tr.completePlan, () async {
          await _service.completePlan(plan);
          await _loadPlans();
        }),
      );
    } else if (plan.status == StudyPlanStatus.paused) {
      actions.add(
        _textAction(context.tr.resumePlan, () async {
          await _service.resumePlan(plan);
          await _loadPlans();
        }),
      );
    }
    actions.add(
      _textAction(context.tr.deletePlan, () async {
        if (plan.id != null) {
          await _service.deletePlan(plan.id!);
          await _loadPlans();
        }
      }, danger: true),
    );
    return actions;
  }

  /// 文本操作按钮
  Widget _textAction(String label, VoidCallback onTap, {bool danger = false}) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: danger ? Colors.red : FluidTheme.primaryFluidGradient[0],
        ),
      ),
    );
  }

  /// 打开创建计划对话框
  Future<void> _openCreateDialog() async {
    final wordBooks = context.read<WordBookProvider>().wordBooks;
    final sheetKey = GlobalKey<_CreatePlanSheetState>();
    final created = await showFluidDialog<bool>(
      context: context,
      title: context.tr.createPlan,
      //回车键等同于表单里的「确定」
      onConfirm: () => sheetKey.currentState?.submit(),
      content: CreatePlanSheet(
        key: sheetKey,
        wordBooks: wordBooks,
        service: _service,
      ),
    );
    if (created == true) {
      await _loadPlans();
    }
  }
}

/// 创建计划居中表单
class CreatePlanSheet extends StatefulWidget {
  final List<WordBook> wordBooks;
  final StudyPlanService service;

  const CreatePlanSheet({
    super.key,
    required this.wordBooks,
    required this.service,
  });

  @override
  State<CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<CreatePlanSheet> {
  final _nameController = TextEditingController();
  final _dailyController = TextEditingController(text: '20');

  /// 已选词库 id 集合
  final Set<int> _selectedBookIds = {};

  /// 计划类型
  StudyPlanType _type = StudyPlanType.fixedDaily;

  /// 目标日期（按截止日 / 考试目标时使用）
  DateTime? _targetDate;

  bool _submitting = false;
  String? _nameError;
  String? _bookError;
  String? _dailyError;
  String? _dateError;

  @override
  void dispose() {
    _nameController.dispose();
    _dailyController.dispose();
    super.dispose();
  }

  /// 供弹窗「回车=确定」调用（提交中忽略重复触发）
  void submit() {
    if (_submitting) return;
    _submit();
  }

  /// 提交创建
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final daily = int.tryParse(_dailyController.text.trim());
    final needsDate = _type != StudyPlanType.fixedDaily;
    setState(() {
      _nameError = name.isEmpty ? context.tr.planNameRequired : null;
      _bookError = _selectedBookIds.isEmpty
          ? context.tr.wordBookRequired
          : null;
      _dailyError =
          _type == StudyPlanType.fixedDaily && (daily == null || daily <= 0)
          ? context.tr.dailyTargetPositiveInteger
          : null;
      _dateError = needsDate && _targetDate == null
          ? context.tr.targetDateRequired
          : null;
    });
    if (_nameError != null ||
        _bookError != null ||
        _dailyError != null ||
        _dateError != null) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.service.createPlan(
        name: name,
        wordBookIds: _selectedBookIds.toList(),
        type: _type,
        targetDate: needsDate ? _targetDate : null,
        dailyNewTarget: _type == StudyPlanType.fixedDaily ? daily! : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr.createPlanFailed}：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 计划名称
        TextField(
          controller: _nameController,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          decoration: InputDecoration(
            labelText: context.tr.planName,
            errorText: _nameError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // 计划类型
        Text(
          context.tr.planType,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // 弹窗内容宽约 235dp，三段中文标签横向排列放不下（大字体下会被弹窗
        // 裁掉尾部导致选项看不见）；改用可换行的 ChoiceChip，文字始终完整
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in <(StudyPlanType, String)>[
              (StudyPlanType.fixedDaily, context.tr.planTypeFixedDaily),
              (StudyPlanType.fixedDeadline, context.tr.planTypeFixedDeadline),
              (StudyPlanType.examTarget, context.tr.planTypeExamTarget),
            ])
              LiquidChoiceChip(
                label: entry.$2,
                selected: _type == entry.$1,
                onTap: () => setState(() {
                  _type = entry.$1;
                  if (_type == StudyPlanType.fixedDaily) {
                    _dateError = null;
                  } else {
                    _dailyError = null;
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // 每日新词目标（固定每日量时显示）/ 目标日期（其余类型显示）
        if (_type == StudyPlanType.fixedDaily)
          TextField(
            controller: _dailyController,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (_dailyError != null) setState(() => _dailyError = null);
            },
            decoration: InputDecoration(
              labelText: context.tr.planDailyNewTarget,
              errorText: _dailyError,
              border: const OutlineInputBorder(),
            ),
          )
        else
          Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr.planTargetDate,
                  style: TextStyle(color: textPrimary),
                ),
                subtitle: Text(
                  _targetDate == null
                      ? '--'
                      : _targetDate!.toIso8601String().substring(0, 10),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final now = DateTime.now();
                  //系统级日期选择器不重构，仅微调主色与液态玻璃风格协调
                  final theme = Theme.of(context);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 30)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365 * 3)),
                    builder: (_, child) => Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          primary: FluidTheme.primaryFluidGradient[0],
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _targetDate = picked;
                      _dateError = null;
                    });
                  }
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: _dateError == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _dateError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        // 词库选择
        Text(
          context.tr.selectWordBook,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...widget.wordBooks.map((book) {
          final id = book.id;
          if (id == null) return const SizedBox.shrink();
          //经典模式保留 CheckboxListTile（整行点按+语义），玻璃模式用 ListTile+LiquidCheckbox
          if (context.isLiquidGlass) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: LiquidCheckbox(
                value: _selectedBookIds.contains(id),
                onChanged: (checked) {
                  setState(() {
                    if (checked) {
                      _selectedBookIds.add(id);
                      _bookError = null;
                    } else {
                      _selectedBookIds.remove(id);
                    }
                  });
                },
              ),
              title: Text(
                context.wordBookName(book.name),
                style: TextStyle(color: textPrimary),
              ),
              subtitle: Text('${book.totalWords} ${context.tr.wordCount}'),
            );
          }
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.wordBookName(book.name),
              style: TextStyle(color: textPrimary),
            ),
            subtitle: Text('${book.totalWords} ${context.tr.wordCount}'),
            value: _selectedBookIds.contains(id),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedBookIds.add(id);
                  _bookError = null;
                } else {
                  _selectedBookIds.remove(id);
                }
              });
            },
          );
        }),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: _bookError == null
              ? const SizedBox.shrink()
              : Text(
                  _bookError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FluidButton(
            text: context.tr.confirm,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}

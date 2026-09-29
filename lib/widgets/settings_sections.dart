import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/providers/providers.dart';
import '../services/app_initialization_service.dart';
import '../services/guide_service.dart';
import '../utils/constants.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../utils/platform_adapt.dart';
import '../utils/platform_info.dart';
import '../utils/platform_settings.dart';
import '../utils/error_handler.dart';
import '../utils/page_transitions.dart';
import '../screens/about_screen.dart';
import '../models/notification_settings.dart';
import '../services/notification_service.dart';
import '../services/reminder_sound_service.dart';
import 'fluid_dialog.dart';
import 'fluid_button.dart';
import 'recall_button_layout_editor.dart';
import 'liquid_controls.dart';
import 'liquid_glass.dart';
import 'slide_segmented_control.dart';

class _SettingsColors {
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;

  const _SettingsColors({
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
  });
}

_SettingsColors _settingsColors(BuildContext context) {
  final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
  return _SettingsColors(
    isDark: isDark,
    textPrimary: FluidTheme.getTextPrimaryColor(isDark),
    textSecondary: FluidTheme.getTextSecondaryColor(isDark),
    textTertiary: FluidTheme.getTextTertiaryColor(isDark),
    border: FluidTheme.getBorderColor(isDark),
  );
}

class _SettingsSectionShell extends StatelessWidget {
  final List<Widget> children;

  const _SettingsSectionShell({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = _settingsColors(context);
    // stretch：分组标题靠左、行与分段控件撑满卡片宽度。
    // （默认的 center 会把标题文字居中，卡片里就出现一个"浮在中间的小标题"）
    final group = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      //Android 真机验证：设置页同屏多张分组卡，逐卡实时背景模糊是掉帧
      //主因 —— 移动端降级为无折射玻璃片，桌面端性能足够保留实时模糊
      return RepaintBoundary(
        child: GlassSurface(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: FluidTheme.cardBorderRadius,
          blurSigma: LiquidGlass.blurSigmaHeavy,
          emphasized: true,
          grain: true,
          forceFlat: isMobilePlatform,
          child: group,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FluidTheme.getSurfaceGradientColors(colors.isDark),
        ),
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        border: Border.all(color: colors.border),
      ),
      child: group,
    );
  }
}

/// 设置分组外框（公开版）
///
/// 设置主页的分类入口、二级/三级页面都靠它保持同一套卡片材质，
/// 避免各处各写一份"玻璃 / 渐变卡"分支后出现细微色差。
class SettingsSectionShell extends StatelessWidget {
  final List<Widget> children;

  const SettingsSectionShell({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      _SettingsSectionShell(children: children);
}

/// 设置项入口：图标 + 标题 + 说明 + 右侧箭头。
/// 设置主页的每个分类、二级页面里的三级入口都用它。
class SettingsEntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const SettingsEntryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: FluidTheme.primaryFluidGradient[0]),
      title: Text(title, style: _titleStyle(context)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: _subtitleStyle(context)),
      trailing: const _SettingsChevron(),
      onTap: onTap,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: _settingsColors(context).border);
  }
}

class _SettingsChevron extends StatelessWidget {
  const _SettingsChevron();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right,
      color: _settingsColors(context).textTertiary,
    );
  }
}

TextStyle _titleStyle(BuildContext context) {
  final colors = _settingsColors(context);
  return FluidTheme.labelLarge(
    colors.isDark,
  ).copyWith(color: colors.textPrimary);
}

TextStyle _subtitleStyle(BuildContext context) {
  final colors = _settingsColors(context);
  return FluidTheme.bodySmall(
    colors.isDark,
  ).copyWith(color: colors.textSecondary);
}

/// 设置分组标题 - 流体渐变风格
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          return LinearGradient(
            //浅色玻璃上原渐变仅 ~1.9:1，小号标题几乎不可读
            colors: FluidTheme.textGradient(isDark),
          ).createShader(bounds);
        },
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 数据管理设置分组
class DataManagementSettingsSection extends StatelessWidget {
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onImport;
  final VoidCallback onDeleteBackup;
  final VoidCallback onClearData;

  const DataManagementSettingsSection({
    super.key,
    required this.onBackup,
    required this.onRestore,
    required this.onImport,
    required this.onDeleteBackup,
    required this.onClearData,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.dataManagement),
        ListTile(
          leading: Icon(
            Icons.backup,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.backupData, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.exportToLocal,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: onBackup,
        ),
        ListTile(
          leading: Icon(
            Icons.restore,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.restoreData, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.restoreFromBackup,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: onRestore,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_outline,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.deleteBackup, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.deleteBackupDesc,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: onDeleteBackup,
        ),
        ListTile(
          leading: Icon(
            Icons.upload_file,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.importWordBook, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.importFromTxt,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: onImport,
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt, color: FluidTheme.error),
          title: Text(
            context.tr.resetApp,
            style: const TextStyle(
              color: FluidTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            context.tr.resetAppDesc,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: onClearData,
        ),
      ],
    );
  }
}

/// 帮助与引导设置分组
///
/// 两个入口：
/// - 重看新手引导：回到首次启动的引导流程（语言 / 风格 / 词库）
/// - 重看功能提示：清掉各页面的上下文引导标记，下次进入时重新弹出
class GuideSettingsSection extends StatelessWidget {
  const GuideSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.helpAndGuide),
        ListTile(
          leading: Icon(
            Icons.school_outlined,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.replayOnboarding, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.replayOnboardingDesc,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => _replayOnboarding(context),
        ),
        ListTile(
          leading: Icon(
            Icons.lightbulb_outline,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.replayTips, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.replayTipsDesc,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => _replayTips(context),
        ),
      ],
    );
  }

  /// 重看新手引导：确认后回到引导流程（不清空任何学习数据）
  void _replayOnboarding(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showFluidDialog(
      context: context,
      title: context.tr.replayOnboarding,
      content: Text(
        context.tr.replayOnboardingDesc,
        style: FluidTheme.bodyMedium(
          isDark,
        ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
      ),
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.confirm,
          onPressed: () {
            //引导页与首页在同一根路由内互换，而本入口位于 push 出来的二级页；
            //不先出栈，引导页会被二级页盖住，表现为「确认后没反应、要返回才生效」
            Navigator.of(context).popUntil((route) => route.isFirst);
            //与「初始化应用」共用同一条通路：重置后回到首次引导页
            AppInitializationService.showOnboardingAfterInitialization();
          },
        ),
      ],
    );
  }

  /// 重看功能提示：清空各页面的上下文引导标记并立即重播
  Future<void> _replayTips(BuildContext context) async {
    await GuideService.resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.replayTipsDone),
        behavior: SnackBarBehavior.floating,
      ),
    );
    //先出栈回到首页路由：引导巡览的锚点在首页各 Tab 上，
    //二级页盖在上面时高亮目标不可见，巡览会一直等待而"看起来没运行"
    Navigator.of(context).popUntil((route) => route.isFirst);
    GuideService.notifyReplayTips();
  }
}

/// 回忆模式：释义显示方式设置分组
///
/// 回忆模式曾经底部常驻一个「显示释义」大按钮，每次都要伸手点一下。
/// 现在释义由「停留一段时间自动出现」和「点击题面空白处出现」两种触发承担，
/// 这里让用户选触发方式与等待时长（3 档 + 自定义）。
/// 移动端没有物理空格键，Space 触发只在桌面端出现。
class RecallDisplaySettingsSection extends StatelessWidget {
  const RecallDisplaySettingsSection({super.key});

  /// 自定义档的哨兵值：选中它时弹滑块对话框，而不是直接落盘
  static const int _customDelaySentinel = -1;

  @override
  Widget build(BuildContext context) {
    //内部订阅 provider：值变化后分组重建，选中态才会跟着更新
    final provider = context.watch<StudySettingsProvider>();
    final trigger = provider.recallRevealTrigger;
    final delay = provider.recallRevealDelaySeconds;

    //释义显示 + 评分按键布局两组卡片，同级铺开（不套二级页）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRevealSection(context, provider, trigger, delay),
        const SizedBox(height: 12),
        _buildButtonLayoutSection(context, provider),
      ],
    );
  }

  /// 自定义等待时长对话框：1~60 秒滑块，确定才落盘
  Future<void> _showCustomDelayDialog(
    BuildContext context,
    StudySettingsProvider provider,
  ) async {
    var seconds = provider.recallRevealDelaySeconds;
    if (kRecallRevealDelayOptions.contains(seconds)) {
      // 从档位进入自定义：给一个介于 10 秒之外的起点，避免和档位重叠观感
      seconds = 20;
    }
    final result = await showFluidDialog<int>(
      context: context,
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr.recallRevealDelayCustomTitle,
              style: FluidTheme.headingSmall(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            const SizedBox(height: 16),
            LiquidSlider(
              value: seconds.toDouble(),
              min: kRecallRevealDelayMin.toDouble(),
              max: kRecallRevealDelayMax.toDouble(),
              divisions: kRecallRevealDelayMax - kRecallRevealDelayMin,
              onChanged: (v) => setDialogState(() => seconds = v.round()),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr.recallRevealDelayCustomHint(seconds),
              textAlign: TextAlign.center,
              style: FluidTheme.bodyMedium(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FluidButton(
          text: context.tr.confirm,
          onPressed: () => Navigator.of(context).pop(seconds),
        ),
      ],
    );
    if (result != null && context.mounted) {
      await provider.setRecallRevealDelaySeconds(result);
    }
  }

  /// 释义显示方式分组
  Widget _buildRevealSection(
    BuildContext context,
    StudySettingsProvider provider,
    RecallRevealTrigger trigger,
    int delay,
  ) {
    final isMobile = PlatformAdapt.isMobile;
    //移动端不给出 Space 档：存过的 space 在移动端按「全部」展示，
    //用户重新选择后即被覆盖，不会出现"选了一个没用的触发方式"
    final triggerValues = isMobile
        ? const [
            RecallRevealTrigger.delayed,
            RecallRevealTrigger.tapBlank,
            RecallRevealTrigger.all,
          ]
        : const [
            RecallRevealTrigger.delayed,
            RecallRevealTrigger.tapBlank,
            RecallRevealTrigger.space,
            RecallRevealTrigger.all,
          ];
    final shownTrigger = (isMobile && trigger == RecallRevealTrigger.space)
        ? RecallRevealTrigger.all
        : trigger;
    final delayValues = [...kRecallRevealDelayOptions, _customDelaySentinel];
    final shownDelay = kRecallRevealDelayOptions.contains(delay)
        ? delay
        : _customDelaySentinel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.recallRevealSectionTitle),
        ListTile(
          leading: Icon(
            Icons.visibility_outlined,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(
            context.tr.recallRevealTriggerLabel,
            style: _titleStyle(context),
          ),
          subtitle: Text(
            isMobile
                ? context.tr.recallRevealTriggerDescMobile
                : context.tr.recallRevealTriggerDesc,
            style: _subtitleStyle(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          //摁住滑动即可换档（与导航条同一手感），不必抬手指再点一次
          child: SlideSegmentedControl<RecallRevealTrigger>(
            values: triggerValues,
            selected: shownTrigger,
            onChanged: (value) => provider.setRecallRevealTrigger(value),
            labelBuilder: (value, selected) => Text(
              switch (value) {
                RecallRevealTrigger.delayed => context.tr.recallRevealDelayed,
                RecallRevealTrigger.tapBlank => context.tr.recallRevealTapBlank,
                RecallRevealTrigger.space => context.tr.recallRevealSpace,
                RecallRevealTrigger.all => context.tr.recallRevealAll,
              },
              style: FluidTheme.labelLarge(isDark).copyWith(
                color: selected
                    ? FluidTheme.primaryFluidGradient[0]
                    : FluidTheme.getTextSecondaryColor(isDark),
              ),
            ),
          ),
        ),
        //只有启用"延时自动"时才需要调等待时长
        if (trigger == RecallRevealTrigger.delayed ||
            trigger == RecallRevealTrigger.all) ...[
          const _SettingsDivider(),
          ListTile(
            leading: Icon(
              Icons.hourglass_empty,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            title: Text(
              context.tr.recallRevealDelayLabel,
              style: _titleStyle(context),
            ),
            subtitle: Text(
              context.tr.recallRevealDelayDesc,
              style: _subtitleStyle(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SlideSegmentedControl<int>(
              values: delayValues,
              selected: shownDelay,
              onChanged: (value) {
                if (value == _customDelaySentinel) {
                  unawaited(_showCustomDelayDialog(context, provider));
                } else {
                  provider.setRecallRevealDelaySeconds(value);
                }
              },
              labelBuilder: (value, selected) => Text(
                value == _customDelaySentinel
                    ? (kRecallRevealDelayOptions.contains(delay)
                          ? context.tr.recallRevealDelayCustom
                          : context.tr.recallRevealDelaySeconds(delay))
                    : context.tr.recallRevealDelaySeconds(value),
                style: FluidTheme.labelLarge(isDark).copyWith(
                  color: selected
                      ? FluidTheme.primaryFluidGradient[0]
                      : FluidTheme.getTextSecondaryColor(isDark),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 评分按键布局分组：进入编辑器自由拖动键位（参考手游自定义键位）。
  /// 位置 / 大小 / 透明度的调整都收进编辑器（所见即所得 + 实时预览），
  /// 这里只留入口与恢复默认。
  Widget _buildButtonLayoutSection(
    BuildContext context,
    StudySettingsProvider provider,
  ) {
    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(
          title: context.tr.t('评分按键布局', 'Answer Button Layout'),
        ),
        ListTile(
          leading: Icon(
            Icons.gamepad_outlined,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(
            context.tr.t('自定义按键位置', 'Customize Button Layout'),
            style: _titleStyle(context),
          ),
          subtitle: Text(
            context.tr.t(
              '在编辑器里把评分键拖到任意位置，每颗键的宽、高与透明度都可单独调',
              'Drag the answer buttons anywhere, and tune each key\'s width, height and opacity separately.',
            ),
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => Navigator.push(
            context,
            PageTransitions.slideFromRight(
              page: const RecallButtonLayoutEditor(),
            ),
          ),
        ),
        const _SettingsDivider(),
        ListTile(
          leading: Icon(
            Icons.restart_alt,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(
            context.tr.t('恢复默认布局', 'Reset Layout'),
            style: _titleStyle(context),
          ),
          subtitle: Text(
            context.tr.t(
              '三颗键的位置、尺寸与透明度恢复为默认一排',
              'Restore all three keys to the default row, size and opacity.',
            ),
            style: _subtitleStyle(context),
          ),
          onTap: () => provider.resetRecallButtonLayout(),
        ),
      ],
    );
  }
}

/// 测验模式（英选中 / 中选英）设置分组
///
/// 四个选项作为一个整体，在屏幕剩余区域里上下移动：有人习惯拇指够下方，
/// 有人习惯选项贴着题面，位置偏好因人而异，故开放成滑块。
class QuizOptionsSettingsSection extends StatelessWidget {
  const QuizOptionsSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudySettingsProvider>();
    final position = provider.quizOptionsVertical;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.quizSettingsTitle),
        ListTile(
          leading: Icon(
            Icons.format_list_numbered_rtl_outlined,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(
            context.tr.quizOptionsPositionLabel,
            style: _titleStyle(context),
          ),
          subtitle: Text(
            context.tr.quizOptionsPositionDesc,
            style: _subtitleStyle(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: LiquidSlider(
            value: position.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => provider.setQuizOptionsVertical(v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                [
                      Text(context.tr.quizOptionsPositionTop),
                      Text(context.tr.quizOptionsPositionMiddle),
                      Text(context.tr.quizOptionsPositionBottom),
                    ]
                    .map(
                      (w) => DefaultTextStyle(
                        style: FluidTheme.bodySmall(isDark).copyWith(
                          color: FluidTheme.getTextTertiaryColor(isDark),
                        ),
                        child: w,
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }
}

/// 关于设置分组
///
/// 移动端屏幕空间有限：不在设置一级页把版本 / 开发者 / 协议 / GitHub 全部
/// 铺开，收缩成一个入口，点进二级页面（[AboutScreen]）再看；
/// 桌面端横向空间充裕，保持原样直接展开。
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformAdapt.isMobile) {
      return _SettingsSectionShell(
        children: [
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            title: Text(context.tr.about, style: _titleStyle(context)),
            subtitle: Text(
              AppConstants.appVersion,
              style: _subtitleStyle(context),
            ),
            trailing: const _SettingsChevron(),
            onTap: () => Navigator.push(
              context,
              PageTransitions.slideFromRight(page: const AboutScreen()),
            ),
          ),
        ],
      );
    }
    return const AboutDetailSection();
  }
}

/// 关于详情卡片（版本 / 开发者 / 开源协议 / GitHub）
class AboutDetailSection extends StatelessWidget {
  const AboutDetailSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.about),
        ListTile(
          leading: Icon(Icons.info, color: FluidTheme.primaryFluidGradient[0]),
          title: Text(context.tr.version, style: _titleStyle(context)),
          subtitle: Text(
            AppConstants.appVersion,
            style: _subtitleStyle(context),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.person,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.developer, style: _titleStyle(context)),
          subtitle: Text(context.tr.qingmang, style: _subtitleStyle(context)),
        ),
        ListTile(
          leading: Icon(
            Icons.description,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(
            context.tr.openSourceLicense,
            style: _titleStyle(context),
          ),
          subtitle: Text('Apache License 2.0', style: _subtitleStyle(context)),
        ),
        ListTile(
          leading: Icon(Icons.link, color: FluidTheme.primaryFluidGradient[0]),
          title: Text('GitHub', style: _titleStyle(context)),
          subtitle: Text(
            'https://github.com/qingmang-66/qingmang_weiji',
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () {
            Clipboard.setData(
              const ClipboardData(
                text: 'https://github.com/qingmang-66/qingmang_weiji',
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr.githubLinkCopied)),
            );
          },
        ),
      ],
    );
  }
}

/// 通知提醒设置分组
class NotificationSettingsSection extends StatelessWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    //内部订阅 provider：提醒时间等值变化后分组重建，
    //否则「确认后时间一直显示 20:00」这类「改了但看不见」的问题会复现
    final provider = context.watch<StudySettingsProvider>();
    final settings = provider.notificationSettings;
    // 格式化提醒时间为 HH:mm
    final timeText =
        '${settings.reminderHour.toString().padLeft(2, '0')}:'
        '${settings.reminderMinute.toString().padLeft(2, '0')}';

    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.notificationSettings),
        // 开关：每日学习提醒
        ListTile(
          title: Text(context.tr.enableReminder, style: _titleStyle(context)),
          subtitle: Text(
            settings.enabled
                ? context.tr.reminderEnabledDesc
                : context.tr.reminderDisabledDesc,
            style: _subtitleStyle(context),
          ),
          leading: Icon(
            Icons.notifications_active,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          trailing: LiquidSwitch(
            value: settings.enabled,
            onChanged: (value) async {
              try {
                await provider.updateNotificationSettings(
                  settings.copyWith(enabled: value),
                );
              } catch (e) {
                if (!context.mounted) return;
                _showPermissionTip(context, e);
              }
            },
          ),
          onTap: () async {
            try {
              await provider.updateNotificationSettings(
                settings.copyWith(enabled: !settings.enabled),
              );
            } catch (e) {
              if (!context.mounted) return;
              _showPermissionTip(context, e);
            }
          },
        ),
        ListTile(
          leading: Icon(
            Icons.access_time,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.reminderTime, style: _titleStyle(context)),
          subtitle: Text(timeText, style: _subtitleStyle(context)),
          trailing: const _SettingsChevron(),
          onTap: () => _pickReminderTime(context, provider, settings),
        ),
        // Android：Doze 与国产 ROM 的省电策略会延迟甚至拦截提醒闹钟，
        // 给一个直达"电池优化"设置的入口，免得用户自己找不到地方
        if (PlatformAdapt.isMobile)
          ListTile(
            leading: Icon(
              Icons.battery_saver_outlined,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            title: Text(
              context.tr.batterySettingsTitle,
              style: _titleStyle(context),
            ),
            subtitle: Text(
              context.tr.batterySettingsDesc,
              style: _subtitleStyle(context),
            ),
            trailing: const _SettingsChevron(),
            onTap: () async {
              final ok = await PlatformSettings.openBatterySettings();
              //ROM 没有该设置页/被拦截时给出替代路径，避免"点了没反应"
              if (!ok && context.mounted) {
                ErrorHandler.showError(
                  context,
                  context.tr.batterySettingsFailed,
                );
              }
            },
          ),
        // 提醒声音：Windows 端系统通知声音常被静音，改由应用侧播放提示音
        if (isWindowsPlatform)
          ListTile(
            leading: Icon(
              Icons.volume_up_outlined,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            title: Text(context.tr.reminderSound, style: _titleStyle(context)),
            subtitle: Text(
              settings.soundEnabled
                  ? context.tr.reminderSoundOnDesc
                  : context.tr.reminderSoundOffDesc,
              style: _subtitleStyle(context),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (settings.soundEnabled)
                  IconButton(
                    tooltip: context.tr.reminderSoundPreview,
                    icon: Icon(
                      Icons.play_circle_outline,
                      color: FluidTheme.primaryFluidGradient[0],
                    ),
                    onPressed: () =>
                        ReminderSoundService.instance.playPreview(),
                  ),
                LiquidSwitch(
                  value: settings.soundEnabled,
                  onChanged: (value) async {
                    try {
                      await provider.updateNotificationSettings(
                        settings.copyWith(soundEnabled: value),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ErrorHandler.handleException(
                        context,
                        e,
                        fallbackMessage: _notificationFailureMessage(
                          context,
                          e,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            onTap: () async {
              try {
                await provider.updateNotificationSettings(
                  settings.copyWith(soundEnabled: !settings.soundEnabled),
                );
              } catch (e) {
                if (!context.mounted) return;
                ErrorHandler.handleException(
                  context,
                  e,
                  fallbackMessage: _notificationFailureMessage(context, e),
                );
              }
            },
          ),
      ],
    );
  }

  /// 提醒调度失败时的提示。
  ///
  /// 最常见的原因是 Android 13+ 的通知权限被拒：光说"失败"没用，开关回滚之后
  /// 用户还是不知道下一步该干什么，所以给一个「去设置」直接跳到本应用的
  /// 通知设置页（原生侧 [NotificationService.openSystemSettings]）。
  void _showPermissionTip(BuildContext context, [Object? error]) {
    final messenger = ScaffoldMessenger.of(context);
    final denied =
        error is StateError &&
        error.message.toString().contains('permission denied');
    final message = _notificationFailureMessage(context, error);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: isAndroidPlatform && denied
              ? SnackBarAction(
                  label: context.tr.openSystemSettings,
                  onPressed: () => NotificationService().openSystemSettings(),
                )
              : null,
        ),
      );
    //与错词撤销条同型的兜底：SnackBar 的自动计时要等入场动画播完才开始，
    //动画靠 ticker 驱动，页面切后台被静音时计时永远不走、提示就赖在底部。
    //延迟移除不依赖动画，本分组是无状态组件，直接抓 messengerState 即可
    Future.delayed(const Duration(seconds: 5), messenger.removeCurrentSnackBar);
  }

  /// 选择提醒时间：直接打开滚轮选择器
  Future<void> _pickReminderTime(
    BuildContext context,
    StudySettingsProvider provider,
    NotificationSettings settings,
  ) async {
    final pickerKey = GlobalKey<_FluidTimePickerContentState>();
    final picked = await showFluidDialog<TimeOfDay>(
      context: context,
      title: context.tr.reminderTime,
      // 滚轮 + 大号时间 + 按钮的总高在横屏/小屏上会超过弹窗高度上限，
      // 不可滚动时底部「确定」会被裁掉、用户无法确认；允许滚动保证按钮可达
      scrollable: true,
      //回车键等同于「确定」
      onConfirm: () => pickerKey.currentState?.confirm(),
      content: _FluidTimePickerContent(
        key: pickerKey,
        initialHour: settings.reminderHour,
        initialMinute: settings.reminderMinute,
      ),
    );
    if (picked == null) return;
    try {
      await provider.updateNotificationSettings(
        settings.copyWith(
          reminderHour: picked.hour,
          reminderMinute: picked.minute,
        ),
      );
    } catch (e) {
      if (context.mounted) ErrorHandler.handleException(context, e);
    }
  }
}

/// 桌面端允许鼠标/触控板拖动滚动
/// 提醒设置失败时的提示文案。
///
/// 区分"权限被拒"与"服务不可用/调度失败"：Windows 上根本没有通知权限这个概念，
/// 一律提示"权限被拒"会把用户引向一个不存在的开关（也无从自查）。
String _notificationFailureMessage(BuildContext context, Object? error) {
  final denied =
      error is StateError &&
      error.message.toString().contains('permission denied');
  if (isAndroidPlatform && (denied || error == null)) {
    return context.tr.notificationPermissionDenied;
  }
  return context.tr.notificationScheduleFailedDesktop;
}

class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// 低惯性吸附滚动，桌面拖动更稳
class _SnapScrollPhysics extends ScrollPhysics {
  final double itemExtent;
  const _SnapScrollPhysics({required this.itemExtent, super.parent});

  @override
  _SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _getTargetPixels(ScrollMetrics position, double velocity) {
    var page = position.pixels / itemExtent;
    if (velocity < -200) {
      page -= 0.3;
    } else if (velocity > 200) {
      page += 0.3;
    }
    return page.roundToDouble() * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final target = _getTargetPixels(
      position,
      velocity * 0.28,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity * 0.2,
      tolerance: toleranceFor(position),
    );
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1.1, stiffness: 90, damping: 18);
}

/// Fluid 自定义时间选择内容：桌面可拖动列表滚轮
class _FluidTimePickerContent extends StatefulWidget {
  final int initialHour;
  final int initialMinute;

  const _FluidTimePickerContent({
    super.key,
    required this.initialHour,
    required this.initialMinute,
  });

  @override
  State<_FluidTimePickerContent> createState() =>
      _FluidTimePickerContentState();
}

class _FluidTimePickerContentState extends State<_FluidTimePickerContent> {
  late int _hour;
  late int _minute;
  late ScrollController _hourCtrl;
  late ScrollController _minuteCtrl;

  /// 分钟按 1 分钟步进（0-59），不再限制为 5 分钟的整数倍
  static const _minuteCount = 60;
  static const _itemExtent = 48.0;
  static const _wheelHeight = 192.0;
  bool _hourReady = false;
  bool _minuteReady = false;

  double get _pad => (_wheelHeight - _itemExtent) / 2;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour.clamp(0, 23);
    _minute = widget.initialMinute.clamp(0, _minuteCount - 1);
    _hourCtrl = ScrollController(initialScrollOffset: _hour * _itemExtent);
    _minuteCtrl = ScrollController(initialScrollOffset: _minute * _itemExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _hourReady = true;
          _minuteReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  int _indexFromOffset(double offset, int itemCount) {
    return (offset / _itemExtent).round().clamp(0, itemCount - 1);
  }

  Future<void> _animateTo(ScrollController controller, int index) {
    return controller.animateTo(
      index * _itemExtent,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _wheelColumn({
    required String label,
    required ScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required String Function(int index) labelOf,
    required bool ready,
  }) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final primary = FluidTheme.primaryFluidGradient[0];
    final secondary = FluidTheme.getTextSecondaryColor(isDark);
    return Expanded(
      child: Column(
        children: [
          Text(label, style: _titleStyle(context)),
          const SizedBox(height: 8),
          SizedBox(
            height: _wheelHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Container(
                    height: _itemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                ScrollConfiguration(
                  behavior: _DesktopDragScrollBehavior(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (!ready || !controller.hasClients) return false;
                      final index = _indexFromOffset(
                        controller.offset,
                        itemCount,
                      );
                      if (index != selectedIndex) onSelected(index);
                      return false;
                    },
                    child: ListView.builder(
                      controller: controller,
                      itemExtent: _itemExtent,
                      padding: EdgeInsets.symmetric(vertical: _pad),
                      physics: const _SnapScrollPhysics(
                        itemExtent: _itemExtent,
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: itemCount,
                      itemBuilder: (_, index) {
                        final selected = index == selectedIndex;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _animateTo(controller, index);
                            onSelected(index);
                          },
                          child: Center(
                            child: Text(
                              labelOf(index),
                              textAlign: TextAlign.center,
                              style: FluidTheme.numberStyle(
                                fontSize: selected ? 28 : 18,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected ? primary : secondary,
                                letterSpacing: selected ? 1.0 : 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = FluidTheme.primaryFluidGradient[0];
    final isGlass = context.isLiquidGlass;
    //滚轮选择区：玻璃模式包果冻底盘（弹窗本身已是玻璃，此处只处理内容底盘）
    final wheels = Row(
      children: [
        _wheelColumn(
          label: context.tr.hour,
          controller: _hourCtrl,
          itemCount: 24,
          selectedIndex: _hour,
          ready: _hourReady,
          onSelected: (index) {
            if (_hour != index) setState(() => _hour = index);
          },
          labelOf: (index) => index.toString().padLeft(2, '0'),
        ),
        const SizedBox(width: 12),
        _wheelColumn(
          label: context.tr.minute,
          controller: _minuteCtrl,
          itemCount: _minuteCount,
          selectedIndex: _minute,
          ready: _minuteReady,
          onSelected: (index) {
            if (_minute != index) setState(() => _minute = index);
          },
          labelOf: (index) => index.toString().padLeft(2, '0'),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _hour.toString().padLeft(2, '0'),
              style: FluidTheme.numberStyle(
                fontSize: 52,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                ':',
                style: FluidTheme.numberStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w400,
                  color: primary,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              _minute.toString().padLeft(2, '0'),
              style: FluidTheme.numberStyle(
                fontSize: 52,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(context.tr.twentyFourHour),
        const SizedBox(height: 10),
        if (isGlass)
          GlassSurface(
            borderRadius: 18,
            grain: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: wheels,
          )
        else
          wheels,
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isGlass)
              FluidTextButton(
                text: context.tr.cancel,
                onPressed: () => Navigator.of(context).pop(),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr.cancel),
              ),
            const SizedBox(width: 8),
            if (isGlass)
              FluidButton(
                text: context.tr.confirm,
                colors: FluidTheme.primaryFluidGradient,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                onPressed: confirm,
              )
            else
              FilledButton(onPressed: confirm, child: Text(context.tr.confirm)),
          ],
        ),
      ],
    );
  }

  /// 确认选择：返回当前小时/分钟（弹窗回车键也走这里）
  void confirm() {
    //以滚轮实际停靠位置为准：快速滚动未 settle 时 NotificationListener
    //可能漏掉最后一次 index 更新，直接读 offset 最可靠
    if (_hourCtrl.hasClients) {
      _hour = _indexFromOffset(_hourCtrl.offset, 24);
    }
    if (_minuteCtrl.hasClients) {
      _minute = _indexFromOffset(_minuteCtrl.offset, _minuteCount);
    }
    Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute));
  }
}

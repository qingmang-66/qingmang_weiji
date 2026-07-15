import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/providers/providers.dart';
import '../utils/constants.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../utils/platform_adapt.dart';
import '../utils/error_handler.dart';
import '../models/notification_settings.dart';
import 'fluid_dialog.dart';

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
  final isDark = context.watch<ThemeProvider>().isDarkMode;
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
      child: Column(children: children),
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

ButtonStyle _segmentedButtonStyle(BuildContext context) {
  final colors = _settingsColors(context);

  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.white;
      }
      return colors.textPrimary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return FluidTheme.primaryFluidGradient[0];
      }
      return FluidTheme.getMutedOverlayColor(colors.isDark);
    }),
    side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
  );
}

/// 设置分组标题 - 流体渐变风格
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: FluidTheme.primaryFluidGradient,
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

/// 外观设置分组
class AppearanceSettingsSection extends StatelessWidget {
  final ThemeProvider themeProvider;

  const AppearanceSettingsSection({super.key, required this.themeProvider});

  String _themeModeLabel(ThemeMode mode, BuildContext context) {
    switch (mode) {
      case ThemeMode.dark:
        return context.tr.darkModeActive;
      case ThemeMode.system:
        return context.tr.autoModeDesc;
      case ThemeMode.light:
        return context.tr.lightModeActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _settingsColors(context);

    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.appearance),
        ListTile(
          leading: Icon(
            themeProvider.themeMode == ThemeMode.system
                ? Icons.brightness_auto
                : themeProvider.isDarkMode
                ? Icons.dark_mode
                : Icons.light_mode,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.displayMode, style: _titleStyle(context)),
          subtitle: Text(
            _themeModeLabel(themeProvider.themeMode, context),
            style: _subtitleStyle(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text(context.tr.lightMode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text(context.tr.darkModeLabel),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text(context.tr.systemMode),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (selection) {
              themeProvider.setThemeMode(selection.first);
            },
            style: _segmentedButtonStyle(context),
          ),
        ),
        const _SettingsDivider(),
        SettingsSectionHeader(title: context.tr.splashAnimationSpeed),
        ListTile(
          leading: Icon(
            Icons.animation,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(
            context.tr.splashAnimationSpeed,
            style: _titleStyle(context),
          ),
          subtitle: Text(
            context.tr.splashAnimationSpeedDesc,
            style: _subtitleStyle(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SegmentedButton<SplashAnimationSpeed>(
            segments: [
              ButtonSegment(
                value: SplashAnimationSpeed.fast,
                icon: const Icon(Icons.play_arrow),
                label: Text(context.tr.speedFast),
              ),
              ButtonSegment(
                value: SplashAnimationSpeed.comfortable,
                icon: const Icon(Icons.timer),
                label: Text(context.tr.speedComfortable),
              ),
              ButtonSegment(
                value: SplashAnimationSpeed.slow,
                icon: const Icon(Icons.slow_motion_video),
                label: Text(context.tr.speedSlow),
              ),
            ],
            selected: {themeProvider.splashAnimationSpeed},
            onSelectionChanged: (selection) {
              themeProvider.setSplashAnimationSpeed(selection.first);
            },
            style: _segmentedButtonStyle(context),
          ),
        ),
        const _SettingsDivider(),
        if (PlatformAdapt.isDesktop || kIsWeb) ...[
          SettingsSectionHeader(title: context.tr.navPosition),
          ListTile(
            leading: Icon(
              themeProvider.navPosition == NavPosition.left
                  ? Icons.view_sidebar
                  : Icons.view_carousel,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            title: Text(
              context.tr.navPositionTitle,
              style: _titleStyle(context),
            ),
            subtitle: Text(
              context.tr.navPositionDesc,
              style: _subtitleStyle(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<NavPosition>(
              segments: [
                ButtonSegment(
                  value: NavPosition.bottom,
                  icon: const Icon(Icons.view_carousel),
                  label: Text(context.tr.navBottom),
                ),
                ButtonSegment(
                  value: NavPosition.left,
                  icon: const Icon(Icons.view_sidebar),
                  label: Text(context.tr.navLeft),
                ),
              ],
              selected: {themeProvider.navPosition},
              onSelectionChanged: (selection) {
                themeProvider.setNavPosition(selection.first);
              },
              style: _segmentedButtonStyle(context),
            ),
          ),
          const _SettingsDivider(),
        ],
        SettingsSectionHeader(title: context.tr.language),
        ListTile(
          leading: Icon(
            Icons.language,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.currentLanguage, style: _titleStyle(context)),
          subtitle: Text(
            themeProvider.isEnglishLocale ? 'English' : context.tr.chineseLabel,
            style: _subtitleStyle(context),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  if (!themeProvider.isEnglishLocale) {
                    themeProvider.setEnglishLocale(true);
                  }
                },
                child: Text(
                  context.tr.englishLabel,
                  style: TextStyle(
                    fontWeight: themeProvider.isEnglishLocale
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: themeProvider.isEnglishLocale
                        ? FluidTheme.primaryFluidGradient[0]
                        : colors.textSecondary,
                  ),
                ),
              ),
              Text(' | ', style: TextStyle(color: colors.textTertiary)),
              TextButton(
                onPressed: () {
                  if (themeProvider.isEnglishLocale) {
                    themeProvider.setEnglishLocale(false);
                  }
                },
                child: Text(
                  context.tr.chineseLabel,
                  style: TextStyle(
                    fontWeight: !themeProvider.isEnglishLocale
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: !themeProvider.isEnglishLocale
                        ? FluidTheme.primaryFluidGradient[0]
                        : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 学习设置分组
class StudySettingsSection extends StatelessWidget {
  final StudySettingsProvider provider;
  final VoidCallback onOpenStudyPlan;
  final void Function({
    required BuildContext context,
    required String title,
    required int currentValue,
    required void Function(int) onConfirm,
  })
  showNumberInputDialog;

  const StudySettingsSection({
    super.key,
    required this.provider,
    required this.onOpenStudyPlan,
    required this.showNumberInputDialog,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.learningSettings),
        ListTile(
          leading: Icon(
            Icons.format_list_numbered,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.dailyNewWords, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.dailyNewWordsDesc(provider.dailyNewWords),
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => showNumberInputDialog(
            context: context,
            title: context.tr.dailyNewWords,
            currentValue: provider.dailyNewWords,
            onConfirm: provider.setDailyNewWords,
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.replay,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.dailyReviewLimit, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.dailyReviewWordsDesc(provider.dailyReviewWords),
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => showNumberInputDialog(
            context: context,
            title: context.tr.dailyReviewLimit,
            currentValue: provider.dailyReviewWords,
            onConfirm: provider.setDailyReviewWords,
          ),
        ),
        SwitchListTile(
          title: Text(context.tr.smartModeSwitch, style: _titleStyle(context)),
          subtitle: Text(
            provider.enableSmartModeSwitch
                ? context.tr.smartModeEnabled
                : context.tr.smartModeSwitchDesc,
            style: _subtitleStyle(context),
          ),
          secondary: Icon(
            Icons.auto_awesome,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          value: provider.enableSmartModeSwitch,
          onChanged: provider.setEnableSmartModeSwitch,
        ),
        const _SettingsDivider(),
        ListTile(
          leading: Icon(
            Icons.event_note,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.studyPlan, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.studyPlanDesc,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: onOpenStudyPlan,
        ),
      ],
    );
  }
}

/// 发音与词典设置分组
class AudioDictionarySettingsSection extends StatelessWidget {
  final StudySettingsProvider provider;
  final void Function(BuildContext context, StudySettingsProvider provider)
  showSpeechRatePicker;

  const AudioDictionarySettingsSection({
    super.key,
    required this.provider,
    required this.showSpeechRatePicker,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.audio),
        SwitchListTile(
          title: Text(context.tr.autoPlayAudio, style: _titleStyle(context)),
          subtitle: Text(
            context.tr.autoPlayDesc,
            style: _subtitleStyle(context),
          ),
          secondary: Icon(
            Icons.volume_up,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          value: provider.autoPlayAudio,
          onChanged: provider.setAutoPlayAudio,
        ),
        SwitchListTile(
          title: Text(context.tr.onlineAudio, style: _titleStyle(context)),
          subtitle: Text(
            provider.isOnlineAudio
                ? context.tr.youdaoVoiceDesc
                : context.tr.localTtsDesc2,
            style: _subtitleStyle(context),
          ),
          secondary: Icon(
            provider.isOnlineAudio ? Icons.cloud : Icons.device_hub,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          value: provider.isOnlineAudio,
          onChanged: (value) =>
              provider.setAudioSource(value ? 'online' : 'tts'),
        ),
        if (provider.isOnlineAudio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              style: _segmentedButtonStyle(context),
              segments: [
                ButtonSegment(
                  value: 'us',
                  label: Text(context.tr.usPronunciation),
                ),
                ButtonSegment(
                  value: 'uk',
                  label: Text(context.tr.ukPronunciation),
                ),
              ],
              selected: {provider.accentType},
              onSelectionChanged: (selected) =>
                  provider.setAccentType(selected.first),
            ),
          ),
        const _SettingsDivider(),
        SettingsSectionHeader(title: context.tr.dictDefinition),
        SwitchListTile(
          title: Text(
            context.tr.onlineDefinitionFallback,
            style: _titleStyle(context),
          ),
          subtitle: Text(
            provider.useOnlineDefinition
                ? context.tr.onlineDefOn
                : context.tr.onlineDefOff,
            style: _subtitleStyle(context),
          ),
          secondary: Icon(
            provider.useOnlineDefinition
                ? Icons.cloud_download
                : Icons.offline_pin,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          value: provider.useOnlineDefinition,
          onChanged: (value) => provider.setUseOnlineDefinition(value),
        ),
        if (provider.useOnlineDefinition)
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    context.tr.dictSource,
                    style: _titleStyle(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    context.tr.dictSourceDesc,
                    style: _subtitleStyle(context),
                  ),
                ),
                SegmentedButton<DictionarySource>(
                  style: _segmentedButtonStyle(context),
                  segments: [
                    ButtonSegment(
                      value: DictionarySource.freeDictionary,
                      label: Text(context.tr.enEnDefinition),
                      tooltip: 'Free Dictionary API',
                    ),
                    ButtonSegment(
                      value: DictionarySource.youdao,
                      label: Text(context.tr.zhEnDefinition),
                      tooltip: context.tr.youdaoDict,
                    ),
                  ],
                  selected: {provider.dictionarySource},
                  onSelectionChanged: (selected) =>
                      provider.setDictionarySource(selected.first),
                ),
              ],
            ),
          ),
        ListTile(
          leading: Icon(Icons.speed, color: FluidTheme.primaryFluidGradient[0]),
          title: Text(context.tr.speechRate, style: _titleStyle(context)),
          subtitle: Text(
            provider.speechRate <= 0.3
                ? context.tr.slow
                : provider.speechRate <= 0.5
                ? context.tr.normal
                : context.tr.fast,
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => showSpeechRatePicker(context, provider),
        ),
      ],
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

/// 关于设置分组
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

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
  final StudySettingsProvider provider;

  const NotificationSettingsSection({super.key, required this.provider});

  IconData _conditionIcon(NotificationCondition cond) => switch (cond) {
    NotificationCondition.hasDue => Icons.replay,
    NotificationCondition.planIncomplete => Icons.checklist,
    NotificationCondition.either => Icons.notifications_active_outlined,
  };

  /// 提醒条件文案
  String _conditionLabel(BuildContext context, NotificationCondition cond) {
    switch (cond) {
      case NotificationCondition.hasDue:
        return context.tr.reminderCondHasDue;
      case NotificationCondition.planIncomplete:
        return context.tr.reminderCondPlanIncomplete;
      case NotificationCondition.either:
        return context.tr.reminderCondEither;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = provider.notificationSettings;
    // 格式化提醒时间为 HH:mm
    final timeText =
        '${settings.reminderHour.toString().padLeft(2, '0')}:'
        '${settings.reminderMinute.toString().padLeft(2, '0')}';

    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: context.tr.notificationSettings),
        // 开关：每日学习提醒
        SwitchListTile(
          title: Text(context.tr.enableReminder, style: _titleStyle(context)),
          subtitle: Text(
            settings.enabled
                ? context.tr.reminderEnabledDesc
                : context.tr.reminderDisabledDesc,
            style: _subtitleStyle(context),
          ),
          secondary: Icon(
            Icons.notifications_active,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          value: settings.enabled,
          onChanged: (value) async {
            try {
              await provider.updateNotificationSettings(
                settings.copyWith(enabled: value),
              );
            } catch (e) {
              if (!context.mounted) return;
              ErrorHandler.handleException(
                context,
                e,
                fallbackMessage: context.tr.notificationPermissionDenied,
              );
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
          onTap: () => _pickReminderTime(context, settings),
        ),
        ListTile(
          leading: Icon(Icons.rule, color: FluidTheme.primaryFluidGradient[0]),
          title: Text(
            context.tr.reminderCondition,
            style: _titleStyle(context),
          ),
          subtitle: Text(
            _conditionLabel(context, settings.condition),
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => _pickCondition(context, settings),
        ),
      ],
    );
  }

  /// 选择提醒时间（方案A：大数字 + 快捷项 + Fluid 自定义）
  Future<void> _pickReminderTime(
    BuildContext context,
    NotificationSettings settings,
  ) async {
    var selected = TimeOfDay(
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
    );
    final picked = await showFluidDialog<TimeOfDay>(
      context: context,
      title: context.tr.reminderTime,
      content: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickCustomTime() async {
            // 使用独立 Stateful 控件，避免 StatefulBuilder 重建时重置滚轮
            final custom = await showFluidDialog<TimeOfDay>(
              context: dialogContext,
              title: dialogContext.tr.selectCustomTime,
              scrollable: false,
              content: _FluidTimePickerContent(
                initialHour: selected.hour,
                initialMinute: selected.minute,
              ),
            );
            if (custom != null) setDialogState(() => selected = custom);
          }

          Widget timeNumber(String value) => Container(
            width: 92,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FluidTheme.primaryFluidGradient[0].withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              value,
              style: FluidTheme.numberStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: FluidTheme.primaryFluidGradient[0],
              ),
            ),
          );

          final shortcuts = const [
            TimeOfDay(hour: 8, minute: 0),
            TimeOfDay(hour: 12, minute: 30),
            TimeOfDay(hour: 20, minute: 0),
            TimeOfDay(hour: 22, minute: 0),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  timeNumber(selected.hour.toString().padLeft(2, '0')),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 40)),
                  ),
                  timeNumber(selected.minute.toString().padLeft(2, '0')),
                ],
              ),
              const SizedBox(height: 8),
              Text(context.tr.twentyFourHour),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: shortcuts.map((time) {
                  final label =
                      '${time.hour.toString().padLeft(2, '0')}:'
                      '${time.minute.toString().padLeft(2, '0')}';
                  return ChoiceChip(
                    label: Text(label),
                    selected:
                        selected.hour == time.hour &&
                        selected.minute == time.minute,
                    onSelected: (_) => setDialogState(() => selected = time),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: pickCustomTime,
                icon: const Icon(Icons.tune),
                label: Text(context.tr.customTime),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected),
          child: Text(context.tr.confirm),
        ),
      ],
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

  /// 选择提醒条件
  Future<void> _pickCondition(
    BuildContext context,
    NotificationSettings settings,
  ) async {
    final selected = await showFluidDialog<NotificationCondition>(
      context: context,
      title: context.tr.reminderCondition,
      content: Builder(
        builder: (dialogContext) {
          final isDark = dialogContext.watch<ThemeProvider>().isDarkMode;
          final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
          final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: NotificationCondition.values.map((cond) {
              final isSelected = settings.condition == cond;
              final primary = FluidTheme.primaryFluidGradient[0];
              return Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    _conditionIcon(cond),
                    color: isSelected ? primary : textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    _conditionLabel(dialogContext, cond),
                    style: TextStyle(
                      color: isSelected ? primary : textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: Radio<NotificationCondition>(value: cond),
                  onTap: () => Navigator.pop(dialogContext, cond),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
    if (selected != null) {
      await provider.updateNotificationSettings(
        settings.copyWith(condition: selected),
      );
    }
  }
}

/// 桌面端允许鼠标/触控板拖动滚动
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
  static const _minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
  static const _itemExtent = 48.0;
  static const _wheelHeight = 192.0;
  bool _hourReady = false;
  bool _minuteReady = false;

  double get _pad => (_wheelHeight - _itemExtent) / 2;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour.clamp(0, 23);
    _minute = widget.initialMinute.clamp(0, 55);
    if (!_minutes.contains(_minute)) {
      _minute = (_minute ~/ 5) * 5;
    }
    _hourCtrl = ScrollController(initialScrollOffset: _hour * _itemExtent);
    _minuteCtrl = ScrollController(
      initialScrollOffset:
          _minutes.indexOf(_minute).clamp(0, _minutes.length - 1) * _itemExtent,
    );
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
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
        Row(
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
              itemCount: _minutes.length,
              selectedIndex: _minutes.indexOf(_minute),
              ready: _minuteReady,
              onSelected: (index) {
                final minute = _minutes[index];
                if (_minute != minute) setState(() => _minute = minute);
              },
              labelOf: (index) => _minutes[index].toString().padLeft(2, '0'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr.cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(TimeOfDay(hour: _hour, minute: _minute)),
              child: Text(context.tr.confirm),
            ),
          ],
        ),
      ],
    );
  }
}

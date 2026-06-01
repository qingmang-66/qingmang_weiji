import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/providers/providers.dart';
import '../utils/constants.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../models/notification_settings.dart';

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

  /// 进入学习计划页的回调
  final VoidCallback onOpenStudyPlan;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenCustomWordSets;

  const NotificationSettingsSection({
    super.key,
    required this.provider,
    required this.onOpenStudyPlan,
    required this.onOpenFavorites,
    required this.onOpenCustomWordSets,
  });

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
          onChanged: (value) {
            provider.updateNotificationSettings(
              settings.copyWith(enabled: value),
            );
          },
        ),
        // 提醒时间（仅启用时可点）
        ListTile(
          enabled: settings.enabled,
          leading: Icon(
            Icons.access_time,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(context.tr.reminderTime, style: _titleStyle(context)),
          subtitle: Text(timeText, style: _subtitleStyle(context)),
          trailing: const _SettingsChevron(),
          onTap: settings.enabled
              ? () => _pickReminderTime(context, settings)
              : null,
        ),
        // 提醒条件
        ListTile(
          enabled: settings.enabled,
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
          onTap: settings.enabled
              ? () => _pickCondition(context, settings)
              : null,
        ),
        const _SettingsDivider(),
        ListTile(
          leading: Icon(
            Icons.bookmark,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('收藏夹', style: _titleStyle(context)),
          subtitle: Text('查看收藏单词并进行专项学习', style: _subtitleStyle(context)),
          trailing: const _SettingsChevron(),
          onTap: onOpenFavorites,
        ),
        ListTile(
          leading: Icon(
            Icons.folder_special,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('自定义单词集', style: _titleStyle(context)),
          subtitle: Text('创建专题词集并进行专项学习', style: _subtitleStyle(context)),
          trailing: const _SettingsChevron(),
          onTap: onOpenCustomWordSets,
        ),
        const _SettingsDivider(),
        // 学习计划入口
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

  /// 选择提醒时间
  Future<void> _pickReminderTime(
    BuildContext context,
    NotificationSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );
    if (picked != null) {
      await provider.updateNotificationSettings(
        settings.copyWith(
          reminderHour: picked.hour,
          reminderMinute: picked.minute,
        ),
      );
    }
  }

  /// 选择提醒条件
  Future<void> _pickCondition(
    BuildContext context,
    NotificationSettings settings,
  ) async {
    final selected = await showModalBottomSheet<NotificationCondition>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: NotificationCondition.values.map((cond) {
              return ListTile(
                title: Text(_conditionLabel(ctx, cond)),
                trailing: settings.condition == cond
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, cond),
              );
            }).toList(),
          ),
        );
      },
    );
    if (selected != null) {
      await provider.updateNotificationSettings(
        settings.copyWith(condition: selected),
      );
    }
  }
}

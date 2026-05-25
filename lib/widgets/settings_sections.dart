import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/providers.dart';
import '../utils/constants.dart';
import '../theme/fluid_theme.dart';

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
  return FluidTheme.labelLarge.copyWith(
    color: _settingsColors(context).textPrimary,
  );
}

TextStyle _subtitleStyle(BuildContext context) {
  return FluidTheme.bodySmall.copyWith(
    color: _settingsColors(context).textSecondary,
  );
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

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return '当前使用黑夜模式';
      case ThemeMode.system:
        return '跟随系统设置自动切换白天/黑夜模式';
      case ThemeMode.light:
        return '当前使用白天模式';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _settingsColors(context);

    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: '外观'),
        ListTile(
          leading: Icon(
            themeProvider.themeMode == ThemeMode.system
                ? Icons.brightness_auto
                : themeProvider.isDarkMode
                ? Icons.dark_mode
                : Icons.light_mode,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('显示模式', style: _titleStyle(context)),
          subtitle: Text(
            _themeModeLabel(themeProvider.themeMode),
            style: _subtitleStyle(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('白天模式'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('黑夜模式'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('跟随系统'),
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
        SettingsSectionHeader(title: 'Language / 语言'),
        ListTile(
          leading: Icon(
            Icons.language,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('当前语言', style: _titleStyle(context)),
          subtitle: Text(
            themeProvider.isEnglishLocale ? 'English' : '中文',
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
                  'English',
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
                  '中文',
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
        SettingsSectionHeader(title: '学习设置'),
        ListTile(
          leading: Icon(
            Icons.format_list_numbered,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('每日新词数量', style: _titleStyle(context)),
          subtitle: Text(
            '${provider.dailyNewWords} 个',
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => showNumberInputDialog(
            context: context,
            title: '每日新词数量',
            currentValue: provider.dailyNewWords,
            onConfirm: provider.setDailyNewWords,
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.replay,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('每日复习上限', style: _titleStyle(context)),
          subtitle: Text(
            '${provider.dailyReviewWords} 个',
            style: _subtitleStyle(context),
          ),
          trailing: const _SettingsChevron(),
          onTap: () => showNumberInputDialog(
            context: context,
            title: '每日复习上限',
            currentValue: provider.dailyReviewWords,
            onConfirm: provider.setDailyReviewWords,
          ),
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
        SettingsSectionHeader(title: '发音'),
        SwitchListTile(
          title: Text('自动发音', style: _titleStyle(context)),
          subtitle: Text('显示单词时自动播放发音', style: _subtitleStyle(context)),
          secondary: Icon(
            Icons.volume_up,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          value: provider.autoPlayAudio,
          onChanged: provider.setAutoPlayAudio,
        ),
        SwitchListTile(
          title: Text('在线真人发音', style: _titleStyle(context)),
          subtitle: Text(
            provider.isOnlineAudio ? '使用有道真人发音 (需网络)' : '使用本地 TTS 合成音',
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
              segments: const [
                ButtonSegment(value: 'us', label: Text('美音')),
                ButtonSegment(value: 'uk', label: Text('英音')),
              ],
              selected: {provider.accentType},
              onSelectionChanged: (selected) =>
                  provider.setAccentType(selected.first),
            ),
          ),
        const _SettingsDivider(),
        SettingsSectionHeader(title: '词典释义'),
        SwitchListTile(
          title: Text('在线释义补充', style: _titleStyle(context)),
          subtitle: Text(
            provider.useOnlineDefinition ? '开启：释义缺失时自动从网络获取' : '关闭：仅使用本地词库释义',
            style: _subtitleStyle(context),
          ),
          secondary: Icon(
            provider.useOnlineDefinition
                ? Icons.cloud_download
                : Icons.offline_pin,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          value: provider.useOnlineDefinition,
          onChanged: (value) => provider.useOnlineDefinition = value,
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
                  child: Text('词典源', style: _titleStyle(context)),
                ),
                SegmentedButton<DictionarySource>(
                  style: _segmentedButtonStyle(context),
                  segments: const [
                    ButtonSegment(
                      value: DictionarySource.freeDictionary,
                      label: Text('英英释义'),
                      tooltip: 'Free Dictionary API',
                    ),
                    ButtonSegment(
                      value: DictionarySource.youdao,
                      label: Text('中英释义'),
                      tooltip: '有道词典',
                    ),
                  ],
                  selected: {provider.dictionarySource},
                  onSelectionChanged: (selected) =>
                      provider.dictionarySource = selected.first,
                ),
              ],
            ),
          ),
        ListTile(
          leading: Icon(Icons.speed, color: FluidTheme.primaryFluidGradient[0]),
          title: Text('语速', style: _titleStyle(context)),
          subtitle: Text(
            provider.speechRate <= 0.3
                ? '慢速'
                : provider.speechRate <= 0.5
                ? '正常'
                : '快速',
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
  final VoidCallback onClearData;

  const DataManagementSettingsSection({
    super.key,
    required this.onBackup,
    required this.onRestore,
    required this.onImport,
    required this.onClearData,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: '数据管理'),
        ListTile(
          leading: Icon(
            Icons.backup,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('备份数据', style: _titleStyle(context)),
          subtitle: Text('导出到本地备份文件夹', style: _subtitleStyle(context)),
          trailing: const _SettingsChevron(),
          onTap: onBackup,
        ),
        ListTile(
          leading: Icon(
            Icons.restore,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('恢复数据', style: _titleStyle(context)),
          subtitle: Text('从备份文件夹选择历史版本', style: _subtitleStyle(context)),
          trailing: const _SettingsChevron(),
          onTap: onRestore,
        ),
        ListTile(
          leading: Icon(
            Icons.upload_file,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text('导入词库', style: _titleStyle(context)),
          subtitle: Text('从 TXT 文件导入新单词', style: _subtitleStyle(context)),
          trailing: const _SettingsChevron(),
          onTap: onImport,
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt, color: FluidTheme.error),
          title: const Text(
            '初始化应用',
            style: TextStyle(
              color: FluidTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text('清空数据并重新显示首次引导页', style: _subtitleStyle(context)),
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
        SettingsSectionHeader(title: '关于'),
        ListTile(
          leading: Icon(Icons.info, color: FluidTheme.primaryFluidGradient[0]),
          title: Text('版本', style: _titleStyle(context)),
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
          title: Text('开发者', style: _titleStyle(context)),
          subtitle: Text('清茫', style: _subtitleStyle(context)),
        ),
      ],
    );
  }
}

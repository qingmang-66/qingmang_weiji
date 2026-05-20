import 'package:flutter/material.dart';
import '../services/providers/providers.dart';
import '../utils/constants.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class AppearanceSettingsSection extends StatelessWidget {
  final ThemeProvider themeProvider;
  final ColorScheme colorScheme;

  const AppearanceSettingsSection({
    super.key,
    required this.themeProvider,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSectionHeader(title: '外观', colorScheme: colorScheme),
        SwitchListTile(
          title: const Text('深色模式'),
          subtitle: const Text('切换深色/浅色主题'),
          secondary: Icon(
            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: colorScheme.primary,
          ),
          value: themeProvider.isDarkMode,
          onChanged: themeProvider.setDarkMode,
        ),
        const Divider(),
        SettingsSectionHeader(title: 'Language / 语言', colorScheme: colorScheme),
        ListTile(
          leading: Icon(Icons.language, color: colorScheme.primary),
          title: const Text('当前语言'),
          subtitle: Text(themeProvider.isEnglishLocale ? 'English' : '中文'),
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
                    fontWeight: themeProvider.isEnglishLocale ? FontWeight.bold : FontWeight.normal,
                    color: themeProvider.isEnglishLocale ? colorScheme.primary : null,
                  ),
                ),
              ),
              const Text(' | '),
              TextButton(
                onPressed: () {
                  if (themeProvider.isEnglishLocale) {
                    themeProvider.setEnglishLocale(false);
                  }
                },
                child: Text(
                  '中文',
                  style: TextStyle(
                    fontWeight: !themeProvider.isEnglishLocale ? FontWeight.bold : FontWeight.normal,
                    color: !themeProvider.isEnglishLocale ? colorScheme.primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class StudySettingsSection extends StatelessWidget {
  final StudySettingsProvider provider;
  final ColorScheme colorScheme;
  final void Function({
    required BuildContext context,
    required String title,
    required int currentValue,
    required void Function(int) onConfirm,
  }) showNumberInputDialog;

  const StudySettingsSection({
    super.key,
    required this.provider,
    required this.colorScheme,
    required this.showNumberInputDialog,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSectionHeader(title: '学习设置', colorScheme: colorScheme),
        ListTile(
          leading: Icon(Icons.format_list_numbered, color: colorScheme.primary),
          title: const Text('每日新词数量'),
          subtitle: Text('${provider.dailyNewWords} 个'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showNumberInputDialog(
            context: context,
            title: '每日新词数量',
            currentValue: provider.dailyNewWords,
            onConfirm: provider.setDailyNewWords,
          ),
        ),
        ListTile(
          leading: Icon(Icons.replay, color: colorScheme.primary),
          title: const Text('每日复习上限'),
          subtitle: Text('${provider.dailyReviewWords} 个'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showNumberInputDialog(
            context: context,
            title: '每日复习上限',
            currentValue: provider.dailyReviewWords,
            onConfirm: provider.setDailyReviewWords,
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class AudioDictionarySettingsSection extends StatelessWidget {
  final StudySettingsProvider provider;
  final ColorScheme colorScheme;
  final void Function(BuildContext context, StudySettingsProvider provider) showSpeechRatePicker;

  const AudioDictionarySettingsSection({
    super.key,
    required this.provider,
    required this.colorScheme,
    required this.showSpeechRatePicker,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSectionHeader(title: '发音', colorScheme: colorScheme),
        SwitchListTile(
          title: const Text('自动发音'),
          subtitle: const Text('显示单词时自动播放发音'),
          secondary: Icon(Icons.volume_up, color: colorScheme.primary),
          value: provider.autoPlayAudio,
          onChanged: provider.setAutoPlayAudio,
        ),
        SwitchListTile(
          title: const Text('在线真人发音'),
          subtitle: Text(
            provider.isOnlineAudio ? '使用有道真人发音 (需网络)' : '使用本地 TTS 合成音',
            style: TextStyle(color: colorScheme.secondary),
          ),
          secondary: Icon(provider.isOnlineAudio ? Icons.cloud : Icons.device_hub, color: colorScheme.primary),
          value: provider.isOnlineAudio,
          onChanged: (value) => provider.setAudioSource(value ? 'online' : 'tts'),
        ),
        if (provider.isOnlineAudio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'us', label: Text('美音')),
                ButtonSegment(value: 'uk', label: Text('英音')),
              ],
              selected: {provider.accentType},
              onSelectionChanged: (selected) => provider.setAccentType(selected.first),
            ),
          ),
        const Divider(),
        SettingsSectionHeader(title: '词典释义', colorScheme: colorScheme),
        SwitchListTile(
          title: const Text('在线释义补充'),
          subtitle: Text(
            provider.useOnlineDefinition ? '开启：释义缺失时自动从网络获取' : '关闭：仅使用本地词库释义',
            style: TextStyle(color: colorScheme.secondary),
          ),
          secondary: Icon(provider.useOnlineDefinition ? Icons.cloud_download : Icons.offline_pin, color: colorScheme.primary),
          value: provider.useOnlineDefinition,
          onChanged: (value) => provider.useOnlineDefinition = value,
        ),
        if (provider.useOnlineDefinition)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '词典源',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                SegmentedButton<DictionarySource>(
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
                  onSelectionChanged: (selected) => provider.dictionarySource = selected.first,
                ),
              ],
            ),
          ),
        ListTile(
          leading: Icon(Icons.speed, color: colorScheme.primary),
          title: const Text('语速'),
          subtitle: Text(provider.speechRate <= 0.3 ? '慢速' : provider.speechRate <= 0.5 ? '正常' : '快速'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showSpeechRatePicker(context, provider),
        ),
        const Divider(),
      ],
    );
  }
}

class DataManagementSettingsSection extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onImport;
  final VoidCallback onClearData;

  const DataManagementSettingsSection({
    super.key,
    required this.colorScheme,
    required this.onBackup,
    required this.onRestore,
    required this.onImport,
    required this.onClearData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSectionHeader(title: '数据管理', colorScheme: colorScheme),
        ListTile(
          leading: Icon(Icons.backup, color: colorScheme.primary),
          title: const Text('备份数据'),
          subtitle: const Text('导出到本地备份文件夹'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onBackup,
        ),
        ListTile(
          leading: Icon(Icons.restore, color: colorScheme.primary),
          title: const Text('恢复数据'),
          subtitle: const Text('从备份文件夹选择历史版本'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onRestore,
        ),
        ListTile(
          leading: Icon(Icons.upload_file, color: colorScheme.primary),
          title: const Text('导入词库'),
          subtitle: const Text('从 TXT 文件导入新单词'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onImport,
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('清除所有数据'),
          subtitle: const Text('删除所有学习记录，不可恢复'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onClearData,
        ),
        const Divider(),
      ],
    );
  }
}

class AboutSettingsSection extends StatelessWidget {
  final ColorScheme colorScheme;

  const AboutSettingsSection({
    super.key,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSectionHeader(title: '关于', colorScheme: colorScheme),
        ListTile(
          leading: Icon(Icons.info, color: colorScheme.primary),
          title: const Text('版本'),
          subtitle: const Text(AppConstants.appVersion),
        ),
        ListTile(
          leading: Icon(Icons.description, color: colorScheme.primary),
          title: const Text('开源协议'),
          subtitle: const Text('MIT License'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () {},
        ),
      ],
    );
  }
}

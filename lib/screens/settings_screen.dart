import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/app_provider.dart';
import '../services/database_service.dart';
import '../services/seed_service.dart';
import '../services/word_import_service.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<Directory> _getBackupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'qingmang_backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(Translations.t('设置', 'Settings'))),
      body: ListView(
        children: [
          // 外观
          _SectionHeader(title: Translations.t('外观', 'Appearance'), colorScheme: colorScheme),
          SwitchListTile(
            title: Text(Translations.t('深色模式', 'Dark Mode')),
            subtitle: Text(Translations.t('切换深色/浅色主题', 'Switch dark/light theme')),
            secondary: Icon(provider.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: colorScheme.primary),
            value: provider.isDarkMode,
            onChanged: (value) => provider.setDarkMode(value),
          ),
          const Divider(),

          // 语言设置
          _SectionHeader(title: 'Language / 语言', colorScheme: colorScheme),
          ListTile(
            leading: Icon(Icons.language, color: colorScheme.primary),
            title: Text(Translations.t('当前语言', 'Current Language')),
            subtitle: Text(provider.isEnglishLocale ? 'English' : '中文'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    if (!provider.isEnglishLocale) {
                      provider.setEnglishLocale(true);
                    }
                  },
                  child: Text(
                    'English',
                    style: TextStyle(
                      fontWeight: provider.isEnglishLocale ? FontWeight.bold : FontWeight.normal,
                      color: provider.isEnglishLocale ? colorScheme.primary : null,
                    ),
                  ),
                ),
                const Text(' | '),
                TextButton(
                  onPressed: () {
                    if (provider.isEnglishLocale) {
                      provider.setEnglishLocale(false);
                    }
                  },
                  child: Text(
                    '中文',
                    style: TextStyle(
                      fontWeight: !provider.isEnglishLocale ? FontWeight.bold : FontWeight.normal,
                      color: !provider.isEnglishLocale ? colorScheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // 学习设置
          _SectionHeader(title: Translations.t('学习设置', 'Learning Settings'), colorScheme: colorScheme),
          ListTile(
            leading: Icon(Icons.format_list_numbered, color: colorScheme.primary),
            title: Text(Translations.t('每日新词数量', 'Daily New Words')),
            subtitle: Text('${provider.dailyNewWords} ${Translations.t('个', 'words')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberInputDialog(
              context: context,
              title: Translations.t('每日新词数量', 'Daily New Words'),
              currentValue: provider.dailyNewWords,
              onConfirm: (v) => provider.setDailyNewWords(v),
            ),
          ),
          ListTile(
            leading: Icon(Icons.replay, color: colorScheme.primary),
            title: Text(Translations.t('每日复习上限', 'Daily Review Limit')),
            subtitle: Text('${provider.dailyReviewWords} ${Translations.t('个', 'words')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberInputDialog(
              context: context,
              title: Translations.t('每日复习上限', 'Daily Review Limit'),
              currentValue: provider.dailyReviewWords,
              onConfirm: (v) => provider.setDailyReviewWords(v),
            ),
          ),
          const Divider(),

          // 发音设置
          _SectionHeader(title: Translations.t('发音', 'Audio'), colorScheme: colorScheme),
          SwitchListTile(
            title: Text(Translations.t('自动发音', 'Auto Play Audio')),
            subtitle: Text(Translations.t('显示单词时自动播放发音', 'Play audio when showing word')),
            secondary: Icon(Icons.volume_up, color: colorScheme.primary),
            value: provider.autoPlayAudio,
            onChanged: (value) => provider.setAutoPlayAudio(value),
          ),
          SwitchListTile(
            title: Text(Translations.t('在线真人发音', 'Online Voice')),
            subtitle: Text(
              Translations.t(
                provider.isOnlineAudio ? '使用有道真人发音 (需网络)' : '使用本地 TTS 合成音',
                provider.isOnlineAudio ? 'Youdao Voice (need network)' : 'Local TTS',
              ),
              style: TextStyle(color: colorScheme.secondary),
            ),
            secondary: Icon(provider.isOnlineAudio ? Icons.cloud : Icons.device_hub, color: colorScheme.primary),
            value: provider.isOnlineAudio,
            onChanged: (value) => provider.setAudioSource(value ? 'online' : 'tts'),
          ),
          if (provider.isOnlineAudio) ...[
            ValueListenableBuilder<String>(
              valueListenable: ValueNotifier(provider.accentType),
              builder: (context, accentType, _) {
                return Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(Translations.t('美音', 'US Pronunciation')),
                      value: 'us',
                      groupValue: accentType,
                      onChanged: (value) => provider.setAccentType(value!),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      title: Text(Translations.t('英音', 'UK Pronunciation')),
                      value: 'uk',
                      groupValue: accentType,
                      onChanged: (value) => provider.setAccentType(value!),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      dense: true,
                    ),
                  ],
                );
              },
            ),
          ],
          const Divider(),

          // 词典释义设置
          _SectionHeader(title: Translations.t('词典释义', 'Dictionary'), colorScheme: colorScheme),
          SwitchListTile(
            title: Text(Translations.t('在线释义补充', 'Online Definition')),
            subtitle: Text(
              Translations.t(
                provider.useOnlineDefinition ? '开启：释义缺失时自动从网络获取' : '关闭：仅使用本地词库释义',
                provider.useOnlineDefinition ? 'Fetch missing definitions online' : 'Offline only',
              ),
              style: TextStyle(color: colorScheme.secondary),
            ),
            secondary: Icon(provider.useOnlineDefinition ? Icons.cloud_download : Icons.offline_pin, color: colorScheme.primary),
            value: provider.useOnlineDefinition,
            onChanged: (value) => provider.useOnlineDefinition = value,
          ),
          // 词典源选择（仅在开启在线释义时显示）
          if (provider.useOnlineDefinition)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      Translations.t('词典源', 'Dictionary Source'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  ValueListenableBuilder<DictionarySource>(
                    valueListenable: ValueNotifier(provider.dictionarySource),
                    builder: (context, dictSource, _) {
                      return Column(
                        children: [
                          RadioListTile<DictionarySource>(
                            title: Text(Translations.t('英英释义', 'English Definition')),
                            subtitle: const Text('Free Dictionary API'),
                            value: DictionarySource.freeDictionary,
                            groupValue: dictSource,
                            onChanged: (value) => provider.dictionarySource = value!,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          RadioListTile<DictionarySource>(
                            title: Text(Translations.t('中英释义', 'Chinese + English')),
                            subtitle: const Text('有道词典'),
                            value: DictionarySource.youdao,
                            groupValue: dictSource,
                            onChanged: (value) => provider.dictionarySource = value!,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ListTile(
            leading: Icon(Icons.speed, color: colorScheme.primary),
            title: Text(Translations.t('语速', 'Speech Rate')),
            subtitle: Text(Translations.t(
              provider.speechRate <= 0.3 ? '慢速' : provider.speechRate <= 0.5 ? '正常' : '快速',
              provider.speechRate <= 0.3 ? 'Slow' : provider.speechRate <= 0.5 ? 'Normal' : 'Fast',
            )),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSpeechRatePicker(context, provider),
          ),
          const Divider(),

          // 数据管理
          _SectionHeader(title: Translations.t('数据管理', 'Data Management'), colorScheme: colorScheme),
          ListTile(
            leading: Icon(Icons.backup, color: colorScheme.primary),
            title: Text(Translations.t('备份数据', 'Backup Data')),
            subtitle: Text(Translations.t('导出到本地备份文件夹', 'Export to backup folder')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _backupData(context),
          ),
          ListTile(
            leading: Icon(Icons.restore, color: colorScheme.primary),
            title: Text(Translations.t('恢复数据', 'Restore Data')),
            subtitle: Text(Translations.t('从备份文件夹选择历史版本', 'Select from backup history')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRestorePicker(context),
          ),
          ListTile(
            leading: Icon(Icons.upload_file, color: colorScheme.primary),
            title: Text(Translations.t('导入词库', 'Import Word Book')),
            subtitle: Text(Translations.t('从 TXT 文件导入新单词', 'Import from TXT file')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _importWordBook(context),
          ),
          ListTile(
            leading: Icon(Icons.restore, color: colorScheme.tertiary),
            title: Text(Translations.t('重置内置词库', 'Reset Built-in Word Books')),
            subtitle: Text(Translations.t('重新下载并导入内置词库', 'Re-download and import built-in word books')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _resetBuiltInWordBooks(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text(Translations.t('清除所有数据', 'Clear All Data')),
            subtitle: Text(Translations.t('删除所有学习记录，不可恢复', 'Delete all records, cannot undo')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearConfirm(context),
          ),
          const Divider(),

          // 关于
          _SectionHeader(title: Translations.t('关于', 'About'), colorScheme: colorScheme),
          ListTile(
            leading: Icon(Icons.info, color: colorScheme.primary),
            title: Text(Translations.t('版本', 'Version')),
            subtitle: const Text(AppConstants.appVersion),
          ),
          ListTile(
            leading: Icon(Icons.description, color: colorScheme.primary),
            title: Text(Translations.t('开源协议', 'Open Source License')),
            subtitle: const Text('MIT License'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showNumberInputDialog({
    required BuildContext context,
    required String title,
    required int currentValue,
    required void Function(int) onConfirm,
  }) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: Translations.t('请输入数字', 'Enter number'),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) {
            final v = int.tryParse(controller.text);
            if (v != null && v > 0) {
              onConfirm(v);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v > 0) {
                onConfirm(v);
                Navigator.pop(ctx);
              }
            },
            child: Text(Translations.t('确定', 'Confirm')),
          ),
        ],
      ),
    );
  }

  void _showSpeechRatePicker(BuildContext context, AppProvider provider) {
    double selected = provider.speechRate;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(Translations.t('语速', 'Speech Rate')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Translations.t(
                  selected <= 0.3 ? '慢速' : selected <= 0.5 ? '正常' : '快速',
                  selected <= 0.3 ? 'Slow' : selected <= 0.5 ? 'Normal' : 'Fast',
                ),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              Slider(
                value: selected,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: selected.toStringAsFixed(1),
                onChanged: (v) => setState(() => selected = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Translations.t('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                provider.setSpeechRate(selected);
                Navigator.pop(ctx);
              },
              child: Text(Translations.t('确定', 'Confirm')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupData(BuildContext context) async {
    try {
      final data = await DatabaseService.exportAll();
      final jsonStr = const JsonEncoder.withIndent(' ').convert(data);
      final backupDir = await _getBackupDir();
      final now = DateTime.now();
      final filename = 'qingmang_backup_'
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}.json';
      final file = File(p.join(backupDir.path, filename));
      await file.writeAsString(jsonStr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.t('备份成功，已保存到备份文件夹', 'Backup success, saved to folder')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.t('备份失败：', 'Backup failed: ') + e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showRestorePicker(BuildContext context) async {
    try {
      final backupDir = await _getBackupDir();
      final files = await backupDir
          .list()
          .where((f) => f is File && f.path.endsWith('.json'))
          .map((f) => f as File)
          .toList();
      if (files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Translations.t('暂无备份文件，请先备份', 'No backup files, please backup first')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (!context.mounted) return;

      final selected = await showModalBottomSheet<File>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.restore),
                    const SizedBox(width: 8),
                    Text(
                      Translations.t('选择备份文件', 'Select Backup File'),
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: files.length,
                  itemBuilder: (ctx, i) {
                    final file = files[i];
                    final name = p.basename(file.path);
                    final mtime = file.lastModifiedSync();
                    final dateStr = '${mtime.year}-${mtime.month.toString().padLeft(2, '0')}-${mtime.day.toString().padLeft(2, '0')} ${mtime.hour.toString().padLeft(2, '0')}:${mtime.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(name),
                      subtitle: Text(dateStr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(ctx, file),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected == null || !context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(Translations.t('确认恢复', 'Confirm Restore')),
          content: Text(
            Translations.t('恢复后将覆盖当前所有数据，确定继续吗？\n\n选中的备份：', 'Current data will be overwritten. Continue?\n\nSelected: ') + p.basename(selected.path),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.t('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.t('确定', 'Confirm')),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final jsonStr = await selected.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      await DatabaseService.importAll(data);

      if (context.mounted) {
        context.read<AppProvider>().loadWordBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.t('恢复成功', 'Restore Success')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.t('恢复失败：', 'Restore failed: ') + e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importWordBook(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final fileName = p.basename(filePath);

      if (!context.mounted) return;
      final bookName = await _showBookNameInputDialog(context, fileName);
      if (bookName == null || bookName.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Translations.t('词库名称不能为空', 'Word book name cannot be empty')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(Translations.t('正在导入词库...', 'Importing word book...')),
            ],
          ),
        ),
      );

      await WordImportService.importWordsFromFile(
        filePath,
        bookName.trim(),
        description: '从 $fileName 导入',
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        context.read<AppProvider>().loadWordBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.t('✓ 词库 "', '✓ Word book "') + bookName + Translations.t('" 导入成功！', '" imported successfully!')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.t('✗ 导入失败：', '✗ Import failed: ') + e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _showBookNameInputDialog(BuildContext context, String defaultFileName) {
    final controller = TextEditingController(text: _formatBookName(defaultFileName));
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.t('导入词库', 'Import Word Book')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 格式说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        Translations.t('格式说明', 'Format Guide'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Translations.t(
                      '📄 每行一个单词\n✅ 例：apple\n✅ 例：beautiful\n❌ 避免：apple,banana',
                      '📄 One word per line\n✅ OK: apple\n✅ OK: beautiful\n❌ Avoid: apple,banana',
                    ),
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(Translations.t('请输入词库名称：', 'Enter word book name:')),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: Translations.t('例如：高考英语词汇', 'e.g. Gaokao English'),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              Translations.t('文件：', 'File: ') + defaultFileName,
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(Translations.t('导入', 'Import')),
          ),
        ],
      ),
    );
  }

  String _formatBookName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'\.txt$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_-]'), ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  void _showClearConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.t('确认清除', 'Confirm Clear')),
        content: Text(Translations.t('确定要清除所有数据吗？此操作不可恢复。', 'Confirm clear all data? This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await DatabaseService.clearAllData();
              if (context.mounted) {
                Navigator.pop(ctx);
                context.read<AppProvider>().loadWordBooks();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(Translations.t('数据已清除', 'Data cleared'))),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(Translations.t('清除', 'Clear')),
          ),
        ],
      ),
    );
  }

  /// 重置内置词库
  void _resetBuiltInWordBooks(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.t('重置内置词库', 'Reset Built-in Word Books')),
        content: Text(Translations.t('将重新下载并导入内置词库，现有数据将被覆盖。', 'Will re-download and import built-in word books. Existing data will be overwritten.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // 显示加载提示
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(Translations.t('正在重置词库...', 'Resetting word books...')),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              
              // 执行重置
              try {
                await SeedService.resetBuiltInData();
                if (context.mounted) {
                  context.read<AppProvider>().loadWordBooks();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(Translations.t('词库重置成功', 'Word books reset successfully'))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(Translations.t('词库重置失败', 'Word books reset failed'))),
                  );
                }
              }
            },
            child: Text(Translations.t('重置', 'Reset')),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;
  const _SectionHeader({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
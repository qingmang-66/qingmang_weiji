import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/providers/providers.dart';
import '../services/backup_service.dart';
import '../services/seed_service.dart';
import '../services/word_import_service.dart';
import '../widgets/settings_sections.dart';
import '../utils/error_handler.dart';
import '../utils/translations.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final studySettingsProvider = context.watch<StudySettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          AppearanceSettingsSection(
            themeProvider: themeProvider,
            colorScheme: colorScheme,
          ),
          StudySettingsSection(
            provider: studySettingsProvider,
            colorScheme: colorScheme,
            showNumberInputDialog: _showNumberInputDialog,
          ),
          AudioDictionarySettingsSection(
            provider: studySettingsProvider,
            colorScheme: colorScheme,
            showSpeechRatePicker: _showSpeechRatePicker,
          ),
          DataManagementSettingsSection(
            colorScheme: colorScheme,
            onBackup: () => _backupData(context),
            onRestore: () => _showRestorePicker(context),
            onImport: () => _importWordBook(context),
            onClearData: () => _showClearConfirm(context),
          ),
          AboutSettingsSection(colorScheme: colorScheme),
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

  void _showSpeechRatePicker(BuildContext context, StudySettingsProvider provider) {
    double selected = provider.speechRate;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('语速'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected <= 0.3 ? '慢速' : selected <= 0.5 ? '正常' : '快速',
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
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                provider.setSpeechRate(selected);
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupData(BuildContext context) async {
    try {
      await BackupService.backupData();
      if (context.mounted) {
        ErrorHandler.showSuccess(context, '备份成功，已保存到备份文件夹');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(context, e, fallbackMessage: '备份失败');
      }
    }
  }

  Future<void> _showRestorePicker(BuildContext context) async {
    try {
      final files = await BackupService.getBackupFiles();
      if (files.isEmpty) {
        if (context.mounted) {
          ErrorHandler.showError(context, '暂无备份文件，请先备份');
        }
        return;
      }
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
                      '选择备份文件',
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
          title: const Text('确认恢复'),
          content: Text('恢复后将覆盖当前所有数据，确定继续吗？\n\n选中的备份：${p.basename(selected.path)}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      await BackupService.restoreData(selected.path);

      if (context.mounted) {
        context.read<WordBookProvider>().loadWordBooks();
        ErrorHandler.showSuccess(context, '恢复成功');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(context, e, fallbackMessage: '恢复失败');
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
          ErrorHandler.showError(context, '词库名称不能为空');
        }
        return;
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在导入词库...'),
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
        context.read<WordBookProvider>().loadWordBooks();
        ErrorHandler.showSuccess(context, '词库 "$bookName" 导入成功！');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ErrorHandler.handleException(context, e, fallbackMessage: '导入失败');
      }
    }
  }

  Future<String?> _showBookNameInputDialog(BuildContext context, String defaultFileName) {
    final controller = TextEditingController(text: _formatBookName(defaultFileName));
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入词库'),
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
                        '格式说明',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '📄 每行一个单词\n✅ 例：apple\n✅ 例：beautiful\n❌ 避免：apple,banana',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('请输入词库名称：'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '例如：高考英语词汇',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              '文件：$defaultFileName',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('导入'),
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
        title: const Text('确认清除'),
        content: const Text('确定要清除所有数据吗？此操作不可恢复。\n\n清除后将自动恢复内置词库。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await BackupService.clearAllData();
              // 清除后重新导入内置词库
              await SeedService.seedBuiltInData();
              if (context.mounted) {
                Navigator.pop(ctx);
                context.read<WordBookProvider>().loadWordBooks();
                ErrorHandler.showSuccess(context, '数据已清除，内置词库已恢复');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/providers/providers.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/seed_service.dart';
import '../services/app_initialization_service.dart';
import '../services/word_import_service.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/settings_sections.dart';
import '../utils/error_handler.dart';
import '../utils/translations.dart';

/// 设置页面 - 流体渐变风格
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final studySettingsProvider = context.watch<StudySettingsProvider>();
    final isDark = themeProvider.isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return FluidBackground(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '设置',
              style: FluidTheme.headingMedium.copyWith(color: textPrimary),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AppearanceSettingsSection(themeProvider: themeProvider),
                const SizedBox(height: 12),
                StudySettingsSection(
                  provider: studySettingsProvider,
                  showNumberInputDialog: _showNumberInputDialog,
                ),
                const SizedBox(height: 12),
                AudioDictionarySettingsSection(
                  provider: studySettingsProvider,
                  showSpeechRatePicker: _showSpeechRatePicker,
                ),
                const SizedBox(height: 12),
                DataManagementSettingsSection(
                  onBackup: () => _backupData(context),
                  onRestore: () => _showRestorePicker(context),
                  onImport: () => _importWordBook(context),
                  onClearData: () => _showClearConfirm(context),
                ),
                const SizedBox(height: 12),
                AboutSettingsSection(),
                const SizedBox(height: 32),
              ]),
            ),
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
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textColor = FluidTheme.getTextPrimaryColor(isDark);
    final hintColor = FluidTheme.getTextTertiaryColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);
    showFluidDialog(
      context: context,
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          filled: true,
          fillColor: FluidTheme.getInputFillColor(isDark),
          hintText: Translations.t('请输入数字', 'Enter number'),
          hintStyle: TextStyle(color: hintColor),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: FluidTheme.primaryFluidGradient[0]),
          ),
        ),
        autofocus: true,
        onSubmitted: (_) {
          final v = int.tryParse(controller.text);
          if (v != null && v > 0) {
            onConfirm(v);
            Navigator.pop(context);
          }
        },
      ),
      title: title,
      actions: [
        FluidTextButton(
          text: Translations.t('取消', 'Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: Translations.t('确定', 'Confirm'),
          onPressed: () {
            final v = int.tryParse(controller.text);
            if (v != null && v > 0) {
              onConfirm(v);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  void _showSpeechRatePicker(
    BuildContext context,
    StudySettingsProvider provider,
  ) {
    double selected = provider.speechRate;
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);

    showFluidDialog(
      context: context,
      content: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected <= 0.3
                  ? '慢速'
                  : selected <= 0.5
                  ? '正常'
                  : '快速',
              style: FluidTheme.headingSmall.copyWith(color: textPrimary),
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(ctx).copyWith(
                activeTrackColor: FluidTheme.primaryFluidGradient[0],
                inactiveTrackColor: borderColor,
                thumbColor: FluidTheme.primaryFluidGradient[0],
                overlayColor: FluidTheme.primaryFluidGradient[0].withValues(
                  alpha: 0.2,
                ),
              ),
              child: Slider(
                value: selected,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: selected.toStringAsFixed(1),
                onChanged: (v) => setState(() => selected = v),
              ),
            ),
          ],
        ),
      ),
      title: '语速',
      actions: [
        FluidTextButton(text: '取消', onPressed: () => Navigator.pop(context)),
        FluidButton(
          text: '确定',
          onPressed: () {
            provider.setSpeechRate(selected);
            Navigator.pop(context);
          },
        ),
      ],
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

      final isDark = context.read<ThemeProvider>().isDarkMode;
      final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
      final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
      final iconColor = FluidTheme.getTextSecondaryColor(isDark);

      final selected = await showModalBottomSheet<File>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: FluidTheme.getDialogSurfaceColor(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: FluidTheme.getBorderColor(isDark)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FluidTheme.getMutedOverlayColor(isDark),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.restore,
                      color: FluidTheme.primaryFluidGradient[0],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Translations.t('选择备份文件', 'Select backup file'),
                      style: FluidTheme.headingSmall.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: files.length,
                  itemBuilder: (ctx, index) {
                    final file = files[index];
                    final fileName = p.basename(file.path);
                    final fileSize = file.lengthSync();
                    final sizeStr = fileSize < 1024
                        ? '$fileSize B'
                        : fileSize < 1024 * 1024
                        ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
                        : '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: FluidCard(
                        enableShimmer: false,
                        padding: const EdgeInsets.all(12),
                        onTap: () => Navigator.pop(ctx, file),
                        child: Row(
                          children: [
                            Icon(
                              Icons.backup,
                              color: FluidTheme.primaryFluidGradient[0],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: FluidTheme.labelLarge.copyWith(
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    sizeStr,
                                    style: FluidTheme.bodySmall.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: iconColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected != null && context.mounted) {
        _confirmRestore(context, selected);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(context, e, fallbackMessage: '获取备份列表失败');
      }
    }
  }

  void _confirmRestore(BuildContext context, File backupFile) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    showFluidDialog(
      context: context,
      content: Text(
        '确定要恢复备份吗？这将覆盖当前数据。',
        style: FluidTheme.bodyMedium.copyWith(color: textPrimary),
      ),
      title: '恢复备份',
      actions: [
        FluidTextButton(text: '取消', onPressed: () => Navigator.pop(context)),
        FluidButton(
          text: '恢复',
          onPressed: () async {
            Navigator.pop(context);
            try {
              await BackupService.restoreData(backupFile.path);
              if (context.mounted) {
                ErrorHandler.showSuccess(context, '恢复成功');
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.handleException(
                  context,
                  e,
                  fallbackMessage: '恢复失败',
                );
              }
            }
          },
        ),
      ],
    );
  }

  Future<void> _importWordBook(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv', 'json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (context.mounted) {
          _showImportDialog(context, file);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(context, e, fallbackMessage: '选择文件失败');
      }
    }
  }

  void _showImportDialog(BuildContext context, File file) {
    final fileName = p.basenameWithoutExtension(file.path);
    final nameController = TextEditingController(text: fileName);
    final descController = TextEditingController();
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);
    final inputFillColor = FluidTheme.getInputFillColor(isDark);

    showFluidDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputFillColor,
              labelText: '词库名称',
              labelStyle: TextStyle(color: textSecondary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputFillColor,
              labelText: '描述（可选）',
              labelStyle: TextStyle(color: textSecondary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
      title: '导入词库',
      actions: [
        FluidTextButton(text: '取消', onPressed: () => Navigator.pop(context)),
        FluidButton(
          text: '导入',
          onPressed: () async {
            if (nameController.text.trim().isNotEmpty) {
              Navigator.pop(context);
              try {
                await WordImportService.importWordsFromFile(
                  file.path,
                  nameController.text.trim(),
                  description: descController.text.trim(),
                );
                if (context.mounted) {
                  ErrorHandler.showSuccess(context, '导入成功');
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.handleException(
                    context,
                    e,
                    fallbackMessage: '导入失败',
                  );
                }
              }
            }
          },
        ),
      ],
    );
  }

  void _showClearConfirm(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    showFluidDialog(
      context: context,
      content: Text(
        '确定要初始化应用吗？这会清空当前学习数据和自定义词库，重新导入内置词库，并在重启后显示首次导航说明。',
        style: FluidTheme.bodyMedium.copyWith(color: textPrimary),
      ),
      title: '初始化应用',
      actions: [
        FluidTextButton(text: '取消', onPressed: () => Navigator.pop(context)),
        FluidButton(
          text: '初始化',
          onPressed: () async {
            Navigator.pop(context);
            try {
              await _initializeApplication(context);
              if (context.mounted) {
                ErrorHandler.showSuccess(context, '应用已初始化，请重新打开应用查看导航说明');
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.handleException(
                  context,
                  e,
                  fallbackMessage: '初始化失败',
                );
              }
            }
          },
          colors: FluidTheme.errorFluidGradient,
        ),
      ],
    );
  }

  Future<void> _initializeApplication(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();
    final studySettingsProvider = context.read<StudySettingsProvider>();
    final wordBookProvider = context.read<WordBookProvider>();

    await DatabaseService.clearAllData();
    await SeedService.seedBuiltInData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('hasSeenOnboarding', false);
    await themeProvider.loadPreferences();
    await studySettingsProvider.loadPreferences();
    await wordBookProvider.loadWordBooks();
    AppInitializationService.showOnboardingAfterInitialization();
  }
}

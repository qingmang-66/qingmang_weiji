import '../utils/file_compat.dart';
import '../utils/picked_file_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/providers/providers.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
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
import 'study_plan_screen.dart';

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
              context.tr.navSettings,
              style: FluidTheme.headingMedium(
                isDark,
              ).copyWith(color: textPrimary),
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
                  onOpenStudyPlan: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StudyPlanScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                AudioDictionarySettingsSection(
                  provider: studySettingsProvider,
                  showSpeechRatePicker: _showSpeechRatePicker,
                ),
                const SizedBox(height: 12),
                NotificationSettingsSection(provider: studySettingsProvider),
                const SizedBox(height: 12),
                DataManagementSettingsSection(
                  onBackup: () => _backupData(context),
                  onRestore: () => _showRestorePicker(context),
                  onImport: () => _importWordBook(context),
                  onDeleteBackup: () => _showDeleteBackupPicker(context),
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
          hintText: context.tr.enterNumber,
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
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.confirm,
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
                  ? context.tr.slow
                  : selected <= 0.5
                  ? context.tr.normal
                  : context.tr.fast,
              style: FluidTheme.headingSmall(
                isDark,
              ).copyWith(color: textPrimary),
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
      title: context.tr.speechRate,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.confirm,
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
        ErrorHandler.showSuccess(context, context.tr.backupSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.backupFailed,
        );
      }
    }
  }

  Future<void> _showRestorePicker(BuildContext context) async {
    try {
      final files = await BackupService.getBackupFiles();
      if (files.isEmpty) {
        if (context.mounted) {
          ErrorHandler.showError(context, context.tr.noBackupFiles);
        }
        return;
      }
      if (!context.mounted) return;

      final isDark = context.read<ThemeProvider>().isDarkMode;
      final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
      final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
      final iconColor = FluidTheme.getTextSecondaryColor(isDark);

      final selected = await showModalBottomSheet<AppFile>(
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
                      context.tr.selectBackupFile,
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
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
                                    style: FluidTheme.labelLarge(
                                      isDark,
                                    ).copyWith(color: textPrimary),
                                  ),
                                  Text(
                                    sizeStr,
                                    style: FluidTheme.bodySmall(
                                      isDark,
                                    ).copyWith(color: textSecondary),
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
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.getBackupListFailed,
        );
      }
    }
  }

  void _confirmRestore(BuildContext context, AppFile backupFile) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    showFluidDialog(
      context: context,
      content: Text(
        context.tr.confirmRestoreHint,
        style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
      ),
      title: context.tr.restoreBackup,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.restore,
          onPressed: () async {
            Navigator.pop(context);
            try {
              await BackupService.restoreData(backupFile.path);
              if (context.mounted) {
                ErrorHandler.showSuccess(context, context.tr.restoreSuccess);
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.handleException(
                  context,
                  e,
                  fallbackMessage: context.tr.restoreFailed,
                );
              }
            }
          },
        ),
      ],
    );
  }

  /// 显示删除备份文件选择器
  Future<void> _showDeleteBackupPicker(BuildContext context) async {
    try {
      final files = await BackupService.getBackupFiles();
      if (files.isEmpty) {
        if (context.mounted) {
          ErrorHandler.showError(context, context.tr.noBackupFiles);
        }
        return;
      }
      if (!context.mounted) return;

      final isDark = context.read<ThemeProvider>().isDarkMode;
      final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
      final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

      final selected = await showModalBottomSheet<AppFile>(
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
                    Icon(Icons.delete_outline, color: FluidTheme.error),
                    const SizedBox(width: 8),
                    Text(
                      context.tr.deleteBackup,
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
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
                                    style: FluidTheme.labelLarge(
                                      isDark,
                                    ).copyWith(color: textPrimary),
                                  ),
                                  Text(
                                    sizeStr,
                                    style: FluidTheme.bodySmall(
                                      isDark,
                                    ).copyWith(color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.delete_forever,
                              size: 20,
                              color: FluidTheme.error,
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
        _confirmDeleteBackup(context, selected);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.deleteBackupFailed,
        );
      }
    }
  }

  /// 确认删除备份文件
  void _confirmDeleteBackup(BuildContext context, AppFile backupFile) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    showFluidDialog(
      context: context,
      content: Text(
        context.tr.confirmDeleteBackup,
        style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
      ),
      title: context.tr.deleteBackup,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.deleteBackup,
          onPressed: () async {
            Navigator.pop(context);
            try {
              await BackupService.deleteBackupFile(backupFile.path);
              if (context.mounted) {
                ErrorHandler.showSuccess(
                  context,
                  context.tr.deleteBackupSuccess,
                );
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.handleException(
                  context,
                  e,
                  fallbackMessage: context.tr.deleteBackupFailed,
                );
              }
            }
          },
          colors: FluidTheme.errorFluidGradient,
        ),
      ],
    );
  }

  Future<void> _importWordBook(BuildContext context) async {
    try {
      final file = await PickedFileHelper.pickSingleFile(
        extensions: ['txt', 'csv', 'json'],
      );
      if (file != null && context.mounted) {
        _showImportDialog(context, file);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.selectFileFailed,
        );
      }
    }
  }

  void _showImportDialog(BuildContext context, AppFile file) {
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
              labelText: context.tr.wordBookName,
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
              labelText: context.tr.descriptionOptional,
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
      title: context.tr.importWordBook,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.import,
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
                  ErrorHandler.showSuccess(context, context.tr.importSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.handleException(
                    context,
                    e,
                    fallbackMessage: context.tr.importFailed,
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
        context.tr.confirmInitializeHint,
        style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
      ),
      title: context.tr.initializeApp,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.initialize,
          onPressed: () async {
            Navigator.pop(context);
            try {
              await _initializeApplication(context);
              if (context.mounted) {
                ErrorHandler.showSuccess(context, context.tr.initializeSuccess);
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.handleException(
                  context,
                  e,
                  fallbackMessage: context.tr.initializeFailed,
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
    // 不再自动导入内置词库，让用户自行选择导入
    // await SeedService.seedBuiltInData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('hasSeenOnboarding', false);
    await themeProvider.loadPreferences();
    await studySettingsProvider.loadPreferences();
    await wordBookProvider.loadWordBooks();
    AppInitializationService.showOnboardingAfterInitialization();
  }
}

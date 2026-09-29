import 'dart:async';

import '../utils/file_compat.dart';
import '../utils/picked_file_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/providers/providers.dart';
import '../services/providers/reader_settings_provider.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/di_container.dart';
import '../services/app_initialization_service.dart';
import '../services/guide_service.dart';
import '../services/word_import_service.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/settings_sections.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../utils/guide_keys.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';

/// 设置页二级/三级页面外壳
class SettingsSubPage extends StatelessWidget {
  final String title;
  final Widget child;

  const SettingsSubPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final glass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return FluidPage(
      top: false,
      child: Scaffold(
        backgroundColor: glass
            ? Colors.transparent
            : FluidTheme.getBackgroundColor(isDark),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            title,
            style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 4, bottom: 32),
          child: child,
        ),
      ),
    );
  }
}

/// 打开「回忆模式设置」页
///
/// 回忆模式的释义触发方式只从学习页顶栏设置按钮进入，
/// 设置一级页不再放这个入口（避免同一设置出现两处）。
Future<void> openRecallRevealSettings(BuildContext context) {
  return Navigator.push(
    context,
    PageTransitions.slideFromRight(
      page: SettingsSubPage(
        title: context.tr.recallSettingsTitle,
        child: const RecallDisplaySettingsSection(),
      ),
    ),
  );
}

/// 打开「测验模式设置」页：两个测验模式共用（选项区垂直位置）
Future<void> openQuizSettings(BuildContext context) {
  return Navigator.push(
    context,
    PageTransitions.slideFromRight(
      page: SettingsSubPage(
        title: context.tr.quizSettingsTitle,
        child: const QuizOptionsSettingsSection(),
      ),
    ),
  );
}

/// 设置页面 - 流体渐变风格
///
/// 全部铺平：外观、学习、提醒、数据、帮助与关于都在一级页直接展开，
/// 不再套「通知 / 数据 / 帮助」二级页面（用户反馈：设置里点一下就跳走，
/// 找回一项设置要进进出出好几层）。
/// 每个分组是独立小组件、各自订阅 provider，
/// 任一设置变化只重建对应分组，而不是整页 ListView（此前掉帧的根因）。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FluidBackground(
      child: ListView(
        //底部用主 Scaffold(extendBody) 注入的导航条高度动态避让：
        //悬浮胶囊导航压在内容上，固定值会在设置页末尾（GitHub 行等）
        //被导航条遮住
        padding: EdgeInsets.only(
          top: 4,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        children: [
          const _IdentityHeader(),
          const _AppearanceCard(),
          const SizedBox(height: 12),
          const _StudyCard(),
          const SizedBox(height: 12),
          //提醒设置：原来藏在二级页里，现在与其它分组同级直接铺开
          const NotificationSettingsSection(),
          const SizedBox(height: 12),
          //数据与备份：操作项全在一张卡上，不用先进入「数据」页再选
          DataManagementSettingsSection(
            onBackup: () => _backupData(context),
            onRestore: () => _showRestorePicker(context),
            onImport: () => _importWordBook(context),
            onDeleteBackup: () => _showDeleteBackupPicker(context),
            onClearData: () => _showClearConfirm(context),
          ),
          const SizedBox(height: 12),
          const _HelpCard(),
        ],
      ),
    );
  }
}

/// 顶部身份区：应用图标 + 名称 + 版本
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/app_icon_source_760.png',
                // 只显示 54dp，按 3x 密度限制解码尺寸
                cacheWidth: 162,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.appName,
                  style: FluidTheme.headingMedium(
                    isDark,
                  ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.tr.version} ${AppConstants.appVersion}',
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 外观与显示卡片：主题 / 风格 / 动画速度 / 循环动效 / 导航位置 / 语言
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    //本卡片展示多项主题状态，整体订阅；变化只重建这张卡
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final tr = context.tr;
    return KeyedSubtree(
      //上下文引导高亮目标
      key: guideSettingsAppearanceKey,
      child: SettingsSectionShell(
        children: [
          SettingsSectionHeader(title: tr.settingsCommonTitle),
          _settingTile(
            isDark: isDark,
            icon: switch (theme.themeMode) {
              ThemeMode.system => Icons.brightness_auto,
              ThemeMode.dark => Icons.dark_mode,
              ThemeMode.light => Icons.light_mode,
            },
            title: tr.displayMode,
            subtitle: _themeModeLabel(context, theme.themeMode),
          ),
          _segmentedRow<ThemeMode>(
            value: theme.themeMode,
            segments: [
              (ThemeMode.light, tr.lightMode),
              (ThemeMode.dark, tr.darkModeLabel),
              (ThemeMode.system, tr.systemMode),
            ],
            onChanged: theme.setThemeMode,
          ),
          _settingTile(
            isDark: isDark,
            icon: theme.isLiquidGlass ? Icons.filter_b_and_w : Icons.gradient,
            title: tr.uiStyle,
            subtitle: theme.isLiquidGlass
                ? tr.uiStyleGlassDesc
                : tr.uiStyleFluidDesc,
          ),
          _segmentedRow<AppStyle>(
            value: theme.appStyle,
            segments: [
              (AppStyle.fluid, tr.uiStyleFluid),
              (AppStyle.liquidGlass, tr.uiStyleGlass),
            ],
            onChanged: theme.setAppStyle,
          ),
          const Divider(height: 1),
          _settingTile(
            isDark: isDark,
            icon: Icons.animation,
            title: tr.splashAnimationSpeed,
            subtitle: tr.splashAnimationSpeedDesc,
          ),
          _segmentedRow<SplashAnimationSpeed>(
            value: theme.splashAnimationSpeed,
            segments: [
              (SplashAnimationSpeed.fast, tr.speedFast),
              (SplashAnimationSpeed.comfortable, tr.speedComfortable),
              (SplashAnimationSpeed.slow, tr.speedSlow),
            ],
            onChanged: theme.setSplashAnimationSpeed,
          ),
          //循环动效开关只在桌面端保留：Android 上动效已整体移除
          //（shimmer/背景光斑逐帧重绘，持续耗电而观感提升有限），
          //开关在那里没有意义，直接不渲染
          if (!PlatformAdapt.isAndroid)
            ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: FluidTheme.primaryFluidGradient[0],
              ),
              title: Text(tr.loopEffects, style: FluidTheme.labelLarge(isDark)),
              subtitle: Text(
                tr.loopEffectsDesc,
                style: FluidTheme.bodySmall(isDark),
              ),
              trailing: LiquidSwitch(
                value: theme.loopEffectsEnabled,
                onChanged: theme.setLoopEffectsEnabled,
              ),
              onTap: () =>
                  theme.setLoopEffectsEnabled(!theme.loopEffectsEnabled),
            ),
          // "侧栏 vs 底部栏"在大屏才有意义：桌面/Web，以及宽度 ≥600dp 的平板横屏
          if (PlatformAdapt.isDesktop ||
              kIsWeb ||
              MediaQuery.sizeOf(context).width >= 600) ...[
            const Divider(height: 1),
            _settingTile(
              isDark: isDark,
              icon: theme.navPosition == NavPosition.bottom
                  ? Icons.view_carousel
                  : Icons.view_sidebar,
              title: tr.navPositionTitle,
              subtitle: tr.navPositionDesc,
            ),
            _segmentedRow<NavPosition>(
              value: theme.navPosition,
              segments: [
                (NavPosition.bottom, tr.navBottom),
                (NavPosition.left, tr.navLeft),
                // 右侧导航仅 Windows 桌面端提供
                if (PlatformAdapt.isWindows) (NavPosition.right, tr.navRight),
              ],
              onChanged: theme.setNavPosition,
            ),
          ],
          const Divider(height: 1),
          _settingTile(
            isDark: isDark,
            icon: Icons.language,
            title: tr.currentLanguage,
            subtitle: theme.isEnglishLocale ? tr.englishLabel : tr.chineseLabel,
          ),
          _segmentedRow<bool>(
            value: theme.isEnglishLocale,
            segments: [(false, tr.chineseLabel), (true, tr.englishLabel)],
            onChanged: theme.setEnglishLocale,
          ),
        ],
      ),
    );
  }
}

/// 学习卡片：自动发音 / 智能切换 / 在线音频与口音 / 在线释义与词典源
class _StudyCard extends StatelessWidget {
  const _StudyCard();

  @override
  Widget build(BuildContext context) {
    //本卡片展示多项学习状态，整体订阅；变化只重建这张卡
    final s = context.watch<StudySettingsProvider>();
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final tr = context.tr;
    return SettingsSectionShell(
      children: [
        SettingsSectionHeader(title: tr.learningSettings),
        ListTile(
          leading: Icon(
            Icons.volume_up_outlined,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(tr.autoPlayAudio, style: FluidTheme.labelLarge(isDark)),
          subtitle: Text(tr.autoPlayDesc, style: FluidTheme.bodySmall(isDark)),
          trailing: LiquidSwitch(
            value: s.autoPlayAudio,
            onChanged: s.setAutoPlayAudio,
          ),
          onTap: () => s.setAutoPlayAudio(!s.autoPlayAudio),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.auto_awesome,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(tr.smartModeSwitch, style: FluidTheme.labelLarge(isDark)),
          subtitle: Text(
            tr.smartModeSwitchDesc,
            style: FluidTheme.bodySmall(isDark),
          ),
          trailing: LiquidSwitch(
            value: s.enableSmartModeSwitch,
            onChanged: s.setEnableSmartModeSwitch,
          ),
          onTap: () => s.setEnableSmartModeSwitch(!s.enableSmartModeSwitch),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            s.isOnlineAudio ? Icons.cloud : Icons.device_hub,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(tr.onlineAudio, style: FluidTheme.labelLarge(isDark)),
          subtitle: Text(
            s.isOnlineAudio ? tr.youdaoVoiceDesc : tr.localTtsDesc2,
            style: FluidTheme.bodySmall(isDark),
          ),
          trailing: LiquidSwitch(
            value: s.isOnlineAudio,
            onChanged: (v) => s.setAudioSource(v ? 'online' : 'tts'),
          ),
          onTap: () => s.setAudioSource(s.isOnlineAudio ? 'tts' : 'online'),
        ),
        if (s.isOnlineAudio)
          _segmentedRow<String>(
            value: s.accentType,
            segments: [('us', tr.usPronunciation), ('uk', tr.ukPronunciation)],
            onChanged: s.setAccentType,
          ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            s.useOnlineDefinition ? Icons.cloud_download : Icons.offline_pin,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          title: Text(
            tr.onlineDefinitionFallback,
            style: FluidTheme.labelLarge(isDark),
          ),
          subtitle: Text(
            s.useOnlineDefinition ? tr.onlineDefOn : tr.onlineDefOff,
            style: FluidTheme.bodySmall(isDark),
          ),
          trailing: LiquidSwitch(
            value: s.useOnlineDefinition,
            onChanged: s.setUseOnlineDefinition,
          ),
          onTap: () => s.setUseOnlineDefinition(!s.useOnlineDefinition),
        ),
        if (s.useOnlineDefinition)
          _segmentedRow<DictionarySource>(
            value: s.dictionarySource,
            segments: [
              (DictionarySource.freeDictionary, tr.enEnDefinition),
              (DictionarySource.youdao, tr.zhEnDefinition),
            ],
            onChanged: s.setDictionarySource,
          ),
      ],
    );
  }
}

/// 设置项标题行（图标 + 名称 + 当前值）
Widget _settingTile({
  required bool isDark,
  required IconData icon,
  required String title,
  String? subtitle,
}) {
  return ListTile(
    leading: Icon(icon, color: FluidTheme.primaryFluidGradient[0]),
    title: Text(title, style: FluidTheme.labelLarge(isDark)),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, style: FluidTheme.bodySmall(isDark)),
  );
}

/// 整行分段控件（双风格：流体渐变 / 液态玻璃）
Widget _segmentedRow<T>({
  required T value,
  required List<(T, String)> segments,
  required ValueChanged<T> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: LiquidSegmented<T>(
      value: value,
      segments: [
        for (final s in segments) LiquidSegment(value: s.$1, label: s.$2),
      ],
      onChanged: onChanged,
    ),
  );
}

String _themeModeLabel(BuildContext context, ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return context.tr.darkModeActive;
    case ThemeMode.system:
      return context.tr.autoModeDesc;
    case ThemeMode.light:
      return context.tr.lightModeActive;
  }
}

/// 「帮助与关于」分组卡片：功能引导 + 版本/开源信息直接铺开。
///
/// 原来是「帮助与关于」二级页（入口套入口，找一项设置要进出好几层）；
/// 现在与其余分组同级展开，引导重看与关于详情（版本 / 开源协议 / GitHub）
/// 都在一级卡片上，关于里那种只在移动端才有的二级页一并取消。
class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuideSettingsSection(),
        SizedBox(height: 12),
        AboutDetailSection(),
      ],
    );
  }
}

// ==================== 数据管理（备份 / 恢复 / 导入 / 初始化） ====================

Future<void> _backupData(BuildContext context) async {
  // 先询问口令：非空 → 导出加密备份（PBKDF2+AES-GCM）；留空 → 明文备份
  final password = await _askBackupPassword(context, forRestore: false);
  if (password == null) return; // 用户取消
  final effectivePassword = password.isEmpty ? null : password;
  try {
    if (PlatformAdapt.isMobile) {
      //手机端通过系统分享面板保存备份到文件管理器/网盘
      await BackupService.backupAndShare(password: effectivePassword);
      if (context.mounted) {
        ErrorHandler.showSuccess(context, context.tr.backupSharedHint);
      }
    } else {
      await BackupService.backupData(password: effectivePassword);
      if (context.mounted) {
        ErrorHandler.showSuccess(context, context.tr.backupSuccess);
      }
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

/// 弹出口令输入框。
///
/// 返回值：
/// - [forRestore] = false（导出）：`''` 表示用户选择不加密；null 表示取消
/// - [forRestore] = true（恢复）：非空口令；null 表示取消
///
/// 导出时要求两次输入一致（不一致留在对话框内提示，不关闭）。
Future<String?> _askBackupPassword(
  BuildContext context, {
  required bool forRestore,
}) async {
  final controller = TextEditingController();
  final confirmController = TextEditingController();
  var obscure = true;
  var mismatch = false;
  try {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final result = await showFluidDialog<String>(
      context: context,
      title: forRestore
          ? context.tr.backupPasswordRestoreTitle
          : context.tr.backupPasswordTitle,
      content: StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              forRestore
                  ? ctx.tr.backupPasswordRestoreHint
                  : ctx.tr.backupPasswordSetHint,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: ctx.tr.backupPasswordLabel,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => setModalState(() => obscure = !obscure),
                ),
              ),
            ),
            if (!forRestore) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscure,
                //回车 = 确定（TextInputAction.done + onSubmitted）。
                //必须与「确认」按钮走同一套校验，否则第二次打错按回车会用
                //第一个口令加密，事后无法解密
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  final pwd = controller.text;
                  if (pwd != confirmController.text) {
                    setModalState(() => mismatch = true);
                    return;
                  }
                  Navigator.pop(ctx, pwd);
                },
                decoration: InputDecoration(
                  labelText: ctx.tr.backupPasswordConfirmLabel,
                ),
              ),
              if (mismatch) ...[
                const SizedBox(height: 8),
                Text(
                  ctx.tr.backupPasswordMismatch,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: FluidTheme.error),
                ),
              ],
            ],
            const SizedBox(height: 18),
            // 按钮放在 content 内：需要访问 setModalState 做"口令不一致"
            // 的内联校验（actions 参数在 StatefulBuilder 之外，改不了内部状态）
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FluidTextButton(
                  text: ctx.tr.cancel,
                  onPressed: () => Navigator.pop(ctx),
                ),
                const SizedBox(width: 10),
                FluidButton(
                  text: ctx.tr.confirm,
                  onPressed: () {
                    final pwd = controller.text;
                    if (!forRestore && pwd != confirmController.text) {
                      setModalState(() => mismatch = true);
                      return;
                    }
                    Navigator.pop(ctx, pwd);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result;
  } finally {
    controller.dispose();
    confirmController.dispose();
  }
}

Future<void> _showRestorePicker(BuildContext context) async {
  try {
    final files = await BackupService.getBackupFiles();
    if (files.isEmpty) {
      //本地无备份时直接从系统文件选择
      if (context.mounted) {
        await _pickExternalBackup(context);
      }
      return;
    }
    if (!context.mounted) return;

    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final iconColor = FluidTheme.getTextSecondaryColor(isDark);
    //先异步取好文件大小：在 itemBuilder 里调用 lengthSync() 是同步磁盘 IO，
    //列表滚动/重建时会阻塞 UI 线程
    final sizeByPath = await _loadFileSizes(files);
    if (!context.mounted) return;

    final selected = await showFluidDialog<AppFile>(
      context: context,
      title: context.tr.selectBackupFile,
      scrollable: false,
      content: SizedBox(
        height: MediaQuery.of(context).size.height * 0.4,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: files.length + 1,
                itemBuilder: (ctx, index) {
                  //首项为从系统文件选择外部备份的入口
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: FluidCard(
                        enableShimmer: false,
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (context.mounted) {
                            _pickExternalBackup(context);
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_open,
                              color: FluidTheme.primaryFluidGradient[0],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.tr.pickExternalBackup,
                                style: FluidTheme.labelLarge(
                                  isDark,
                                ).copyWith(color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final file = files[index - 1];
                  final fileName = p.basename(file.path);
                  final fileSize = sizeByPath[file.path] ?? 0;
                  final sizeStr = _formatFileSize(fileSize);

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
            await _performRestore(context, backupFile);
          } finally {
            //恢复流程结束，清理选择器生成的临时副本
            await backupFile.cleanup();
          }
        },
      ),
    ],
  );
}

/// 执行恢复：加密备份会依次索要口令，口令错误允许重试（不重走整个流程）。
Future<void> _performRestore(BuildContext context, AppFile backupFile) async {
  String? password;
  while (true) {
    try {
      final counts = await BackupService.restoreData(
        backupFile.path,
        password: password,
      );
      // 恢复了整库数据：内存里的词库列表/计数/薄弱词/周报缓存全部失效，
      // 必须重新载入，否则首页仍显示"恢复前"的数据
      if (context.mounted) {
        await _refreshAfterDataSwap(context);
      }
      //通知首页和计划页刷新数据
      AppInitializationService.notifyDatabaseRefreshed();
      if (context.mounted) {
        ErrorHandler.showSuccess(
          context,
          context.tr.restoreSuccessWithCounts(
            wordBooks: counts['wordBooks'] ?? 0,
            words: counts['words'] ?? 0,
            records: counts['records'] ?? 0,
            studyPlans: counts['studyPlans'] ?? 0,
          ),
        );
      }
      return;
    } on BackupPasswordRequiredException {
      // 加密备份但未提供口令：弹框索要后重试
      if (!context.mounted) return;
      final pwd = await _askBackupPassword(context, forRestore: true);
      if (pwd == null || pwd.isEmpty) return;
      password = pwd;
    } on BackupPasswordException {
      // 口令错误/文件被篡改：明确提示后允许再输一次
      if (!context.mounted) return;
      ErrorHandler.handleException(
        context,
        const BackupPasswordException(),
        fallbackMessage: context.tr.backupPasswordWrong,
      );
      final pwd = await _askBackupPassword(context, forRestore: true);
      if (pwd == null || pwd.isEmpty) return;
      password = pwd;
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.restoreFailed,
        );
      }
      return;
    }
  }
}

/// 从系统文件选择外部备份（Android SAF等场景由PickedFileHelper复制到可读临时路径）
Future<void> _pickExternalBackup(BuildContext context) async {
  try {
    final file = await PickedFileHelper.pickSingleFile(
      extensions: ['json'],
      dialogTitle: context.tr.pickExternalBackup,
    );
    if (file != null && context.mounted) {
      _restoreFromExternalFile(context, file);
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

/// 恢复外部备份文件，走统一的确认恢复流程
void _restoreFromExternalFile(BuildContext context, AppFile file) {
  _confirmRestore(context, file);
}

/// 并发读取一组文件的大小（避免在构建期做同步磁盘 IO）
Future<Map<String, int>> _loadFileSizes(List<AppFile> files) async {
  if (files.isEmpty) return const {};
  final sizes = await Future.wait(files.map((file) => file.length()));
  return {for (var i = 0; i < files.length; i++) files[i].path: sizes[i]};
}

String _formatFileSize(int fileSize) => fileSize < 1024
    ? '$fileSize B'
    : fileSize < 1024 * 1024
    ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
    : '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';

/// 显示删除备份文件选择器（删除成功后即时从列表移除）
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
    //预取文件大小，避免在 itemBuilder 里做同步磁盘 IO
    final sizeByPath = await _loadFileSizes(files);
    if (!context.mounted) return;

    await showFluidDialog<void>(
      context: context,
      title: context.tr.deleteBackup,
      scrollable: false,
      content: StatefulBuilder(
        builder: (ctx, setPickerState) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: files.length,
            itemBuilder: (ctx, index) {
              final file = files[index];
              final fileName = p.basename(file.path);
              final sizeStr = _formatFileSize(sizeByPath[file.path] ?? 0);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: FluidCard(
                  enableShimmer: false,
                  padding: const EdgeInsets.all(12),
                  onTap: () =>
                      _confirmDeleteBackup(ctx, file, files, setPickerState),
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
      ),
    );
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

/// 确认删除备份文件，成功后从选择器列表即时移除
void _confirmDeleteBackup(
  BuildContext sheetContext,
  AppFile backupFile,
  List<AppFile> files,
  void Function(VoidCallback) setPickerState,
) {
  final isDark = sheetContext.read<ThemeProvider>().isDarkMode;
  final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

  showFluidDialog(
    context: sheetContext,
    content: Text(
      sheetContext.tr.confirmDeleteBackup,
      style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
    ),
    title: sheetContext.tr.deleteBackup,
    actions: [
      FluidTextButton(
        text: sheetContext.tr.cancel,
        onPressed: () => Navigator.pop(sheetContext),
      ),
      FluidButton(
        text: sheetContext.tr.deleteBackup,
        onPressed: () async {
          Navigator.pop(sheetContext);
          try {
            await BackupService.deleteBackupFile(backupFile.path);
            // 即时从当前选择器移除，全部删完自动关闭
            setPickerState(() {
              files.removeWhere((f) => f.path == backupFile.path);
            });
            if (files.isEmpty && sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          } catch (e) {
            if (sheetContext.mounted) {
              ErrorHandler.handleException(
                sheetContext,
                e,
                fallbackMessage: sheetContext.tr.deleteBackupFailed,
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
              borderSide: BorderSide(color: FluidTheme.primaryFluidGradient[0]),
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
              borderSide: BorderSide(color: FluidTheme.primaryFluidGradient[0]),
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
          //先把输入取出来，避免对话框关闭后才读取
          final bookName = nameController.text.trim();
          if (bookName.isEmpty) return;
          final bookDesc = descController.text.trim();
          Navigator.pop(context);
          try {
            await WordImportService.importWordsFromFile(
              file.path,
              bookName,
              description: bookDesc,
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
          } finally {
            //导入结束，清理选择器生成的临时副本
            await file.cleanup();
          }
        },
      ),
    ],
  ).whenComplete(() {
    //对话框关闭后释放输入控制器
    nameController.dispose();
    descController.dispose();
  });
}

void _showClearConfirm(BuildContext context) {
  final isDark = context.read<ThemeProvider>().isDarkMode;
  final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

  //「初始化」动作：按钮与回车共用。actions.last 是「取消」，不同文件里
  //既有约定又是"最后一个动作为肯定操作"，若交给默认回车就等于取消，
  //故显式传 onConfirm 指向本动作，同时保持按钮竖排顺序不变
  Future<void> initialize() async {
    Navigator.pop(context);
    try {
      //成功后直接进引导页，不依赖可能被覆盖的成功弹窗
      await _initializeApplication(context);
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.initializeFailed,
        );
      }
    }
  }

  showFluidDialog(
    context: context,
    content: Text(
      context.tr.confirmInitializeHint,
      style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
    ),
    title: context.tr.initializeApp,
    onConfirm: initialize,
    actions: [
      //三个按钮竖排整行：原来横排 Wrap 在窄屏会把「初始化」挤到第二行、
      //与「取消」文字挤在一起，观感凌乱。竖排等宽后主次分明、不再错位。
      FluidButton(
        text: context.tr.t('备份后初始化', 'Backup & Init'),
        expanded: true,
        onPressed: () async {
          Navigator.pop(context);
          await _backupBeforeInit(context);
        },
      ),
      FluidButton(
        text: context.tr.initialize,
        expanded: true,
        onPressed: initialize,
        colors: FluidTheme.errorFluidGradient,
      ),
      FluidTextButton(
        text: context.tr.cancel,
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}

Future<void> _backupBeforeInit(BuildContext context) async {
  try {
    if (PlatformAdapt.isMobile) {
      await BackupService.backupAndShare();
    } else {
      await BackupService.backupData();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.t('备份完成', 'Backup Complete')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.t('备份失败', 'Backup Failed'),
      );
    }
    // 备份没成功就绝不继续初始化：初始化会不可逆地清空全部数据，
    // 用户此时以为"反正有备份"，实际上既没备份也没数据。
    // 此前这里会继续往下执行，是最危险的一条路径。
    return;
  }
  //备份成功后才执行初始化
  if (context.mounted) {
    await _initializeApplication(context);
  }
}

/// 「初始化应用」是否正在执行。
///
/// 清库 + 清偏好不是瞬时操作（大库可能数秒），此前没有任何重入保护：
/// 用户在无进度反馈的界面里可以再点一次，两轮 clear + prefs.clear 并发执行，
/// 第二轮可能在 Provider 读取偏好的中途再把键清掉，读到的设置随机会不对。
bool _isInitializingApplication = false;

/// 数据被整体替换（初始化应用 / 恢复备份）后，刷新所有内存缓存与 Provider。
///
/// 数据库内容被换掉、而 Provider 与仓储还持有旧值时，界面会长时间显示
/// "恢复前"的词库与计数，用户会判定成"恢复没生效"，然后在旧数据上继续学习。
Future<void> _refreshAfterDataSwap(BuildContext context) async {
  DIContainer.instance.wordBookRepository.invalidateCache();
  DIContainer.instance.reviewRepository.invalidateAllCountCache();
  DIContainer.instance.weakVocabularyService.invalidate();
  DIContainer.instance.weeklyReportRepository.invalidate();
  if (!context.mounted) return;
  //先取出 Provider 再 await，避免在 async gap 之后继续碰 context
  final wordBooks = context.read<WordBookProvider>();
  final theme = context.read<ThemeProvider>();
  final studySettings = context.read<StudySettingsProvider>();
  final readerSettings = context.read<ReaderSettingsProvider>();
  final collectionSettings = context.read<WordCollectionSettingsProvider>();
  try {
    await wordBooks.init();
    //备份现在包含设置（SharedPreferences 已整库替换）：四个设置 Provider
    //都要重载，否则界面还显示恢复前的设置
    await theme.loadPreferences();
    await studySettings.loadPreferences();
    await readerSettings.loadPreferences();
    await collectionSettings.loadPreferences();
  } catch (e) {
    debugPrint('数据替换后刷新 Provider 失败：$e');
  }
}

Future<void> _initializeApplication(BuildContext context) async {
  if (_isInitializingApplication) return; // 重入守卫
  _isInitializingApplication = true;
  // 模态进度遮罩：清库期间界面必须有反馈，同时挡住二次点击。
  // barrierDismissible 只挡点击遮罩，系统返回键仍能关掉它，故再包一层
  // PopScope(canPop: false) 拦下返回键，避免无进度反馈地"闪退"
  unawaited(
    showFluidDialog<void>(
      context: context,
      barrierDismissible: false,
      content: PopScope(
        canPop: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Text(context.tr.t('正在初始化…', 'Initializing…')),
          ],
        ),
      ),
    ),
  );
  final themeProvider = context.read<ThemeProvider>();
  final studySettingsProvider = context.read<StudySettingsProvider>();
  try {
    await DatabaseService.clearAllData();
    // 不再自动导入内置词库，让用户自行选择导入。
    // 「初始化应用」= 回到全新状态：5 页新手引导结束后，回到首页时功能
    // 巡览（各页顶栏 coach mark）应自动重播，所以教学提示的「已看过」
    // 标记必须清空。resetAll 显式执行且必须在清空偏好**之前**——
    // 放在清空之后会因标记已被整体 wipe 而变成 no-op（语义歧义）。
    await GuideService.resetAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('hasSeenOnboarding', false);
    // 全部偏好都要重新载入：此前只重载了主题与学习设置，阅读设置 /
    // 词集设置仍留在内存里 —— 用户当场看到"重置没生效"，重启后设置却突然
    // 变成默认值（磁盘已被清空），表现为"设置自己变了"。
    await themeProvider.loadPreferences();
    await studySettingsProvider.loadPreferences();
    if (context.mounted) {
      // 统一走"数据替换后刷新"：词库 Provider（含通知开关/正序乱序设置）、
      // 阅读设置、词集设置都会从（已被清空的）磁盘重新载入
      await _refreshAfterDataSwap(context);
    }
  } finally {
    _isInitializingApplication = false;
    if (context.mounted) {
      //只关闭遮罩这类 DialogRoute：原来无条件 rootNavigator.pop() 会在
      //遮罩已不在此栈顶时误弹栈顶的设置页路由
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route is! DialogRoute);
      //保留原有语义：初始化完成后把设置页整条路由出栈，回到首页
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
  //通知首页和计划页刷新数据，再进入引导流程
  AppInitializationService.notifyDatabaseRefreshed();
  AppInitializationService.showOnboardingAfterInitialization();
}

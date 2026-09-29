import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/providers/word_collection_settings_provider.dart';
import '../utils/translations.dart';
import 'fluid_dialog.dart';
import 'fluid_settings.dart';

/// 打开「错题集」设置面板
Future<void> showWrongWordsSettings(BuildContext context) =>
    showFluidDialog<void>(
      context: context,
      title: context.tr.collectionSettings,
      maxWidth: 360,
      content: const WrongWordsSettingsPanel(),
    );

/// 打开「收藏夹」设置面板
Future<void> showFavoritesSettings(BuildContext context) =>
    showFluidDialog<void>(
      context: context,
      title: context.tr.collectionSettings,
      maxWidth: 360,
      content: const FavoritesSettingsPanel(),
    );

/// 错题集设置：首页数量徽标 + 攻克进度
///
/// 入口挂在错题集页右上角（参考阅读模式：设置跟着功能走，
/// 不往全局设置页里塞）。
class WrongWordsSettingsPanel extends StatelessWidget {
  const WrongWordsSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<WordCollectionSettingsProvider>();
    return FluidSettingsSection(
      title: context.tr.wrongWordCollection,
      children: [
        fluidSettingsSwitchRow(
          context: context,
          label: context.tr.showCountOnHome,
          hint: context.tr.showCountOnHomeHint,
          value: settings.showWrongWordsBadge,
          onChanged: (value) => context
              .read<WordCollectionSettingsProvider>()
              .setShowWrongWordsBadge(value),
        ),
        fluidSettingsSwitchRow(
          context: context,
          label: context.tr.t('显示答错次数', 'Show wrong count'),
          hint: context.tr.t(
            '在单词卡片上显示"×N"答错次数徽标',
            'Show a "×N" wrong-count badge on word cards',
          ),
          value: settings.showWrongCount,
          onChanged: (value) => context
              .read<WordCollectionSettingsProvider>()
              .setShowWrongCount(value),
        ),
        fluidSettingsSwitchRow(
          context: context,
          label: context.tr.showMasteryProgress,
          hint: context.tr.showMasteryProgressHint,
          value: settings.showMasteryProgress,
          onChanged: (value) => context
              .read<WordCollectionSettingsProvider>()
              .setShowMasteryProgress(value),
        ),
        fluidSettingsSwitchRow(
          context: context,
          label: context.tr.t('显示错因', 'Show wrong cause'),
          hint: context.tr.t(
            '在单词卡片上显示"错因 · xx"标签（老数据可能没有错因记录）',
            'Show a "Cause · xx" tag on word cards (older records may lack cause data)',
          ),
          value: settings.showWrongCause,
          onChanged: (value) => context
              .read<WordCollectionSettingsProvider>()
              .setShowWrongCause(value),
        ),
      ],
    );
  }
}

/// 收藏夹设置：首页数量徽标
class FavoritesSettingsPanel extends StatelessWidget {
  const FavoritesSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<WordCollectionSettingsProvider>();
    return FluidSettingsSection(
      title: context.tr.favorites,
      children: [
        fluidSettingsSwitchRow(
          context: context,
          label: context.tr.showCountOnHome,
          hint: context.tr.showCountOnHomeHint,
          value: settings.showFavoritesBadge,
          onChanged: (value) => context
              .read<WordCollectionSettingsProvider>()
              .setShowFavoritesBadge(value),
        ),
      ],
    );
  }
}

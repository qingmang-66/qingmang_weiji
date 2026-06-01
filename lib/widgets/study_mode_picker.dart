import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/constants.dart';

/// 统一学习模式选择器
///
/// 被收藏夹、错词专项、自定义词集等专项学习入口复用，避免各页面重复维护模式选择 UI。
Future<int?> showStudyModePicker(BuildContext context) {
  final isDark = context.read<ThemeProvider>().isDarkMode;
  final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FluidTheme.getDialogSurfaceColor(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: FluidTheme.getBorderColor(isDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '选择学习模式',
            style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
          ),
          const SizedBox(height: 12),
          _modeTile(
            ctx,
            Icons.psychology,
            AppConstants.studyModeRecall,
            '回忆模式',
          ),
          _modeTile(ctx, Icons.edit, AppConstants.studyModeSpell, '拼写模式'),
          _modeTile(
            ctx,
            Icons.headphones,
            AppConstants.studyModeListen,
            '听力模式',
          ),
          _modeTile(ctx, Icons.quiz, AppConstants.studyModeQuiz, '测验模式'),
        ],
      ),
    ),
  );
}

Widget _modeTile(BuildContext context, IconData icon, int mode, String label) {
  return ListTile(
    leading: Icon(icon, color: FluidTheme.primaryFluidGradient[0]),
    title: Text(label),
    onTap: () => Navigator.pop(context, mode),
  );
}

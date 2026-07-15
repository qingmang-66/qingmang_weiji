import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';
import 'fluid_dialog.dart';

/// 统一学习模式选择器
///
/// 被收藏夹、错词专项、自定义词集等专项学习入口复用，避免各页面重复维护模式选择 UI。
Future<int?> showStudyModePicker(BuildContext context) {
  final tr = context.tr;
  return showFluidDialog<int>(
    context: context,
    title: tr.selectStudyMode,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeTile(
          context,
          Icons.psychology,
          AppConstants.studyModeRecall,
          tr.recallMode,
        ),
        _modeTile(
          context,
          Icons.edit,
          AppConstants.studyModeSpell,
          tr.spellingMode,
        ),
        _modeTile(
          context,
          Icons.headphones,
          AppConstants.studyModeListen,
          tr.listeningMode,
        ),
        _modeTile(
          context,
          Icons.quiz,
          AppConstants.studyModeQuiz,
          tr.quizModeEnToCn,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr.cancel),
      ),
    ],
  );
}

Widget _modeTile(BuildContext context, IconData icon, int mode, String label) {
  final isDark = context.read<ThemeProvider>().isDarkMode;
  return ListTile(
    leading: Icon(icon, color: FluidTheme.primaryFluidGradient[0]),
    title: Text(
      label,
      style: TextStyle(color: FluidTheme.getTextPrimaryColor(isDark)),
    ),
    onTap: () => Navigator.pop(context, mode),
  );
}

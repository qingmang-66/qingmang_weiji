import 'package:flutter/material.dart';
import '../theme/fluid_theme.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';
import 'fluid_button.dart';
import 'fluid_dialog.dart';
import 'liquid_glass.dart';

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
        _StudyModeContent(
          modes: [
            (Icons.psychology, AppConstants.studyModeRecall, tr.recallMode),
            (Icons.edit, AppConstants.studyModeSpell, tr.spellingMode),
            (Icons.headphones, AppConstants.studyModeListen, tr.listeningMode),
            (Icons.quiz, AppConstants.studyModeQuiz, tr.quizModeEnToCn),
          ],
        ),
        const SizedBox(height: 4),
        // 取消按钮放在内容里而不是 actions：框架的"回车=触发最后一个
        // action"会让回车误关闭弹窗。本弹窗点选即返回，回车应当无动作。
        Align(
          alignment: Alignment.centerRight,
          child: FluidTextButton(
            text: tr.cancel,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    ),
  );
}

class _StudyModeContent extends StatefulWidget {
  final List<(IconData, int, String)> modes;

  const _StudyModeContent({required this.modes});

  @override
  State<_StudyModeContent> createState() => _StudyModeContentState();
}

class _StudyModeContentState extends State<_StudyModeContent> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = FluidTheme.primaryFluidGradient[0];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.modes.length; i++)
          _modeTile(
            context,
            widget.modes[i],
            isDark,
            selected: _selected == i,
            accent: accent,
            onTap: () {
              setState(() => _selected = i);
              Navigator.pop(context, widget.modes[i].$2);
            },
          ),
      ],
    );
  }

  //玻璃选项卡：16 圆角玻璃片 + hover 视差，选中态加 accent 描边
  Widget _modeTile(
    BuildContext context,
    (IconData, int, String) mode,
    bool isDark, {
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.55), width: 1.5)
            : null,
      ),
      child: GlassSurface(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Icon(mode.$1, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mode.$3,
                  style: TextStyle(
                    color: FluidTheme.getTextPrimaryColor(isDark),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: FluidTheme.getTextSecondaryColor(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

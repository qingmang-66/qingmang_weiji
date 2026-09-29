import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../widgets/fluid_background.dart';
import '../widgets/settings_sections.dart';

/// 关于页（二级页面）
///
/// 移动端屏幕空间有限，关于信息（版本 / 开发者 / 开源协议 / GitHub）
/// 不再全部铺在设置一级页上，收缩成设置页里的一个入口，点进来再看。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FluidBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimary),
                      tooltip: context.tr.back,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        context.tr.about,
                        style: FluidTheme.headingSmall(
                          isDark,
                        ).copyWith(color: textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: AboutDetailSection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

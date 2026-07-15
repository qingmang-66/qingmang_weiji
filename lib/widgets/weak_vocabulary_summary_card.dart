import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weakness_overview.dart';
import '../screens/weak_vocabulary_screen.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/page_transitions.dart';
import '../utils/translations.dart';
import 'fluid_card.dart';

class WeakVocabularySummaryCard extends StatelessWidget {
  const WeakVocabularySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeaknessOverview>(
      future: DIContainer.instance.weakVocabularyRepository.loadOverview(),
      builder: (context, snapshot) {
        final overview = snapshot.data;
        if (overview == null || overview.totalCount == 0) {
          return const SizedBox.shrink();
        }
        final isDark = context.watch<ThemeProvider>().isDarkMode;
        return FluidCard(
          enableShimmer: overview.criticalCount > 0,
          enableBorderGradient: true,
          borderColors: overview.criticalCount > 0
              ? FluidTheme.errorFluidGradient
              : FluidTheme.warningFluidGradient,
          padding: const EdgeInsets.all(16),
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.slideFromRight(
                page: const WeakVocabularyScreen(),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FluidTheme.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_alt,
                  color: FluidTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.weakVocabulary,
                      style: FluidTheme.labelLarge(
                        isDark,
                      ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr.criticalWeak} ${overview.criticalCount} · ${context.tr.weakLevelWeak} ${overview.weakCount}',
                      style: FluidTheme.bodyMedium(isDark).copyWith(
                        color: FluidTheme.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: FluidTheme.getTextTertiaryColor(isDark),
              ),
            ],
          ),
        );
      },
    );
  }
}

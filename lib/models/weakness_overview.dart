import 'weak_word_entry.dart';
import 'weakness_level.dart';

class WeaknessOverview {
  final List<WeakWordEntry> entries;
  final int totalCount;
  final int shakyCount;
  final int weakCount;
  final int criticalCount;
  final double averageScore;
  final DateTime generatedAt;

  const WeaknessOverview({
    required this.entries,
    required this.totalCount,
    required this.shakyCount,
    required this.weakCount,
    required this.criticalCount,
    required this.averageScore,
    required this.generatedAt,
  });

  factory WeaknessOverview.fromEntries(List<WeakWordEntry> entries) {
    final total = entries.length;
    final average = total == 0
        ? 0.0
        : entries.fold<double>(0, (sum, entry) => sum + entry.score) / total;
    return WeaknessOverview(
      entries: entries,
      totalCount: total,
      shakyCount: entries
          .where((entry) => entry.level == WeaknessLevel.shaky)
          .length,
      weakCount: entries
          .where((entry) => entry.level == WeaknessLevel.weak)
          .length,
      criticalCount: entries
          .where((entry) => entry.level == WeaknessLevel.critical)
          .length,
      averageScore: average,
      generatedAt: DateTime.now(),
    );
  }

  factory WeaknessOverview.empty() => WeaknessOverview.fromEntries(const []);

  List<WeakWordEntry> get urgentEntries => entries
      .where((entry) => entry.level.priority >= WeaknessLevel.weak.priority)
      .toList(growable: false);
}

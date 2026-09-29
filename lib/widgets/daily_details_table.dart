import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_study_detail.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';

/// 逐日学习明细表
///
/// 每天一行：日期 | 学 | 练 | 记住 | 填错 | 正确率，
/// 可选汇总行，超过 [maxRows] 行时内部滚动。
class DailyDetailsTable extends StatelessWidget {
  final List<DailyStudyDetail> details;
  final bool showSummary;
  final int? maxRows;

  const DailyDetailsTable({
    super.key,
    required this.details,
    this.showSummary = true,
    this.maxRows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);
    final tr = context.tr;

    if (details.isEmpty) {
      return Text(
        tr.noStudyDataIn(''),
        style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
      );
    }

    Widget table = Column(
      children: [
        //表头
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  tr.dailyColDate,
                  style: _headerStyle(isDark, textSecondary),
                ),
              ),
              Expanded(
                child: _headerText(tr.dailyColNew, isDark, textSecondary),
              ),
              Expanded(
                child: _headerText(tr.dailyColPracticed, isDark, textSecondary),
              ),
              Expanded(
                child: _headerText(
                  tr.dailyColRemembered,
                  isDark,
                  textSecondary,
                ),
              ),
              Expanded(
                child: _headerText(tr.dailyColWrong, isDark, textSecondary),
              ),
              Expanded(
                child: _headerText(
                  tr.dailyColAccuracy,
                  isDark,
                  textSecondary,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        //数据行
        for (int i = 0; i < details.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: i == details.length - 1
                      ? Colors.transparent
                      : borderColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    _dateText(details[i]),
                    style: FluidTheme.bodySmall(isDark).copyWith(
                      color: details[i].hasActivity
                          ? textPrimary
                          : textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: _valueText(
                    '${details[i].newWords}',
                    isDark,
                    textPrimary: textPrimary,
                    dim: details[i].newWords == 0,
                  ),
                ),
                Expanded(
                  child: _valueText(
                    '${details[i].practicedWords}',
                    isDark,
                    textPrimary: textPrimary,
                    dim: details[i].practicedWords == 0,
                  ),
                ),
                Expanded(
                  child: _valueText(
                    '${details[i].rememberedWords}',
                    isDark,
                    textPrimary: textPrimary,
                    color: details[i].rememberedWords > 0
                        ? FluidTheme.success
                        : null,
                    dim: details[i].rememberedWords == 0,
                  ),
                ),
                Expanded(
                  child: _valueText(
                    '${details[i].wrongWords}',
                    isDark,
                    textPrimary: textPrimary,
                    color: details[i].wrongWords > 0 ? FluidTheme.error : null,
                    dim: details[i].wrongWords == 0,
                  ),
                ),
                Expanded(
                  child: _valueText(
                    details[i].attempts > 0 ? details[i].correctRateText : '-',
                    isDark,
                    textPrimary: textPrimary,
                    color: _rateColor(details[i].correctRate),
                    dim: details[i].attempts == 0,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        //汇总行
        if (showSummary)
          _buildSummaryRow(context, isDark, textPrimary, borderColor),
      ],
    );

    //超出最大行数时内部滚动（行高按 36 估算）
    if (maxRows != null && details.length > maxRows!) {
      table = SizedBox(
        height: (maxRows! + 2) * 36.0,
        child: SingleChildScrollView(child: table),
      );
    }
    return table;
  }

  TextStyle _headerStyle(bool isDark, Color color) {
    return FluidTheme.bodySmall(
      isDark,
    ).copyWith(color: color, fontWeight: FontWeight.w600);
  }

  Widget _headerText(
    String text,
    bool isDark,
    Color color, {
    TextAlign textAlign = TextAlign.center,
  }) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _headerStyle(isDark, color),
    );
  }

  Widget _valueText(
    String text,
    bool isDark, {
    required Color textPrimary,
    Color? color,
    bool dim = false,
    TextAlign textAlign = TextAlign.center,
  }) {
    return Text(
      text,
      textAlign: textAlign,
      style: FluidTheme.bodySmall(isDark).copyWith(
        //dim 原为 0.45，在玻璃上仅约 2.6:1；提到 0.72 后约 6.5:1
        color:
            color ?? (dim ? textPrimary.withValues(alpha: 0.72) : textPrimary),
        fontWeight: color != null ? FontWeight.w600 : null,
      ),
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 0.8) return FluidTheme.success;
    if (rate >= 0.6) return FluidTheme.warning;
    return FluidTheme.error;
  }

  String _dateText(DailyStudyDetail d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (d.date == today) return '${d.shortDateText} · 今';
    return d.shortDateText;
  }

  Widget _buildSummaryRow(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color borderColor,
  ) {
    final tr = context.tr;
    final newWords = details.fold(0, (s, d) => s + d.newWords);
    final practiced = details.fold(0, (s, d) => s + d.practicedWords);
    final remembered = details.fold(0, (s, d) => s + d.rememberedWords);
    final wrong = details.fold(0, (s, d) => s + d.wrongWords);
    final attempts = details.fold(0, (s, d) => s + d.attempts);
    final wrongCount = details.fold(0, (s, d) => s + d.wrongCount);
    final rateText = attempts > 0
        ? '${((attempts - wrongCount) / attempts * 100).round()}%'
        : '-';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: FluidTheme.primaryFluidGradient[0].withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              tr.dailySummaryRow,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              '$newWords',
              textAlign: TextAlign.center,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              '$practiced',
              textAlign: TextAlign.center,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              '$remembered',
              textAlign: TextAlign.center,
              style: FluidTheme.bodySmall(isDark).copyWith(
                color: FluidTheme.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$wrong',
              textAlign: TextAlign.center,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: FluidTheme.error, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              rateText,
              textAlign: TextAlign.right,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

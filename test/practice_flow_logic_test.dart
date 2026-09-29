import 'dart:io';

import 'package:test/test.dart';

/// 读取学习流程入口库的完整源码（含拆分的 part 文件），供静态行为断言使用
String _preStudySource() {
  final buf = StringBuffer();
  for (final p in [
    'lib/screens/pre_study_screen.dart',
    'lib/screens/pre_study_screen/direct_study_screen.dart',
    'lib/screens/pre_study_screen/quiz_widgets.dart',
    'lib/screens/pre_study_screen/study_mode_chip.dart',
  ]) {
    buf.writeln(File(p).readAsStringSync());
  }
  return buf.toString();
}

void main() {
  group('DirectStudyScreen 完成流程', () {
    test('最后一题点击完成应进入学习总结页并展示会话质量', () {
      final source = _preStudySource();

      expect(source, contains('Navigator.pushReplacement('));
      expect(source, contains('page: _StudySummaryScreen('));
      expect(source, contains('sessionSummary: sessionSummary'));
    });

    test('总结页返回首页应退出整个学习流程并触发首页刷新', () {
      final source = _preStudySource();

      final returnHomeCount = 'Navigator.of(context).popUntil('
          .allMatches(source)
          .length;
      expect(returnHomeCount, greaterThanOrEqualTo(2));
      expect(source, contains('route.isFirst'));
    });

    test('完成学习时应只清理本轮进度（不能全表清掉其它来源）', () {
      final source = _preStudySource();

      expect(
        source,
        contains('studyProgressRepository.clearStudyProgress(progressKey:'),
      );
      // study_progress 按 progress_key 多来源并存：无参调用 = 全表删除，
      // 会把别的词库/专项学习的"继续学习"一起清掉
      expect(source, isNot(contains('clearStudyProgress()')));
    });

    test('继续学习和专项复习入口应保留智能模式开关状态', () {
      final source = _preStudySource();

      expect(source, contains('enableSmartMode: _enableSmartMode'));
      expect(source, contains('enableSmartMode: widget.enableSmartMode'));
    });

    test('总结页应保留本轮原始错词用于展示和再次复习', () {
      final source = _preStudySource();

      expect(source, contains('_sessionWrongWords'));
      expect(source, contains('wrongWords: _sessionWrongWords'));
    });

    test('普通学习中的低质量结果应写入错词本', () {
      final source = _preStudySource();

      expect(source, contains('_addCurrentWordToWrongWords'));
      expect(source, contains('wrongWordService.addWrongWord'));
      expect(
        source,
        contains('widget.specializedRequest?.source != StudySource.wrongWords'),
      );
    });

    test('智能模式跳过词不应计入计划完成数', () {
      final source = _preStudySource();

      expect(source, contains('_completedOriginalWords'));
      expect(
        source,
        isNot(contains('newWords: widget.isReview ? 0 : _totalOriginalWords')),
      );
      expect(
        source,
        isNot(
          contains('reviewWords: widget.isReview ? _totalOriginalWords : 0'),
        ),
      );
    });

    test('拼写和听写同一题重复检查不应重复计错', () {
      final source = _preStudySource();

      expect(source, contains('_hasRecordedTypedWrongAttempt'));
      expect(source, contains('if (!_hasRecordedTypedWrongAttempt)'));
    });
  });
}

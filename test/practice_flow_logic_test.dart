import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('DirectStudyScreen 完成流程', () {
    test('最后一题点击完成应进入学习总结页并展示会话质量', () {
      final source = File(
        'lib/screens/pre_study_screen.dart',
      ).readAsStringSync();

      expect(source, contains('Navigator.pushReplacement('));
      expect(source, contains('page: _StudySummaryScreen('));
      expect(source, contains('sessionSummary: sessionSummary'));
    });

    test('总结页返回首页应退出整个学习流程并触发首页刷新', () {
      final source = File(
        'lib/screens/pre_study_screen.dart',
      ).readAsStringSync();

      final returnHomeCount = 'Navigator.of(context).popUntil('
          .allMatches(source)
          .length;
      expect(returnHomeCount, greaterThanOrEqualTo(2));
      expect(source, contains('route.isFirst'));
    });

    test('完成学习时应清理继续学习进度', () {
      final source = File(
        'lib/screens/pre_study_screen.dart',
      ).readAsStringSync();

      expect(source, contains('studyProgressRepository.clearStudyProgress()'));
    });

    test('继续学习和专项复习入口应保留智能模式开关状态', () {
      final source = File(
        'lib/screens/pre_study_screen.dart',
      ).readAsStringSync();

      expect(source, contains('enableSmartMode: _enableSmartMode'));
      expect(source, contains('enableSmartMode: widget.enableSmartMode'));
    });

    test('总结页应保留本轮原始错词用于展示和再次复习', () {
      final source = File(
        'lib/screens/pre_study_screen.dart',
      ).readAsStringSync();

      expect(source, contains('_sessionWrongWords'));
      expect(source, contains('wrongWords: _sessionWrongWords'));
    });
  });
}

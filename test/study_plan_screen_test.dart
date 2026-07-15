import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/models/models.dart';
import 'package:qingmang_weiji/screens/study_plan_screen.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';
import 'package:qingmang_weiji/services/study_plan_service.dart';

class FakeStudyPlanService implements StudyPlanService {
  int callCount = 0;

  @override
  Future<StudyPlan> createPlan({
    required String name,
    required List<int> wordBookIds,
    required StudyPlanType type,
    DateTime? targetDate,
    int? dailyNewTarget,
  }) async {
    callCount++;
    return StudyPlan(
      name: name,
      wordBookIds: wordBookIds,
      type: type,
      targetDate: targetDate,
      dailyNewTarget: dailyNewTarget ?? 1,
      totalWords: 1,
      status: StudyPlanStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget buildPlanSheet(FakeStudyPlanService service) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: Scaffold(
        body: CreatePlanSheet(
          key: ValueKey(service),
          wordBooks: [WordBook(id: 7, name: 'CET-4')],
          service: service,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('无效字段显示内联错误且不调用服务', (tester) async {
    final service = FakeStudyPlanService();
    await tester.pumpWidget(buildPlanSheet(service));

    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.tap(find.text('确定'));
    await tester.pump();

    expect(find.text('请输入计划名称'), findsOneWidget);
    expect(find.text('请至少选择一个词库'), findsOneWidget);
    expect(find.text('每日新词目标必须是正整数'), findsOneWidget);
    expect(service.callCount, 0);
    expect(find.byType(CreatePlanSheet), findsOneWidget);
    expect(find.widgetWithText(TextField, '0'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '四级计划');
    await tester.pump();
    expect(find.text('请输入计划名称'), findsNothing);

    await tester.tap(find.text('CET-4'));
    await tester.pump();
    expect(find.text('请至少选择一个词库'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.pump();
    expect(find.text('每日新词目标必须是正整数'), findsNothing);
  });

  testWidgets('每日目标拒绝负数和非数字', (tester) async {
    final service = FakeStudyPlanService();
    await tester.pumpWidget(buildPlanSheet(service));

    for (final value in ['-1', 'abc']) {
      await tester.enterText(find.byType(TextField).at(1), value);
      await tester.tap(find.text('确定'));
      await tester.pump();
      expect(find.text('每日新词目标必须是正整数'), findsOneWidget);
      expect(service.callCount, 0);
    }
  });

  testWidgets('截止日期和考试目标必须选择日期且选择后清除错误', (tester) async {
    for (final type in ['按截止日期', '考试目标']) {
      final service = FakeStudyPlanService();
      await tester.pumpWidget(buildPlanSheet(service));
      await tester.enterText(find.byType(TextField).first, '四级计划');
      await tester.tap(find.text('CET-4'));
      await tester.tap(find.text(type));
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pump();

      expect(find.text('请选择目标日期'), findsOneWidget);
      expect(service.callCount, 0);
      expect(find.byType(CreatePlanSheet), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('请选择目标日期'), findsNothing);
    }
  });
}

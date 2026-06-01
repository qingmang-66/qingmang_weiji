import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/screens/pre_study_screen.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/widgets/fluid_card.dart';

void main() {
  Widget buildStudyModeChipHarness() {
    return ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: StudyModeChip(
              icon: Icons.edit_outlined,
              label: '拼写模式',
              isSelected: false,
              onTap: null,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('学习模式按钮整块区域首次点击就会触发切换', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudyModeChip(
                icon: Icons.edit_outlined,
                label: '拼写模式',
                isSelected: false,
                onTap: () => tapCount++,
              ),
            ),
          ),
        ),
      ),
    );

    final chipFinder = find.byType(StudyModeChip);
    final chipRect = tester.getRect(chipFinder);
    await tester.tapAt(Offset(chipRect.right - 4, chipRect.center.dy));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('学习模式按钮没有回调时不会报错', (tester) async {
    await tester.pumpWidget(buildStudyModeChipHarness());

    final chipFinder = find.byType(StudyModeChip);
    final chipRect = tester.getRect(chipFinder);
    await tester.tapAt(chipRect.center);
    await tester.pump();

    expect(find.text('拼写模式'), findsOneWidget);
  });

  testWidgets('带闪光效果的卡片不会拦截内部学习模式按钮点击', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluidCard(
                enableShimmer: false,
                child: StudyModeChip(
                  icon: Icons.headphones_outlined,
                  label: '听力模式',
                  isSelected: false,
                  onTap: () => tapCount++,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final chipFinder = find.text('听力模式');
    await tester.tap(chipFinder);
    await tester.pump();

    expect(tapCount, 1);
  });
}

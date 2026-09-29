import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/services/definition_service.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/widgets/dictionary_dialog.dart';

void main() {
  testWidgets(
    'DictionaryDialog renders preset word, phonetic, definition, and bilingual example',
    (tester) async {
      final preset = DictionaryQueryResult(
        word: 'abandon',
        phonetic: '/əˈbændən/',
        definition: 'v. 放弃；遗弃',
        example: 'He decided to abandon the project.',
        exampleTranslation: '他决定放弃这个项目。',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: DictionaryDialog(
                word: 'abandon',
                preset: preset,
                lookupFull: false,
              ),
            ),
          ),
        ),
      );

      //无需等待常驻动画，直接单帧泵出
      await tester.pump();

      //验证单词
      expect(find.text('abandon'), findsOneWidget);
      //验证音标
      expect(find.text('/əˈbændən/'), findsOneWidget);
      //验证释义
      expect(find.text('v. 放弃；遗弃'), findsOneWidget);
      //验证英文例句
      expect(find.text('He decided to abandon the project.'), findsOneWidget);
      //验证例句翻译
      expect(find.text('他决定放弃这个项目。'), findsOneWidget);
      //验证发音图标
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      //验证关闭按钮
      expect(find.text('关闭'), findsOneWidget);
    },
  );
}

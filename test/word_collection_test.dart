import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/models/study_source.dart';
import 'package:qingmang_weiji/services/providers/theme_provider.dart';
import 'package:qingmang_weiji/services/specialized_study_service.dart';
import 'package:qingmang_weiji/services/wrong_word_service.dart';
import 'package:qingmang_weiji/widgets/home_components.dart';

/// 首页「词集」段 + 收藏词专项复习的契约测试
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: Scaffold(body: child)),
  );

  group('词集入口卡片', () {
    testWidgets('数量为 0 也照常显示入口（旧实现会在 0 时整段消失）', (tester) async {
      await tester.pumpWidget(
        wrap(
          QuickAction(
            icon: Icons.error_outline,
            label: '错题集',
            color: Colors.red,
            count: 0,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('错题集'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('关闭徽标开关后只留图标与名称', (tester) async {
      await tester.pumpWidget(
        wrap(
          QuickAction(
            icon: Icons.star_border,
            label: '收藏夹',
            color: Colors.amber,
            count: 12,
            showCount: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('收藏夹'), findsOneWidget);
      expect(find.text('12'), findsNothing);
    });

    testWidgets('没有数量数据时不显示徽标', (tester) async {
      await tester.pumpWidget(
        wrap(
          QuickAction(
            icon: Icons.star_border,
            label: '收藏夹',
            color: Colors.amber,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('收藏夹'), findsOneWidget);
    });
  });

  group('收藏词专项复习请求', () {
    //buildFavoritesRequest 不触碰 wrongWordService，传单例即可
    final service = SpecializedStudyService(
      wrongWordService: WrongWordService(),
    );

    test('空词表返回 null', () async {
      final request = await service.buildFavoritesRequest(
        wordIds: const [],
        studyMode: 1,
      );
      expect(request, isNull);
    });

    test('全部收藏词：source 为 favorites、跨词库(wordBookId 为 null)', () async {
      final request = await service.buildFavoritesRequest(
        wordIds: const [3, 1, 2],
        studyMode: 2,
        title: '收藏词专项复习',
      );

      expect(request, isNotNull);
      expect(request!.source, StudySource.favorites);
      expect(request.wordBookId, isNull);
      expect(request.wordIds, [3, 1, 2]);
      expect(request.studyMode, 2);
      expect(request.isReview, isTrue);
      //没有显式 progressKey 时落到 favorites:global，供"继续上次学习"恢复
      expect(request.progressKey, 'favorites:global');
    });

    test('只复习选中部分时 progressKey 带具体 id，避免覆盖全部复习的进度', () async {
      final request = await service.buildFavoritesRequest(
        wordIds: const [7, 9],
        studyMode: 1,
        isSubset: true,
      );

      expect(request!.progressKey, 'favorites:selected:7-9');
    });

    test('StudySource.favorites 的持久化 key 稳定', () {
      expect(StudySource.favorites.key, 'favorites');
    });
  });
}

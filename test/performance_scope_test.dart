import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qingmang_weiji/screens/stats_screen.dart';
import 'package:qingmang_weiji/services/providers/providers.dart';

class TestWordBookProvider extends WordBookProvider {
  void emit() => notifyListeners();
}

class CountingThemeProvider extends ThemeProvider {
  int configReads = 0;

  @override
  ThemeMode get themeMode {
    configReads++;
    return super.themeMode;
  }

  @override
  bool get isEnglishLocale {
    configReads++;
    return super.isEnglishLocale;
  }
}

void main() {
  test('相同词库通知不重复加载，重复明确刷新合并在途请求', () async {
    final requests = <Completer<int>>[];
    final applied = <int>[];
    final loader = StatsLoadController<int>(
      load: (_) {
        final completer = Completer<int>();
        requests.add(completer);
        return completer.future;
      },
      apply: applied.add,
    );

    final initial = loader.updateBook(1);
    expect(requests, hasLength(1));
    //同 bookId 不新建请求，返回在途 future（完成前不要 await）
    final sameBook = loader.updateBook(1);
    expect(requests, hasLength(1));

    requests.single.complete(1);
    await Future.wait(<Future<void>>[initial, sameBook]);
    final refresh1 = loader.refresh();
    final refresh2 = loader.refresh();
    expect(requests, hasLength(2));

    requests.last.complete(2);
    await Future.wait(<Future<void>>[refresh1, refresh2]);
    expect(applied, [1, 2]);
  });

  test('词库变化启动新generation且旧结果不能覆盖', () async {
    final requests = <int?, Completer<int>>{};
    final applied = <int>[];
    final loader = StatsLoadController<int>(
      load: (bookId) => requests.putIfAbsent(bookId, Completer<int>.new).future,
      apply: applied.add,
    );

    final oldRequest = loader.updateBook(1);
    final newRequest = loader.updateBook(2);
    requests[2]!.complete(2);
    await newRequest;
    requests[1]!.complete(1);
    await oldRequest;

    expect(applied, [2]);
  });

  test('加载失败时错误向上传播且不产生未处理异常', () async {
    final loader = StatsLoadController<int>(
      load: (_) async => throw StateError('failed'),
      apply: (_) {},
    );
    //错误由调用方处理的future传播，不再有onError回调
    await expectLater(loader.updateBook(1), throwsStateError);
  });

  testWidgets('WordBookProvider普通通知不重新读取MaterialApp配置', (tester) async {
    final theme = CountingThemeProvider();
    final wordBooks = TestWordBookProvider();

    //镜像根级 Selector：仅主题/语言影响 MaterialApp 配置读取
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider<WordBookProvider>.value(value: wordBooks),
        ],
        child: Selector<ThemeProvider, ({ThemeMode mode, bool english})>(
          selector: (_, provider) =>
              (mode: provider.themeMode, english: provider.isEnglishLocale),
          builder: (context, config, _) => MaterialApp(
            themeMode: config.mode,
            locale: config.english ? const Locale('en') : const Locale('zh'),
            home: const SizedBox(),
          ),
        ),
      ),
    );
    final reads = theme.configReads;

    wordBooks.emit();
    await tester.pump();

    expect(theme.configReads, reads);
  });
}

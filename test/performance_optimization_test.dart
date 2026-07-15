import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/asset_wordbook_service.dart';
import 'package:qingmang_weiji/services/dictionary_api_service.dart';

void main() {
  test('弱项词汇页使用SliverList懒构建并缓存筛选排序结果', () async {
    final source = await File(
      'lib/screens/weak_vocabulary_screen.dart',
    ).readAsString();

    expect(source, contains('SliverList.builder'));
    expect(source, isNot(contains('..._visibleEntries(overview).map')));
    expect(source, contains('_cachedVisibleEntries'));
  });

  test('音频缓存超过上限时删除最后修改时间最早的文件', () async {
    final dir = await Directory.systemTemp.createTemp('audio_cache_limit_');
    addTearDown(() => dir.delete(recursive: true));
    final old = File('${dir.path}/old.mp3');
    final middle = File('${dir.path}/middle.mp3');
    final recent = File('${dir.path}/recent.mp3');
    await old.writeAsBytes([1]);
    await middle.writeAsBytes([2]);
    await recent.writeAsBytes([3]);
    final now = DateTime.now();
    await old.setLastModified(now.subtract(const Duration(minutes: 3)));
    await middle.setLastModified(now.subtract(const Duration(minutes: 2)));
    await recent.setLastModified(now.subtract(const Duration(minutes: 1)));

    await DictionaryApiService.pruneAudioCacheForTesting(dir, maxFiles: 2);

    expect(await old.exists(), isFalse);
    expect(await middle.exists(), isTrue);
    expect(await recent.exists(), isTrue);
  });

  test('完整词库缓存只保留最近使用的2本', () {
    AssetWordBookService.clearWordsCacheForTesting();
    addTearDown(AssetWordBookService.clearWordsCacheForTesting);

    AssetWordBookService.cacheWordsForTesting('a.json', const []);
    AssetWordBookService.cacheWordsForTesting('b.json', const []);
    AssetWordBookService.cacheWordsForTesting('c.json', const []);

    expect(
      AssetWordBookService.cachedBookNamesForTesting,
      orderedEquals(['b.json', 'c.json']),
    );
  });
}

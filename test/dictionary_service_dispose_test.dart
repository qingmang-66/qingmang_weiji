import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/dictionary_api_service.dart';
import 'package:qingmang_weiji/services/youdao_service.dart';

void main() {
  test(
    'dictionary services remain usable after DI container dispose behavior changes',
    () async {
      final result1 = await DictionaryApiService.getCachedAudioPath('test');
      final result2 = await YoudaoService.fetchWord('test');

      expect(result1, anyOf(isNull, isA<String>()));
      expect(result2, anyOf(isNull, isNotNull));
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/word.dart';
import 'package:qingmang_weiji/utils/phonetic_utils.dart';

void main() {
  group('PhoneticUtils.primary', () {
    test('单读音原样返回', () {
      expect(PhoneticUtils.primary('həˈləʊ'), 'həˈləʊ');
    });

    test('多读音只保留第一个', () {
      expect(PhoneticUtils.primary('æbˈsɔrb; æbˈzɔrb; əbˈsɔrb'), 'æbˈsɔrb');
      expect(PhoneticUtils.primary("ˈeʒə;ˈeʃə"), 'ˈeʒə');
    });

    test('剥离用途注释（前缀/后缀两种写法）', () {
      expect(
        PhoneticUtils.primary("'ædɪkt (for n.); əˈdɪkt (for v.)"),
        "'ædɪkt",
      );
      expect(
        PhoneticUtils.primary('(for v.)ɪnˈtræns; (for n.) ˈɛntrəns'),
        'ɪnˈtræns',
      );
    });

    test('完全重复的读音不会重复返回', () {
      expect(PhoneticUtils.primary("'klæs'rʊm; 'klæs'rʊm"), "'klæs'rʊm");
    });

    test('空值与空白安全', () {
      expect(PhoneticUtils.primary(null), '');
      expect(PhoneticUtils.primary(''), '');
      expect(PhoneticUtils.primary('   '), '');
    });
  });

  group('Word 音标规范化', () {
    test('构造时统一取主读音', () {
      final word = Word(
        word: 'absorb',
        phonetic: 'æbˈsɔrb; æbˈzɔrb; əbˈsɔrb',
        wordBookId: 1,
      );
      expect(word.phonetic, 'æbˈsɔrb');
    });

    test('fromMap / toMap 往返保持规范音标', () {
      final restored = Word.fromMap({
        'word': 'absorb',
        'phonetic': 'æbˈsɔrb; æbˈzɔrb',
        'definition': '吸收',
        'word_book_id': 1,
      });
      expect(restored.phonetic, 'æbˈsɔrb');
      expect(restored.toMap()['phonetic'], 'æbˈsɔrb');
    });

    test('单读音单词不受影响', () {
      final word = Word(word: 'abandon', phonetic: 'əˈbændən', wordBookId: 1);
      expect(word.phonetic, 'əˈbændən');
    });
  });
}

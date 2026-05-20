import 'package:test/test.dart';
import 'package:qingmang_weiji/utils/translations.dart';

void main() {
  group('Translations', () {
    tearDown(() => Translations.setLocale(false));

    test('defaults to Chinese', () {
      Translations.setLocale(false);

      expect(Translations.isEnglish, isFalse);
      expect(Translations.t('中文', 'English'), equals('中文'));
      expect(Translations.navHome, equals('首页'));
    });

    test('switches to English', () {
      Translations.setLocale(true);

      expect(Translations.isEnglish, isTrue);
      expect(Translations.t('中文', 'English'), equals('English'));
      expect(Translations.navHome, equals('Home'));
    });

    test('common getters follow current locale', () {
      Translations.setLocale(false);
      expect(Translations.backupSuccess, equals('备份成功'));

      Translations.setLocale(true);
      expect(Translations.backupSuccess, equals('Backup Success'));
    });
  });
}

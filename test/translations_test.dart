import 'package:test/test.dart';
import 'package:qingmang_weiji/utils/translations.dart';

void main() {
  group('Translations', () {
    test('defaults to Chinese', () {
      const translations = Translations(false);

      expect(translations.isEnglish, isFalse);
      expect(translations.t('中文', 'English'), equals('中文'));
      expect(translations.navHome, equals('首页'));
    });

    test('switches to English', () {
      const translations = Translations(true);

      expect(translations.isEnglish, isTrue);
      expect(translations.t('中文', 'English'), equals('English'));
      expect(translations.navHome, equals('Home'));
    });

    test('common getters follow current locale', () {
      const zhTranslations = Translations(false);
      const enTranslations = Translations(true);

      expect(zhTranslations.backupSuccess, equals('备份成功'));
      expect(enTranslations.backupSuccess, equals('Backup Success'));
    });
  });
}

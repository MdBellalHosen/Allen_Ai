import 'package:flutter_test/flutter_test.dart';
import 'package:maya/voice/language_detector.dart';

void main() {
  test('Bangla script -> bn', () => expect(LanguageDetector.replyLanguage('ভলিউম বাড়াও'), SpokenLang.bn));
  test('mixed script -> bn', () => expect(LanguageDetector.replyLanguage('YouTube এ ঢুকে সার্চ করো'), SpokenLang.bn));
  test('English -> en', () => expect(LanguageDetector.replyLanguage('Upload this video to Instagram'), SpokenLang.en));
  test('Banglish -> bn', () => expect(LanguageDetector.replyLanguage('youtube e dhuke gaan chalao'), SpokenLang.bn));
  test('cloud says bn -> bn', () => expect(LanguageDetector.replyLanguage('next', sttLanguage: 'bn'), SpokenLang.bn));
}

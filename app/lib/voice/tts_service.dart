import 'package:flutter_tts/flutter_tts.dart';

import 'language_detector.dart';

class TtsService {
  final _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  /// Returns false if the language voice is not installed (caller may show a hint).
  Future<bool> speak(String text, SpokenLang lang) async {
    await _init();
    final tag = lang == SpokenLang.bn ? 'bn-BD' : 'en-US';
    final avail = await _tts.isLanguageAvailable(tag);
    if (avail != true) return false;
    await _tts.setLanguage(tag);
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() => _tts.stop();
}

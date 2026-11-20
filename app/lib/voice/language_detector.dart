/// Lightweight script/word based language detection for the REPLY language.
/// Rule from the spec: pure English -> English; Bangla or mixed -> Bangla.
enum SpokenLang { bn, en }

class LanguageDetector {
  static final _bnScript = RegExp(r'[ঀ-৿]');
  static final _latin = RegExp(r'[A-Za-z]');

  // Common Banglish (Bangla in Latin letters) words.
  static const _banglish = {
    'koro', 'korun', 'kor', 'chalao', 'chalan', 'bondho', 'kholo', 'dhuke', 'dhukao', 'jao',
    'pathao', 'bolo', 'bolun', 'dao', 'daw', 'ta', 'ke', 'e', 'er', 'ami', 'amar', 'tumi',
    'gaan', 'gan', 'ektu', 'aro', 'choto', 'boro', 'barao', 'komao', 'thamo', 'abar', 'hobe',
    'na', 'ki', 'keno', 'kothay', 'ache', 'nai', 'sob', 'shob', 'ekta', 'ekhon', 'pore',
  };

  static SpokenLang replyLanguage(String text, {String? sttLanguage}) {
    if (_bnScript.hasMatch(text)) return SpokenLang.bn; // Bangla script or mixed
    if (sttLanguage == 'bn') return SpokenLang.bn;
    if (!_latin.hasMatch(text)) return SpokenLang.en;
    final words = text.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty);
    final hits = words.where(_banglish.contains).length;
    return hits >= 2 || (hits == 1 && words.length <= 3) ? SpokenLang.bn : SpokenLang.en;
  }
}

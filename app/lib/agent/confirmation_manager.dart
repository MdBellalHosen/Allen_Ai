import 'rule_parser.dart';

/// Understands spoken yes / no (Bangla, English, Banglish) and stop words.
class ConfirmationManager {
  static const _no = [
    'no', 'nope', 'nah', 'cancel', 'stop', 'dont', 'don t', 'do not', 'na', 'nai', 'thak', 'thamo', 'bad dao', 'nao na',
    'না', 'নয়', 'থাক', 'থামো', 'থামুন', 'বাদ দাও', 'বাদ', 'দরকার নেই', 'বাতিল',
  ];
  static const _yes = [
    'yes', 'yeah', 'yep', 'yup', 'ok', 'okay', 'sure', 'confirm', 'go ahead', 'do it', 'send it', 'proceed',
    'ha', 'haa', 'han', 'hya', 'hyan', 'hoy', 'thik ache', 'thik', 'koro', 'korun', 'pathao', 'dao',
    'হ্যাঁ', 'হ্যা', 'হাঁ', 'হা', 'হ্যাঁ', 'ঠিক আছে', 'ঠিক', 'ঠিকাছে', 'করো', 'করুন', 'ওকে', 'অবশ্যই', 'পাঠাও', 'দাও',
  ];
  static const _stop = ['stop', 'cancel', 'থামো', 'থামুন', 'বাতিল'];

  static bool _has(String t, List<String> words) {
    final padded = ' $t ';
    return words.any((w) => padded.contains(' $w '));
  }

  /// true = yes, false = no, null = could not tell. "No" wins ("করো না" means don't).
  static bool? parseAnswer(String raw) {
    final t = RuleParser.norm(raw);
    if (t.isEmpty) return null;
    if (_has(t, _no)) return false;
    if (_has(t, _yes)) return true;
    return null;
  }

  /// "Allen stop", "stop", "থামো" ...
  static bool isStop(String raw) => _has(RuleParser.norm(raw), _stop);
}

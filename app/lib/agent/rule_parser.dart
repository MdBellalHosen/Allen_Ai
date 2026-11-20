import 'tool_call.dart';

/// Phase 3 rule-based command parser (no LLM). Understands Bangla script, English and Banglish.
/// Phase 4 replaces it with the Claude planner; the emitted [ToolCall]s stay the same, so the
/// device layer is already proven by then. Order of rules matters (see [parse]).
class RuleParser {
  static const _digits = {'০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4', '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9'};

  static String norm(String s) {
    var t = s.toLowerCase();
    _digits.forEach((k, v) => t = t.replaceAll(k, v));
    t = t.replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _ascii(String s) => s.codeUnits.every((c) => c < 128);

  /// English needles match whole words/phrases; Bangla needles match as substrings
  /// (Bangla attaches suffixes: ফেসবুক + ে).
  static bool has(String text, List<String> needles) {
    final padded = ' $text ';
    for (final n in needles) {
      if (_ascii(n) ? padded.contains(' $n ') : text.contains(n)) return true;
    }
    return false;
  }

  // canonical (English) app name -> spoken forms
  static const _apps = <String, List<String>>{
    'youtube': ['youtube', 'you tube', 'ইউটিউব'],
    'facebook': ['facebook', 'fb', 'ফেসবুক', 'ফেইসবুক'],
    'messenger': ['messenger', 'মেসেঞ্জার'],
    'instagram': ['instagram', 'insta', 'ইনস্টাগ্রাম', 'ইন্সটাগ্রাম'],
    'whatsapp': ['whatsapp', 'whats app', 'হোয়াটসঅ্যাপ', 'হোয়াটসএপ'],
    'chrome': ['chrome', 'ক্রোম'],
    'gmail': ['gmail', 'জিমেইল'],
    'maps': ['maps', 'google maps', 'ম্যাপ'],
    'spotify': ['spotify', 'স্পটিফাই'],
    'telegram': ['telegram', 'টেলিগ্রাম'],
    'tiktok': ['tiktok', 'টিকটক'],
    'camera': ['camera', 'ক্যামেরা'],
    'settings': ['settings', 'setting', 'সেটিংস'],
  };

  static String? _appIn(String text) {
    for (final e in _apps.entries) {
      if (has(text, e.value)) return e.key;
    }
    return null;
  }

  static const _openVerbs = [
    'open', 'launch', 'start', 'go to', 'khol', 'kholo', 'kholen', 'khulo', 'dhuk', 'dhuko', 'dhuke', 'dhukao',
    'খোল', 'খুল', 'ঢোক', 'ঢুক', 'চালু কর',
  ];

  static const _searchVerbs = [
    'search', 'play', 'find', 'khuj', 'khoj', 'chalao', 'chalan', 'dekhao', 'shonao',
    'সার্চ', 'খুঁজ', 'খোঁজ', 'খুজ', 'চালাও', 'চালান', 'দেখাও', 'শোনাও',
  ];

  static const _playFirstHints = [
    'play', 'chalao', 'chalan', 'shonao', 'first video', 'prothom video', 'চালাও', 'চালান', 'শোনাও', 'প্রথম ভিডিও',
  ];

  // Dropped when extracting a search query / app name.
  static const _filler = {
    'search', 'find', 'play', 'open', 'launch', 'start', 'go', 'to', 'on', 'in', 'for', 'the', 'a', 'an', 'and', 'then',
    'please', 'plz', 'hey', 'ok', 'okay', 'app', 'into', 'from', 'of', 'song', 'songs', 'video', 'videos',
    'koro', 'kor', 'korun', 'kore', 'kholo', 'khol', 'khulo', 'dhuke', 'dhuko', 'dhuk', 'giye', 'jao', 'jan', 'e', 'te',
    'er', 'theke', 'khuj', 'khoj', 'khujo', 'chalao', 'chalan', 'dekhao', 'shonao', 'dao', 'den', 'ar', 'tarpor', 'gaan', 'gan',
    'vai', 'allen',
    'সার্চ', 'করো', 'করে', 'করুন', 'কর', 'এ', 'তে', 'ঢুকে', 'গিয়ে', 'যাও', 'যান', 'খুঁজ', 'খুঁজে', 'খোঁজ', 'খুজে', 'চালাও', 'চালান',
    'দেখাও', 'শোনাও', 'খোলো', 'খোল', 'খুলো', 'এর', 'থেকে', 'দাও', 'দেন', 'আর', 'তারপর', 'গান', 'ভিডিও', 'ভাই', 'অ্যালেন', 'অ্যাপ',
  };

  static List<String> _queryTokens(String text, {String? dropApp}) {
    var t = text
        .replaceAll(RegExp(r'(first|prothom|1st) (video|ta|টা)'), ' ')
        .replaceAll('প্রথম ভিডিও', ' ')
        .replaceAll('প্রথমটা', ' ');
    final appForms = <String>[
      for (final e in _apps.entries)
        if (dropApp == null || e.key == dropApp) ...e.value,
    ];
    final out = <String>[];
    for (final w in t.split(' ')) {
      if (w.isEmpty || _filler.contains(w)) continue;
      // drop app words incl. Bangla suffixes (ইউটিউবে)
      if (appForms.any((a) => _ascii(a) ? w == a : w.startsWith(a))) continue;
      out.add(w);
    }
    return out;
  }

  static List<ToolCall> parse(String raw) {
    final t = norm(raw);
    if (t.isEmpty) return const [];

    // 1) volume
    final lvl = RegExp(r'(?:volume|ভলিউম)\D{0,14}(\d{1,3})|(\d{1,3})\s*(?:percent|%|শতাংশ)').firstMatch(t);
    if (lvl != null && has(t, ['volume', 'ভলিউম', 'awaz', 'আওয়াজ'])) {
      final n = int.parse((lvl.group(1) ?? lvl.group(2))!);
      return [ToolCall('set_volume', {'level': n.clamp(0, 100)})];
    }
    if (has(t, ['volume up', 'volume barao', 'volume bariye', 'sound barao', 'awaz barao', 'louder', 'increase volume', 'volume increase', 'ভলিউম বাড়াও', 'ভলিউম বাড়ান', 'আওয়াজ বাড়াও', 'আওয়াজ বাড়ান'])) {
      return [const ToolCall('set_volume', {'direction': 'up'})];
    }
    if (has(t, ['volume down', 'volume komao', 'volume kombe', 'awaz komao', 'quieter', 'decrease volume', 'volume decrease', 'lower volume', 'ভলিউম কমাও', 'ভলিউম কমান', 'আওয়াজ কমাও', 'আওয়াজ কমান'])) {
      return [const ToolCall('set_volume', {'direction': 'down'})];
    }
    if (has(t, ['mute', 'মিউট', 'ভলিউম বন্ধ'])) {
      return [const ToolCall('set_volume', {'direction': 'mute'})];
    }
    if (has(t, ['unmute', 'আনমিউট'])) {
      return [const ToolCall('set_volume', {'direction': 'unmute'})];
    }

    // 2) torch / flashlight
    if (has(t, ['torch', 'flashlight', 'flash light', 'টর্চ', 'ফ্ল্যাশলাইট', 'ফ্ল্যাশ'])) {
      final off = has(t, ['off', 'nibhao', 'nibhan', 'নিভাও', 'নিভান', 'বন্ধ', 'অফ']);
      final on = has(t, ['on', 'jalao', 'jalan', 'jalo', 'জ্বালাও', 'জ্বালান', 'চালু', 'অন']);
      return [ToolCall('toggle_setting', {'name': 'flashlight', 'on': off ? false : (on ? true : null)})];
    }

    // 3) system panels (Android only lets the user flip these)
    if (has(t, ['wifi', 'wi fi', 'ওয়াইফাই', 'ওয়াই ফাই'])) return [const ToolCall('toggle_setting', {'name': 'wifi'})];
    if (has(t, ['bluetooth', 'ব্লুটুথ'])) return [const ToolCall('toggle_setting', {'name': 'bluetooth'})];
    if (has(t, ['do not disturb', 'dnd', 'ডু নট ডিস্টার্ব'])) return [const ToolCall('toggle_setting', {'name': 'dnd'})];
    if (has(t, ['airplane', 'flight mode', 'এয়ারপ্লেন', 'ফ্লাইট মোড'])) return [const ToolCall('toggle_setting', {'name': 'airplane'})];

    final app = _appIn(t);
    final scrollWord = has(t, ['scroll', 'স্ক্রল']);

    // 4) YouTube / Google search
    if (app == 'youtube' && has(t, _searchVerbs)) {
      final q = _queryTokens(t, dropApp: 'youtube').join(' ');
      if (q.isEmpty) return [const ToolCall('open_app', {'name': 'youtube'})];
      return [ToolCall('search_in_app', {'app': 'youtube', 'query': q, 'play_first': has(t, _playFirstHints)})];
    }
    if (has(t, ['google', 'গুগল']) && has(t, ['search', 'সার্চ', 'khuj', 'খুঁজ', 'খোঁজ'])) {
      final q = _queryTokens(t).where((w) => w != 'google' && w != 'গুগল').join(' ');
      if (q.isNotEmpty) return [ToolCall('search_in_app', {'app': 'google', 'query': q})];
    }

    // 5) open an app (optionally followed by scroll)
    final openVerb = has(t, _openVerbs);
    if (app != null && (openVerb || t.split(' ').length <= 3 || scrollWord || has(t, ['jao', 'যাও']))) {
      return [
        ToolCall('open_app', {'name': app}),
        if (scrollWord) const ToolCall('scroll', {'direction': 'down'}),
      ];
    }
    if (app == null && openVerb) {
      final name = _queryTokens(t).join(' ');
      if (name.isNotEmpty) return [ToolCall('open_app', {'name': name})];
    }

    // 6) navigation
    if (has(t, ['go home', 'home e jao', 'home jao', 'home screen', 'homescreen', 'হোমে যাও', 'হোম স্ক্রিনে'])) {
      return [const ToolCall('press_global', {'action': 'home'})];
    }
    if (has(t, ['recent', 'recents', 'recent apps', 'রিসেন্ট'])) return [const ToolCall('press_global', {'action': 'recents'})];
    if (has(t, ['notification', 'notifications', 'নোটিফিকেশন'])) return [const ToolCall('press_global', {'action': 'notifications'})];

    // 7) media (previous before back so "back song"-style phrases stay media)
    if (has(t, ['previous', 'prev', 'ager gaan', 'ager gan', 'আগের গান', 'আগের'])) return [const ToolCall('media_control', {'action': 'previous'})];
    if (has(t, ['next', 'skip', 'porer gaan', 'porer gan', 'gaan bodlao', 'gan bodlao', 'gaan paltao', 'পরের গান', 'পরের', 'গান বদলাও', 'গান পাল্টাও'])) {
      return [const ToolCall('media_control', {'action': 'next'})];
    }
    if (has(t, ['pause', 'gaan thamao', 'gan thamao', 'গান থামাও', 'থামাও', 'থামান'])) return [const ToolCall('media_control', {'action': 'pause'})];
    if (has(t, ['resume', 'play music', 'gaan chalao', 'gan chalao', 'গান চালাও', 'গান ছাড়ো'])) return [const ToolCall('media_control', {'action': 'play'})];

    if (has(t, ['back', 'go back', 'back jao', 'ব্যাক', 'ফিরে যাও', 'পেছনে যাও'])) return [const ToolCall('press_global', {'action': 'back'})];

    // 8) scroll
    if (scrollWord || has(t, ['niche jao', 'upore jao', 'নিচে যাও', 'নিচে নামো', 'উপরে যাও'])) {
      final up = has(t, ['up', 'upore', 'উপরে', 'উপর', 'ওপরে']);
      return [ToolCall('scroll', {'direction': up ? 'up' : 'down'})];
    }

    return const [];
  }
}

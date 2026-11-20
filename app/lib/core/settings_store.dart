import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VoiceMode { bn, en, auto }

/// Persisted user settings.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs)
      : voiceMode = VoiceMode.values.byName(_prefs.getString('voiceMode') ?? 'bn'),
        wakeWordEnabled = _prefs.getBool('wakeWord') ?? false;

  final SharedPreferences _prefs;
  VoiceMode voiceMode;
  bool wakeWordEnabled;

  Future<void> setVoiceMode(VoiceMode m) async {
    voiceMode = m;
    await _prefs.setString('voiceMode', m.name);
    notifyListeners();
  }

  Future<void> setWakeWord(bool v) async {
    wakeWordEnabled = v;
    await _prefs.setBool('wakeWord', v);
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

enum VoiceMode { bn, en, auto }

/// Persisted user settings.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs)
      : voiceMode = VoiceMode.values.byName(_prefs.getString('voiceMode') ?? 'bn'),
        wakeWordEnabled = _prefs.getBool('wakeWord') ?? false,
        backendUrl = _prefs.getString('backendUrl') ?? AppConfig.backendUrl,
        registrationCode = _prefs.getString('registrationCode') ?? AppConfig.registrationCode;

  final SharedPreferences _prefs;
  VoiceMode voiceMode;
  bool wakeWordEnabled;
  String backendUrl;
  String registrationCode;

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

  Future<void> setBackend(String url, String code) async {
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    registrationCode = code.trim();
    await _prefs.setString('backendUrl', backendUrl);
    await _prefs.setString('registrationCode', registrationCode);
    notifyListeners();
  }
}

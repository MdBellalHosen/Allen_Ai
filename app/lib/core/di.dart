import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/backend_client.dart';
import '../data/repositories/auth_repo.dart';
import '../platform/device_bridge.dart';
import '../voice/tts_service.dart';
import '../voice/voice_controller.dart';
import '../voice/wake_word_service.dart';
import 'settings_store.dart';

/// Tiny hand-rolled service graph (no DI package needed yet).
class Services {
  Services._(this.prefs, this.settings, this.auth, this.backend, this.voice, this.bridge);
  final SharedPreferences prefs;
  final SettingsStore settings;
  final AuthRepo auth;
  final BackendClient backend;
  final VoiceController voice;
  final DeviceBridge bridge;

  static Future<Services> create() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs);
    final auth = AuthRepo(prefs);
    final backend = BackendClient(getToken: auth.token, onUnauthorized: auth.clearToken);
    auth.backend = backend;
    final voice = VoiceController(settings: settings, backend: backend, tts: TtsService(), wake: WakeWordService());
    await voice.init();
    return Services._(prefs, settings, auth, backend, voice, DeviceBridge());
  }
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({super.key, required this.services, required super.child});
  final Services services;

  static Services of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ServicesScope>()!.services;

  @override
  bool updateShouldNotify(ServicesScope old) => services != old.services;
}

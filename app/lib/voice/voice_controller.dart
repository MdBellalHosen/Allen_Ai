
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/logger.dart';
import '../core/settings_store.dart';
import '../data/api/backend_client.dart';
import '../l10n/gen/app_localizations.dart';
import 'language_detector.dart';
import 'stt_service.dart';
import 'tts_service.dart';
import 'wake_word_service.dart';

enum VoiceState { idle, listening, processing, speaking, error }

/// Phase 2 voice loop: wake word / tap -> STT -> live transcript -> echo the transcript by voice.
/// Phase 4 replaces the echo with the LLM agent.
class VoiceController extends ChangeNotifier {
  VoiceController({
    required this.settings,
    required this.backend,
    required this.tts,
    required this.wake,
  });

  final SettingsStore settings;
  final BackendClient backend;
  final TtsService tts;
  final WakeWordService wake;

  VoiceState state = VoiceState.idle;
  String transcript = '';
  String? message; // last error/hint, shown in UI
  SttService? _stt;

  void _set(VoiceState s, {String? msg}) {
    state = s;
    message = msg;
    notifyListeners();
  }

  Future<void> init() async {
    settings.addListener(_syncWake);
    await _syncWake();
  }

  Future<void> _syncWake() async {
    if (settings.wakeWordEnabled && state == VoiceState.idle) {
      await wake.start(() => startListening());
    } else if (!settings.wakeWordEnabled) {
      await wake.stop();
    }
  }

  SttService _makeStt() {
    switch (settings.voiceMode) {
      case VoiceMode.bn:
        return OnDeviceStt(langCode: 'bn');
      case VoiceMode.en:
        return OnDeviceStt(langCode: 'en');
      case VoiceMode.auto:
        return CloudStt(backend);
    }
  }

  Future<void> toggle() => state == VoiceState.listening ? stopListening() : startListening();

  Future<void> startListening() async {
    if (state != VoiceState.idle && state != VoiceState.error) return;
    if (!await Permission.microphone.request().isGranted) {
      _set(VoiceState.error, msg: 'mic');
      return;
    }
    await wake.stop(); // Porcupine releases the mic
    transcript = '';
    _set(VoiceState.listening);
    final stt = _makeStt();
    _stt = stt;
    await _runStt(stt, allowCloudFallback: settings.voiceMode != VoiceMode.auto);
  }

  Future<void> _runStt(SttService stt, {required bool allowCloudFallback}) async {
    SttResult? last;
    try {
      await for (final r in stt.listen()) {
        last = r;
        transcript = r.text;
        notifyListeners();
      }
    } catch (e) {
      logd('voice', 'stt error: $e');
      if (allowCloudFallback) {
        // On-device recognizer missing for this language -> try cloud (needs backend + OPENAI key).
        final cloud = CloudStt(backend, languageHint: settings.voiceMode == VoiceMode.bn ? 'bn' : 'en');
        _stt = cloud;
        return _runStt(cloud, allowCloudFallback: false);
      }
      await _finish(null, error: true);
      return;
    }
    await _finish(last);
  }

  Future<void> stopListening() async => _stt?.stop();

  Future<void> cancel() async {
    await _stt?.cancel();
    await tts.stop();
    _set(VoiceState.idle);
    await _syncWake();
  }

  Future<void> _finish(SttResult? r, {bool error = false}) async {
    final text = (r?.text ?? '').trim();
    if (error || text.isEmpty) {
      _set(VoiceState.idle, msg: error ? 'stt' : 'nospeech');
      await _syncWake();
      return;
    }
    _set(VoiceState.processing);
    final lang = LanguageDetector.replyLanguage(text, sttLanguage: r?.language);
    final t = lookupAppLocalizations(Locale(lang == SpokenLang.bn ? 'bn' : 'en'));
    _set(VoiceState.speaking);
    await tts.speak(t.echoReply(text), lang);
    _set(VoiceState.idle);
    await _syncWake();
  }

  @override
  void dispose() {
    settings.removeListener(_syncWake);
    wake.dispose();
    super.dispose();
  }
}

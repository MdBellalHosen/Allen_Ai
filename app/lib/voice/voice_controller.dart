
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../agent/rule_parser.dart';
import '../agent/tool_call.dart';
import '../agent/tool_dispatcher.dart';
import '../core/logger.dart';
import '../core/settings_store.dart';
import '../data/api/backend_client.dart';
import '../l10n/gen/app_localizations.dart';
import 'language_detector.dart';
import 'stt_service.dart';
import 'tts_service.dart';
import 'wake_word_service.dart';

enum VoiceState { idle, listening, processing, speaking, error }

/// Voice loop: wake word / tap -> STT -> live transcript -> command -> device tools -> spoken reply.
/// Phase 3 maps the transcript with [RuleParser]; Phase 4 swaps in the LLM agent.
class VoiceController extends ChangeNotifier {
  VoiceController({
    required this.settings,
    required this.backend,
    required this.tts,
    required this.wake,
    required this.dispatcher,
  });

  final SettingsStore settings;
  final BackendClient backend;
  final TtsService tts;
  final WakeWordService wake;
  final ToolDispatcher dispatcher;

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
    await _execute(text, r?.language);
  }

  /// Dev helper: run a typed command through the same path as speech (proves the device layer).
  Future<void> runText(String text) async {
    final cmd = text.trim();
    if (cmd.isEmpty || (state != VoiceState.idle && state != VoiceState.error)) return;
    await wake.stop();
    transcript = cmd;
    await _execute(cmd, null);
  }

  Future<void> _execute(String text, String? sttLang) async {
    _set(VoiceState.processing);
    final lang = LanguageDetector.replyLanguage(text, sttLanguage: sttLang);
    final t = lookupAppLocalizations(Locale(lang == SpokenLang.bn ? 'bn' : 'en'));
    final calls = RuleParser.parse(text);
    final String reply;
    if (calls.isEmpty) {
      reply = t.notUnderstood(text);
    } else {
      final results = await dispatcher.runAll(calls);
      reply = _replyFor(t, results);
    }
    _set(VoiceState.speaking);
    await tts.speak(reply, lang);
    _set(VoiceState.idle);
    await _syncWake();
  }

  String _replyFor(AppLocalizations t, List<ToolResult> results) {
    final bad = results.where((r) => !r.ok);
    if (bad.isNotEmpty) {
      final m = bad.first.message;
      if (m == 'accessibility_off') return t.needAccessibility;
      if (m.startsWith('sensitive_screen')) return t.sensitiveRefused;
      if (m == 'node_not_found') return t.couldntFind;
      if (m == 'app_not_found' || m == 'app_not_launchable') return t.appNotFound;
      if (m == 'launch_blocked') return t.launchBlocked;
      return t.actionFailed;
    }
    if (results.any((r) => r.message == 'panel_opened')) return t.panelOpened;
    return t.actionDone;
  }

  @override
  void dispose() {
    settings.removeListener(_syncWake);
    wake.dispose();
    super.dispose();
  }
}

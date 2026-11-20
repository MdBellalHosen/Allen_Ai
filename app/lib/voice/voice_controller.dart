import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../agent/agent_controller.dart';
import '../agent/agent_ui.dart';
import '../agent/confirmation_manager.dart';
import '../agent/rule_parser.dart';
import '../agent/tool_call.dart';
import '../agent/tool_dispatcher.dart';
import '../core/logger.dart';
import '../core/settings_store.dart';
import '../data/api/backend_client.dart';
import '../l10n/gen/app_localizations.dart';
import '../platform/device_bridge.dart';
import 'language_detector.dart';
import 'stt_service.dart';
import 'tts_service.dart';
import 'wake_word_service.dart';

enum VoiceState { idle, listening, processing, speaking, error }

/// Voice loop: wake word / tap -> STT -> command.
/// Simple commands run instantly through [RuleParser]; everything else goes to the Claude agent
/// ([AgentController]). This class is also the agent's UI: it speaks, asks and confirms.
class VoiceController extends ChangeNotifier implements AgentUi {
  VoiceController({
    required this.settings,
    required this.backend,
    required this.tts,
    required this.wake,
    required this.dispatcher,
    required this.agent,
    required this.bridge,
  });

  final SettingsStore settings;
  final BackendClient backend;
  final TtsService tts;
  final WakeWordService wake;
  final ToolDispatcher dispatcher;
  final AgentController agent;
  final DeviceBridge bridge;

  VoiceState state = VoiceState.idle;
  String transcript = '';
  String? message; // last error/hint, shown in UI
  String? pendingConfirmation; // preview text while waiting for yes / no
  SttService? _stt;
  Completer<bool>? _confirm;

  bool get agentRunning => agent.running;

  void _set(VoiceState s, {String? msg}) {
    state = s;
    message = msg;
    notifyListeners();
  }

  Future<void> init() async {
    settings.addListener(_syncWake);
    bridge.onKill = kill;
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

  /// One-shot listen used for answers to questions and confirmations. Returns null on silence.
  Future<String?> listenOnce() async {
    if (!await Permission.microphone.isGranted) return null;
    final stt = _makeStt();
    _stt = stt;
    _set(VoiceState.listening);
    SttResult? last;
    try {
      await for (final r in stt.listen()) {
        last = r;
        transcript = r.text;
        notifyListeners();
      }
    } catch (e) {
      logd('voice', 'listenOnce error: $e');
    }
    _stt = null;
    final text = (last?.text ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// Kill switch: stop everything now (button, volume-down x3, or spoken "stop").
  Future<void> kill() async {
    agent.cancel();
    if (!(_confirm?.isCompleted ?? true)) _confirm!.complete(false);
    await _stt?.cancel();
    await tts.stop();
    pendingConfirmation = null;
    _set(VoiceState.idle);
    await _syncWake();
  }

  Future<void> cancel() => kill();

  // ---- AgentUi ------------------------------------------------------------------------------
  SpokenLang _lang(String l) => l == 'bn' ? SpokenLang.bn : SpokenLang.en;

  @override
  Future<void> say(String text, String lang) async {
    _set(VoiceState.speaking);
    await tts.speak(text, _lang(lang));
    if (agent.running) _set(VoiceState.processing);
  }

  @override
  Future<bool> confirm(String preview, String lang) async {
    final c = _confirm = Completer<bool>();
    pendingConfirmation = preview;
    _set(VoiceState.speaking);
    unawaited(_voiceConfirm(preview, lang, c));
    final yes = await c.future.timeout(const Duration(seconds: 60), onTimeout: () => false);
    pendingConfirmation = null;
    _set(agent.running ? VoiceState.processing : VoiceState.idle);
    return yes;
  }

  Future<void> _voiceConfirm(String preview, String lang, Completer<bool> c) async {
    await tts.speak(preview, _lang(lang));
    for (var attempt = 0; attempt < 2 && !c.isCompleted; attempt++) {
      final heard = await listenOnce();
      if (c.isCompleted) return;
      if (heard != null) {
        final a = ConfirmationManager.parseAnswer(heard);
        if (a != null) {
          c.complete(a);
          return;
        }
      }
    }
    // no usable voice answer: the Yes / No buttons stay available until the timeout
    if (!c.isCompleted) _set(VoiceState.speaking);
  }

  /// Called by the Yes / No buttons.
  void answerConfirmation(bool yes) {
    if (!(_confirm?.isCompleted ?? true)) _confirm!.complete(yes);
    _stt?.cancel();
  }

  @override
  Future<String?> ask(String question, String lang) async {
    _set(VoiceState.speaking);
    await tts.speak(question, _lang(lang));
    final answer = await listenOnce();
    _set(agent.running ? VoiceState.processing : VoiceState.idle);
    return answer;
  }

  // ---- commands -----------------------------------------------------------------------------
  Future<void> _finish(SttResult? r, {bool error = false}) async {
    final text = (r?.text ?? '').trim();
    if (error || text.isEmpty) {
      _set(VoiceState.idle, msg: error ? 'stt' : 'nospeech');
      await _syncWake();
      return;
    }
    if (ConfirmationManager.isStop(text)) {
      await kill();
      return;
    }
    await _execute(text, r?.language);
  }

  /// Dev helper: run a typed command through the same path as speech.
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
    String? reply;
    var replyLang = lang;
    if (calls.isNotEmpty) {
      // Fast path: no network, no LLM.
      reply = _replyFor(t, await dispatcher.runAll(calls));
    } else {
      final outcome = await agent.run(
        text,
        ui: this,
        locale: lang == SpokenLang.bn ? 'bn' : 'en',
        caps: {'accessibility_enabled': await bridge.isAccessibilityEnabled()},
      );
      switch (outcome.end) {
        case AgentEnd.done:
          reply = outcome.summary.isEmpty ? null : outcome.summary;
          replyLang = _lang(outcome.lang);
        case AgentEnd.cancelled:
          reply = null; // kill switch: stay quiet
        case AgentEnd.error:
          logd('agent', outcome.error);
          reply = t.agentError;
      }
    }
    if (reply != null) {
      _set(VoiceState.speaking);
      await tts.speak(reply, replyLang);
    }
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

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/logger.dart';
import '../data/api/backend_client.dart';

class SttResult {
  SttResult(this.text, {this.isFinal = false, this.language});
  final String text;
  final bool isFinal;
  final String? language; // set by cloud STT (bn/en)
}

class SttUnavailable implements Exception {
  SttUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'SttUnavailable: $reason';
}

abstract class SttService {
  /// Emits partial results, then one final result, then completes.
  Stream<SttResult> listen();
  Future<void> stop();
  Future<void> cancel();
}

/// On-device Android SpeechRecognizer (low latency). Needs a fixed locale: bn or en.
class OnDeviceStt implements SttService {
  OnDeviceStt({required this.langCode});
  final String langCode; // 'bn' | 'en'
  final _speech = stt.SpeechToText();
  StreamController<SttResult>? _ctrl;

  Future<String?> _resolveLocale() async {
    final locales = await _speech.locales();
    final want = langCode == 'bn' ? ['bn_BD', 'bn-BD', 'bn_IN', 'bn'] : ['en_US', 'en-US', 'en_GB', 'en'];
    for (final w in want) {
      for (final l in locales) {
        if (l.localeId.toLowerCase() == w.toLowerCase()) return l.localeId;
      }
    }
    for (final l in locales) {
      if (l.localeId.toLowerCase().startsWith(langCode)) return l.localeId;
    }
    return null;
  }

  @override
  Stream<SttResult> listen() {
    final c = _ctrl = StreamController<SttResult>();
    () async {
      try {
        final ok = await _speech.initialize(
          onError: (e) {
            logd('stt', 'error ${e.errorMsg}');
            if (!c.isClosed) {
              c.addError(SttUnavailable(e.errorMsg));
              c.close();
            }
          },
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && !c.isClosed) c.close();
          },
        );
        if (!ok) throw SttUnavailable('speech recognition unavailable');
        final locale = await _resolveLocale();
        if (locale == null) throw SttUnavailable('no $langCode locale installed');
        await _speech.listen(
          localeId: locale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          onResult: (r) {
            if (c.isClosed) return;
            c.add(SttResult(r.recognizedWords, isFinal: r.finalResult, language: langCode));
          },
        );
      } catch (e) {
        if (!c.isClosed) {
          c.addError(e);
          await c.close();
        }
      }
    }();
    return c.stream;
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    if (!(_ctrl?.isClosed ?? true)) await _ctrl!.close();
  }
}

/// Cloud STT: records audio, stops on silence, sends to backend (Whisper). Auto-detects language.
class CloudStt implements SttService {
  CloudStt(this.backend, {this.languageHint});
  final BackendClient backend;
  final String? languageHint;
  final _rec = AudioRecorder();
  bool _cancelled = false;
  Completer<void>? _stopReq;

  @override
  Stream<SttResult> listen() {
    final c = StreamController<SttResult>();
    () async {
      try {
        if (!await _rec.hasPermission()) throw SttUnavailable('no mic permission');
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/allen_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1), path: path);
        _stopReq = Completer<void>();
        await _waitForSilence();
        await _rec.stop();
        if (_cancelled) {
          await c.close();
          return;
        }
        final file = File(path);
        final res = await backend.transcribe(file, languageHint: languageHint);
        if (await file.exists()) await file.delete(); // don't keep voice recordings
        c.add(SttResult(res.text, isFinal: true, language: res.language));
      } catch (e) {
        c.addError(e);
      } finally {
        await c.close();
      }
    }();
    return c.stream;
  }

  /// Ends when: user stops, 1.5s of silence after speech, 4s with no speech at all, or 20s max.
  Future<void> _waitForSilence() async {
    const tick = Duration(milliseconds: 200);
    var elapsed = Duration.zero, quiet = Duration.zero;
    var heardSpeech = false;
    while (elapsed < const Duration(seconds: 20)) {
      if (_stopReq == null || _stopReq!.isCompleted || _cancelled) return;
      await Future.delayed(tick);
      elapsed += tick;
      final amp = await _rec.getAmplitude();
      if (amp.current > -35) {
        heardSpeech = true;
        quiet = Duration.zero;
      } else {
        quiet += tick;
      }
      if (heardSpeech && quiet >= const Duration(milliseconds: 1500)) return;
      if (!heardSpeech && elapsed >= const Duration(seconds: 4)) return;
    }
  }

  @override
  Future<void> stop() async {
    if (!(_stopReq?.isCompleted ?? true)) _stopReq!.complete();
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await stop();
    if (await _rec.isRecording()) await _rec.stop();
  }
}

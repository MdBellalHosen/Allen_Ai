import 'package:flutter/services.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

import '../core/config.dart';
import '../core/logger.dart';

/// "Hey Allen" wake word via Picovoice Porcupine. Optional: if the AccessKey or the
/// custom keyword file is missing, [available] is false and tap-to-talk still works.
/// Porcupine owns the mic while listening, so the controller calls [stop] before STT.
class WakeWordService {
  PorcupineManager? _mgr;
  bool running = false;

  Future<bool> get available async {
    if (AppConfig.picovoiceAccessKey.isEmpty) return false;
    try {
      await rootBundle.load(AppConfig.wakeWordAsset);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> start(void Function() onWake) async {
    if (running) return true;
    if (!await available) return false;
    try {
      _mgr ??= await PorcupineManager.fromKeywordPaths(
        AppConfig.picovoiceAccessKey,
        [AppConfig.wakeWordAsset],
        (_) => onWake(),
        errorCallback: (PorcupineException e) => logd('wake', e.message),
      );
      await _mgr!.start();
      running = true;
      return true;
    } catch (e) {
      logd('wake', 'start failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (!running) return;
    await _mgr?.stop();
    running = false;
  }

  Future<void> dispose() async {
    await stop();
    await _mgr?.delete();
    _mgr = null;
  }
}

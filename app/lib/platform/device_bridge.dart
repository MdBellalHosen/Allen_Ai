import 'package:flutter/services.dart';

/// Wrapper for the native Kotlin bridge. Phase 2: foreground service. Phase 3 adds device tools.
class DeviceBridge {
  static const _ch = MethodChannel('allen/device');

  Future<void> startForegroundService() => _ch.invokeMethod('startForegroundService');
  Future<void> stopForegroundService() => _ch.invokeMethod('stopForegroundService');
}

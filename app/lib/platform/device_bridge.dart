import 'package:flutter/services.dart';

import '../agent/tool_call.dart';

/// Typed wrapper over the native Kotlin bridge (MethodChannel "allen/device").
class DeviceBridge {
  static const _ch = MethodChannel('allen/device');

  Future<ToolResult> call(String method, [Map<String, Object?>? args]) async {
    try {
      final r = await _ch.invokeMethod<Map<Object?, Object?>>(method, args);
      if (r == null) return const ToolResult(true, 'ok');
      final data = r['data'];
      return ToolResult(
        r['ok'] == true,
        (r['message'] as String?) ?? '',
        data is Map ? data.map((k, v) => MapEntry(k.toString(), v)) : null,
      );
    } on MissingPluginException {
      return const ToolResult(false, 'no_native_bridge');
    } on PlatformException catch (e) {
      return ToolResult(false, 'platform_error:${e.code}');
    }
  }

  Future<void> startForegroundService() => call('startForegroundService');
  Future<void> stopForegroundService() => call('stopForegroundService');

  Future<bool> isAccessibilityEnabled() async {
    try {
      return (await _ch.invokeMethod<bool>('isAccessibilityEnabled')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() => call('openAccessibilitySettings');
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/tool_call.dart';

/// Typed wrapper over the native Kotlin bridge (MethodChannel "allen/device").
class DeviceBridge {
  static const _ch = MethodChannel('allen/device');

  /// Kill switch: the native side calls this when the user presses volume-down 3 times quickly.
  void Function()? onKill;

  DeviceBridge() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'killSwitch') onKill?.call();
      return null;
    });
  }

  static bool get _ios => !kIsWeb && Platform.isIOS;

  // iPhone: apps cannot control other apps, so only launching works (URL schemes / universal links).
  static const _iosSchemes = <String, String>{
    'youtube': 'youtube://', 'ইউটিউব': 'youtube://',
    'facebook': 'fb://', 'fb': 'fb://', 'ফেসবুক': 'fb://',
    'messenger': 'fb-messenger://', 'মেসেঞ্জার': 'fb-messenger://',
    'instagram': 'instagram://', 'insta': 'instagram://', 'ইনস্টাগ্রাম': 'instagram://', 'ইন্সটাগ্রাম': 'instagram://',
    'whatsapp': 'whatsapp://', 'হোয়াটসঅ্যাপ': 'whatsapp://',
    'telegram': 'tg://', 'টেলিগ্রাম': 'tg://',
    'spotify': 'spotify://', 'স্পটিফাই': 'spotify://',
    'gmail': 'googlegmail://', 'জিমেইল': 'googlegmail://',
    'chrome': 'googlechromes://', 'ক্রোম': 'googlechromes://',
    'maps': 'maps://', 'ম্যাপ': 'maps://',
    'tiktok': 'snssdk1233://', 'টিকটক': 'snssdk1233://',
  };

  Future<ToolResult> _iosLaunch(Uri? u) async {
    if (u == null) return const ToolResult(false, 'bad_url');
    try {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      return ok ? const ToolResult(true, 'opened') : const ToolResult(false, 'app_not_found');
    } catch (_) {
      return const ToolResult(false, 'app_not_found');
    }
  }

  Future<ToolResult> _iosCall(String method, Map<String, Object?>? a) async {
    switch (method) {
      case 'startForegroundService':
      case 'stopForegroundService':
        return const ToolResult(true, 'ok');
      case 'openApp':
        final scheme = _iosSchemes[((a?['name'] as String?) ?? '').toLowerCase().trim()];
        return scheme == null ? const ToolResult(false, 'app_not_found') : _iosLaunch(Uri.parse(scheme));
      case 'openUrl':
        return _iosLaunch(Uri.tryParse((a?['url'] as String?) ?? ''));
      case 'searchInApp':
        final q = Uri.encodeQueryComponent((a?['query'] as String?) ?? '');
        final app = ((a?['app'] as String?) ?? '').toLowerCase();
        if (app == 'youtube' || app == 'ইউটিউব') {
          return _iosLaunch(Uri.parse('https://www.youtube.com/results?search_query=$q')); // opens the YouTube app if installed
        }
        if (app == 'google' || app == 'web' || app == 'গুগল') return _iosLaunch(Uri.parse('https://www.google.com/search?q=$q'));
        return const ToolResult(false, 'search_not_supported_for_app');
      default:
        return const ToolResult(false, 'not_supported_on_ios');
    }
  }

  Future<ToolResult> call(String method, [Map<String, Object?>? args]) async {
    if (_ios) return _iosCall(method, args);
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
    if (_ios) return false;
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

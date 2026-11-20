import '../core/logger.dart';
import '../platform/device_bridge.dart';
import 'tool_call.dart';

/// Routes device tool calls to the native bridge. Cloud tools join in Phase 5.
class ToolDispatcher {
  ToolDispatcher(this.bridge, {this.settle = const Duration(milliseconds: 1500)});
  final DeviceBridge bridge;

  /// Pause after launching an app so its first screen exists before the next step reads it.
  final Duration settle;

  // Words YouTube puts on a video result row (English + Bangla UI).
  static const _videoRow = ['play video', 'ভিডিও চালান', 'ভিডিও প্লে'];

  Future<ToolResult> run(ToolCall c) async {
    logd('tool', c);
    final a = c.args;
    switch (c.name) {
      case 'open_app':
        return bridge.call('openApp', {'name': a['name']});
      case 'open_url':
        return bridge.call('openUrl', {'url': a['url']});
      case 'search_in_app':
        final r = await bridge.call('searchInApp', {'app': a['app'], 'query': a['query']});
        if (!r.ok || a['play_first'] != true) return r;
        // Wait for results, then tap the first video row (needs the accessibility service).
        await Future.delayed(settle);
        return bridge.call('tap', {'match': _videoRow, 'clickableOnly': true, 'timeoutMs': 6000});
      case 'tap':
        return bridge.call('tap', {
          if (a['match'] != null) 'match': a['match'],
          if (a['x'] != null) 'x': (a['x'] as num).toDouble(),
          if (a['y'] != null) 'y': (a['y'] as num).toDouble(),
          'clickableOnly': a['clickable_only'] ?? false,
          'timeoutMs': a['timeout_ms'] ?? 0,
        });
      case 'type_text':
        return bridge.call('typeText', {'text': a['text']});
      case 'scroll':
        return bridge.call('scroll', {'direction': a['direction'] ?? 'down'});
      case 'swipe':
        return bridge.call('swipe', {
          for (final k in ['x1', 'y1', 'x2', 'y2']) k: (a[k] as num).toDouble(),
          'durationMs': a['duration_ms'] ?? 300,
        });
      case 'press_global':
        return bridge.call('pressGlobal', {'action': a['action']});
      case 'read_screen':
        return bridge.call('readScreen');
      case 'media_control':
        return bridge.call('mediaControl', {'action': a['action']});
      case 'set_volume':
        return bridge.call('setVolume', {'direction': a['direction'], 'level': a['level']});
      case 'toggle_setting':
        return bridge.call('toggleSetting', {'name': a['name'], 'on': a['on']});
      default:
        return ToolResult(false, 'unknown_tool:${c.name}');
    }
  }

  /// Runs calls in order; stops at the first failure. Returns every result so far.
  Future<List<ToolResult>> runAll(List<ToolCall> calls) async {
    final out = <ToolResult>[];
    for (var i = 0; i < calls.length; i++) {
      final r = await run(calls[i]);
      out.add(r);
      if (!r.ok) break;
      final launched = calls[i].name == 'open_app' || calls[i].name == 'search_in_app';
      if (launched && i < calls.length - 1) await Future.delayed(settle);
    }
    return out;
  }
}

import 'package:allen_ai/agent/rule_parser.dart';
import 'package:allen_ai/agent/tool_call.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bangla / English / Banglish utterances -> expected tool calls (Phase 3 rule parser).
/// COMMAND_TEST_SET.md grows from this list for the Phase 4 LLM agent.
void main() {
  void expectCalls(String said, List<ToolCall> want) =>
      test(said, () => expect(RuleParser.parse(said), want));

  group('open apps', () {
    expectCalls('open youtube', [const ToolCall('open_app', {'name': 'youtube'})]);
    expectCalls('ইউটিউব খোলো', [const ToolCall('open_app', {'name': 'youtube'})]);
    expectCalls('youtube e dhuke gaan chalao', [const ToolCall('open_app', {'name': 'youtube'})]);
    expectCalls('open whatsapp', [const ToolCall('open_app', {'name': 'whatsapp'})]);
    expectCalls('ফেসবুকে ঢুকে স্ক্রল করো', [
      const ToolCall('open_app', {'name': 'facebook'}),
      const ToolCall('scroll', {'direction': 'down'}),
    ]);
    expectCalls('open calculator', [const ToolCall('open_app', {'name': 'calculator'})]);
  });

  group('youtube search', () {
    expectCalls("YouTube এ ঢুকে 'Arijit Singh' সার্চ করো",
        [const ToolCall('search_in_app', {'app': 'youtube', 'query': 'arijit singh', 'play_first': false})]);
    expectCalls("অ্যালেন, YouTube এ গিয়ে 'lofi music' সার্চ করে প্রথম ভিডিও চালাও",
        [const ToolCall('search_in_app', {'app': 'youtube', 'query': 'lofi music', 'play_first': true})]);
    expectCalls('search lofi music on youtube',
        [const ToolCall('search_in_app', {'app': 'youtube', 'query': 'lofi music', 'play_first': false})]);
    expectCalls('play arijit singh on youtube',
        [const ToolCall('search_in_app', {'app': 'youtube', 'query': 'arijit singh', 'play_first': true})]);
  });

  group('media', () {
    expectCalls('next song', [const ToolCall('media_control', {'action': 'next'})]);
    expectCalls('গান বদলাও', [const ToolCall('media_control', {'action': 'next'})]);
    expectCalls('porer gaan', [const ToolCall('media_control', {'action': 'next'})]);
    expectCalls('previous song', [const ToolCall('media_control', {'action': 'previous'})]);
    expectCalls('pause koro', [const ToolCall('media_control', {'action': 'pause'})]);
    expectCalls('music pause koro', [const ToolCall('media_control', {'action': 'pause'})]);
  });

  group('volume', () {
    expectCalls('volume up', [const ToolCall('set_volume', {'direction': 'up'})]);
    expectCalls('ভলিউম বাড়াও', [const ToolCall('set_volume', {'direction': 'up'})]);
    expectCalls('volume komao', [const ToolCall('set_volume', {'direction': 'down'})]);
    expectCalls('volume 50 percent', [const ToolCall('set_volume', {'level': 50})]);
    expectCalls('mute', [const ToolCall('set_volume', {'direction': 'mute'})]);
  });

  group('torch and panels', () {
    expectCalls('torch on', [const ToolCall('toggle_setting', {'name': 'flashlight', 'on': true})]);
    expectCalls('টর্চ জ্বালাও', [const ToolCall('toggle_setting', {'name': 'flashlight', 'on': true})]);
    expectCalls('torch off', [const ToolCall('toggle_setting', {'name': 'flashlight', 'on': false})]);
    expectCalls('টর্চ নিভাও', [const ToolCall('toggle_setting', {'name': 'flashlight', 'on': false})]);
    expectCalls('wifi off koro', [const ToolCall('toggle_setting', {'name': 'wifi'})]);
    expectCalls('ওয়াইফাই বন্ধ করো', [const ToolCall('toggle_setting', {'name': 'wifi'})]);
  });

  group('navigation and scroll', () {
    expectCalls('back jao', [const ToolCall('press_global', {'action': 'back'})]);
    expectCalls('home e jao', [const ToolCall('press_global', {'action': 'home'})]);
    expectCalls('scroll down', [const ToolCall('scroll', {'direction': 'down'})]);
    expectCalls('scroll up', [const ToolCall('scroll', {'direction': 'up'})]);
  });

  group('no match', () {
    expectCalls('hello how are you', const []);
    expectCalls('', const []);
  });
}

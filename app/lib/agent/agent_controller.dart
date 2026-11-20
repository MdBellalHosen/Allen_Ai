import 'agent_api.dart';
import 'agent_ui.dart';
import 'tool_call.dart';

abstract class ToolRunner {
  Future<ToolResult> run(ToolCall c);
}

enum AgentEnd { done, cancelled, error }

class AgentOutcome {
  const AgentOutcome(this.end, {this.summary = '', this.lang = 'en', this.error});
  const AgentOutcome.cancelled() : this(AgentEnd.cancelled);
  const AgentOutcome.error(String e) : this(AgentEnd.error, error: e);
  final AgentEnd end;
  final String summary;
  final String lang;
  final String? error;
}

/// The step loop: ask the backend what to do, run device tools locally, relay confirmations,
/// repeat until the planner says done. [cancel] is the kill switch: it stops before the next step.
class AgentController {
  AgentController({
    required this.api,
    required this.runner,
    this.maxRounds = 30,
    this.settle = const Duration(milliseconds: 1200),
  });

  final AgentApi api;
  final ToolRunner runner;
  final int maxRounds;

  /// Pause after launching an app so its screen exists before the model reads it.
  final Duration settle;

  bool _cancelled = false;
  bool _running = false;
  String? _sid;

  bool get running => _running;

  void cancel() {
    _cancelled = true;
    final s = _sid;
    if (s != null) api.cancel(s).catchError((_) {});
  }

  Future<AgentOutcome> run(
    String transcript, {
    required AgentUi ui,
    String? locale,
    Map<String, Object?> caps = const {},
  }) async {
    _cancelled = false;
    _running = true;
    _sid = null;
    try {
      var step = await api.start(transcript, locale: locale, caps: caps);
      _sid = step.sessionId;
      for (var round = 0; round < maxRounds; round++) {
        if (_cancelled) return const AgentOutcome.cancelled();
        for (final s in step.say) {
          await ui.say(s.text, s.lang);
          if (_cancelled) return const AgentOutcome.cancelled();
        }
        switch (step.status) {
          case 'done':
            return AgentOutcome(AgentEnd.done, summary: step.summary ?? '', lang: step.lang);
          case 'error':
            return AgentOutcome.error(step.error ?? 'error');
          case 'confirm':
            final yes = await ui.confirm(step.preview ?? '', step.lang);
            if (_cancelled) return const AgentOutcome.cancelled();
            step = await api.submit(step.sessionId, [CallReport(step.callId!, true, yes ? 'confirmed' : 'declined')]);
          case 'ask_user':
            final answer = await ui.ask(step.question ?? '', step.lang);
            if (_cancelled) return const AgentOutcome.cancelled();
            step = await api.submit(step.sessionId, [CallReport(step.callId!, true, answer ?? '')]);
          case 'tool_calls':
            final reports = <CallReport>[];
            var failed = false;
            for (final rc in step.calls) {
              if (_cancelled) return const AgentOutcome.cancelled();
              if (failed) {
                reports.add(CallReport(rc.id, false, 'skipped_after_failure'));
                continue;
              }
              final r = await runner.run(rc.call);
              reports.add(CallReport(rc.id, r.ok, r.message, r.data));
              if (!r.ok) failed = true;
            }
            if (_cancelled) return const AgentOutcome.cancelled();
            final launched = step.calls.any((c) => c.call.name == 'open_app' || c.call.name == 'search_in_app');
            if (launched && settle > Duration.zero) await Future.delayed(settle);
            step = await api.submit(step.sessionId, reports);
          default:
            return AgentOutcome.error('unknown_status:${step.status}');
        }
      }
      return const AgentOutcome.error('too_many_rounds');
    } catch (e) {
      return AgentOutcome.error('$e');
    } finally {
      _running = false;
    }
  }
}

import '../data/api/backend_client.dart';
import 'tool_call.dart';

class SayLine {
  const SayLine(this.text, this.lang);
  final String text;
  final String lang; // bn | en
}

class RemoteCall {
  const RemoteCall(this.id, this.call);
  final String id;
  final ToolCall call;
}

/// One response from the backend planner: what the app must do next.
class AgentStep {
  AgentStep({
    required this.sessionId,
    required this.status, // tool_calls | ask_user | confirm | done | error
    this.say = const [],
    this.calls = const [],
    this.callId,
    this.question,
    this.preview,
    this.summary,
    this.lang = 'en',
    this.error,
  });

  final String sessionId;
  final String status;
  final List<SayLine> say;
  final List<RemoteCall> calls;
  final String? callId, question, preview, summary, error;
  final String lang;

  factory AgentStep.fromJson(Map<String, dynamic> j) => AgentStep(
        sessionId: j['session_id'] as String,
        status: j['status'] as String,
        say: [for (final s in (j['say'] as List? ?? const [])) SayLine(s['text'] as String, s['lang'] as String)],
        calls: [
          for (final c in (j['tool_calls'] as List? ?? const []))
            RemoteCall(c['id'] as String, ToolCall(c['name'] as String, Map<String, Object?>.from(c['args'] as Map))),
        ],
        callId: j['call_id'] as String?,
        question: j['question'] as String?,
        preview: j['preview'] as String?,
        summary: j['summary'] as String?,
        lang: (j['lang'] as String?) ?? 'en',
        error: j['error'] as String?,
      );
}

class CallReport {
  const CallReport(this.id, this.ok, this.message, [this.data]);
  final String id;
  final bool ok;
  final String message;
  final Map<String, Object?>? data;

  Map<String, Object?> toJson() => {'id': id, 'ok': ok, 'message': message, 'data': data};
}

abstract class AgentApi {
  Future<AgentStep> start(String transcript, {String? locale, Map<String, Object?> caps});
  Future<AgentStep> submit(String sessionId, List<CallReport> reports);
  Future<void> cancel(String sessionId);
}

class HttpAgentApi implements AgentApi {
  HttpAgentApi(this.backend);
  final BackendClient backend;

  @override
  Future<AgentStep> start(String transcript, {String? locale, Map<String, Object?> caps = const {}}) async =>
      AgentStep.fromJson(await backend.postJson('/v1/agent/command', {
        'transcript': transcript,
        if (locale != null) 'locale': locale,
        'device_caps': caps,
      }));

  @override
  Future<AgentStep> submit(String sessionId, List<CallReport> reports) async =>
      AgentStep.fromJson(await backend.postJson('/v1/agent/$sessionId/result', {
        'results': [for (final r in reports) r.toJson()],
      }));

  @override
  Future<void> cancel(String sessionId) async {
    await backend.postJson('/v1/agent/$sessionId/cancel', {});
  }
}

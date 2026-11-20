import 'package:allen_ai/agent/agent_api.dart';
import 'package:allen_ai/agent/agent_controller.dart';
import 'package:allen_ai/agent/agent_ui.dart';
import 'package:allen_ai/agent/tool_call.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi implements AgentApi {
  FakeApi(this.steps);
  final List<AgentStep> steps;
  final submitted = <List<CallReport>>[];
  final cancelled = <String>[];
  @override
  Future<AgentStep> start(String t, {String? locale, Map<String, Object?> caps = const {}}) async => steps.removeAt(0);
  @override
  Future<AgentStep> submit(String id, List<CallReport> r) async {
    submitted.add(r);
    return steps.removeAt(0);
  }

  @override
  Future<void> cancel(String id) async => cancelled.add(id);
}

class FakeRunner implements ToolRunner {
  final ran = <String>[];
  Set<String> failing = {};
  void Function(String)? onRun;
  @override
  Future<ToolResult> run(ToolCall c) async {
    ran.add(c.name);
    onRun?.call(c.name);
    return failing.contains(c.name) ? const ToolResult(false, 'node_not_found') : const ToolResult(true, 'ok');
  }
}

class FakeUi implements AgentUi {
  bool answerYes = true;
  String? answer = 'Rahim';
  final said = <String>[];
  final previews = <String>[];
  @override
  Future<void> say(String text, String lang) async => said.add(text);
  @override
  Future<bool> confirm(String p, String lang) async {
    previews.add(p);
    return answerYes;
  }

  @override
  Future<String?> ask(String q, String lang) async => answer;
}

AgentStep calls(List<(String, String)> cs, {List<SayLine> say = const []}) => AgentStep(
      sessionId: 's1',
      status: 'tool_calls',
      say: say,
      calls: [for (final c in cs) RemoteCall(c.$1, ToolCall(c.$2))],
    );
AgentStep done(String s) => AgentStep(sessionId: 's1', status: 'done', summary: s, lang: 'bn');

void main() {
  AgentController make(FakeApi api, FakeRunner r) => AgentController(api: api, runner: r, settle: Duration.zero);

  test('tool call then done', () async {
    final api = FakeApi([calls([('t1', 'open_app')]), done('ঠিক আছে')]);
    final r = FakeRunner();
    final out = await make(api, r).run('open youtube', ui: FakeUi());
    expect(r.ran, ['open_app']);
    expect(api.submitted.single.single.id, 't1');
    expect(api.submitted.single.single.ok, true);
    expect(out.end, AgentEnd.done);
    expect(out.summary, 'ঠিক আছে');
    expect(out.lang, 'bn');
  });

  test('failure skips the rest and is reported', () async {
    final api = FakeApi([calls([('a', 'tap'), ('b', 'scroll')]), done('x')]);
    final r = FakeRunner()..failing = {'tap'};
    await make(api, r).run('x', ui: FakeUi());
    expect(r.ran, ['tap']);
    final rep = api.submitted.single;
    expect(rep[0].ok, false);
    expect(rep[1].message, 'skipped_after_failure');
  });

  test('confirmation: decline and accept are relayed', () async {
    for (final yes in [true, false]) {
      final api = FakeApi([AgentStep(sessionId: 's1', status: 'confirm', callId: 'c1', preview: 'Send?'), done('k')]);
      final ui = FakeUi()..answerYes = yes;
      await make(api, FakeRunner()).run('x', ui: ui);
      expect(ui.previews, ['Send?']);
      expect(api.submitted.single.single.id, 'c1');
      expect(api.submitted.single.single.message, yes ? 'confirmed' : 'declined');
    }
  });

  test('ask_user relays the answer', () async {
    final api = FakeApi([AgentStep(sessionId: 's1', status: 'ask_user', callId: 'q1', question: 'Who?'), done('k')]);
    await make(api, FakeRunner()).run('x', ui: FakeUi());
    expect(api.submitted.single.single.message, 'Rahim');
  });

  test('say lines are spoken before acting', () async {
    final api = FakeApi([calls([('t1', 'scroll')], say: [const SayLine('wait', 'en')]), done('k')]);
    final ui = FakeUi();
    await make(api, FakeRunner()).run('x', ui: ui);
    expect(ui.said, ['wait']);
  });

  test('kill switch stops before the next step and tells the backend', () async {
    final api = FakeApi([calls([('t1', 'tap')]), done('never')]);
    final r = FakeRunner();
    final c = make(api, r);
    r.onRun = (_) => c.cancel(); // user hits the kill switch while a tool runs
    final out = await c.run('x', ui: FakeUi());
    expect(out.end, AgentEnd.cancelled);
    expect(api.cancelled, ['s1']);
    expect(api.submitted, isEmpty); // nothing more was sent to the planner
    expect(c.running, false);
  });

  test('backend error status and exceptions end as error', () async {
    final api = FakeApi([AgentStep(sessionId: 's1', status: 'error', error: 'LLM_MODEL is not set')]);
    final out = await make(api, FakeRunner()).run('x', ui: FakeUi());
    expect(out.end, AgentEnd.error);
    expect(out.error, contains('LLM_MODEL'));

    final out2 = await make(FakeApi([]), FakeRunner()).run('x', ui: FakeUi()); // start() throws
    expect(out2.end, AgentEnd.error);
  });

  test('round limit prevents endless loops', () async {
    final api = FakeApi([for (var i = 0; i < 10; i++) calls([('t$i', 'read_screen')])]);
    final c = AgentController(api: api, runner: FakeRunner(), maxRounds: 3, settle: Duration.zero);
    final out = await c.run('x', ui: FakeUi());
    expect(out.end, AgentEnd.error);
    expect(out.error, 'too_many_rounds');
  });
}

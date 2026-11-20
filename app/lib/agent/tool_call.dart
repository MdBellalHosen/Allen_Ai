/// One tool invocation (Section 5 contract). Names are stable: the LLM agent (Phase 4) emits the same ones.
class ToolCall {
  const ToolCall(this.name, [this.args = const {}]);
  final String name;
  final Map<String, Object?> args;

  @override
  String toString() => 'ToolCall($name, $args)';

  @override
  bool operator ==(Object o) => o is ToolCall && o.name == name && _eq(o.args, args);

  @override
  int get hashCode => Object.hash(name, args.length);

  static bool _eq(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }
}

class ToolResult {
  const ToolResult(this.ok, this.message, [this.data]);
  final bool ok;
  final String message; // machine code, e.g. "ok", "accessibility_off", "node_not_found"
  final Map<String, Object?>? data;

  @override
  String toString() => 'ToolResult($ok, $message)';
}

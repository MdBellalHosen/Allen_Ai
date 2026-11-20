/// What the agent loop needs from the UI / voice layer.
abstract class AgentUi {
  Future<void> say(String text, String lang);

  /// Resolves true/false from a button tap or a spoken yes/no.
  Future<bool> confirm(String preview, String lang);

  /// Spoken question; returns the user's answer text, or null if none.
  Future<String?> ask(String question, String lang);
}

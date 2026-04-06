/// Abstract interface for all AI providers.
///
/// Every provider — local LLM, Claude Code, Gemini, OpenAI, Anthropic,
/// Ollama — implements this interface. Feature classes (NlpToCommand,
/// ErrorExplainer, etc.) depend only on this abstraction.
abstract class AiProvider {
  /// Sends a [prompt] and returns the text response.
  Future<String> generateContent(String prompt);

  /// Whether this provider is ready to accept queries.
  Future<bool> isAvailable();

  /// Human-readable name for error messages.
  String get displayName;
}

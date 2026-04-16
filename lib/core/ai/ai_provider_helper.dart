import 'ai_provider.dart';
import 'api_key_storage.dart';
import 'claude_provider.dart';
import 'gemini_provider.dart';
import 'local_llm_provider.dart';
import 'model_manager.dart';
import 'openai_compatible_provider.dart';

/// Helper to create an [AiProvider] from widget parameters.
///
/// Used by UI widgets that receive provider config as individual props
/// (aiProvider, geminiModel, anthropicMode, etc.) rather than a full
/// [AiConfig] object.
class AiProviderHelper {
  AiProviderHelper._();

  /// Cached local provider instance (server lifecycle is shared).
  static LocalLlmProvider? _localProvider;

  /// Set by TerminalShell when config loads/changes.
  /// Used to read localModelSize without threading it through every widget.
  static String configuredLocalModelSize = 'small';

  /// Creates an [AiProvider] from widget-level parameters.
  static Future<AiProvider?> create({
    required String providerName,
    String geminiModel = 'gemma-3-27b-it',
    String anthropicMode = 'claude-code',
    String ollamaUrl = 'http://127.0.0.1:11434',
    String ollamaModel = 'llama3',
  }) async {
    switch (providerName) {
      case 'local':
        final size = ModelSize.values.firstWhere(
          (s) => s.name == configuredLocalModelSize,
          orElse: () => ModelSize.small,
        );
        // Recreate if preferred size changed
        if (_localProvider != null && _localProvider!.preferredSize != size) {
          _localProvider!.dispose();
          _localProvider = null;
        }
        _localProvider ??= LocalLlmProvider(preferredSize: size);
        return _localProvider;

      case 'anthropic':
        if (anthropicMode == 'claude-code') return ClaudeProvider();
        final key = await ApiKeyStorage.readKey('anthropic');
        if (key == null || key.isEmpty) return null;
        return OpenAiCompatibleProvider(
          baseUrl: 'https://api.anthropic.com',
          model: 'claude-sonnet-4-20250514',
          apiKey: key,
          name: 'Anthropic',
        );

      case 'openai':
        final key = await ApiKeyStorage.readKey('openai');
        if (key == null || key.isEmpty) return null;
        return OpenAiCompatibleProvider(
          baseUrl: 'https://api.openai.com',
          model: 'gpt-4o',
          apiKey: key,
          name: 'OpenAI',
        );

      case 'ollama':
        // Ollama runs locally and never needs an API key.
        return OpenAiCompatibleProvider(
          baseUrl: ollamaUrl,
          model: ollamaModel,
          name: 'Ollama',
        );

      case 'google':
      case 'gemini': // legacy config compat
        final key = await ApiKeyStorage.readKey('gemini');
        if (key == null || key.isEmpty) return null;
        return GeminiProvider(apiKey: key, model: geminiModel);

      default:
        return null;
    }
  }

  /// Whether the cached local provider has an active llamafile server.
  /// Use this before firing opportunistic requests that must not
  /// trigger an on-demand model load.
  static bool isLocalLoaded() => _localProvider?.isRunning ?? false;

  /// Disposes the shared local provider (call on app exit).
  static void dispose() {
    _localProvider?.dispose();
    _localProvider = null;
  }
}

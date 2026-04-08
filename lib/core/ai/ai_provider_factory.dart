import '../config/app_config.dart';
import 'ai_provider.dart';
import 'api_key_storage.dart';
import 'claude_provider.dart';
import 'gemini_provider.dart';
import 'local_llm_provider.dart';
import 'openai_compatible_provider.dart';

/// Creates the appropriate [AiProvider] based on the user's config.
///
/// Centralizes provider selection logic so feature classes don't need
/// to know about specific providers — they just call [generateContent].
class AiProviderFactory {
  AiProviderFactory._();

  /// Creates an [AiProvider] from the current [AiConfig].
  ///
  /// Returns null if the provider can't be created (missing API key, etc.).
  static Future<AiProvider?> create(AiConfig config) async {
    switch (config.provider) {
      case 'local':
        return LocalLlmProvider();

      case 'anthropic':
        if (config.anthropicMode == 'claude-code') {
          return ClaudeProvider();
        }
        final key = await ApiKeyStorage.readKey('anthropic');
        if (key == null || key.isEmpty) return null;
        return OpenAiCompatibleProvider(
          baseUrl: 'https://api.anthropic.com',
          model: config.anthropicModel,
          apiKey: key,
          name: 'Anthropic',
        );

      case 'openai':
        final key = await ApiKeyStorage.readKey('openai');
        if (key == null || key.isEmpty) return null;
        return OpenAiCompatibleProvider(
          baseUrl: 'https://api.openai.com',
          model: config.openaiModel,
          apiKey: key,
          name: 'OpenAI',
        );

      case 'ollama':
        // Ollama runs locally and never needs an API key.
        return OpenAiCompatibleProvider(
          baseUrl: config.ollamaUrl,
          model: config.model.isNotEmpty ? config.model : 'llama3',
          name: 'Ollama',
        );

      case 'gemini':
        final key = await ApiKeyStorage.readKey('gemini');
        if (key == null || key.isEmpty) return null;
        return GeminiProvider(
          apiKey: key,
          model: config.geminiModel,
        );

      default:
        return null;
    }
  }
}

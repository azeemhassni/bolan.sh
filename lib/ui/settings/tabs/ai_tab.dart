import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/bolan_theme.dart';
import '../../shared/bolan_components.dart';
import '../widgets/api_key_field.dart';
import '../widgets/local_model_card.dart';
import '../widgets/test_connection_button.dart';

typedef AiUpdater = void Function({
  String? provider,
  String? model,
  String? ollamaUrl,
  String? geminiModel,
  String? openaiModel,
  String? anthropicModel,
  String? huggingfaceModel,
  String? anthropicMode,
  bool? enabled,
  bool? commandSuggestions,
  bool? smartHistorySearch,
  bool? shareHistory,
  String? localModelSize,
});

class AiTab extends StatelessWidget {
  final AppConfig config;
  final BolonTheme theme;
  final AiUpdater onChanged;

  const AiTab({
    super.key,
    required this.config,
    required this.theme,
    required this.onChanged,
  });

  List<Widget> _providerSettings() {
    switch (config.ai.provider) {
      case 'local':
        return [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LocalModelCard(
              theme: theme,
              activeSize: config.ai.localModelSize,
              onChanged: () {},
              onSizeChanged: (size) => onChanged(localModelSize: size),
            ),
          ),
        ];
      case 'google':
      case 'gemini':
        return [
          ApiKeyField(provider: 'gemini', theme: theme),
          BolanField(
            label: 'Model',
            child: BolanDropdown(
              value: config.ai.geminiModel,
              options: const [
                'gemini-2.5-flash',
                'gemini-2.5-pro',
                'gemini-2.0-flash',
                'gemma-3-27b-it',
              ],
              onChanged: (v) => onChanged(geminiModel: v),
            ),
          ),
        ];
      case 'anthropic':
        return [
          BolanField(
            label: 'Mode',
            help: 'Use Claude Code CLI or API key',
            child: BolanSegmentedControl(
              value: config.ai.anthropicMode,
              options: const ['claude-code', 'api'],
              onChanged: (v) => onChanged(anthropicMode: v),
            ),
          ),
          if (config.ai.anthropicMode == 'api') ...[
            ApiKeyField(provider: 'anthropic', theme: theme),
            BolanField(
              label: 'Model',
              child: BolanDropdown(
                value: config.ai.anthropicModel,
                options: const [
                  'claude-sonnet-4-20250514',
                  'claude-opus-4-20250514',
                  'claude-haiku-4-5-20251001',
                ],
                onChanged: (v) => onChanged(anthropicModel: v),
              ),
            ),
          ],
        ];
      case 'openai':
        return [
          ApiKeyField(provider: 'openai', theme: theme),
          BolanField(
            label: 'Model',
            child: BolanDropdown(
              value: config.ai.openaiModel,
              options: const [
                'gpt-4o',
                'gpt-4o-mini',
                'gpt-4.1',
                'gpt-4.1-mini',
                'o3-mini',
              ],
              onChanged: (v) => onChanged(openaiModel: v),
            ),
          ),
        ];
      case 'huggingface':
        return [
          ApiKeyField(provider: 'huggingface', theme: theme),
          BolanField(
            label: 'Model',
            help: 'HuggingFace model ID (must support Inference API)',
            child: BolanDropdown(
              value: config.ai.huggingfaceModel,
              options: const [
                'moonshotai/Kimi-K2-Instruct-0905',
                'Qwen/Qwen2.5-Coder-32B-Instruct',
                'deepseek-ai/DeepSeek-R1',
                'meta-llama/Llama-3.3-70B-Instruct',
                'mistralai/Mistral-Small-24B-Instruct-2501',
              ],
              onChanged: (v) => onChanged(huggingfaceModel: v),
            ),
          ),
        ];
      case 'ollama':
        return [
          BolanField(
            label: 'URL',
            child: BolanTextField(
              value: config.ai.ollamaUrl,
              hint: 'http://127.0.0.1:11434',
              onChanged: (v) => onChanged(ollamaUrl: v),
            ),
          ),
          BolanField(
            label: 'Model',
            child: BolanTextField(
              value: config.ai.model,
              hint: 'llama3',
              onChanged: (v) => onChanged(model: v),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        BolanToggle(
          label: 'Enable AI Features',
          value: config.ai.enabled,
          onChanged: (v) => onChanged(enabled: v),
        ),
        BolanToggle(
          label: 'Command Suggestions',
          help: 'Suggest next command after each execution',
          value: config.ai.commandSuggestions,
          onChanged: (v) => onChanged(commandSuggestions: v),
        ),
        BolanToggle(
          label: 'Smart History Search',
          help: 'Use AI for natural language history search (Ctrl+R)',
          value: config.ai.smartHistorySearch,
          onChanged: (v) => onChanged(smartHistorySearch: v),
        ),
        BolanToggle(
          label: 'Share History with AI',
          help: 'Send recent commands for better suggestions',
          value: config.ai.shareHistory,
          onChanged: (v) => onChanged(shareHistory: v),
        ),
        const SizedBox(height: 8),
        BolanField(
          label: 'Provider',
          child: BolanSegmentedControl(
            value: config.ai.provider,
            options: const [
              'local',
              'google',
              'anthropic',
              'openai',
              'huggingface',
              'ollama'
            ],
            onChanged: (v) => onChanged(provider: v),
          ),
        ),
        ..._providerSettings(),
        const SizedBox(height: 16),
        TestConnectionButton(
          config: config.ai,
          theme: theme,
        ),
      ],
    );
  }
}

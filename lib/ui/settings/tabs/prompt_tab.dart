import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/prompt_style.dart';
import '../prompt_editor.dart';

class PromptTab extends StatelessWidget {
  final AppConfig config;
  final ValueChanged<List<String>> onChipsChanged;
  final ValueChanged<PromptStyleConfig> onStyleChanged;

  const PromptTab({
    super.key,
    required this.config,
    required this.onChipsChanged,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        PromptEditor(
          activeChipIds: config.general.promptChips,
          promptStyle: config.general.promptStyle,
          onChanged: onChipsChanged,
          onStyleChanged: onStyleChanged,
        ),
      ],
    );
  }
}

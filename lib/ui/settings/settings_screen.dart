import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_loader.dart';
import '../../core/theme/bolan_theme.dart';

/// Settings screen for editing all config.toml options.
///
/// Opened via Cmd+, or from the tab bar actions.
class SettingsScreen extends StatefulWidget {
  final ConfigLoader configLoader;

  const SettingsScreen({super.key, required this.configLoader});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.configLoader.config;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.tabBarBackground,
        title: Text(
          'Settings',
          style: TextStyle(
            color: theme.foreground,
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.foreground, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Editor section
          _SectionHeader(title: 'Editor', theme: theme),
          const SizedBox(height: 8),
          _TextOption(
            label: 'Font Family',
            value: _config.editor.fontFamily,
            theme: theme,
            onChanged: (v) => _updateEditor(fontFamily: v),
          ),
          _SliderOption(
            label: 'Font Size',
            value: _config.editor.fontSize,
            min: 8,
            max: 32,
            theme: theme,
            onChanged: (v) => _updateEditor(fontSize: v),
          ),
          _SliderOption(
            label: 'Line Height',
            value: _config.editor.lineHeight,
            min: 1.0,
            max: 2.5,
            theme: theme,
            onChanged: (v) => _updateEditor(lineHeight: v),
          ),
          _DropdownOption(
            label: 'Cursor Style',
            value: _config.editor.cursorStyle,
            options: const ['block', 'underline', 'bar'],
            theme: theme,
            onChanged: (v) => _updateEditor(cursorStyle: v),
          ),
          _ToggleOption(
            label: 'Cursor Blink',
            value: _config.editor.cursorBlink,
            theme: theme,
            onChanged: (v) => _updateEditor(cursorBlink: v),
          ),
          _SliderOption(
            label: 'Scrollback Lines',
            value: _config.editor.scrollbackLines.toDouble(),
            min: 100,
            max: 100000,
            divisions: 999,
            theme: theme,
            onChanged: (v) =>
                _updateEditor(scrollbackLines: v.round()),
          ),

          const SizedBox(height: 24),

          // General section
          _SectionHeader(title: 'General', theme: theme),
          const SizedBox(height: 8),
          _TextOption(
            label: 'Shell',
            value: _config.general.shell,
            hint: 'Default (from \$SHELL)',
            theme: theme,
            onChanged: (v) => _updateGeneral(shell: v),
          ),
          _TextOption(
            label: 'Working Directory',
            value: _config.general.workingDirectory,
            hint: 'Default (home)',
            theme: theme,
            onChanged: (v) => _updateGeneral(workingDirectory: v),
          ),

          const SizedBox(height: 24),

          // AI section
          _SectionHeader(title: 'AI', theme: theme),
          const SizedBox(height: 8),
          _ToggleOption(
            label: 'Enable AI Features',
            value: _config.ai.enabled,
            theme: theme,
            onChanged: (v) => _updateAi(enabled: v),
          ),
          _DropdownOption(
            label: 'Provider',
            value: _config.ai.provider,
            options: const ['ollama', 'openai', 'anthropic'],
            theme: theme,
            onChanged: (v) => _updateAi(provider: v),
          ),
          _TextOption(
            label: 'Model',
            value: _config.ai.model,
            hint: 'Default',
            theme: theme,
            onChanged: (v) => _updateAi(model: v),
          ),
          _TextOption(
            label: 'Ollama URL',
            value: _config.ai.ollamaUrl,
            theme: theme,
            onChanged: (v) => _updateAi(ollamaUrl: v),
          ),

          const SizedBox(height: 32),

          // Config file location hint
          Text(
            'Config file: ~/.config/bolan/config.toml',
            style: TextStyle(
              color: theme.dimForeground,
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _updateEditor({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    String? cursorStyle,
    bool? cursorBlink,
    int? scrollbackLines,
  }) {
    setState(() {
      _config = AppConfig(
        general: _config.general,
        editor: EditorConfig(
          fontFamily: fontFamily ?? _config.editor.fontFamily,
          fontSize: fontSize ?? _config.editor.fontSize,
          lineHeight: lineHeight ?? _config.editor.lineHeight,
          cursorStyle: cursorStyle ?? _config.editor.cursorStyle,
          cursorBlink: cursorBlink ?? _config.editor.cursorBlink,
          scrollbackLines: scrollbackLines ?? _config.editor.scrollbackLines,
          blockMode: _config.editor.blockMode,
        ),
        ai: _config.ai,
        activeTheme: _config.activeTheme,
      );
    });
    widget.configLoader.save(_config);
  }

  void _updateGeneral({String? shell, String? workingDirectory}) {
    setState(() {
      _config = AppConfig(
        general: GeneralConfig(
          shell: shell ?? _config.general.shell,
          workingDirectory:
              workingDirectory ?? _config.general.workingDirectory,
          restoreSessions: _config.general.restoreSessions,
        ),
        editor: _config.editor,
        ai: _config.ai,
        activeTheme: _config.activeTheme,
      );
    });
    widget.configLoader.save(_config);
  }

  void _updateAi({
    String? provider,
    String? model,
    String? ollamaUrl,
    bool? enabled,
  }) {
    setState(() {
      _config = AppConfig(
        general: _config.general,
        editor: _config.editor,
        ai: AiConfig(
          provider: provider ?? _config.ai.provider,
          model: model ?? _config.ai.model,
          ollamaUrl: ollamaUrl ?? _config.ai.ollamaUrl,
          enabled: enabled ?? _config.ai.enabled,
        ),
        activeTheme: _config.activeTheme,
      );
    });
    widget.configLoader.save(_config);
  }
}

// --- Reusable option widgets ---

class _SectionHeader extends StatelessWidget {
  final String title;
  final BolonTheme theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: theme.foreground,
        fontFamily: 'JetBrainsMono',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TextOption extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final BolonTheme theme;
  final ValueChanged<String> onChanged;

  const _TextOption({
    required this.label,
    required this.value,
    this.hint,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                color: theme.blockHeaderFg,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: theme.statusChipBg,
              borderRadius: BorderRadius.circular(4),
              child: TextField(
                controller: TextEditingController(text: value),
                style: TextStyle(
                  color: theme.foreground,
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: theme.dimForeground,
                    fontSize: 12,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.blockBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.blockBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.cursor),
                  ),
                  isDense: true,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderOption extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final BolonTheme theme;
  final ValueChanged<double> onChanged;

  const _SliderOption({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                color: theme.blockHeaderFg,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: theme.cursor,
                inactiveTrackColor: theme.statusChipBg,
                thumbColor: theme.cursor,
                overlayColor: theme.cursor.withAlpha(30),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              value == value.roundToDouble()
                  ? '${value.round()}'
                  : value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.foreground,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool value;
  final BolonTheme theme;
  final ValueChanged<bool> onChanged;

  const _ToggleOption({
    required this.label,
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                color: theme.blockHeaderFg,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.cursor,
            inactiveTrackColor: theme.statusChipBg,
          ),
        ],
      ),
    );
  }
}

class _DropdownOption extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final BolonTheme theme;
  final ValueChanged<String> onChanged;

  const _DropdownOption({
    required this.label,
    required this.value,
    required this.options,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                color: theme.blockHeaderFg,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
          ),
          Material(
            color: theme.statusChipBg,
            borderRadius: BorderRadius.circular(4),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: theme.blockBackground,
              underline: const SizedBox.shrink(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              style: TextStyle(
                color: theme.foreground,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

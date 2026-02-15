import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai/api_key_storage.dart';
import '../../core/ai/claude_provider.dart';
import '../../core/ai/gemini_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_loader.dart';
import '../../core/theme/bolan_theme.dart';

/// Settings screen with sidebar tab navigation.
class SettingsScreen extends StatefulWidget {
  final ConfigLoader configLoader;

  const SettingsScreen({super.key, required this.configLoader});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppConfig _config;
  int _selectedTab = 0;

  static const _tabs = ['General', 'Editor', 'AI'];
  static const _tabIcons = [
    Icons.settings_outlined,
    Icons.edit_outlined,
    Icons.auto_awesome_outlined,
  ];
  static const _maxContentWidth = 560.0;

  @override
  void initState() {
    super.initState();
    _config = widget.configLoader.config;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape):
            () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.background,
          body: Row(
            children: [
              // Sidebar
              Container(
                width: 180,
                color: theme.tabBarBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          color: theme.foreground,
                          fontFamily: 'Operator Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _tabs.length; i++)
                      _SidebarTab(
                        icon: _tabIcons[i],
                        label: _tabs[i],
                        isSelected: _selectedTab == i,
                        theme: theme,
                        onTap: () => setState(() => _selectedTab = i),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Bolan v0.1.0',
                        style: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: 'Operator Mono',
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Column(
                  children: [
                    // Top bar with close button
                    Container(
                      height: 48,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Icon(Icons.close,
                            color: theme.foreground, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    // Settings content
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: _maxContentWidth),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 8),
                            children: _buildTabContent(theme),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabContent(BolonTheme theme) {
    return switch (_selectedTab) {
      0 => _buildGeneralTab(theme),
      1 => _buildEditorTab(theme),
      2 => _buildAiTab(theme),
      _ => [],
    };
  }

  // ---- General Tab ----

  List<Widget> _buildGeneralTab(BolonTheme theme) {
    return [
      _Field(
        label: 'Shell',
        help: 'Leave empty to use \$SHELL',
        theme: theme,
        child: _Input(
          value: _config.general.shell,
          hint: '/bin/zsh',
          theme: theme,
          onChanged: (v) => _updateGeneral(shell: v),
        ),
      ),
      _Field(
        label: 'Working Directory',
        help: 'Default directory for new tabs',
        theme: theme,
        child: _Input(
          value: _config.general.workingDirectory,
          hint: '~ (home)',
          theme: theme,
          onChanged: (v) => _updateGeneral(workingDirectory: v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Config: ~/.config/bolan/config.toml',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: 'Operator Mono',
            fontSize: 11,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ];
  }

  // ---- Editor Tab ----

  List<Widget> _buildEditorTab(BolonTheme theme) {
    return [
      _Field(
        label: 'Font Family',
        theme: theme,
        child: _Input(
          value: _config.editor.fontFamily,
          hint: 'Operator Mono',
          theme: theme,
          onChanged: (v) => _updateEditor(fontFamily: v),
        ),
      ),
      _Field(
        label: 'Font Size',
        theme: theme,
        child: _Slider(
          value: _config.editor.fontSize,
          min: 8,
          max: 32,
          step: 1,
          suffix: 'px',
          theme: theme,
          onChanged: (v) => _updateEditor(fontSize: v),
        ),
      ),
      _Field(
        label: 'Line Height',
        theme: theme,
        child: _Slider(
          value: _config.editor.lineHeight,
          min: 1.0,
          max: 2.0,
          step: 0.1,
          theme: theme,
          onChanged: (v) => _updateEditor(lineHeight: v),
        ),
      ),
      _Field(
        label: 'Cursor Style',
        theme: theme,
        child: _SegmentedControl(
          value: _config.editor.cursorStyle,
          options: const ['block', 'underline', 'bar'],
          theme: theme,
          onChanged: (v) => _updateEditor(cursorStyle: v),
        ),
      ),
      _Field(
        label: 'Scrollback Lines',
        theme: theme,
        child: _Slider(
          value: _config.editor.scrollbackLines.toDouble(),
          min: 1000,
          max: 50000,
          step: 1000,
          theme: theme,
          onChanged: (v) => _updateEditor(scrollbackLines: v.round()),
        ),
      ),
    ];
  }

  // ---- AI Tab ----

  List<Widget> _buildAiTab(BolonTheme theme) {
    return [
      _Toggle(
        label: 'Enable AI Features',
        value: _config.ai.enabled,
        theme: theme,
        onChanged: (v) => _updateAi(enabled: v),
      ),
      _Toggle(
        label: 'Command Suggestions',
        help: 'Suggest next command after each execution',
        value: _config.ai.commandSuggestions,
        theme: theme,
        onChanged: (v) => _updateAi(commandSuggestions: v),
      ),
      _Toggle(
        label: 'Share History with AI',
        help: 'Send recent commands for better suggestions',
        value: _config.ai.shareHistory,
        theme: theme,
        onChanged: (v) => _updateAi(shareHistory: v),
      ),
      const SizedBox(height: 8),
      _Field(
        label: 'Provider',
        theme: theme,
        child: _SegmentedControl(
          value: _config.ai.provider,
          options: const ['gemini', 'anthropic', 'openai', 'ollama'],
          theme: theme,
          onChanged: (v) => _updateAi(provider: v),
        ),
      ),

      // Provider-specific settings
      ..._buildProviderSettings(theme),

      // Test connection
      const SizedBox(height: 16),
      _TestConnectionButton(
        config: _config.ai,
        theme: theme,
      ),
    ];
  }

  List<Widget> _buildProviderSettings(BolonTheme theme) {
    switch (_config.ai.provider) {
      case 'gemini':
        return [
          _ApiKeyField(provider: 'gemini', theme: theme),
          _Field(
            label: 'Model',
            theme: theme,
            child: _Input(
              value: _config.ai.geminiModel,
              hint: 'gemma-3-27b-it',
              theme: theme,
              onChanged: (v) => _updateAi(geminiModel: v),
            ),
          ),
        ];
      case 'anthropic':
        return [
          _Field(
            label: 'Mode',
            help: 'Use Claude Code CLI or API key',
            theme: theme,
            child: _SegmentedControl(
              value: _config.ai.anthropicMode,
              options: const ['claude-code', 'api'],
              theme: theme,
              onChanged: (v) => _updateAi(anthropicMode: v),
            ),
          ),
          if (_config.ai.anthropicMode == 'api') ...[
            _ApiKeyField(provider: 'anthropic', theme: theme),
            _Field(
              label: 'Model',
              theme: theme,
              child: _Input(
                value: _config.ai.anthropicModel,
                hint: 'claude-sonnet-4-20250514',
                theme: theme,
                onChanged: (v) => _updateAi(anthropicModel: v),
              ),
            ),
          ],
        ];
      case 'openai':
        return [
          _ApiKeyField(provider: 'openai', theme: theme),
          _Field(
            label: 'Model',
            theme: theme,
            child: _Input(
              value: _config.ai.openaiModel,
              hint: 'gpt-4o',
              theme: theme,
              onChanged: (v) => _updateAi(openaiModel: v),
            ),
          ),
        ];
      case 'ollama':
        return [
          _Field(
            label: 'URL',
            theme: theme,
            child: _Input(
              value: _config.ai.ollamaUrl,
              hint: 'http://127.0.0.1:11434',
              theme: theme,
              onChanged: (v) => _updateAi(ollamaUrl: v),
            ),
          ),
          _Field(
            label: 'Model',
            theme: theme,
            child: _Input(
              value: _config.ai.model,
              hint: 'llama3',
              theme: theme,
              onChanged: (v) => _updateAi(model: v),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  // ---- Update methods ----

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
          scrollableBlocks: _config.editor.scrollableBlocks,
        ),
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
    String? geminiModel,
    String? openaiModel,
    String? anthropicModel,
    String? anthropicMode,
    bool? enabled,
    bool? commandSuggestions,
    bool? shareHistory,
  }) {
    setState(() {
      _config = AppConfig(
        general: _config.general,
        editor: _config.editor,
        ai: AiConfig(
          provider: provider ?? _config.ai.provider,
          model: model ?? _config.ai.model,
          ollamaUrl: ollamaUrl ?? _config.ai.ollamaUrl,
          geminiModel: geminiModel ?? _config.ai.geminiModel,
          openaiModel: openaiModel ?? _config.ai.openaiModel,
          anthropicModel: anthropicModel ?? _config.ai.anthropicModel,
          anthropicMode: anthropicMode ?? _config.ai.anthropicMode,
          enabled: enabled ?? _config.ai.enabled,
          commandSuggestions:
              commandSuggestions ?? _config.ai.commandSuggestions,
          shareHistory: shareHistory ?? _config.ai.shareHistory,
        ),
        activeTheme: _config.activeTheme,
      );
    });
    widget.configLoader.save(_config);
  }
}

// ---- Reusable Components ----

class _SidebarTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _SidebarTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isSelected ? theme.blockBackground : Colors.transparent,
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isSelected ? theme.foreground : theme.dimForeground),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? theme.foreground : theme.dimForeground,
                  fontFamily: 'Operator Mono',
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w500 : FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? help;
  final BolonTheme theme;
  final Widget child;

  const _Field({
    required this.label,
    this.help,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.foreground,
              fontFamily: 'Operator Mono',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (help != null) ...[
            const SizedBox(height: 2),
            Text(
              help!,
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: 'Operator Mono',
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final String value;
  final String hint;
  final BolonTheme theme;
  final ValueChanged<String> onChanged;
  final bool obscure;

  const _Input({
    required this.value,
    required this.hint,
    required this.theme,
    required this.onChanged,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.statusChipBg,
      borderRadius: BorderRadius.circular(6),
      child: TextField(
        controller: TextEditingController(text: value),
        obscureText: obscure,
        style: TextStyle(
          color: theme.foreground,
          fontFamily: 'Operator Mono',
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.dimForeground, fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.blockBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.blockBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.cursor),
          ),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final String? suffix;
  final BolonTheme theme;
  final ValueChanged<double> onChanged;

  const _Slider({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.suffix,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final divisions = ((max - min) / step).round();
    final displayValue = value == value.roundToDouble()
        ? '${value.round()}'
        : value.toStringAsFixed(1);

    return Row(
      children: [
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
              onChanged: (v) {
                // Snap to step
                final snapped = (v / step).round() * step;
                onChanged(snapped);
              },
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '$displayValue${suffix ?? ''}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: theme.foreground,
              fontFamily: 'Operator Mono',
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final String value;
  final List<String> options;
  final BolonTheme theme;
  final ValueChanged<String> onChanged;

  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++)
          GestureDetector(
            onTap: () => onChanged(options[i]),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: value == options[i]
                      ? theme.cursor.withAlpha(25)
                      : theme.statusChipBg,
                  border: Border.all(
                    color: value == options[i]
                        ? theme.cursor.withAlpha(80)
                        : theme.blockBorder,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0
                        ? const Radius.circular(6)
                        : Radius.zero,
                    right: i == options.length - 1
                        ? const Radius.circular(6)
                        : Radius.zero,
                  ),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    color: value == options[i]
                        ? theme.cursor
                        : theme.dimForeground,
                    fontFamily: 'Operator Mono',
                    fontSize: 12,
                    fontWeight: value == options[i]
                        ? FontWeight.w600
                        : FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final String? help;
  final bool value;
  final BolonTheme theme;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    this.help,
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: 'Operator Mono',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (help != null)
                  Text(
                    help!,
                    style: TextStyle(
                      color: theme.dimForeground,
                      fontFamily: 'Operator Mono',
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
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

class _ApiKeyField extends StatefulWidget {
  final String provider;
  final BolonTheme theme;

  const _ApiKeyField({required this.provider, required this.theme});

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  bool _hasKey = false;
  bool _editing = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    try {
      final has = await ApiKeyStorage.hasKey(widget.provider);
      if (mounted) setState(() => _hasKey = has);
    } on Exception {
      // Keychain error
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API Key',
            style: TextStyle(
              color: widget.theme.foreground,
              fontFamily: 'Operator Mono',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          if (_editing)
            Row(
              children: [
                Expanded(
                  child: _Input(
                    value: '',
                    hint: 'Paste API key...',
                    theme: widget.theme,
                    obscure: true,
                    onChanged: (v) => _controller.text = v,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Save',
                  color: widget.theme.exitSuccessFg,
                  theme: widget.theme,
                  onTap: _saveKey,
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  _hasKey ? '••••••••••••••••' : 'Not configured',
                  style: TextStyle(
                    color: _hasKey
                        ? widget.theme.foreground
                        : widget.theme.dimForeground,
                    fontFamily: 'Operator Mono',
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  label: _hasKey ? 'Change' : 'Set',
                  color: widget.theme.cursor,
                  theme: widget.theme,
                  onTap: () => setState(() => _editing = true),
                ),
                if (_hasKey) ...[
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Remove',
                    color: widget.theme.exitFailureFg,
                    theme: widget.theme,
                    onTap: _deleteKey,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _saveKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    try {
      await ApiKeyStorage.saveKey(widget.provider, key);
      _controller.clear();
      setState(() {
        _hasKey = true;
        _editing = false;
      });
    } on Exception {
      // Keychain error
    }
  }

  Future<void> _deleteKey() async {
    try {
      await ApiKeyStorage.deleteKey(widget.provider);
      setState(() => _hasKey = false);
    } on Exception {
      // Keychain error
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'Operator Mono',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _TestConnectionButton extends StatefulWidget {
  final AiConfig config;
  final BolonTheme theme;

  const _TestConnectionButton({
    required this.config,
    required this.theme,
  });

  @override
  State<_TestConnectionButton> createState() => _TestConnectionButtonState();
}

class _TestConnectionButtonState extends State<_TestConnectionButton> {
  bool _testing = false;
  String? _result;
  bool? _success;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _testing ? null : _test,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.theme.statusChipBg,
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: widget.theme.blockBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_testing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: widget.theme.cursor,
                      ),
                    )
                  else
                    Icon(Icons.science_outlined,
                        size: 16, color: widget.theme.foreground),
                  const SizedBox(width: 8),
                  Text(
                    _testing ? 'Testing...' : 'Test Connection',
                    style: TextStyle(
                      color: widget.theme.foreground,
                      fontFamily: 'Operator Mono',
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _success == true ? Icons.check_circle : Icons.error,
                size: 14,
                color: _success == true
                    ? widget.theme.exitSuccessFg
                    : widget.theme.exitFailureFg,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _result!,
                  style: TextStyle(
                    color: _success == true
                        ? widget.theme.exitSuccessFg
                        : widget.theme.exitFailureFg,
                    fontFamily: 'Operator Mono',
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
      _success = null;
    });

    try {
      final config = widget.config;

      if (config.provider == 'anthropic' &&
          config.anthropicMode == 'claude-code') {
        final available = await ClaudeProvider.isAvailable();
        if (available) {
          final provider = ClaudeProvider();
          await provider.generateContent('Say "ok" and nothing else.');
          setState(() {
            _result = 'Claude Code connected';
            _success = true;
          });
        } else {
          setState(() {
            _result = 'Claude Code not found in PATH';
            _success = false;
          });
        }
      } else {
        String? apiKey;
        try {
          apiKey = await ApiKeyStorage.readKey(config.provider);
        } on Exception {
          // Keychain error
        }
        if (apiKey == null || apiKey.isEmpty) {
          setState(() {
            _result = 'No API key configured';
            _success = false;
          });
          return;
        }

        final provider = GeminiProvider(
          apiKey: apiKey,
          model: config.geminiModel,
        );
        await provider.generateContent('Say "ok" and nothing else.');
        setState(() {
          _result = 'Connected to ${config.provider}';
          _success = true;
        });
      }
    } on Exception catch (e) {
      setState(() {
        _result = '$e';
        _success = false;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}

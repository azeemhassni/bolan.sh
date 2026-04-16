import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_provider_helper.dart';
import '../../core/ai/api_key_storage.dart';
import '../../core/ai/features/theme_generator.dart';
import '../../core/ai/model_manager.dart';
import '../../core/app_version.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_loader.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/theme/theme_registry.dart';
import '../../providers/model_download_provider.dart';
import '../shared/bolan_button.dart';
import '../shared/bolan_components.dart';
import 'font_picker.dart';
import 'prompt_editor.dart';
import 'theme_editor.dart';
import 'workspaces_tab.dart';

/// Settings screen with sidebar tab navigation.
class SettingsScreen extends StatefulWidget {
  final ConfigLoader configLoader;
  final ThemeRegistry themeRegistry;
  final int initialTab;

  const SettingsScreen({
    super.key,
    required this.configLoader,
    required this.themeRegistry,
    this.initialTab = 0,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AppConfig _config;
  late int _selectedTab;
  late final AnimationController _toastController;
  late final Animation<double> _toastOpacity;
  Timer? _toastTimer;
  Timer? _saveDebounce;
  String? _shellError;
  String? _workingDirError;
  bool _generatingTheme = false;
  String? _themeGenError;
  BolonTheme? _previewTheme;

  static const _tabs = [
    'General', 'Editor', 'Appearance', 'AI', 'Prompt', 'Workspaces',
  ];
  static const _tabIcons = [
    Icons.settings_outlined,
    Icons.edit_outlined,
    Icons.palette_outlined,
    Icons.auto_awesome_outlined,
    Icons.terminal_outlined,
    Icons.workspaces_outlined,
  ];
  static const _maxContentWidth = 860.0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _config = widget.configLoader.config;
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _toastOpacity =
        CurvedAnimation(parent: _toastController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _saveDebounce?.cancel();
    _toastController.dispose();
    super.dispose();
  }

  void _showSavedToast() {
    _toastTimer?.cancel();
    _toastController.forward(from: 0);
    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _toastController.reverse();
    });
  }

  void _save() {
    widget.configLoader.save(_config);
    // Debounce the toast so it doesn't flash on every keystroke
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _showSavedToast);
  }

  /// Resolves a shell name to a full path and validates it exists.
  /// Returns null if valid, or an error message string.
  String? _validateShell(String value) {
    if (value.isEmpty) return null; // empty = use $SHELL default
    var path = value;
    if (!path.contains('/')) {
      try {
        final result = Process.runSync('which', [path]);
        if (result.exitCode == 0) {
          path = (result.stdout as String).trim();
        }
      } on ProcessException {
        // ignore
      }
    }
    if (!File(path).existsSync()) {
      return 'Shell not found: $value';
    }
    return null;
  }

  /// Validates a working directory path exists.
  String? _validateWorkingDir(String value) {
    if (value.isEmpty) return null; // empty = use $HOME
    var path = value;
    final home = Platform.environment['HOME'] ?? '';
    if (path.startsWith('~/')) {
      path = '$home${path.substring(1)}';
    } else if (path == '~') {
      path = home;
    }
    if (!Directory(path).existsSync()) {
      return 'Directory not found: $value';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Focus(
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
                          fontFamily: theme.fontFamily,
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
                        'Bolan v$appVersion',
                        style: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: theme.fontFamily,
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
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 48),
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
                    Positioned(
                      top: 16,
                      right: 24,
                      child: FadeTransition(
                        opacity: _toastOpacity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.blockBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: theme.blockBorder, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 13,
                                  color: theme.ansiGreen),
                              const SizedBox(width: 6),
                              Text(
                                'Saved',
                                style: TextStyle(
                                  color: theme.dimForeground,
                                  fontFamily: theme.fontFamily,
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
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
    );
  }

  List<Widget> _buildTabContent(BolonTheme theme) {
    return switch (_selectedTab) {
      0 => _buildGeneralTab(theme),
      1 => _buildEditorTab(theme),
      2 => _buildAppearanceTab(theme),
      3 => _buildAiTab(theme),
      4 => _buildPromptTab(theme),
      5 => const [WorkspacesTab()],
      _ => [],
    };
  }

  // ---- Appearance Tab ----

  ThemeRegistry get _registry => widget.themeRegistry;

  List<Widget> _buildAppearanceTab(BolonTheme theme) {
    final themes = _registry.allThemes;
    final activeTheme = _registry.getTheme(_config.activeTheme);

    return [
      Text(
        'Theme',
        style: TextStyle(
          color: theme.foreground,
          fontFamily: theme.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in themes)
            _ThemeCard(
              theme: t,
              isActive: _config.activeTheme == t.name,
              currentTheme: theme,
              onTap: () {
                setState(() {
                  _config = _config.copyWith(activeTheme: t.name);
                });
                _save();
              },
            ),
        ],
      ),
      const SizedBox(height: 20),

      // Theme actions
      Row(
        children: [
          _ActionButton(
            label: 'Duplicate',
            color: theme.cursor,
            theme: theme,
            onTap: () => _duplicateTheme(activeTheme),
          ),
          const SizedBox(width: 12),
          _ActionButton(
            label: 'Export',
            color: theme.cursor,
            theme: theme,
            onTap: () => _exportTheme(activeTheme),
          ),
          const SizedBox(width: 12),
          _ActionButton(
            label: 'Import',
            color: theme.cursor,
            theme: theme,
            onTap: _importTheme,
          ),
          if (!activeTheme.isBuiltIn) ...[
            const SizedBox(width: 12),
            _ActionButton(
              label: 'Rename',
              color: theme.cursor,
              theme: theme,
              onTap: () => _renameTheme(activeTheme),
            ),
            const SizedBox(width: 12),
            _ActionButton(
              label: 'Delete',
              color: theme.exitFailureFg,
              theme: theme,
              onTap: () => _deleteTheme(activeTheme),
            ),
          ],
        ],
      ),
      const SizedBox(height: 24),

      // AI theme generator
      if (_config.ai.enabled)
        _AiThemeGenerator(
          generating: _generatingTheme,
          error: _themeGenError,
          previewTheme: _previewTheme,
          onGenerate: _generateTheme,
          onSave: _saveGeneratedTheme,
          onDiscard: () => setState(() {
            _previewTheme = null;
            _themeGenError = null;
          }),
        ),

      const SizedBox(height: 24),

      // Color editor
      ThemeEditor(
        theme: activeTheme,
        editable: !activeTheme.isBuiltIn,
        onChanged: (updated) async {
          await _registry.saveCustomTheme(updated);
          setState(() {});
        },
      ),
    ];
  }

  Future<void> _generateTheme(String description) async {
    if (description.trim().isEmpty) return;
    setState(() {
      _generatingTheme = true;
      _themeGenError = null;
      _previewTheme = null;
    });
    try {
      final provider = await AiProviderHelper.create(
        providerName: _config.ai.provider,
        geminiModel: _config.ai.geminiModel,
        anthropicMode: _config.ai.anthropicMode,
      );
      if (provider == null) {
        setState(() {
          _themeGenError = 'No AI provider configured.';
          _generatingTheme = false;
        });
        return;
      }
      final generator = ThemeGenerator(provider: provider);
      final theme = await generator.generate(description.trim());
      if (!mounted) return;
      setState(() {
        _previewTheme = theme;
        _generatingTheme = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _themeGenError = 'Failed to generate: $e';
        _generatingTheme = false;
      });
    }
  }

  Future<void> _saveGeneratedTheme() async {
    final theme = _previewTheme;
    if (theme == null) return;
    await _registry.saveCustomTheme(theme);
    setState(() {
      _config = _config.copyWith(activeTheme: theme.name);
      _previewTheme = null;
    });
    _save();
  }

  Future<void> _duplicateTheme(BolonTheme source) async {
    final newName = '${source.name}-copy';
    final displayName = '${source.displayName} Copy';
    final copy = await _registry.duplicateTheme(source, newName, displayName);
    if (!mounted) return;
    setState(() {
      _config = _config.copyWith(activeTheme: copy.name);
    });
    _save();
  }

  Future<void> _exportTheme(BolonTheme theme) async {
    final location = await getSaveLocation(
      suggestedName: '${theme.name}.toml',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'TOML', extensions: ['toml']),
      ],
    );
    if (location == null) return;
    await _registry.exportTheme(theme, location.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${location.path}')),
      );
    }
  }

  Future<void> _importTheme() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'TOML', extensions: ['toml']),
      ],
    );
    if (file == null) return;

    final theme = await _registry.importTheme(file.path);
    if (theme != null && mounted) {
      setState(() {
        _config = _config.copyWith(activeTheme: theme.name);
      });
      _save();
    }
  }

  Future<void> _renameTheme(BolonTheme theme) async {
    final controller = TextEditingController(text: theme.displayName);
    final t = BolonTheme.of(context);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: t.blockBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rename Theme',
                style: TextStyle(
                  color: t.foreground,
                  fontFamily: theme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: t.statusChipBg,
                borderRadius: BorderRadius.circular(6),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(
                    color: t.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: t.blockBorder),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel',
                        style: TextStyle(color: t.dimForeground)),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(controller.text.trim()),
                    child: Text('Rename',
                        style: TextStyle(color: t.cursor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    controller.dispose();
    if (newName == null || newName.isEmpty || newName == theme.displayName) {
      return;
    }

    final slug = newName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await _registry.removeCustomTheme(theme.name);
    final renamed = theme.copyWith(name: slug, displayName: newName);
    await _registry.saveCustomTheme(renamed);
    if (!mounted) return;
    setState(() {
      _config = _config.copyWith(activeTheme: slug);
    });
    _save();
  }

  Future<void> _deleteTheme(BolonTheme theme) async {
    await _registry.removeCustomTheme(theme.name);
    if (!mounted) return;
    setState(() {
      _config = _config.copyWith(activeTheme: 'default-dark');
    });
    _save();
  }

  // ---- Prompt Tab ----

  List<Widget> _buildPromptTab(BolonTheme theme) {
    return [
      PromptEditor(
        activeChipIds: _config.general.promptChips,
        onChanged: (chips) {
          setState(() {
            _config = _config.copyWith(
              general: GeneralConfig(
                shell: _config.general.shell,
                workingDirectory: _config.general.workingDirectory,
                restoreSessions: _config.general.restoreSessions,
                confirmOnQuit: _config.general.confirmOnQuit,
                notifyLongRunning: _config.general.notifyLongRunning,
                longRunningThresholdSeconds:
                    _config.general.longRunningThresholdSeconds,
                startupCommands: _config.general.startupCommands,
                promptChips: chips,
              ),
            );
          });
          _save();
        },
      ),
    ];
  }

  // ---- General Tab ----

  List<Widget> _buildGeneralTab(BolonTheme theme) {
    return [
      BolanField(
        label: 'Shell',
        help: 'Leave empty to use \$SHELL',
        error: _shellError,
        child: BolanTextField(
          value: _config.general.shell,
          hint: '/bin/zsh',
          onChanged: (v) {
            setState(() => _shellError = _validateShell(v));
            _updateGeneral(shell: v);
          },
        ),
      ),
      BolanField(
        label: 'Working Directory',
        help: 'Default directory for new tabs',
        error: _workingDirError,
        child: BolanTextField(
          value: _config.general.workingDirectory,
          hint: '~ (home)',
          onChanged: (v) {
            setState(() => _workingDirError = _validateWorkingDir(v));
            _updateGeneral(workingDirectory: v);
          },
        ),
      ),
      BolanToggle(
        label: 'Confirm on Quit',
        help: 'Ask before closing the app',
        value: _config.general.confirmOnQuit,
        onChanged: (v) => _updateGeneral(confirmOnQuit: v),
      ),
      BolanToggle(
        label: 'Restore Sessions',
        help: 'Reopen tabs and panes on startup',
        value: _config.general.restoreSessions,
        onChanged: (v) => _updateGeneral(restoreSessions: v),
      ),
      BolanToggle(
        label: 'Long-Running Notifications',
        help: 'Notify when commands take longer than ${_config.general.longRunningThresholdSeconds}s',
        value: _config.general.notifyLongRunning,
        onChanged: (v) => _updateGeneral(notifyLongRunning: v),
      ),
      BolanToggle(
        label: 'Auto-Check for Updates',
        help: 'Check for new versions on startup',
        value: _config.update.autoCheck,
        onChanged: (v) => _updateUpdate(autoCheck: v),
      ),
      const SizedBox(height: 32),
      Align(
        alignment: Alignment.centerLeft,
        child: BolanButton.danger(
          label: 'Restore All Settings to Defaults',
          icon: Icons.restore,
          onTap: () => _confirmRestoreDefaults(theme),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Config: ~/.config/bolan/config.toml',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
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
      BolanField(
        label: 'Font Family',
        child: FontPicker(
          selectedFont: _config.editor.fontFamily,
          theme: theme,
          onSelected: (v) => _updateEditor(fontFamily: v),
        ),
      ),
      BolanField(
        label: 'Font Size',
        child: BolanSlider(
          value: _config.editor.fontSize,
          min: 8,
          max: 32,
          step: 1,
          suffix: 'px',
          onChanged: (v) => _updateEditor(fontSize: v),
        ),
      ),
      BolanField(
        label: 'Line Height',
        child: BolanSlider(
          value: _config.editor.lineHeight,
          min: 1.0,
          max: 2.0,
          step: 0.1,
          onChanged: (v) => _updateEditor(lineHeight: v),
        ),
      ),
      BolanField(
        label: 'Cursor Style',
        child: BolanSegmentedControl(
          value: _config.editor.cursorStyle,
          options: const ['block', 'underline', 'bar'],
          onChanged: (v) => _updateEditor(cursorStyle: v),
        ),
      ),
      BolanField(
        label: 'Scrollback Lines',
        child: BolanSlider(
          value: _config.editor.scrollbackLines.toDouble(),
          min: 1000,
          max: 50000,
          step: 1000,
          onChanged: (v) => _updateEditor(scrollbackLines: v.round()),
        ),
      ),
      BolanToggle(
        label: 'Ligatures',
        help: 'Enable font ligatures in block output (e.g., => != ->)',
        value: _config.editor.ligatures,
        onChanged: (v) => _updateEditor(ligatures: v),
      ),
    ];
  }

  void _confirmRestoreDefaults(BolonTheme theme) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.blockBackground,
        title: Text(
          'Restore defaults?',
          style: TextStyle(color: theme.foreground, fontFamily: theme.fontFamily),
        ),
        content: Text(
          'This resets all settings in this workspace to their defaults. '
          'Your command history, tabs, and workspaces are not affected.',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.foreground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _restoreDefaults();
            },
            child: Text('Restore', style: TextStyle(color: theme.exitFailureFg)),
          ),
        ],
      ),
    );
  }

  void _restoreDefaults() {
    setState(() {
      _config = const AppConfig();
    });
    _save();
  }

  // ---- AI Tab ----

  List<Widget> _buildAiTab(BolonTheme theme) {
    return [
      BolanToggle(
        label: 'Enable AI Features',
        value: _config.ai.enabled,
        onChanged: (v) => _updateAi(enabled: v),
      ),
      BolanToggle(
        label: 'Command Suggestions',
        help: 'Suggest next command after each execution',
        value: _config.ai.commandSuggestions,
        onChanged: (v) => _updateAi(commandSuggestions: v),
      ),
      BolanToggle(
        label: 'Smart History Search',
        help: 'Use AI for natural language history search (Ctrl+R)',
        value: _config.ai.smartHistorySearch,
        onChanged: (v) => _updateAi(smartHistorySearch: v),
      ),
      BolanToggle(
        label: 'Share History with AI',
        help: 'Send recent commands for better suggestions',
        value: _config.ai.shareHistory,
        onChanged: (v) => _updateAi(shareHistory: v),
      ),
      const SizedBox(height: 8),
      BolanField(
        label: 'Provider',
        child: BolanSegmentedControl(
          value: _config.ai.provider,
          options: const ['local', 'google', 'anthropic', 'openai', 'huggingface', 'ollama'],
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
      case 'local':
        return [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _LocalModelCard(
              theme: theme,
              activeSize: _config.ai.localModelSize,
              onChanged: () => setState(() {}),
              onSizeChanged: (size) =>
                  _updateAi(localModelSize: size),
            ),
          ),
        ];
      case 'google':
      case 'gemini': // legacy
        return [
          _ApiKeyField(provider: 'gemini', theme: theme),
          BolanField(
            label: 'Model',
            child: BolanDropdown(
              value: _config.ai.geminiModel,
              options: const [
                'gemini-2.5-flash',
                'gemini-2.5-pro',
                'gemini-2.0-flash',
                'gemma-3-27b-it',
              ],
              onChanged: (v) => _updateAi(geminiModel: v),
            ),
          ),
        ];
      case 'anthropic':
        return [
          BolanField(
            label: 'Mode',
            help: 'Use Claude Code CLI or API key',
            child: BolanSegmentedControl(
              value: _config.ai.anthropicMode,
              options: const ['claude-code', 'api'],
              onChanged: (v) => _updateAi(anthropicMode: v),
            ),
          ),
          if (_config.ai.anthropicMode == 'api') ...[
            _ApiKeyField(provider: 'anthropic', theme: theme),
            BolanField(
              label: 'Model',
              child: BolanDropdown(
                value: _config.ai.anthropicModel,
                options: const [
                  'claude-sonnet-4-20250514',
                  'claude-opus-4-20250514',
                  'claude-haiku-4-5-20251001',
                ],
                onChanged: (v) => _updateAi(anthropicModel: v),
              ),
            ),
          ],
        ];
      case 'openai':
        return [
          _ApiKeyField(provider: 'openai', theme: theme),
          BolanField(
            label: 'Model',
            child: BolanDropdown(
              value: _config.ai.openaiModel,
              options: const [
                'gpt-4o',
                'gpt-4o-mini',
                'gpt-4.1',
                'gpt-4.1-mini',
                'o3-mini',
              ],
              onChanged: (v) => _updateAi(openaiModel: v),
            ),
          ),
        ];
      case 'huggingface':
        return [
          _ApiKeyField(provider: 'huggingface', theme: theme),
          BolanField(
            label: 'Model',
            help: 'HuggingFace model ID (must support Inference API)',
            child: BolanDropdown(
              value: _config.ai.huggingfaceModel,
              options: const [
                'moonshotai/Kimi-K2-Instruct-0905',
                'Qwen/Qwen2.5-Coder-32B-Instruct',
                'deepseek-ai/DeepSeek-R1',
                'meta-llama/Llama-3.3-70B-Instruct',
                'mistralai/Mistral-Small-24B-Instruct-2501',
              ],
              onChanged: (v) => _updateAi(huggingfaceModel: v),
            ),
          ),
        ];
      case 'ollama':
        return [
          BolanField(
            label: 'URL',
            child: BolanTextField(
              value: _config.ai.ollamaUrl,
              hint: 'http://127.0.0.1:11434',
              onChanged: (v) => _updateAi(ollamaUrl: v),
            ),
          ),
          BolanField(
            label: 'Model',
            child: BolanTextField(
              value: _config.ai.model,
              hint: 'llama3',
              onChanged: (v) => _updateAi(model: v),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  // ---- Update methods ----

  void _updateGeneral({
    String? shell,
    String? workingDirectory,
    bool? confirmOnQuit,
    bool? restoreSessions,
    bool? notifyLongRunning,
  }) {
    setState(() {
      _config = _config.copyWith(
        general: GeneralConfig(
          shell: shell ?? _config.general.shell,
          workingDirectory:
              workingDirectory ?? _config.general.workingDirectory,
          restoreSessions:
              restoreSessions ?? _config.general.restoreSessions,
          confirmOnQuit: confirmOnQuit ?? _config.general.confirmOnQuit,
          notifyLongRunning:
              notifyLongRunning ?? _config.general.notifyLongRunning,
          longRunningThresholdSeconds:
              _config.general.longRunningThresholdSeconds,
          promptChips: _config.general.promptChips,
          startupCommands: _config.general.startupCommands,
        ),
      );
    });
    _save();
  }

  void _updateUpdate({bool? autoCheck}) {
    setState(() {
      _config = _config.copyWith(
        update: _config.update.copyWith(
          autoCheck: autoCheck ?? _config.update.autoCheck,
        ),
      );
    });
    _save();
  }

  void _updateEditor({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    String? cursorStyle,
    bool? cursorBlink,
    int? scrollbackLines,
    bool? ligatures,
  }) {
    setState(() {
      _config = _config.copyWith(
        editor: EditorConfig(
          fontFamily: fontFamily ?? _config.editor.fontFamily,
          fontSize: fontSize ?? _config.editor.fontSize,
          lineHeight: lineHeight ?? _config.editor.lineHeight,
          cursorStyle: cursorStyle ?? _config.editor.cursorStyle,
          cursorBlink: cursorBlink ?? _config.editor.cursorBlink,
          scrollbackLines: scrollbackLines ?? _config.editor.scrollbackLines,
          blockMode: _config.editor.blockMode,
          scrollableBlocks: _config.editor.scrollableBlocks,
          ligatures: ligatures ?? _config.editor.ligatures,
        ),
      );
    });
    _save();
  }

  void _updateAi({
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
  }) {
    // Belt-and-suspenders: this can be invoked from an async download
    // completion callback that fires after the user has navigated
    // away from Settings.
    if (!mounted) return;
    setState(() {
      _config = _config.copyWith(
        ai: AiConfig(
          provider: provider ?? _config.ai.provider,
          localModelSize: localModelSize ?? _config.ai.localModelSize,
          model: model ?? _config.ai.model,
          ollamaUrl: ollamaUrl ?? _config.ai.ollamaUrl,
          geminiModel: geminiModel ?? _config.ai.geminiModel,
          openaiModel: openaiModel ?? _config.ai.openaiModel,
          anthropicModel: anthropicModel ?? _config.ai.anthropicModel,
          huggingfaceModel: huggingfaceModel ?? _config.ai.huggingfaceModel,
          anthropicMode: anthropicMode ?? _config.ai.anthropicMode,
          enabled: enabled ?? _config.ai.enabled,
          commandSuggestions:
              commandSuggestions ?? _config.ai.commandSuggestions,
          smartHistorySearch:
              smartHistorySearch ?? _config.ai.smartHistorySearch,
          shareHistory: shareHistory ?? _config.ai.shareHistory,
        ),
      );
    });
    _save();
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
                  fontFamily: theme.fontFamily,
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

// ignore: unused_element
class _Field extends StatelessWidget {
  final String label;
  final String? help;
  final String? error;
  final BolonTheme theme;
  final Widget child;

  const _Field({
    required this.label,
    this.help, // ignore: unused_element_parameter
    this.error, // ignore: unused_element_parameter
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
              fontFamily: theme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (help != null && error == null) ...[
            const SizedBox(height: 2),
            Text(
              help!,
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 2),
            Text(
              error!,
              style: TextStyle(
                color: theme.exitFailureFg,
                fontFamily: theme.fontFamily,
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

// ignore: unused_element
class _ModelDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final BolonTheme theme;
  final ValueChanged<String> onChanged;

  const _ModelDropdown({
    required this.value,
    required this.options,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValue = options.contains(value) ? value : options.first;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.blockBackground,
        border: Border.all(color: theme.blockBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<String>(
        value: effectiveValue,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: theme.blockBackground,
        style: TextStyle(
          color: theme.foreground,
          fontFamily: theme.fontFamily,
          fontSize: 12,
        ),
        icon: Icon(Icons.expand_more, size: 16, color: theme.dimForeground),
        items: [
          for (final opt in options)
            DropdownMenuItem(value: opt, child: Text(opt)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _Input extends StatefulWidget {
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
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_Input old) {
    super.didUpdateWidget(old);
    // Only reset text if the value changed externally (not from typing).
    if (old.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.theme.statusChipBg,
      borderRadius: BorderRadius.circular(6),
      child: TextField(
        controller: _controller,
        obscureText: widget.obscure,
        style: TextStyle(
          color: widget.theme.foreground,
          fontFamily: widget.theme.fontFamily,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
              color: widget.theme.dimForeground, fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: widget.theme.blockBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: widget.theme.blockBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: widget.theme.cursor),
          ),
          isDense: true,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ignore: unused_element
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
    this.suffix, // ignore: unused_element_parameter
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
              fontFamily: theme.fontFamily,
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
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
                    fontFamily: theme.fontFamily,
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

// ignore: unused_element
class _Toggle extends StatelessWidget {
  final String label;
  final String? help;
  final bool value;
  final BolonTheme theme;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    this.help, // ignore: unused_element_parameter
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
                    fontFamily: theme.fontFamily,
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
                      fontFamily: theme.fontFamily,
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
              fontFamily: widget.theme.fontFamily,
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
                    fontFamily: widget.theme.fontFamily,
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
            fontFamily: theme.fontFamily,
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
                      fontFamily: widget.theme.fontFamily,
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
                    fontFamily: widget.theme.fontFamily,
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
      final provider = await AiProviderHelper.create(
        providerName: config.provider,
        geminiModel: config.geminiModel,
        anthropicMode: config.anthropicMode,
        ollamaUrl: config.ollamaUrl,
        ollamaModel: config.model.isNotEmpty ? config.model : 'llama3',
      );

      if (provider == null) {
        setState(() {
          // Ollama and Local LLM never need an API key, so this branch
          // only fires for cloud providers (OpenAI / Anthropic / Gemini).
          _result = 'No API key configured';
          _success = false;
        });
        return;
      }

      if (!await provider.isAvailable()) {
        setState(() {
          _result = '${provider.displayName} not available';
          _success = false;
        });
        return;
      }

      await provider.generateContent('Say "ok" and nothing else.');
      setState(() {
        _result = 'Connected to ${provider.displayName}';
        _success = true;
      });
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

class _ThemeCard extends StatelessWidget {
  final BolonTheme theme;
  final bool isActive;
  final BolonTheme currentTheme;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.currentTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 120,
          height: 90,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? currentTheme.cursor
                  : currentTheme.blockBorder,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Mini preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewLine('\$ ', theme.dimForeground, 'ls -la', theme.ansiGreen),
                      _previewLine('  ', theme.foreground, 'src/ lib/', theme.foreground),
                      _previewLine('\$ ', theme.dimForeground, 'git push', theme.ansiBlue),
                      _previewLine('  ', theme.exitSuccessFg, '✓ done', theme.exitSuccessFg),
                    ],
                  ),
                ),
              ),
              // Name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.tabBarBackground,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
                child: Text(
                  theme.displayName,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewLine(String prefix, Color prefixColor, String text, Color textColor) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: TextStyle(color: prefixColor, fontFamily: theme.fontFamily, fontSize: 7, height: 1.4),
          ),
          TextSpan(
            text: text,
            style: TextStyle(color: textColor, fontFamily: theme.fontFamily, fontSize: 7, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Inline card for local model size selection, download, and status.
class _LocalModelCard extends ConsumerStatefulWidget {
  final BolonTheme theme;
  final String activeSize;
  final VoidCallback onChanged;
  final ValueChanged<String> onSizeChanged;

  const _LocalModelCard({
    required this.theme,
    required this.activeSize,
    required this.onChanged,
    required this.onSizeChanged,
  });

  @override
  ConsumerState<_LocalModelCard> createState() => _LocalModelCardState();
}

class _LocalModelCardState extends ConsumerState<_LocalModelCard> {
  ModelSize _selectedSize = ModelSize.small;
  VoidCallback? _onCompleteCallback;
  // Cached notifier reference. Riverpod forbids `ref` access in
  // dispose, so we save the notifier from initState and use this
  // reference to detach our callback at teardown.
  ModelDownloadNotifier? _downloadNotifier;

  @override
  void initState() {
    super.initState();
    final dl = ref.read(modelDownloadProvider);
    _downloadNotifier = dl;
    // If a download is already running, sync selected size from it
    if (dl.state.downloading || dl.state.paused) {
      _selectedSize = dl.state.size;
    } else {
      _selectedSize = ModelSize.values.firstWhere(
        (s) => s.name == widget.activeSize,
        orElse: () => ModelManager.downloadedSize() ?? ModelSize.small,
      );
    }
    _onCompleteCallback = () {
      // The download notifier is global and outlives this card. If
      // the user navigates away from Settings before the download
      // finishes, the closure can fire on a disposed widget — guard
      // and bail.
      if (!mounted) return;
      widget.onSizeChanged(_selectedSize.name);
      widget.onChanged();
    };
    dl.onComplete = _onCompleteCallback;
  }

  @override
  void dispose() {
    // Detach our completion callback from the global notifier so it
    // doesn't reach back into a defunct State after the user leaves
    // Settings while a download is still running. Identity check
    // prevents clearing a newer instance's callback if the card was
    // recreated after we registered ours. We use the cached
    // [_downloadNotifier] because Riverpod refuses `ref` access
    // post-dispose.
    final dl = _downloadNotifier;
    if (dl != null && identical(dl.onComplete, _onCompleteCallback)) {
      dl.onComplete = null;
    }
    super.dispose();
  }

  bool get _isSelectedDownloaded =>
      ModelManager.isModelDownloaded(_selectedSize);

  bool get _hasPartial => hasPartialDownload(_selectedSize);

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final dl = ref.watch(modelDownloadProvider);
    final dlState = dl.state;
    final isActiveDownload =
        (dlState.downloading || dlState.paused) && dlState.size == _selectedSize;
    final t = widget.theme;
    final info = modelInfoMap[_selectedSize]!;
    final configuredSize = ModelSize.values.firstWhere(
      (s) => s.name == widget.activeSize,
      orElse: () => ModelSize.small,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.statusChipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model size selector
          Row(
            children: [
              for (final size in ModelSize.values) ...[
                if (size != ModelSize.values.first)
                  const SizedBox(width: 6),
                _ModelSizeChip(
                  size: size,
                  isSelected: _selectedSize == size,
                  isDownloaded: ModelManager.isModelDownloaded(size),
                  theme: t,
                  onTap: dlState.downloading
                      ? null
                      : () {
                          setState(() => _selectedSize = size);
                          // If this size is downloaded, make it the active model
                          if (ModelManager.isModelDownloaded(size)) {
                            widget.onSizeChanged(size.name);
                          }
                        },
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Selected model info
          Text(
            info.description,
            style: TextStyle(
              color: t.foreground,
              fontFamily: t.fontFamily,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Download: ${info.downloadSize}  ·  RAM: ${info.ramRequired}',
            style: TextStyle(
              color: t.dimForeground,
              fontFamily: t.fontFamily,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
          if (_selectedSize == ModelSize.xl)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: t.ansiYellow),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This model requires more memory and may be noticeably slower on machines with limited RAM or no dedicated GPU.',
                      style: TextStyle(
                        color: t.ansiYellow,
                        fontFamily: t.fontFamily,
                        fontSize: 10,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Action row
          Row(
            children: [
              if (_isSelectedDownloaded && configuredSize == _selectedSize)
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: Color(0xFF00FF92)),
                    const SizedBox(width: 6),
                    Text(
                      'Active  ·  ${_formatBytes(ModelManager.modelFileSize(_selectedSize))}',
                      style: TextStyle(
                        color: t.dimForeground,
                        fontFamily: t.fontFamily,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                )
              else if (_isSelectedDownloaded)
                Text(
                  'Downloaded  ·  ${_formatBytes(ModelManager.modelFileSize(_selectedSize))}',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                )
              else if (_hasPartial && !isActiveDownload)
                Text(
                  'Paused  ·  ${_formatBytes(partialDownloadSize(_selectedSize))} downloaded',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              const Spacer(),
              if (_isSelectedDownloaded && !isActiveDownload)
                GestureDetector(
                  onTap: () async {
                    await ModelManager.deleteModel(_selectedSize);
                    setState(() {});
                    widget.onChanged();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: t.exitFailureFg,
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              // Download / Resume button
              if (!_isSelectedDownloaded && !isActiveDownload)
                GestureDetector(
                  onTap: () {
                    final n = ref.read(modelDownloadProvider);
                    // Reuse the mounted-guarded closure from initState
                    // (also tracked for cleanup in dispose) instead of
                    // installing a fresh unguarded one on every click.
                    n.onComplete = _onCompleteCallback;
                    if (dlState.paused && dlState.size == _selectedSize) {
                      n.resume();
                    } else {
                      n.start(_selectedSize);
                    }
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF92),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (dlState.paused && dlState.size == _selectedSize) || _hasPartial
                            ? 'Resume'
                            : 'Download',
                        style: TextStyle(
                          color: t.background,
                          fontFamily: t.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              // Pause + Cancel during active download
              if (isActiveDownload && dlState.downloading) ...[
                GestureDetector(
                  onTap: () => ref.read(modelDownloadProvider).pause(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Pause',
                      style: TextStyle(
                        color: t.dimForeground,
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => ref.read(modelDownloadProvider).cancel(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: t.exitFailureFg,
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Download progress (shown while downloading or paused)
          if (isActiveDownload) ...[
            const SizedBox(height: 10),
            if (dlState.phaseCount > 1 && dlState.phase != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Step ${dlState.phaseIndex} of ${dlState.phaseCount}  ·  ${dlState.phaseLabel}',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: dlState.total > 0 ? dlState.progress : null,
                minHeight: 4,
                backgroundColor: t.blockBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00FF92)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatBytes(dlState.received)}${dlState.total > 0 ? ' / ${_formatBytes(dlState.total)}  ${(dlState.progress * 100).toStringAsFixed(0)}%' : ''}',
              style: TextStyle(
                color: t.dimForeground,
                fontFamily: t.fontFamily,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ],

          // Error
          if (dlState.error != null && dlState.size == _selectedSize)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 14, color: t.exitFailureFg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Download failed. Tap Download to retry.\n${dlState.error}',
                      style: TextStyle(
                        color: t.exitFailureFg,
                        fontFamily: t.fontFamily,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelSizeChip extends StatelessWidget {
  final ModelSize size;
  final bool isSelected;
  final bool isDownloaded;
  final BolonTheme theme;
  final VoidCallback? onTap;

  const _ModelSizeChip({
    required this.size,
    required this.isSelected,
    required this.isDownloaded,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = modelInfoMap[size]!;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor:
            onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? theme.blockBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00FF92)
                  : theme.blockBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDownloaded)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child:
                      Icon(Icons.check, size: 12, color: Color(0xFF00FF92)),
                ),
              Text(
                info.label,
                style: TextStyle(
                  color: isSelected ? theme.foreground : theme.dimForeground,
                  fontFamily: theme.fontFamily,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
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

class _AiThemeGenerator extends StatefulWidget {
  final bool generating;
  final String? error;
  final BolonTheme? previewTheme;
  final ValueChanged<String> onGenerate;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _AiThemeGenerator({
    required this.generating,
    this.error,
    this.previewTheme,
    required this.onGenerate,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  State<_AiThemeGenerator> createState() => _AiThemeGeneratorState();
}

class _AiThemeGeneratorState extends State<_AiThemeGenerator> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BolanSectionHeader('Generate with AI'),
        Row(
          children: [
            Expanded(
              child: Material(
                color: theme.statusChipBg,
                borderRadius: BorderRadius.circular(5),
                child: TextField(
                  controller: _controller,
                  enabled: !widget.generating,
                  onSubmitted: (_) => widget.onGenerate(_controller.text),
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe your theme... (e.g. "ocean sunset")',
                    hintStyle: TextStyle(
                        color: theme.dimForeground, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: theme.blockBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: theme.blockBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: theme.cursor),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            BolanButton.primary(
              label: widget.generating ? 'Generating...' : 'Generate',
              icon: widget.generating ? null : Icons.auto_awesome,
              onTap: widget.generating
                  ? null
                  : () => widget.onGenerate(_controller.text),
            ),
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: TextStyle(
              color: theme.exitFailureFg,
              fontFamily: theme.fontFamily,
              fontSize: 11,
            ),
          ),
        ],
        if (widget.previewTheme != null) ...[
          const SizedBox(height: 12),
          _ThemePreview(theme: widget.previewTheme!),
          const SizedBox(height: 8),
          Row(
            children: [
              BolanButton.primary(
                label: 'Save & Apply',
                icon: Icons.check,
                onTap: widget.onSave,
              ),
              const SizedBox(width: 8),
              BolanButton(
                label: 'Discard',
                onTap: widget.onDiscard,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final BolonTheme theme;
  const _ThemePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = BolonTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.blockBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theme.displayName,
            style: TextStyle(
              color: theme.foreground,
              fontFamily: t.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$ git status',
            style: TextStyle(
              color: theme.foreground,
              fontFamily: t.fontFamily,
              fontSize: 12,
            ),
          ),
          Text(
            'On branch main',
            style: TextStyle(
              color: theme.ansiGreen,
              fontFamily: t.fontFamily,
              fontSize: 12,
            ),
          ),
          Text(
            'modified:   src/app.dart',
            style: TextStyle(
              color: theme.ansiRed,
              fontFamily: t.fontFamily,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final c in [
                theme.ansiBlack, theme.ansiRed, theme.ansiGreen,
                theme.ansiYellow, theme.ansiBlue, theme.ansiMagenta,
                theme.ansiCyan, theme.ansiWhite,
              ])
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final c in [
                theme.ansiBrightBlack, theme.ansiBrightRed,
                theme.ansiBrightGreen, theme.ansiBrightYellow,
                theme.ansiBrightBlue, theme.ansiBrightMagenta,
                theme.ansiBrightCyan, theme.ansiBrightWhite,
              ])
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.cursor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'cursor / accent',
                  style: TextStyle(
                    color: theme.background,
                    fontFamily: t.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'dim text',
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: t.fontFamily,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

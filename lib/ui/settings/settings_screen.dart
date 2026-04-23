import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_version.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_loader.dart';
import '../../core/config/global_config.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/theme/theme_registry.dart';
import '../../core/workspace/workspace_paths.dart';
import 'keybindings_tab.dart';
import 'tabs/ai_tab.dart';
import 'tabs/appearance_tab.dart';
import 'tabs/editor_tab.dart';
import 'tabs/general_tab.dart';
import 'tabs/prompt_tab.dart';
import 'tabs/updates_tab.dart';
import 'widgets/sidebar_tab.dart';
import 'workspaces_tab.dart';

/// Settings screen with sidebar tab navigation.
class SettingsScreen extends StatefulWidget {
  final ConfigLoader configLoader;
  final GlobalConfigLoader globalConfigLoader;
  final ThemeRegistry themeRegistry;
  final int initialTab;
  final int navGeneration;

  const SettingsScreen({
    super.key,
    required this.configLoader,
    required this.globalConfigLoader,
    required this.themeRegistry,
    this.initialTab = 0,
    this.navGeneration = 0,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AppConfig _config;
  late GlobalConfig _globalConfig;
  late int _selectedTab;
  late final AnimationController _toastController;
  late final Animation<double> _toastOpacity;
  Timer? _toastTimer;
  Timer? _saveDebounce;

  // Tab indices: 0-3 = global tabs, 4-7 = workspace tabs.
  static const _globalTabs = ['Editor', 'Keybindings', 'Updates', 'Workspaces'];
  static const _globalTabIcons = [
    Icons.edit_outlined,
    Icons.keyboard_outlined,
    Icons.system_update_outlined,
    Icons.workspaces_outlined,
  ];
  static const _workspaceTabs = ['General', 'Appearance', 'Prompt', 'AI'];
  static const _workspaceTabIcons = [
    Icons.settings_outlined,
    Icons.palette_outlined,
    Icons.terminal_outlined,
    Icons.auto_awesome_outlined,
  ];
  static const _maxContentWidth = 860.0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _config = widget.configLoader.config;
    _globalConfig = widget.globalConfigLoader.config;
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _toastOpacity =
        CurvedAnimation(parent: _toastController, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(SettingsScreen old) {
    super.didUpdateWidget(old);
    if (widget.navGeneration != old.navGeneration) {
      setState(() => _selectedTab = widget.initialTab);
    }
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
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _showSavedToast);
  }

  void _saveGlobal() {
    widget.globalConfigLoader.save(_globalConfig);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _showSavedToast);
  }

  void _updateGeneral({
    String? shell,
    String? workingDirectory,
    bool? confirmOnQuit,
    bool? restoreSessions,
    bool? notifyLongRunning,
    bool? inheritWorkingDirectory,
    bool? hidePromptWhileRunning,
  }) {
    setState(() {
      _config = _config.copyWith(
        general: _config.general.copyWith(
          shell: shell,
          workingDirectory: workingDirectory,
          restoreSessions: restoreSessions,
          confirmOnQuit: confirmOnQuit,
          hidePromptWhileRunning: hidePromptWhileRunning,
          notifyLongRunning: notifyLongRunning,
          inheritWorkingDirectory: inheritWorkingDirectory,
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
      _globalConfig = _globalConfig.copyWith(
        editor: EditorConfig(
          fontFamily: fontFamily ?? _globalConfig.editor.fontFamily,
          fontSize: fontSize ?? _globalConfig.editor.fontSize,
          lineHeight: lineHeight ?? _globalConfig.editor.lineHeight,
          cursorStyle: cursorStyle ?? _globalConfig.editor.cursorStyle,
          cursorBlink: cursorBlink ?? _globalConfig.editor.cursorBlink,
          scrollbackLines:
              scrollbackLines ?? _globalConfig.editor.scrollbackLines,
          blockMode: _globalConfig.editor.blockMode,
          scrollableBlocks: _globalConfig.editor.scrollableBlocks,
          ligatures: ligatures ?? _globalConfig.editor.ligatures,
        ),
      );
    });
    _saveGlobal();
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
    // completion callback that fires after the user has navigated away
    // from Settings.
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

  void _restoreDefaults() {
    setState(() => _config = const AppConfig());
    _save();
  }

  String _activeWorkspaceName() =>
      WorkspacePaths.activeWorkspace?.name ?? 'Default';

  Color _activeWorkspaceColor(BolonTheme theme) =>
      WorkspacePaths.activeWorkspace?.accentColor ?? theme.cursor;

  Widget _buildTabContent(BolonTheme theme) {
    return switch (_selectedTab) {
      0 => EditorTab(
          globalConfig: _globalConfig,
          theme: theme,
          onChanged: _updateEditor,
        ),
      1 => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: KeybindingsTab(
            overrides: _globalConfig.keybindingOverrides,
            theme: theme,
            onChanged: (overrides) {
              setState(() {
                _globalConfig = _globalConfig.copyWith(
                    keybindingOverrides: overrides);
              });
              _saveGlobal();
            },
          ),
        ),
      2 => UpdatesTab(
          globalConfig: _globalConfig,
          onAutoCheckChanged: (v) {
            setState(() {
              _globalConfig = _globalConfig.copyWith(
                update: _globalConfig.update.copyWith(autoCheck: v),
              );
            });
            _saveGlobal();
          },
        ),
      3 => const SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: WorkspacesTab(),
        ),
      4 => GeneralTab(
          config: _config,
          theme: theme,
          onGeneralChanged: _updateGeneral,
          onAutoCheckUpdateChanged: (v) => _updateUpdate(autoCheck: v),
          onRestoreDefaults: _restoreDefaults,
        ),
      5 => AppearanceTab(
          config: _config,
          registry: widget.themeRegistry,
          theme: theme,
          onActiveThemeChanged: (name) {
            setState(() => _config = _config.copyWith(activeTheme: name));
            _save();
          },
        ),
      6 => PromptTab(
          config: _config,
          onChipsChanged: (chips) {
            setState(() {
              _config = _config.copyWith(
                general: _config.general.copyWith(promptChips: chips),
              );
            });
            _save();
          },
          onStyleChanged: (style) {
            setState(() {
              _config = _config.copyWith(
                general: _config.general.copyWith(promptStyle: style),
              );
            });
            _save();
          },
        ),
      7 => AiTab(
          config: _config,
          theme: theme,
          onChanged: _updateAi,
        ),
      _ => const SizedBox.shrink(),
    };
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
            _sidebar(theme),
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
                            child: _buildTabContent(theme),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _savedToast(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar(BolonTheme theme) {
    return Container(
      width: 180,
      color: theme.tabBarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          _sectionLabel(theme, 'GLOBAL', const EdgeInsets.only(left: 16, top: 8, bottom: 4)),
          for (var i = 0; i < _globalTabs.length; i++)
            SidebarTab(
              icon: _globalTabIcons[i],
              label: _globalTabs[i],
              isSelected: _selectedTab == i,
              theme: theme,
              onTap: () => setState(() => _selectedTab = i),
            ),
          _sectionLabel(theme, 'WORKSPACE', const EdgeInsets.only(left: 16, top: 16, bottom: 4)),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _activeWorkspaceColor(theme),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _activeWorkspaceName(),
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _workspaceTabs.length; i++)
            SidebarTab(
              icon: _workspaceTabIcons[i],
              label: _workspaceTabs[i],
              isSelected: _selectedTab == i + _globalTabs.length,
              theme: theme,
              onTap: () => setState(
                  () => _selectedTab = i + _globalTabs.length),
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
    );
  }

  Widget _sectionLabel(BolonTheme theme, String text, EdgeInsets padding) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          color: theme.dimForeground,
          fontFamily: theme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _savedToast(BolonTheme theme) {
    return Positioned(
      top: 16,
      right: 24,
      child: FadeTransition(
        opacity: _toastOpacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.blockBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.blockBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 13, color: theme.ansiGreen),
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
    );
  }
}

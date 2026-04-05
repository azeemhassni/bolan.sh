import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/actions/app_action.dart';
import '../../core/config/config_loader.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/pane/pane_manager.dart';
import '../../core/pane/pane_node.dart';
import '../../core/platform_shortcuts.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/config_provider.dart';
import '../../providers/font_size_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/theme_provider.dart';
import '../palette/command_palette.dart';
import '../settings/settings_screen.dart';
import '../shared/confirm_dialog.dart';
import 'empty_state.dart';
import 'pane_focus_registry.dart';
import 'pane_tree_widget.dart';
import 'tab_bar.dart';

/// Root layout widget for the terminal emulator.
///
/// Owns the [ConfigLoader] and syncs config changes to Riverpod providers
/// so the UI updates live when settings change.
class TerminalShell extends ConsumerStatefulWidget {
  const TerminalShell({super.key});

  @override
  ConsumerState<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends ConsumerState<TerminalShell>
    with WidgetsBindingObserver {
  final _configLoader = ConfigLoader();
  final _notificationService = NotificationService();
  bool _showPalette = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configLoader.addListener(_onConfigChanged);
    _configLoader.load();
    _configLoader.startWatching();
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(configLoaderProvider.notifier).state = _configLoader;
      ref.read(notificationServiceProvider.notifier).state =
          _notificationService;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    _configLoader.removeListener(_onConfigChanged);
    _configLoader.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _notificationService.setAppFocused(
      state == AppLifecycleState.resumed,
    );
  }

  void _onConfigChanged() {
    final config = _configLoader.config;
    final currentFontSize = ref.read(fontSizeProvider);
    if (config.editor.fontSize != currentFontSize) {
      ref.read(fontSizeProvider.notifier).setSize(config.editor.fontSize);
    }
    // Sync active theme
    final currentTheme = ref.read(activeThemeNameProvider);
    if (config.activeTheme != currentTheme) {
      ref.read(activeThemeNameProvider.notifier).state = config.activeTheme;
    }
  }

  /// Global key handler: forwards printable key presses to the focused pane's
  /// prompt input, so typing anywhere automatically goes to the right pane.
  bool _globalKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Cmd+Shift+P — command palette (works regardless of focus)
    if (event.logicalKey == LogicalKeyboardKey.keyP &&
        isPrimaryModifierPressed &&
        HardwareKeyboard.instance.isShiftPressed) {
      _togglePalette();
      return true;
    }

    // Cmd+Q — quit (works regardless of focus)
    if (event.logicalKey == LogicalKeyboardKey.keyQ && isPrimaryModifierPressed) {
      _quitWithConfirm();
      return true;
    }

    // Don't forward keys when palette is open
    if (_showPalette) return false;

    final s = ref.read(sessionProvider);
    final tab = s.activeTab;
    if (tab == null) return false;

    final promptState = PaneFocusRegistry.get(tab.focusedPaneId);
    if (promptState == null) return false;

    // Cmd+L (macOS) / Ctrl+L (Linux) — focus prompt and select all
    if (event.logicalKey == LogicalKeyboardKey.keyL && isPrimaryModifierPressed) {
      promptState.requestFocus();
      promptState.selectAll();
      return true;
    }

    // Don't interfere during command execution
    final session = tab.focusedSession;
    if (session != null && session.isCommandRunning) return false;
    if (promptState.isHistorySearchOpen) return false;

    final isPrintable = event.character != null &&
        event.character!.isNotEmpty &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed;

    if (isPrintable) {
      promptState.requestFocus();
    }
    return false;
  }

  void _switchTab(int delta) {
    final s = ref.read(sessionProvider);
    final count = s.tabs.length;
    if (count <= 1) return;
    final newIndex = (s.activeTabIndex + delta) % count;
    ref.read(sessionProvider.notifier).switchTab(newIndex);
  }

  void _openSettings() {
    final currentTheme = ref.read(activeThemeProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BolonThemeProvider(
          theme: currentTheme,
          child: SettingsScreen(configLoader: _configLoader),
        ),
      ),
    );
  }

  /// Checks if any session across all tabs has a running command.
  bool _hasRunningCommands() {
    return ref.read(sessionProvider).allSessions.any((s) => s.isCommandRunning);
  }

  /// Cmd+W — close tab with confirmation if needed.
  Future<void> _closeTabWithConfirm() async {
    final currentTheme = ref.read(activeThemeProvider);
    final s = ref.read(sessionProvider);
    final tab = s.activeTab;
    if (tab == null) {
      // No tabs open — treat as quit
      await _quitWithConfirm();
      return;
    }

    final leaves = PaneManager.allLeaves(tab.rootPane);
    final hasMultiplePanes = leaves.length > 1;
    final hasRunning = leaves.any((l) => l.session.isCommandRunning);

    if (hasRunning) {
      final result = await showConfirmDialog(
        context,
        theme: currentTheme,
        title: 'Kill running processes?',
        message:
            'This tab has running processes. Closing will terminate them.',
        confirmLabel: 'Close Tab',
        secondaryLabel: hasMultiplePanes ? 'Close Pane' : null,
        isDangerous: true,
      );
      if (result == ConfirmResult.closeAll) {
        ref.read(sessionProvider.notifier).closeTab(s.activeTabIndex);
      } else if (result == ConfirmResult.closePane) {
        ref.read(sessionProvider.notifier).closePane();
      }
      return;
    }

    if (hasMultiplePanes) {
      final result = await showConfirmDialog(
        context,
        theme: currentTheme,
        title: 'Close tab?',
        message: 'This tab has ${leaves.length} panes. Close all or just the current pane?',
        confirmLabel: 'Close Tab',
        secondaryLabel: 'Close Pane',
      );
      if (result == ConfirmResult.closeAll) {
        ref.read(sessionProvider.notifier).closeTab(s.activeTabIndex);
      } else if (result == ConfirmResult.closePane) {
        ref.read(sessionProvider.notifier).closePane();
      }
      return;
    }

    ref.read(sessionProvider.notifier).closeTab(s.activeTabIndex);
  }

  /// Cmd+Shift+W — close pane with confirmation if running.
  Future<void> _closePaneWithConfirm() async {
    final currentTheme = ref.read(activeThemeProvider);
    final s = ref.read(sessionProvider);
    final tab = s.activeTab;
    if (tab == null) return;

    final session = tab.focusedSession;
    if (session != null && session.isCommandRunning) {
      final result = await showConfirmDialog(
        context,
        theme: currentTheme,
        title: 'Kill running process?',
        message: 'This pane has a running process. Closing will terminate it.',
        confirmLabel: 'Close Pane',
        isDangerous: true,
      );
      if (result != ConfirmResult.closeAll) return;
    }

    ref.read(sessionProvider.notifier).closePane();
  }

  /// Cmd+Q — quit with confirmation.
  Future<void> _quitWithConfirm() async {
    final currentTheme = ref.read(activeThemeProvider);
    if (_hasRunningCommands()) {
      final result = await showConfirmDialog(
        context,
        theme: currentTheme,
        title: 'Quit with running processes?',
        message:
            'There are running processes. Quitting will terminate them.',
        confirmLabel: 'Quit',
        isDangerous: true,
      );
      if (result != ConfirmResult.closeAll) return;
      exit(0);
    }

    final configLoader = ref.read(configLoaderProvider);
    final confirmOnQuit =
        configLoader?.config.general.confirmOnQuit ?? true;

    if (confirmOnQuit) {
      final result = await showConfirmDialog(
        context,
        theme: currentTheme,
        title: 'Quit Bolan?',
        message: 'Are you sure you want to quit?',
        confirmLabel: 'Quit',
      );
      if (result != ConfirmResult.closeAll) return;
    }

    exit(0);
  }

  void _togglePalette() {
    setState(() => _showPalette = !_showPalette);
  }

  List<AppAction> _buildActions() {
    final mod = Platform.isMacOS ? '⌘' : 'Ctrl+';
    return [
      AppAction(
        id: 'new_tab',
        label: 'New Tab',
        shortcut: '${mod}T',
        icon: Icons.add,
        keywords: const ['tab', 'create'],
        callback: () => ref.read(sessionProvider.notifier).createTab(),
      ),
      AppAction(
        id: 'close_tab',
        label: 'Close Tab',
        shortcut: '${mod}W',
        icon: Icons.close,
        keywords: const ['tab', 'close', 'remove'],
        callback: _closeTabWithConfirm,
      ),
      AppAction(
        id: 'split_right',
        label: 'Split Pane Right',
        shortcut: '${mod}D',
        icon: Icons.vertical_split,
        keywords: const ['split', 'pane', 'horizontal'],
        callback: () =>
            ref.read(sessionProvider.notifier).splitPane(Axis.horizontal),
      ),
      AppAction(
        id: 'split_down',
        label: 'Split Pane Down',
        shortcut: '$mod⇧D',
        icon: Icons.horizontal_split,
        keywords: const ['split', 'pane', 'vertical'],
        callback: () =>
            ref.read(sessionProvider.notifier).splitPane(Axis.vertical),
      ),
      AppAction(
        id: 'close_pane',
        label: 'Close Pane',
        shortcut: '$mod⇧W',
        icon: Icons.close_fullscreen,
        keywords: const ['pane', 'close'],
        callback: _closePaneWithConfirm,
      ),
      AppAction(
        id: 'settings',
        label: 'Settings',
        shortcut: '$mod,',
        icon: Icons.settings_outlined,
        keywords: const ['preferences', 'config', 'options'],
        callback: _openSettings,
      ),
      AppAction(
        id: 'focus_prompt',
        label: 'Focus Prompt',
        shortcut: '${mod}L',
        icon: Icons.terminal,
        keywords: const ['focus', 'input', 'prompt'],
        callback: () {
          final s = ref.read(sessionProvider);
          final tab = s.activeTab;
          if (tab == null) return;
          PaneFocusRegistry.get(tab.focusedPaneId)?.requestFocus();
        },
      ),
      AppAction(
        id: 'next_tab',
        label: 'Next Tab',
        shortcut: '$mod}',
        icon: Icons.arrow_forward,
        keywords: const ['tab', 'switch', 'next'],
        callback: () => _switchTab(1),
      ),
      AppAction(
        id: 'prev_tab',
        label: 'Previous Tab',
        shortcut: '$mod{',
        icon: Icons.arrow_back,
        keywords: const ['tab', 'switch', 'previous'],
        callback: () => _switchTab(-1),
      ),
      AppAction(
        id: 'increase_font',
        label: 'Increase Font Size',
        shortcut: '$mod+',
        icon: Icons.text_increase,
        keywords: const ['font', 'zoom', 'bigger'],
        callback: () => ref.read(fontSizeProvider.notifier).increase(),
      ),
      AppAction(
        id: 'decrease_font',
        label: 'Decrease Font Size',
        shortcut: '$mod-',
        icon: Icons.text_decrease,
        keywords: const ['font', 'zoom', 'smaller'],
        callback: () => ref.read(fontSizeProvider.notifier).decrease(),
      ),
      AppAction(
        id: 'reset_font',
        label: 'Reset Font Size',
        shortcut: '${mod}0',
        icon: Icons.format_size,
        keywords: const ['font', 'reset', 'default'],
        callback: () => ref.read(fontSizeProvider.notifier).reset(),
      ),
    ];
  }

  String? _lastFocusedPaneId;
  int? _lastActiveTabIndex;

  /// Ensures the focused pane's prompt input has keyboard focus whenever
  /// the active tab or focused pane changes.
  void _syncPromptFocus(SessionState sessionState) {
    final tab = sessionState.activeTab;
    if (tab == null) return;

    final paneChanged = tab.focusedPaneId != _lastFocusedPaneId;
    final tabChanged = sessionState.activeTabIndex != _lastActiveTabIndex;

    if (paneChanged || tabChanged) {
      _lastFocusedPaneId = tab.focusedPaneId;
      _lastActiveTabIndex = sessionState.activeTabIndex;

      // Don't steal focus from running commands
      final session = tab.focusedSession;
      if (session != null && session.isCommandRunning) return;

      _requestFocusOnPane(tab.focusedPaneId);
    }
  }

  /// Requests focus on a pane's prompt, retrying if the pane hasn't
  /// registered yet (happens with newly created panes).
  void _requestFocusOnPane(String paneId, [int attempt = 0]) {
    if (attempt > 3 || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prompt = PaneFocusRegistry.get(paneId);
      if (prompt != null) {
        prompt.requestFocus();
      } else {
        // Pane not registered yet — retry next frame
        _requestFocusOnPane(paneId, attempt + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final theme = ref.watch(activeThemeProvider);

    // Auto-focus the active pane's prompt on tab/pane changes
    _syncPromptFocus(sessionState);

    // Update macOS window chrome to match theme brightness
    if (Platform.isMacOS) {
      Window.setEffect(
        effect: WindowEffect.sidebar,
        dark: theme.brightness == Brightness.dark,
      );
    }

    return BolonThemeProvider(
      theme: theme,
      child: Focus(
        autofocus: true,
        child: CallbackShortcuts(
        bindings: {
          primaryActivator(LogicalKeyboardKey.comma):
              _openSettings,
          primaryActivator(LogicalKeyboardKey.keyT):
              () => ref.read(sessionProvider.notifier).createTab(),
          primaryActivator(LogicalKeyboardKey.keyW):
              _closeTabWithConfirm,
          // Tab switching
          primaryActivator(LogicalKeyboardKey.braceRight):
              () => _switchTab(1),
          primaryActivator(LogicalKeyboardKey.braceLeft):
              () => _switchTab(-1),
          // Pane splitting
          primaryActivator(LogicalKeyboardKey.keyD):
              () => ref
                  .read(sessionProvider.notifier)
                  .splitPane(Axis.horizontal),
          primaryActivator(LogicalKeyboardKey.keyD, shift: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .splitPane(Axis.vertical),
          // Close pane
          primaryActivator(LogicalKeyboardKey.keyW, shift: true):
              _closePaneWithConfirm,
          // Pane navigation
          primaryActivator(LogicalKeyboardKey.arrowLeft, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.left),
          primaryActivator(LogicalKeyboardKey.arrowRight, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.right),
          primaryActivator(LogicalKeyboardKey.arrowUp, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.up),
          primaryActivator(LogicalKeyboardKey.arrowDown, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.down),
          // Quit
          primaryActivator(LogicalKeyboardKey.keyQ):
              _quitWithConfirm,
          // Command palette
          primaryActivator(LogicalKeyboardKey.keyP, shift: true):
              _togglePalette,
        },
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: theme.background,
              child: Column(
                children: [
                  BolonTabBar(
                    onSettings: _openSettings,
                    onCloseTab: (_) => _closeTabWithConfirm(),
                  ),
                  Expanded(
                    child: sessionState.tabs.isEmpty
                        ? EmptyState(
                            onNewSession: () =>
                                ref.read(sessionProvider.notifier).createTab(),
                          )
                        : IndexedStack(
                            index: sessionState.activeTabIndex,
                            children: [
                              for (var i = 0;
                                  i < sessionState.tabs.length;
                                  i++)
                                PaneTreeWidget(
                                  node: sessionState.tabs[i].rootPane,
                                  focusedPaneId:
                                      sessionState.tabs[i].focusedPaneId,
                                  isSinglePane: sessionState.tabs[i].rootPane
                                      is LeafPane,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            if (_showPalette)
              CommandPalette(
                actions: _buildActions(),
                onDismiss: () => setState(() => _showPalette = false),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

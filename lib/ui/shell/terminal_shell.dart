import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/actions/app_action.dart';
import '../../core/ai/ai_provider_helper.dart';
import '../../core/ai/local_llm_provider.dart';
import '../../core/ai/model_manager.dart';
import '../../core/config/config_loader.dart';
import '../../core/config/keybinding.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/pane/pane_manager.dart';
import '../../core/pane/pane_node.dart';
// ignore: unused_import
import '../../core/platform_shortcuts.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/config_provider.dart';
import '../../providers/font_size_provider.dart';
import '../../providers/model_download_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/workspace_provider.dart';
import '../ai/memory_warning_dialog.dart';
import '../ai/model_download_dialog.dart';
import '../ai/model_download_toast.dart';
import '../palette/command_palette.dart';
import '../settings/keybindings_tab.dart';
import '../settings/settings_screen.dart';
import '../shared/confirm_dialog.dart';
import '../update/update_dialog.dart';
import '../update/update_toast.dart';
import '../workspace/workspace_sidebar.dart';
import 'empty_state.dart';
import 'pane_focus_registry.dart';
import 'pane_tree_widget.dart';
import 'session_view.dart';
import 'tab_bar.dart';

/// Root layout widget for the terminal emulator.
///
/// Owns the [ConfigLoader] and syncs config changes to Riverpod providers
/// so the UI updates live when settings change.
class TerminalShell extends ConsumerStatefulWidget {
  /// Global key so the menu bar can invoke actions on this state.
  static final globalKey = GlobalKey<_TerminalShellState>();

  TerminalShell() : super(key: globalKey);

  @override
  ConsumerState<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends ConsumerState<TerminalShell>
    with WidgetsBindingObserver {
  ConfigLoader get _configLoader => ref.read(configLoaderProvider);
  final _notificationService = NotificationService();
  bool _showPalette = false;
  bool _showDownloadDialog = false;
  bool _showDownloadToast = false;
  bool _showUpdateDialog = false;
  bool _showUpdateToast = false;
  bool _sidebarOpen = false;
  Timer? _updateCheckTimer;
  final _downloadDialogKey = GlobalKey<ModelDownloadDialogState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configLoader.addListener(_onConfigChanged);
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
    LocalLlmProvider.memoryConfirmCallback = _confirmHighMemoryLoad;
    // Sweep up any orphan llamafile server left from a previous Bolan
    // run that was force-quit, crashed, or interrupted by reboot.
    LocalLlmProvider.killStaleLocalLlmServer();
    // Sync theme + font size from already-loaded config so the first
    // frame uses the right values instead of defaults. Can't modify
    // providers inside initState, so defer to after the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onConfigChanged();
    });
    _initAsync();
  }

  Future<void> _initAsync() async {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider.notifier).state =
          _notificationService;
      ref.read(updateProvider).setConfigLoader(_configLoader);
      _checkLocalModelNeeded();
      _checkForUpdates();
      // Re-check every hour for long-running sessions.
      _updateCheckTimer = Timer.periodic(
        const Duration(hours: 1),
        (_) => _checkForUpdates(),
      );
    });
  }

  /// Bridges [LocalLlmProvider]'s memory warning into a UI dialog.
  Future<bool> _confirmHighMemoryLoad({
    required String modelLabel,
    required int requiredBytes,
    required int availableBytes,
    int? totalBytes,
  }) async {
    if (!mounted) return false;
    // Use the Riverpod theme provider — this State's own context is
    // above the BolonThemeProvider in the tree.
    final theme = ref.read(activeThemeProvider);
    return showMemoryWarningDialog(
      context,
      theme: theme,
      modelLabel: modelLabel,
      requiredBytes: requiredBytes,
      availableBytes: availableBytes,
      totalBytes: totalBytes,
    );
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    LocalLlmProvider.memoryConfirmCallback = null;
    AiProviderHelper.dispose();
    _configLoader.removeListener(_onConfigChanged);
    _configLoader.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _notificationService.setAppFocused(
      state == AppLifecycleState.resumed,
    );
    if (state == AppLifecycleState.resumed) {
      _checkForUpdates();
    }
    // App window closed / process about to exit — kill the LLM server
    // so it doesn't outlive Bolan as an orphan.
    if (state == AppLifecycleState.detached) {
      AiProviderHelper.dispose();
    }
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
    // Sync local model size for AI provider. If the size actually
    // changed, eagerly tear down the running server so the old model
    // stops hogging RAM — otherwise it would linger until the next
    // AI request triggered a lazy restart.
    final newSize = config.ai.localModelSize;
    if (AiProviderHelper.configuredLocalModelSize != newSize) {
      AiProviderHelper.configuredLocalModelSize = newSize;
      AiProviderHelper.dispose();
    }
    AiProviderHelper.configuredHuggingfaceModel = config.ai.huggingfaceModel;
    // Bump the config version so widgets watching it rebuild with
    // fresh values (cursor style, line height, etc.).
    ref.read(configVersionProvider.notifier).state++;
  }

  /// Global key handler: forwards printable key presses to the focused pane's
  /// prompt input, so typing anywhere automatically goes to the right pane.
  bool _globalKeyHandler(KeyEvent event) {
    // Don't intercept keys while the shortcut recorder is active.
    if (KeybindingsTab.isRecording) return false;

    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (!isDown && !isRepeat) return false;

    final metaDown = HardwareKeyboard.instance.isMetaPressed;
    final ctrlDown = HardwareKeyboard.instance.isControlPressed;
    final shiftDown = HardwareKeyboard.instance.isShiftPressed;
    final altDown = HardwareKeyboard.instance.isAltPressed;
    final key = event.logicalKey;
    final overrides = ref.read(keybindingOverridesProvider);

    KeyAction? action() => matchAction(
          metaDown: metaDown,
          ctrlDown: ctrlDown,
          shiftDown: shiftDown,
          altDown: altDown,
          pressed: key,
          overrides: overrides,
        );

    // ── Repeating shortcuts (act on hold) ──
    // Zoom in/out should keep firing while the user holds the key,
    // matching browser/IDE convention. Done before the
    // single-fire-only guard below.
    final a = action();
    if (a == KeyAction.zoomIn) {
      ref.read(fontSizeProvider.notifier).increase();
      return true;
    }
    if (a == KeyAction.zoomOut) {
      ref.read(fontSizeProvider.notifier).decrease();
      return true;
    }

    // Everything below this line should fire ONCE per press, never
    // on auto-repeat (you don't want holding ⌘T to spawn 60 tabs).
    if (!isDown) return false;

    // ── Global shortcuts (always work, any focus state) ──
    switch (a) {
      case KeyAction.togglePalette:
        _togglePalette();
        return true;
      case KeyAction.quit:
        _quitWithConfirm();
        return true;
      case KeyAction.openSettings:
        _openSettings();
        return true;
      case KeyAction.toggleSidebar:
        _toggleSidebar();
        return true;
      case KeyAction.newTab:
        ref.read(currentSessionNotifierProvider).createTab();
        return true;
      case KeyAction.closePane:
        _closePaneWithConfirm();
        return true;
      case KeyAction.closeTab:
        _closeTabWithConfirm();
        return true;
      case KeyAction.nextTab:
        _switchTab(1);
        return true;
      case KeyAction.previousTab:
        _switchTab(-1);
        return true;
      case KeyAction.reorderTabLeft:
        final s = ref.read(currentSessionProvider);
        if (s.activeTabIndex > 0) {
          ref.read(currentSessionNotifierProvider)
              .reorderTab(s.activeTabIndex, s.activeTabIndex - 1);
        }
        return true;
      case KeyAction.reorderTabRight:
        final s = ref.read(currentSessionProvider);
        if (s.activeTabIndex < s.tabs.length - 1) {
          ref.read(currentSessionNotifierProvider)
              .reorderTab(s.activeTabIndex, s.activeTabIndex + 2);
        }
        return true;
      case KeyAction.splitDown:
        ref.read(currentSessionNotifierProvider).splitPane(Axis.vertical);
        return true;
      case KeyAction.splitRight:
        ref.read(currentSessionNotifierProvider).splitPane(Axis.horizontal);
        return true;
      case KeyAction.navigatePaneLeft:
        ref.read(currentSessionNotifierProvider).navigatePane(AxisDirection.left);
        return true;
      case KeyAction.navigatePaneRight:
        ref.read(currentSessionNotifierProvider).navigatePane(AxisDirection.right);
        return true;
      case KeyAction.navigatePaneUp:
        ref.read(currentSessionNotifierProvider).navigatePane(AxisDirection.up);
        return true;
      case KeyAction.navigatePaneDown:
        ref.read(currentSessionNotifierProvider).navigatePane(AxisDirection.down);
        return true;
      case KeyAction.find:
        final s = ref.read(currentSessionProvider);
        final tab = s.activeTab;
        if (tab != null && tab.focusedPaneId != null) {
          SessionViewState.of(tab.focusedPaneId!)?.toggleFindBar();
        }
        return true;
      case KeyAction.resetZoom:
        ref.read(fontSizeProvider.notifier).reset();
        return true;
      case KeyAction.broadcastInput:
        final current = ref.read(broadcastInputProvider);
        ref.read(broadcastInputProvider.notifier).state = !current;
        return true;
      case KeyAction.workspace1:
        _switchWorkspace(0);
        return true;
      case KeyAction.workspace2:
        _switchWorkspace(1);
        return true;
      case KeyAction.workspace3:
        _switchWorkspace(2);
        return true;
      case KeyAction.workspace4:
        _switchWorkspace(3);
        return true;
      case KeyAction.workspace5:
        _switchWorkspace(4);
        return true;
      case KeyAction.workspace6:
        _switchWorkspace(5);
        return true;
      case KeyAction.workspace7:
        _switchWorkspace(6);
        return true;
      case KeyAction.workspace8:
        _switchWorkspace(7);
        return true;
      case KeyAction.workspace9:
        _switchWorkspace(8);
        return true;
      default:
        break;
    }

    // Don't forward keys when palette is open
    if (_showPalette) return false;

    final s = ref.read(currentSessionProvider);
    final tab = s.activeTab;
    if (tab == null || !tab.isTerminal) return false;

    final promptState = PaneFocusRegistry.get(tab.focusedPaneId!);
    if (promptState == null) return false;

    if (a == KeyAction.focusPrompt) {
      promptState.requestFocus();
      promptState.selectAll();
      return true;
    }

    final session = tab.focusedSession;

    // Don't interfere during command execution
    if (session != null && session.isCommandRunning) return false;
    if (promptState.isHistorySearchOpen) return false;

    // Don't forward keys during tab rename
    if (tabRenameActive) return false;

    // Only redirect printable keystrokes to the prompt when NOTHING
    // else currently owns focus. If any widget already has primary
    // focus — popover search fields, dialog inputs, settings forms,
    // find bar, xterm view, the prompt itself — Flutter's focus
    // system will deliver the key there correctly; we must not call
    // `requestFocus()` and yank focus away to the prompt.
    //
    // Previous attempts tried to detect "is focus inside a text
    // input?" by inspecting the primary FocusNode's context/widget,
    // but that's unreliable: when a TextField is given an explicit
    // `focusNode:` (e.g. the branch / cwd / nvm picker search
    // inputs), primaryFocus.context points at the wrapping `Focus`
    // element, not `EditableText`, and a subtree walk doesn't always
    // reach the `EditableText` either. Checking "is anything
    // focused?" is both simpler and strictly correct.
    if (FocusManager.instance.primaryFocus != null) {
      return false;
    }

    final isPrintable = event.character != null &&
        event.character!.isNotEmpty &&
        !ctrlDown &&
        !metaDown;

    if (isPrintable) {
      promptState.requestFocus();
    }
    return false;
  }

  void _switchTab(int delta) {
    final s = ref.read(currentSessionProvider);
    final count = s.tabs.length;
    if (count <= 1) return;
    final newIndex = (s.activeTabIndex + delta) % count;
    ref.read(currentSessionNotifierProvider).switchTab(newIndex);
  }

  void _switchWorkspace(int index) {
    final registry = ref.read(workspaceRegistryProvider);
    final enabled = registry.workspaces.where((w) => w.enabled).toList();
    if (index >= enabled.length) return;
    final target = enabled[index];
    if (target.id == registry.activeId) return;
    ref.read(switchWorkspaceActionProvider)(target.id);
  }

  /// Public accessors for the menu bar.
  void toggleSidebar() => _toggleSidebar();
  void openSettings() => _openSettings();
  void quitWithConfirm() => _quitWithConfirm();

  void _openSettings() {
    ref.read(currentSessionNotifierProvider).openSettingsTab();
  }

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
  }

  /// Checks if any session across all tabs has a running command.
  bool _hasRunningCommands() {
    return ref.read(currentSessionProvider).allSessions.any((s) => s.isCommandRunning);
  }

  /// Cmd+W — close tab with confirmation if needed.
  Future<void> _closeTabWithConfirm() async {
    final currentTheme = ref.read(activeThemeProvider);
    final s = ref.read(currentSessionProvider);
    final tab = s.activeTab;
    if (tab == null) {
      // No tabs open — treat as quit
      await _quitWithConfirm();
      return;
    }

    // Settings tab — just close it, no confirmation needed.
    if (tab.isSettings) {
      ref.read(currentSessionNotifierProvider).closeTab(s.activeTabIndex);
      return;
    }

    final leaves = PaneManager.allLeaves(tab.rootPane!);
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
        ref.read(currentSessionNotifierProvider).closeTab(s.activeTabIndex);
      } else if (result == ConfirmResult.closePane) {
        ref.read(currentSessionNotifierProvider).closePane();
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
        ref.read(currentSessionNotifierProvider).closeTab(s.activeTabIndex);
      } else if (result == ConfirmResult.closePane) {
        ref.read(currentSessionNotifierProvider).closePane();
      }
      return;
    }

    ref.read(currentSessionNotifierProvider).closeTab(s.activeTabIndex);
  }

  /// Cmd+Shift+W — close pane with confirmation if running.
  Future<void> _closePaneWithConfirm() async {
    final currentTheme = ref.read(activeThemeProvider);
    final s = ref.read(currentSessionProvider);
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

    ref.read(currentSessionNotifierProvider).closePane();
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
      AiProviderHelper.dispose();
      exit(0);
    }

    final configLoader = ref.read(configLoaderProvider);
    final confirmOnQuit =
        configLoader.config.general.confirmOnQuit;

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

    AiProviderHelper.dispose();
    exit(0);
  }

  /// Shows the download dialog if AI is enabled, provider is local,
  /// and the model hasn't been downloaded yet.
  void _checkLocalModelNeeded() {
    final config = _configLoader.config;
    if (!config.ai.enabled) return;
    if (config.ai.provider != 'local') return;
    if (ModelManager.isModelDownloaded()) return;
    setState(() => _showDownloadDialog = true);
  }

  void _dismissDownload() {
    setState(() {
      _showDownloadDialog = false;
      _showDownloadToast = false;
    });
  }

  void _backgroundDownload() {
    setState(() {
      _showDownloadDialog = false;
      _showDownloadToast = true;
    });
  }

  Future<void> _checkForUpdates({bool force = false}) async {
    final notifier = ref.read(updateProvider);
    await notifier.check(force: force);
    if (!mounted) return;

    if (notifier.state.status == UpdateStatus.available) {
      if (force) {
        // Manual check: show the full update dialog
        setState(() => _showUpdateDialog = true);
      } else {
        // Auto check: download in background with toast showing progress.
        notifier.download();
        setState(() => _showUpdateToast = true);
        // Listen for completion or error to update toast state
        void listener() {
          if (!mounted) return;
          final s = notifier.state;
          if (s.status == UpdateStatus.error ||
              s.status == UpdateStatus.idle) {
            setState(() => _showUpdateToast = false);
            notifier.removeListener(listener);
          }
        }
        notifier.addListener(listener);
      }
    }
  }

  void _dismissUpdate() {
    setState(() {
      _showUpdateDialog = false;
      _showUpdateToast = false;
    });
  }

  void _backgroundUpdate() {
    setState(() {
      _showUpdateDialog = false;
      _showUpdateToast = true;
    });
  }

  void _togglePalette() {
    setState(() => _showPalette = !_showPalette);
  }

  List<AppAction> _buildActions() {
    final o = ref.read(keybindingOverridesProvider);
    String kb(KeyAction a) => bindingFor(a, o).label;
    return [
      AppAction(
        id: 'new_tab',
        label: 'New Tab',
        shortcut: kb(KeyAction.newTab),
        icon: Icons.add,
        keywords: const ['tab', 'create'],
        callback: () => ref.read(currentSessionNotifierProvider).createTab(),
      ),
      AppAction(
        id: 'close_tab',
        label: 'Close Tab',
        shortcut: kb(KeyAction.closeTab),
        icon: Icons.close,
        keywords: const ['tab', 'close', 'remove'],
        callback: _closeTabWithConfirm,
      ),
      AppAction(
        id: 'split_right',
        label: 'Split Pane Right',
        shortcut: kb(KeyAction.splitRight),
        icon: Icons.vertical_split,
        keywords: const ['split', 'pane', 'horizontal'],
        callback: () =>
            ref.read(currentSessionNotifierProvider).splitPane(Axis.horizontal),
      ),
      AppAction(
        id: 'split_down',
        label: 'Split Pane Down',
        shortcut: kb(KeyAction.splitDown),
        icon: Icons.horizontal_split,
        keywords: const ['split', 'pane', 'vertical'],
        callback: () =>
            ref.read(currentSessionNotifierProvider).splitPane(Axis.vertical),
      ),
      AppAction(
        id: 'close_pane',
        label: 'Close Pane',
        shortcut: kb(KeyAction.closePane),
        icon: Icons.close_fullscreen,
        keywords: const ['pane', 'close'],
        callback: _closePaneWithConfirm,
      ),
      AppAction(
        id: 'settings',
        label: 'Settings',
        shortcut: kb(KeyAction.openSettings),
        icon: Icons.settings_outlined,
        keywords: const ['preferences', 'config', 'options'],
        callback: _openSettings,
      ),
      AppAction(
        id: 'check_updates',
        label: 'Check for Updates',
        icon: Icons.system_update_outlined,
        keywords: const ['update', 'upgrade', 'version'],
        callback: () => _checkForUpdates(force: true),
      ),
      AppAction(
        id: 'focus_prompt',
        label: 'Focus Prompt',
        shortcut: kb(KeyAction.focusPrompt),
        icon: Icons.terminal,
        keywords: const ['focus', 'input', 'prompt'],
        callback: () {
          final s = ref.read(currentSessionProvider);
          final tab = s.activeTab;
          if (tab == null || tab.focusedPaneId == null) return;
          PaneFocusRegistry.get(tab.focusedPaneId!)?.requestFocus();
        },
      ),
      AppAction(
        id: 'next_tab',
        label: 'Next Tab',
        shortcut: kb(KeyAction.nextTab),
        icon: Icons.arrow_forward,
        keywords: const ['tab', 'switch', 'next'],
        callback: () => _switchTab(1),
      ),
      AppAction(
        id: 'prev_tab',
        label: 'Previous Tab',
        shortcut: kb(KeyAction.previousTab),
        icon: Icons.arrow_back,
        keywords: const ['tab', 'switch', 'previous'],
        callback: () => _switchTab(-1),
      ),
      AppAction(
        id: 'increase_font',
        label: 'Increase Font Size',
        shortcut: kb(KeyAction.zoomIn),
        icon: Icons.text_increase,
        keywords: const ['font', 'zoom', 'bigger'],
        callback: () => ref.read(fontSizeProvider.notifier).increase(),
      ),
      AppAction(
        id: 'decrease_font',
        label: 'Decrease Font Size',
        shortcut: kb(KeyAction.zoomOut),
        icon: Icons.text_decrease,
        keywords: const ['font', 'zoom', 'smaller'],
        callback: () => ref.read(fontSizeProvider.notifier).decrease(),
      ),
      AppAction(
        id: 'reset_font',
        label: 'Reset Font Size',
        shortcut: kb(KeyAction.resetZoom),
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

      // Settings tab has no pane to focus.
      if (!tab.isTerminal || tab.focusedPaneId == null) return;

      // Don't steal focus from running commands
      final session = tab.focusedSession;
      if (session != null && session.isCommandRunning) return;

      _requestFocusOnPane(tab.focusedPaneId!);
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
    final sessionState = ref.watch(currentSessionProvider);

    final configuredFont =
        _configLoader.config.editor.fontFamily;
    final theme = ref.watch(activeThemeProvider)
        .copyWith(fontFamily: configuredFont);

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
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: theme.background,
              child: Column(
                children: [
                  BolonTabBar(
                    onCloseTab: (_) => _closeTabWithConfirm(),
                    sidebarOpen: _sidebarOpen,
                    onToggleSidebar: _toggleSidebar,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        ClipRect(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            width: _sidebarOpen
                                ? WorkspaceSidebar.width
                                : 0,
                            child: const SizedBox(
                              width: WorkspaceSidebar.width,
                              child: WorkspaceSidebar(),
                            ),
                          ),
                        ),
                        Expanded(
                          // Key on the active workspace id so switching
                          // workspaces fully unmounts the previous tab
                          // tree (calling dispose on every SessionView)
                          // before the new one mounts. Without this,
                          // GlobalKeys briefly collide and SessionViews
                          // try to addListener on disposed sessions.
                          child: KeyedSubtree(
                            key: ValueKey(
                                ref.watch(currentWorkspaceProvider).id),
                            child: sessionState.tabs.isEmpty
                              ? EmptyState(
                                  onNewSession: () => ref
                                      .read(currentSessionNotifierProvider)
                                      .createTab(),
                                )
                              : IndexedStack(
                                  index: sessionState.activeTabIndex,
                                  children: [
                                    for (var i = 0;
                                        i < sessionState.tabs.length;
                                        i++)
                                      if (sessionState.tabs[i].isSettings)
                                        SettingsScreen(
                                          configLoader: _configLoader,
                                          globalConfigLoader: ref.read(globalConfigLoaderProvider),
                                          themeRegistry: ref.read(themeRegistryProvider),
                                          initialTab: sessionState
                                              .tabs[i].initialSettingsTab,
                                          navGeneration: sessionState
                                              .tabs[i].settingsNavGeneration,
                                        )
                                      else
                                        PaneTreeWidget(
                                          node: sessionState.tabs[i].rootPane!,
                                          focusedPaneId: sessionState
                                              .tabs[i].focusedPaneId!,
                                          isSinglePane: sessionState
                                                  .tabs[i].rootPane
                                              is LeafPane,
                                        ),
                                  ],
                                ),
                          ),
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
            if (_showDownloadDialog)
              ModelDownloadDialog(
                key: _downloadDialogKey,
                onDismiss: _dismissDownload,
                onBackgrounded: _backgroundDownload,
              ),
            if (_showDownloadToast)
              Builder(builder: (context) {
                final dl = ref.watch(modelDownloadProvider);
                final s = dl.state;
                // Auto-hide toast when download completes
                if (s.complete || (!s.downloading && !s.paused)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _showDownloadToast) {
                      setState(() => _showDownloadToast = false);
                    }
                  });
                }
                return ModelDownloadToast(
                  received: s.received,
                  total: s.total,
                  onTap: () => setState(() {
                    _showDownloadToast = false;
                    _showDownloadDialog = true;
                  }),
                );
              }),
            if (_showUpdateDialog)
              UpdateDialog(
                onDismiss: _dismissUpdate,
                onBackgrounded: _backgroundUpdate,
              ),
            if (_showUpdateToast)
              Builder(builder: (context) {
                final us = ref.watch(updateProvider).state;
                // Auto-hide toast on error or idle.
                if (us.status == UpdateStatus.error ||
                    us.status == UpdateStatus.idle) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _showUpdateToast) {
                      setState(() => _showUpdateToast = false);
                    }
                  });
                }
                // For verifying/installing, switch to dialog.
                if (us.status == UpdateStatus.verifying ||
                    us.status == UpdateStatus.installing) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _showUpdateToast) {
                      setState(() {
                        _showUpdateToast = false;
                        _showUpdateDialog = true;
                      });
                    }
                  });
                }
                return UpdateToast(
                  received: us.received,
                  total: us.total,
                  isReady:
                      us.status == UpdateStatus.readyToRestart,
                  onTap: () => setState(() {
                    _showUpdateToast = false;
                    _showUpdateDialog = true;
                  }),
                  onDismiss: () {
                    ref.read(updateProvider).cancelDownload();
                    setState(() => _showUpdateToast = false);
                  },
                  onRestart: () =>
                      ref.read(updateProvider).restart(),
                );
              }),
          ],
        ),
      ),
    );
  }
}

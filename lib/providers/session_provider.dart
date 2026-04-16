import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/pane/pane_manager.dart';
import '../core/pane/pane_node.dart';
import '../core/session/session_persistence.dart';
import '../core/terminal/command_history.dart';
import '../core/terminal/session.dart';
import 'config_provider.dart';
import 'workspace_provider.dart';

export '../core/pane/pane_node.dart' show DropPosition;

const _uuid = Uuid();

/// Distinguishes terminal tabs (with panes/sessions) from special
/// tabs like Settings that render a standalone widget.
enum TabType { terminal, settings }

/// State for a single tab — a tree of panes with a focused pane.
/// For non-terminal tabs (e.g. settings), [rootPane] and
/// [focusedPaneId] are null.
class TabState {
  final TabType type;
  final PaneNode? rootPane;
  final String? focusedPaneId;
  final String? customTitle;
  final int initialSettingsTab;

  const TabState({
    this.type = TabType.terminal,
    this.rootPane,
    this.focusedPaneId,
    this.customTitle,
    this.initialSettingsTab = 0,
  });

  bool get isTerminal => type == TabType.terminal;
  bool get isSettings => type == TabType.settings;

  LeafPane? get focusedLeaf {
    if (rootPane == null || focusedPaneId == null) return null;
    return PaneManager.findLeaf(rootPane!, focusedPaneId!);
  }

  TerminalSession? get focusedSession => focusedLeaf?.session;

  TabState copyWith({
    PaneNode? rootPane,
    String? focusedPaneId,
    String? customTitle,
    bool clearCustomTitle = false,
  }) {
    return TabState(
      type: type,
      rootPane: rootPane ?? this.rootPane,
      focusedPaneId: focusedPaneId ?? this.focusedPaneId,
      customTitle: clearCustomTitle ? null : (customTitle ?? this.customTitle),
    );
  }
}

/// Top-level state: list of tabs + active tab index.
class SessionState {
  final List<TabState> tabs;
  final int activeTabIndex;

  const SessionState({required this.tabs, required this.activeTabIndex});

  TabState? get activeTab {
    if (activeTabIndex < 0 || activeTabIndex >= tabs.length) return null;
    return tabs[activeTabIndex];
  }

  /// The focused session in the active tab (for tab bar title, etc.)
  TerminalSession? get activeSession => activeTab?.focusedSession;

  bool get activeTabIsSettings => activeTab?.isSettings ?? false;

  /// All sessions across all tabs (for backward compat).
  List<TerminalSession> get allSessions {
    return tabs
        .where((tab) => tab.rootPane != null)
        .expand((tab) => PaneManager.allLeaves(tab.rootPane!))
        .map((leaf) => leaf.session)
        .toList();
  }
}

/// Notifier managing tabs, panes, and sessions.
///
/// Family-keyed by workspace id so each workspace maintains its own
/// tabs, PTYs, and history in parallel. Switching workspaces changes
/// which notifier is rendered; background workspaces stay alive.
class SessionNotifier extends FamilyNotifier<SessionState, String> {
  late CommandHistory history;
  late String _workspaceId;

  /// Mirror of `state.tabs` for use by the dispose closure. Reading
  /// `state` from inside `onDispose` after invalidation triggers a
  /// rebuild, which re-runs `build()` and registers a NEW onDispose
  /// callback while Riverpod is still iterating the disposer list —
  /// hitting "Concurrent modification during iteration".
  List<TabState> _tabsForDisposal = const [];
  int _activeTabIndexForDisposal = 0;

  @override
  SessionState build(String workspaceId) {
    _workspaceId = workspaceId;
    history = CommandHistory(workspaceId: workspaceId);
    history.load();

    ref.onDispose(() {
      // Cancel pending session-change debounce so it can't fire after
      // disposal and trigger `state = ...` on a disposed notifier
      // (which would rebuild and register a new disposer mid-iteration).
      _debounceTimer?.cancel();
      _saveLayout();
      for (final t in _tabsForDisposal) {
        if (t.rootPane != null) PaneManager.disposeAll(t.rootPane!);
      }
    });

    // Try to restore previous session layout
    final restored = _tryRestore();
    final initial = restored ?? SessionState(
      tabs: [_createTab()],
      activeTabIndex: 0,
    );
    _tabsForDisposal = initial.tabs;
    _activeTabIndexForDisposal = initial.activeTabIndex;
    return initial;
  }

  @override
  set state(SessionState value) {
    _tabsForDisposal = value.tabs;
    _activeTabIndexForDisposal = value.activeTabIndex;
    super.state = value;
  }

  SessionState? _tryRestore() {
    final configLoader = ref.read(configLoaderProvider);
    if (configLoader == null) return null;
    if (!configLoader.config.general.restoreSessions) return null;

    final layout = SessionPersistence.load(workspaceId: _workspaceId);
    if (layout == null || layout.tabs.isEmpty) return null;

    final tabs = <TabState>[];
    for (final tabLayout in layout.tabs) {
      final tab = _restoreTabFromLayout(tabLayout);
      if (tab != null) tabs.add(tab);
    }
    if (tabs.isEmpty) return null;

    final activeIndex = layout.activeTabIndex.clamp(0, tabs.length - 1);
    return SessionState(tabs: tabs, activeTabIndex: activeIndex);
  }

  TabState? _restoreTabFromLayout(TabLayout tabLayout) {
    final rootPane = _restorePaneFromLayout(tabLayout.rootPane);
    if (rootPane == null) return null;
    final focusedId = tabLayout.focusedPaneId ??
        PaneManager.allLeaves(rootPane).first.id;
    return TabState(rootPane: rootPane, focusedPaneId: focusedId);
  }

  PaneNode? _restorePaneFromLayout(PaneLayout layout) {
    switch (layout) {
      case LeafLayout():
        final configLoader2 = ref.read(configLoaderProvider);
        final general2 = configLoader2?.config.general;
        final configShell2 = general2?.shell ?? '';
        final configDir2 = general2?.workingDirectory ?? '';
        final cwd = layout.cwd.isNotEmpty &&
                Directory(layout.cwd).existsSync()
            ? layout.cwd
            : (configDir2.isNotEmpty ? configDir2 : null);
        final session = TerminalSession.start(
          id: _uuid.v4(),
          history: history,
          shell: configShell2.isNotEmpty ? configShell2 : null,
          workingDirectory: cwd,
        );
        final leaf = LeafPane(id: _uuid.v4(), session: session);
        _attachSessionListener(session);

        final configLoader = ref.read(configLoaderProvider);
        final startupCommands =
            configLoader?.config.general.startupCommands;
        if (startupCommands != null && startupCommands.isNotEmpty) {
          session.runStartupCommands(startupCommands);
        }

        return leaf;

      case SplitLayout():
        final first = _restorePaneFromLayout(layout.first);
        final second = _restorePaneFromLayout(layout.second);
        if (first == null || second == null) return first ?? second;
        return SplitPane(
          id: _uuid.v4(),
          first: first,
          second: second,
          axis: layout.axis,
          ratio: layout.ratio,
        );
    }
  }

  void _saveLayout() {
    final configLoader = ref.read(configLoaderProvider);
    if (configLoader == null) return;
    if (!configLoader.config.general.restoreSessions) return;

    // Read from the disposal mirror, not `state` — see the comment on
    // [_tabsForDisposal]. This method runs from the dispose closure
    // after the provider may already be invalidated.
    final tabs = _tabsForDisposal
        .where((tab) => tab.isTerminal && tab.rootPane != null)
        .map((tab) {
      return TabLayout(
        rootPane: _serializePane(tab.rootPane!),
        focusedPaneId: tab.focusedPaneId,
      );
    }).toList();

    SessionPersistence.save(
      SessionLayout(
        tabs: tabs,
        activeTabIndex: _activeTabIndexForDisposal,
      ),
      workspaceId: _workspaceId,
    );
  }

  PaneLayout _serializePane(PaneNode node) {
    switch (node) {
      case LeafPane():
        return LeafLayout(cwd: node.session.cwd);
      case SplitPane():
        return SplitLayout(
          first: _serializePane(node.first),
          second: _serializePane(node.second),
          axis: node.axis,
          ratio: node.ratio,
        );
    }
  }

  // --- Tab operations ---

  /// Opens the settings tab. If one already exists, switches to it
  /// (singleton). Otherwise creates a new settings tab.
  void openSettingsTab({int initialSettingsTab = 0}) {
    final existing = state.tabs.indexWhere((t) => t.isSettings);
    if (existing >= 0) {
      switchTab(existing);
      return;
    }
    final tab = TabState(
      type: TabType.settings,
      customTitle: 'Settings',
      initialSettingsTab: initialSettingsTab,
    );
    final tabs = [...state.tabs, tab];
    state = SessionState(tabs: tabs, activeTabIndex: tabs.length - 1);
  }

  void createTab({String? workingDirectory}) {
    final tab = _createTab(workingDirectory: workingDirectory);
    _attachTabListeners(tab);
    final tabs = [...state.tabs, tab];
    state = SessionState(tabs: tabs, activeTabIndex: tabs.length - 1);
  }

  void renameTab(int index, String? title) {
    if (index < 0 || index >= state.tabs.length) return;
    final tabs = [...state.tabs];
    tabs[index] = tabs[index].copyWith(
      customTitle: title,
      clearCustomTitle: title == null || title.isEmpty,
    );
    state = SessionState(tabs: tabs, activeTabIndex: state.activeTabIndex);
  }

  void switchTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    _debounceTimer?.cancel();
    state = SessionState(tabs: state.tabs, activeTabIndex: index);
  }

  void closeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    final closing = state.tabs[index];
    if (closing.rootPane != null) {
      PaneManager.disposeAll(closing.rootPane!);
    }
    final tabs = [...state.tabs]..removeAt(index);

    if (tabs.isEmpty) {
      state = const SessionState(tabs: [], activeTabIndex: -1);
      return;
    }

    var activeIndex = state.activeTabIndex;
    if (activeIndex >= tabs.length) activeIndex = tabs.length - 1;
    if (activeIndex > index) activeIndex--;
    state = SessionState(tabs: tabs, activeTabIndex: activeIndex);
  }

  /// Closes all tabs except the one at [keepIndex].
  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= state.tabs.length) return;
    final kept = state.tabs[keepIndex];
    for (var i = 0; i < state.tabs.length; i++) {
      if (i == keepIndex) continue;
      final tab = state.tabs[i];
      if (tab.rootPane != null) PaneManager.disposeAll(tab.rootPane!);
    }
    state = SessionState(tabs: [kept], activeTabIndex: 0);
  }

  /// Closes all tabs to the right of [index].
  void closeTabsToRight(int index) {
    if (index < 0 || index >= state.tabs.length - 1) return;
    for (var i = index + 1; i < state.tabs.length; i++) {
      final tab = state.tabs[i];
      if (tab.rootPane != null) PaneManager.disposeAll(tab.rootPane!);
    }
    final tabs = state.tabs.sublist(0, index + 1);
    var activeIndex = state.activeTabIndex;
    if (activeIndex > index) activeIndex = index;
    state = SessionState(tabs: tabs, activeTabIndex: activeIndex);
  }

  /// Moves the tab at [oldIndex] to [newIndex], adjusting the active
  /// tab pointer so the same logical tab stays selected.
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= state.tabs.length) return;
    if (newIndex < 0 || newIndex > state.tabs.length) return;

    final tabs = [...state.tabs];
    final moved = tabs.removeAt(oldIndex);
    // Account for the removal shifting indices when moving forward.
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    tabs.insert(insertAt, moved);

    // Recompute the active index so the previously focused tab stays
    // focused after the reorder.
    var active = state.activeTabIndex;
    if (active == oldIndex) {
      active = insertAt;
    } else if (oldIndex < active && insertAt >= active) {
      active--;
    } else if (oldIndex > active && insertAt <= active) {
      active++;
    }
    state = SessionState(tabs: tabs, activeTabIndex: active);
  }

  // --- Pane operations ---

  void splitPane(Axis axis) {
    final tab = state.activeTab;
    if (tab == null || !tab.isTerminal) return;

    final currentFocusId = tab.focusedPaneId!;
    final (newRoot, newLeaf) =
        PaneManager.split(tab.rootPane!, currentFocusId, axis, history);
    _attachSessionListener(newLeaf.session);

    // Focus the newly created pane
    _updateActiveTab(TabState(
      rootPane: newRoot,
      focusedPaneId: newLeaf.id,
    ));
  }

  void closePane() {
    final tab = state.activeTab;
    if (tab == null || !tab.isTerminal) return;

    final newRoot = PaneManager.close(tab.rootPane!, tab.focusedPaneId!);
    if (newRoot == null) {
      // Last pane — close the tab
      closeTab(state.activeTabIndex);
      return;
    }

    // Focus the first remaining leaf
    final newFocus = PaneManager.allLeaves(newRoot).first.id;
    _updateActiveTab(TabState(rootPane: newRoot, focusedPaneId: newFocus));
  }

  void setFocusedPane(String paneId) {
    final tab = state.activeTab;
    if (tab == null || !tab.isTerminal || tab.focusedPaneId == paneId) return;
    _updateActiveTab(TabState(
      rootPane: tab.rootPane,
      focusedPaneId: paneId,
    ));
  }

  void navigatePane(AxisDirection direction) {
    final tab = state.activeTab;
    if (tab == null || !tab.isTerminal) return;

    final targetId = PaneManager.findAdjacentPane(
      tab.rootPane!,
      tab.focusedPaneId!,
      direction,
    );
    if (targetId != null) setFocusedPane(targetId);
  }

  void movePane(String sourceId, String targetId, DropPosition position) {
    final tab = state.activeTab;
    if (tab == null || !tab.isTerminal || sourceId == targetId) return;

    final newRoot = PaneManager.movePane(
      tab.rootPane!, sourceId, targetId, position,
    );
    if (newRoot == null) return;

    _updateActiveTab(TabState(
      rootPane: newRoot,
      focusedPaneId: sourceId,
    ));
  }

  void updateSplitRatio(String splitPaneId, double ratio) {
    final tab = state.activeTab;
    if (tab == null || tab.rootPane == null) return;
    _updateRatio(tab.rootPane!, splitPaneId, ratio);
    // Trigger rebuild
    state = SessionState(
      tabs: state.tabs,
      activeTabIndex: state.activeTabIndex,
    );
  }

  // --- Internal helpers ---

  TabState _createTab({String? workingDirectory}) {
    final configLoader = ref.read(configLoaderProvider);
    final general = configLoader?.config.general;
    final configShell = general?.shell ?? '';
    final configDir = general?.workingDirectory ?? '';
    final session = TerminalSession.start(
      id: _uuid.v4(),
      history: history,
      shell: configShell.isNotEmpty ? configShell : null,
      workingDirectory: workingDirectory ??
          (configDir.isNotEmpty ? configDir : null),
    );
    final leaf = LeafPane(id: _uuid.v4(), session: session);
    _attachSessionListener(session);

    // Run startup commands from config
    final startupCommands = general?.startupCommands;
    if (startupCommands != null && startupCommands.isNotEmpty) {
      session.runStartupCommands(startupCommands);
    }

    return TabState(rootPane: leaf, focusedPaneId: leaf.id);
  }

  void _attachTabListeners(TabState tab) {
    if (tab.rootPane == null) return;
    for (final leaf in PaneManager.allLeaves(tab.rootPane!)) {
      _attachSessionListener(leaf.session);
    }
  }

  void _attachSessionListener(TerminalSession session) {
    session.addListener(_onSessionChanged);
    session.onCommandFinished = _handleCommandFinished;
  }

  void _handleCommandFinished(
      String command, Duration duration, int exitCode) {
    final configLoader = ref.read(configLoaderProvider);
    final config = configLoader?.config.general;
    if (config == null || !config.notifyLongRunning) return;

    final threshold = Duration(seconds: config.longRunningThresholdSeconds);
    if (duration < threshold) return;

    final notifier = ref.read(notificationServiceProvider);
    if (notifier == null) return;

    final seconds = duration.inSeconds;
    final status = exitCode == 0 ? 'succeeded' : 'failed ($exitCode)';
    final cmd =
        command.length > 40 ? '${command.substring(0, 40)}...' : command;
    notifier.notifyIfUnfocused(
      title: 'Command $status',
      body: '`$cmd` finished in ${seconds}s',
    );
  }

  Timer? _debounceTimer;

  void _onSessionChanged() {
    // Debounce session notifications to avoid excessive rebuilds.
    // Tab titles and status icons don't need 60fps updates.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      state = SessionState(
        tabs: state.tabs,
        activeTabIndex: state.activeTabIndex,
      );
    });
  }

  void _updateActiveTab(TabState newTab) {
    final tabs = [...state.tabs];
    tabs[state.activeTabIndex] = newTab;
    state = SessionState(tabs: tabs, activeTabIndex: state.activeTabIndex);
  }

  void _updateRatio(PaneNode node, String splitId, double ratio) {
    if (node is SplitPane) {
      if (node.id == splitId) {
        node.ratio = ratio;
        return;
      }
      _updateRatio(node.first, splitId, ratio);
      _updateRatio(node.second, splitId, ratio);
    }
  }
}

/// Family-keyed session provider: one [SessionNotifier] per workspace id.
/// Background workspaces keep their PTYs alive and their tab state in
/// memory. Use [currentSessionProvider] and [currentSessionNotifierProvider]
/// for the active workspace.
final sessionFamily =
    NotifierProvider.family<SessionNotifier, SessionState, String>(
        SessionNotifier.new);

/// Session state auto-routed to the active workspace.
final currentSessionProvider = Provider<SessionState>((ref) {
  final id = ref.watch(workspaceRegistryProvider).activeId;
  return ref.watch(sessionFamily(id));
});

/// Session notifier auto-routed to the active workspace. For calling
/// actions like `createTab()`, `closeTab()`, `reorderTab()`, etc.
final currentSessionNotifierProvider = Provider<SessionNotifier>((ref) {
  final id = ref.watch(workspaceRegistryProvider).activeId;
  return ref.read(sessionFamily(id).notifier);
});

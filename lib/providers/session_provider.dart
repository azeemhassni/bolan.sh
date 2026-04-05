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

export '../core/pane/pane_node.dart' show DropPosition;

const _uuid = Uuid();

/// State for a single tab — a tree of panes with a focused pane.
class TabState {
  final PaneNode rootPane;
  final String focusedPaneId;

  const TabState({required this.rootPane, required this.focusedPaneId});

  LeafPane? get focusedLeaf =>
      PaneManager.findLeaf(rootPane, focusedPaneId);

  TerminalSession? get focusedSession => focusedLeaf?.session;
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

  /// All sessions across all tabs (for backward compat).
  List<TerminalSession> get allSessions {
    return tabs
        .expand((tab) => PaneManager.allLeaves(tab.rootPane))
        .map((leaf) => leaf.session)
        .toList();
  }
}

/// Notifier managing tabs, panes, and sessions.
class SessionNotifier extends Notifier<SessionState> {
  final CommandHistory history = CommandHistory();

  @override
  SessionState build() {
    history.load();

    ref.onDispose(() {
      _saveLayout();
      for (final t in state.tabs) {
        PaneManager.disposeAll(t.rootPane);
      }
    });

    // Try to restore previous session layout
    final restored = _tryRestore();
    if (restored != null) return restored;

    final tab = _createTab();
    return SessionState(tabs: [tab], activeTabIndex: 0);
  }

  SessionState? _tryRestore() {
    final configLoader = ref.read(configLoaderProvider);
    if (configLoader == null) return null;
    if (!configLoader.config.general.restoreSessions) return null;

    final layout = SessionPersistence.load();
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
        final cwd = layout.cwd.isNotEmpty &&
                Directory(layout.cwd).existsSync()
            ? layout.cwd
            : null;
        final session = TerminalSession.start(
          id: _uuid.v4(),
          history: history,
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

    final tabs = state.tabs.map((tab) {
      return TabLayout(
        rootPane: _serializePane(tab.rootPane),
        focusedPaneId: tab.focusedPaneId,
      );
    }).toList();

    SessionPersistence.save(SessionLayout(
      tabs: tabs,
      activeTabIndex: state.activeTabIndex,
    ));
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

  void createTab({String? workingDirectory}) {
    final tab = _createTab(workingDirectory: workingDirectory);
    _attachTabListeners(tab);
    final tabs = [...state.tabs, tab];
    state = SessionState(tabs: tabs, activeTabIndex: tabs.length - 1);
  }

  void switchTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    _debounceTimer?.cancel();
    state = SessionState(tabs: state.tabs, activeTabIndex: index);
  }

  void closeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    PaneManager.disposeAll(state.tabs[index].rootPane);
    final tabs = [...state.tabs]..removeAt(index);

    if (tabs.isEmpty) {
      final tab = _createTab();
      _attachTabListeners(tab);
      state = SessionState(tabs: [tab], activeTabIndex: 0);
      return;
    }

    var activeIndex = state.activeTabIndex;
    if (activeIndex >= tabs.length) activeIndex = tabs.length - 1;
    if (activeIndex > index) activeIndex--;
    state = SessionState(tabs: tabs, activeTabIndex: activeIndex);
  }

  // --- Pane operations ---

  void splitPane(Axis axis) {
    final tab = state.activeTab;
    if (tab == null) return;

    final currentFocusId = tab.focusedPaneId;
    final (newRoot, newLeaf) =
        PaneManager.split(tab.rootPane, currentFocusId, axis, history);
    _attachSessionListener(newLeaf.session);

    // Keep focus on the original pane, not the new one
    _updateActiveTab(TabState(
      rootPane: newRoot,
      focusedPaneId: currentFocusId,
    ));
  }

  void closePane() {
    final tab = state.activeTab;
    if (tab == null) return;

    final newRoot = PaneManager.close(tab.rootPane, tab.focusedPaneId);
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
    if (tab == null || tab.focusedPaneId == paneId) return;
    _updateActiveTab(TabState(
      rootPane: tab.rootPane,
      focusedPaneId: paneId,
    ));
  }

  void navigatePane(AxisDirection direction) {
    final tab = state.activeTab;
    if (tab == null) return;

    final targetId = PaneManager.findAdjacentPane(
      tab.rootPane,
      tab.focusedPaneId,
      direction,
    );
    if (targetId != null) setFocusedPane(targetId);
  }

  void movePane(String sourceId, String targetId, DropPosition position) {
    final tab = state.activeTab;
    if (tab == null || sourceId == targetId) return;

    final newRoot = PaneManager.movePane(
      tab.rootPane, sourceId, targetId, position,
    );
    if (newRoot == null) return;

    _updateActiveTab(TabState(
      rootPane: newRoot,
      focusedPaneId: sourceId,
    ));
  }

  void updateSplitRatio(String splitPaneId, double ratio) {
    final tab = state.activeTab;
    if (tab == null) return;
    _updateRatio(tab.rootPane, splitPaneId, ratio);
    // Trigger rebuild
    state = SessionState(
      tabs: state.tabs,
      activeTabIndex: state.activeTabIndex,
    );
  }

  // --- Internal helpers ---

  TabState _createTab({String? workingDirectory}) {
    final session = TerminalSession.start(
      id: _uuid.v4(),
      history: history,
      workingDirectory: workingDirectory,
    );
    final leaf = LeafPane(id: _uuid.v4(), session: session);
    _attachSessionListener(session);

    // Run startup commands from config
    final configLoader = ref.read(configLoaderProvider);
    final startupCommands = configLoader?.config.general.startupCommands;
    if (startupCommands != null && startupCommands.isNotEmpty) {
      session.runStartupCommands(startupCommands);
    }

    return TabState(rootPane: leaf, focusedPaneId: leaf.id);
  }

  void _attachTabListeners(TabState tab) {
    for (final leaf in PaneManager.allLeaves(tab.rootPane)) {
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

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

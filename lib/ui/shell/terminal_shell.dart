import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_loader.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/theme/default_dark.dart';
import '../../providers/config_provider.dart';
import '../../providers/font_size_provider.dart';
import '../../providers/session_provider.dart';
import '../settings/settings_screen.dart';
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

class _TerminalShellState extends ConsumerState<TerminalShell> {
  final _configLoader = ConfigLoader();

  @override
  void initState() {
    super.initState();
    _configLoader.addListener(_onConfigChanged);
    _configLoader.load();
    _configLoader.startWatching();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(configLoaderProvider.notifier).state = _configLoader;
    });
  }

  @override
  void dispose() {
    _configLoader.removeListener(_onConfigChanged);
    _configLoader.dispose();
    super.dispose();
  }

  void _onConfigChanged() {
    final config = _configLoader.config;
    final currentFontSize = ref.read(fontSizeProvider);
    if (config.editor.fontSize != currentFontSize) {
      ref.read(fontSizeProvider.notifier).setSize(config.editor.fontSize);
    }
  }

  void _switchTab(int delta) {
    final s = ref.read(sessionProvider);
    final count = s.tabs.length;
    if (count <= 1) return;
    final newIndex = (s.activeTabIndex + delta) % count;
    ref.read(sessionProvider.notifier).switchTab(newIndex);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BolonThemeProvider(
          theme: bolonDefaultDark,
          child: SettingsScreen(configLoader: _configLoader),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final activeTab = sessionState.activeTab;

    return BolonThemeProvider(
      theme: bolonDefaultDark,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.comma, meta: true):
              _openSettings,
          const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
              () => ref.read(sessionProvider.notifier).createTab(),
          const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
              () => ref.read(sessionProvider.notifier).closeTab(
                    ref.read(sessionProvider).activeTabIndex,
                  ),
          // Tab switching
          const SingleActivator(LogicalKeyboardKey.braceRight, meta: true):
              () => _switchTab(1),
          const SingleActivator(LogicalKeyboardKey.braceLeft, meta: true):
              () => _switchTab(-1),
          // Pane splitting
          const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .splitPane(Axis.horizontal),
          const SingleActivator(LogicalKeyboardKey.keyD,
                  meta: true, shift: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .splitPane(Axis.vertical),
          // Close pane
          const SingleActivator(LogicalKeyboardKey.keyW,
                  meta: true, shift: true):
              () => ref.read(sessionProvider.notifier).closePane(),
          // Pane navigation
          const SingleActivator(LogicalKeyboardKey.arrowLeft,
                  meta: true, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.left),
          const SingleActivator(LogicalKeyboardKey.arrowRight,
                  meta: true, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.right),
          const SingleActivator(LogicalKeyboardKey.arrowUp,
                  meta: true, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.up),
          const SingleActivator(LogicalKeyboardKey.arrowDown,
                  meta: true, alt: true):
              () => ref
                  .read(sessionProvider.notifier)
                  .navigatePane(AxisDirection.down),
        },
        child: Focus(
          autofocus: true,
          child: Container(
            color: bolonDefaultDark.background,
            child: Column(
              children: [
                BolonTabBar(onSettings: _openSettings),
                Expanded(
                  child: activeTab != null
                      ? PaneTreeWidget(
                          key: ValueKey(
                              'tab-${sessionState.activeTabIndex}'),
                          node: activeTab.rootPane,
                          focusedPaneId: activeTab.focusedPaneId,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

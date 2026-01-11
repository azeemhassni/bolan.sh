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
import 'session_view.dart';
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
    // Make config loader accessible to other widgets via Riverpod
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
    // Sync config font size to the font size provider
    final currentFontSize = ref.read(fontSizeProvider);
    if (config.editor.fontSize != currentFontSize) {
      ref.read(fontSizeProvider.notifier).setSize(config.editor.fontSize);
    }
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

    return BolonThemeProvider(
      theme: bolonDefaultDark,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.comma, meta: true):
              _openSettings,
        },
        child: Focus(
          autofocus: true,
          child: Container(
            color: bolonDefaultDark.background,
            child: Column(
              children: [
                BolonTabBar(onSettings: _openSettings),
                Expanded(
                  child: sessionState.activeSession != null
                      ? SessionView(
                          key: ValueKey(sessionState.activeSession!.id),
                          session: sessionState.activeSession!,
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

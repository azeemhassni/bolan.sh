import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bolan_theme.dart';
import '../../core/theme/default_dark.dart';
import '../../providers/session_provider.dart';
import 'session_view.dart';
import 'tab_bar.dart';

/// Root layout widget for the terminal emulator.
///
/// Arranges the tab bar (in the title bar area on macOS) and the active
/// terminal session view in a vertical column.
class TerminalShell extends ConsumerWidget {
  const TerminalShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);

    return BolonThemeProvider(
      theme: bolonDefaultDark,
      child: Container(
        color: bolonDefaultDark.background,
        child: Column(
          children: [
            // Tab bar drawn into the title bar area on macOS
            const BolonTabBar(),

            // Active session fills remaining space
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
    );
  }
}

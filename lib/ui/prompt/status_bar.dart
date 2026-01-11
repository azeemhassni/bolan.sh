import 'package:flutter/material.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../shared/status_chip.dart';

/// Status bar pinned at the bottom of the terminal, above the session area.
///
/// Shows CWD, git branch/status, shell name, and terminal dimensions.
/// Updates reactively when the session state changes.
class StatusBar extends StatelessWidget {
  final TerminalSession session;

  const StatusBar({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Container(
      height: 28,
      color: theme.statusBarBackground,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // CWD chip
          if (session.abbreviatedCwd.isNotEmpty)
            StatusChip(
              text: session.abbreviatedCwd,
              fg: theme.statusCwdFg,
              bg: theme.statusChipBg,
              icon: Icons.folder_outlined,
            ),

          if (session.abbreviatedCwd.isNotEmpty) const SizedBox(width: 6),

          // Git branch chip
          if (session.gitBranch.isNotEmpty) ...[
            StatusChip(
              text: '${session.gitBranch} ${session.gitDirty ? "!" : ""}',
              fg: theme.statusGitFg,
              bg: theme.statusChipBg,
            ),
            const SizedBox(width: 6),
          ],

          // Shell name chip
          StatusChip(
            text: session.shellName,
            fg: theme.statusShellFg,
            bg: theme.statusChipBg,
          ),

          const Spacer(),

          // Terminal dimensions
          Text(
            '${session.cols}\u00D7${session.rows}',
            style: TextStyle(
              color: theme.dimForeground,
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

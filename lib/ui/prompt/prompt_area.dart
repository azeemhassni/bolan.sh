import 'package:flutter/material.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../shared/status_chip.dart';
import 'prompt_input.dart';

/// Warp-style prompt area: status chips on top, text input below.
///
/// Sits at the bottom of the session view with a distinct background
/// and top border. Chips show shell, CWD, and git info with outlined style.
class PromptArea extends StatelessWidget {
  final TerminalSession session;
  final double fontSize;
  final GlobalKey<PromptInputState>? promptInputKey;

  const PromptArea({
    super.key,
    required this.session,
    this.fontSize = 13.0,
    this.promptInputKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.promptBackground,
        border: Border(
          top: BorderSide(color: theme.blockBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status chips row
          Padding(
            padding: const EdgeInsets.only(
              left: 12, right: 12, top: 10, bottom: 2,
            ),
            child: Row(
              children: [
                // Shell chip with terminal icon
                StatusChip(
                  text: session.shellName,
                  fg: theme.statusShellFg,
                  bg: theme.statusChipBg,
                  icon: Icons.chevron_right,
                ),
                const SizedBox(width: 6),

                // CWD chip with folder icon
                if (session.abbreviatedCwd.isNotEmpty) ...[
                  StatusChip(
                    text: session.abbreviatedCwd,
                    fg: theme.statusCwdFg,
                    bg: theme.statusChipBg,
                    icon: Icons.folder_outlined,
                  ),
                  const SizedBox(width: 6),
                ],

                // Git branch chip with branch icon
                if (session.gitBranch.isNotEmpty)
                  StatusChip(
                    text: '${session.gitBranch}${session.gitDirty ? " !" : ""}',
                    fg: theme.statusGitFg,
                    bg: theme.statusChipBg,
                    icon: Icons.fork_right,
                  ),
              ],
            ),
          ),

          // Text input
          PromptInput(
            key: promptInputKey,
            session: session,
            fontSize: fontSize,
          ),
        ],
      ),
    );
  }
}

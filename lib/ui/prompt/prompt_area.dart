import 'package:flutter/material.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../shared/status_chip.dart';
import 'prompt_input.dart';

/// Warp-style prompt area: status chips on top, text input below.
///
/// Sits at the bottom of the session view with a distinct background
/// and top border. Chips show shell, CWD, and git info with outlined style.
/// Background changes when AI mode is active (# prefix).
class PromptArea extends StatefulWidget {
  final TerminalSession session;
  final double fontSize;
  final String aiProvider;
  final String geminiModel;
  final String anthropicMode;
  final GlobalKey<PromptInputState>? promptInputKey;

  const PromptArea({
    super.key,
    required this.session,
    this.fontSize = 13.0,
    this.aiProvider = 'gemini',
    this.geminiModel = 'gemma-3-27b-it',
    this.anthropicMode = 'claude-code',
    this.promptInputKey,
  });

  @override
  State<PromptArea> createState() => _PromptAreaState();
}

class _PromptAreaState extends State<PromptArea> {
  bool _aiMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachListener();
    });
  }

  @override
  void didUpdateWidget(PromptArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.promptInputKey != widget.promptInputKey) {
      _attachListener();
    }
  }

  void _attachListener() {
    final state = widget.promptInputKey?.currentState;
    if (state != null) {
      state.aiModeNotifier.removeListener(_onAiModeChanged);
      state.aiModeNotifier.addListener(_onAiModeChanged);
    }
  }

  void _onAiModeChanged() {
    final state = widget.promptInputKey?.currentState;
    if (state == null) return;
    if (mounted && _aiMode != state.isAiMode) {
      setState(() => _aiMode = state.isAiMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _aiMode
            ? theme.ansiMagenta.withAlpha(15)
            : theme.promptBackground,
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
                  text: widget.session.shellName,
                  fg: theme.statusShellFg,
                  bg: theme.statusChipBg,
                  icon: Icons.chevron_right,
                ),
                const SizedBox(width: 6),

                // CWD chip with folder icon
                if (widget.session.abbreviatedCwd.isNotEmpty) ...[
                  StatusChip(
                    text: widget.session.abbreviatedCwd,
                    fg: theme.statusCwdFg,
                    bg: theme.statusChipBg,
                    icon: Icons.folder_outlined,
                  ),
                  const SizedBox(width: 6),
                ],

                // Git branch chip with branch icon
                if (widget.session.gitBranch.isNotEmpty)
                  StatusChip(
                    text: '${widget.session.gitBranch}${widget.session.gitDirty ? " !" : ""}',
                    fg: theme.statusGitFg,
                    bg: theme.statusChipBg,
                    icon: Icons.fork_right,
                  ),
              ],
            ),
          ),

          // Text input
          PromptInput(
            key: widget.promptInputKey,
            session: widget.session,
            fontSize: widget.fontSize,
            aiProvider: widget.aiProvider,
            geminiModel: widget.geminiModel,
            anthropicMode: widget.anthropicMode,
          ),
        ],
      ),
    );
  }
}

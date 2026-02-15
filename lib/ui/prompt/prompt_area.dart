import 'package:flutter/material.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../shared/status_chip.dart';
import 'git_diff_panel.dart';
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
  final bool commandSuggestions;
  final bool smartHistorySearch;
  final bool shareHistory;
  final GlobalKey<PromptInputState>? promptInputKey;

  const PromptArea({
    super.key,
    required this.session,
    this.fontSize = 13.0,
    this.aiProvider = 'gemini',
    this.geminiModel = 'gemma-3-27b-it',
    this.anthropicMode = 'claude-code',
    this.commandSuggestions = true,
    this.smartHistorySearch = true,
    this.shareHistory = false,
    this.promptInputKey,
  });

  @override
  State<PromptArea> createState() => _PromptAreaState();
}

class _PromptAreaState extends State<PromptArea> {
  bool _aiMode = false;
  bool _showDiffPanel = false;

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
              left: 12, right: 12, top: 10, bottom: 12,
            ),
            child: Row(
              children: [
                // Shell chip with terminal icon
                StatusChip(
                  text: widget.session.shellName,
                  fg: theme.statusShellFg,
                  bg: theme.statusChipBg,
                  svgIcon: 'assets/icons/ic_terminal.svg',
                ),
                const SizedBox(width: 6),

                // CWD chip with folder icon
                if (widget.session.abbreviatedCwd.isNotEmpty) ...[
                  StatusChip(
                    text: widget.session.abbreviatedCwd,
                    fg: theme.statusCwdFg,
                    bg: theme.statusChipBg,
                    svgIcon: 'assets/icons/ic_folder_code.svg',
                  ),
                  const SizedBox(width: 6),
                ],

                // Git branch chip
                if (widget.session.gitBranch.isNotEmpty) ...[
                  StatusChip(
                    text: '${widget.session.gitBranch}${widget.session.gitDirty ? " !" : ""}',
                    fg: theme.statusGitFg,
                    bg: theme.statusChipBg,
                    svgIcon: 'assets/icons/ic_git.svg',
                  ),
                  const SizedBox(width: 6),
                ],

                // Git changes chip — clickable to show diff
                if (widget.session.hasGitStats)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showDiffPanel = !_showDiffPanel),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.statusChipBg,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _showDiffPanel
                                ? theme.cursor.withAlpha(80)
                                : theme.foreground.withAlpha(40),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined,
                                size: 14, color: theme.foreground),
                            const SizedBox(width: 5),
                            Text(
                              '${widget.session.gitFilesChanged}',
                              style: TextStyle(
                                color: theme.foreground,
                                fontFamily: 'Operator Mono',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+${widget.session.gitInsertions}',
                              style: TextStyle(
                                color: theme.exitSuccessFg,
                                fontFamily: 'Operator Mono',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '-${widget.session.gitDeletions}',
                              style: TextStyle(
                                color: theme.exitFailureFg,
                                fontFamily: 'Operator Mono',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Diff panel
          if (_showDiffPanel)
            GitDiffPanel(
              cwd: widget.session.cwd,
              onClose: () => setState(() => _showDiffPanel = false),
            ),

          // Text input
          PromptInput(
            key: widget.promptInputKey,
            session: widget.session,
            fontSize: widget.fontSize,
            aiProvider: widget.aiProvider,
            geminiModel: widget.geminiModel,
            anthropicMode: widget.anthropicMode,
            commandSuggestions: widget.commandSuggestions,
            smartHistorySearch: widget.smartHistorySearch,
            shareHistory: widget.shareHistory,
          ),
        ],
      ),
    );
  }
}

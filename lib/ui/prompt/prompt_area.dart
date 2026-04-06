import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../core/config/prompt_config.dart';
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
  final bool aiEnabled;
  final String aiProvider;
  final String geminiModel;
  final String anthropicMode;
  final bool commandSuggestions;
  final bool smartHistorySearch;
  final bool shareHistory;
  final List<String> promptChips;
  final GlobalKey<PromptInputState>? promptInputKey;

  const PromptArea({
    super.key,
    required this.session,
    this.fontSize = 13.0,
    this.aiEnabled = false,
    this.aiProvider = 'gemini',
    this.geminiModel = 'gemma-3-27b-it',
    this.anthropicMode = 'claude-code',
    this.commandSuggestions = true,
    this.smartHistorySearch = true,
    this.shareHistory = false,
    this.promptChips = const ['shell', 'cwd', 'gitBranch', 'gitChanges'],
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

  List<Widget> _buildChip(String chipId, BolonTheme theme) {
    final type = PromptChipMeta.fromId(chipId);
    if (type == null) return [];

    switch (type) {
      case PromptChipType.shell:
        return [
          StatusChip(
            text: widget.session.shellName,
            fg: theme.statusShellFg,
            bg: theme.statusChipBg,
            svgIcon: 'assets/icons/ic_terminal.svg',
          ),
        ];

      case PromptChipType.cwd:
        if (widget.session.abbreviatedCwd.isEmpty) return [];
        return [
          StatusChip(
            text: widget.session.abbreviatedCwd,
            fg: theme.statusCwdFg,
            bg: theme.statusChipBg,
            svgIcon: 'assets/icons/ic_folder_code.svg',
          ),
        ];

      case PromptChipType.gitBranch:
        if (widget.session.gitBranch.isEmpty) return [];
        return [
          StatusChip(
            text: '${widget.session.gitBranch}${widget.session.gitDirty ? " !" : ""}',
            fg: theme.statusGitFg,
            bg: theme.statusChipBg,
            svgIcon: 'assets/icons/ic_git.svg',
          ),
        ];

      case PromptChipType.gitChanges:
        if (!widget.session.hasGitStats) return [];
        return [
          GestureDetector(
            onTap: () => setState(() => _showDiffPanel = !_showDiffPanel),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    SvgPicture.asset(
                      'assets/icons/ic_diff.svg',
                      width: 14, height: 14,
                      colorFilter: ColorFilter.mode(theme.foreground, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 5),
                    Text('${widget.session.gitFilesChanged}',
                      style: TextStyle(color: theme.foreground, fontFamily: theme.fontFamily,
                        fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                    const SizedBox(width: 6),
                    Text('+${widget.session.gitInsertions}',
                      style: TextStyle(color: theme.exitSuccessFg, fontFamily: theme.fontFamily,
                        fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                    const SizedBox(width: 4),
                    Text('-${widget.session.gitDeletions}',
                      style: TextStyle(color: theme.exitFailureFg, fontFamily: theme.fontFamily,
                        fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ),
          ),
        ];

      case PromptChipType.username:
        return [
          StatusChip(
            text: Platform.environment['USER'] ?? 'user',
            fg: theme.ansiYellow,
            bg: theme.statusChipBg,
            icon: Icons.person_outline,
          ),
        ];

      case PromptChipType.hostname:
        return [
          StatusChip(
            text: Platform.localHostname,
            fg: theme.ansiCyan,
            bg: theme.statusChipBg,
            icon: Icons.computer,
          ),
        ];

      case PromptChipType.time12h:
        return [
          StatusChip(
            text: DateFormat('hh:mm a').format(DateTime.now()),
            fg: theme.ansiRed,
            bg: theme.statusChipBg,
            icon: Icons.schedule,
          ),
        ];

      case PromptChipType.time24h:
        return [
          StatusChip(
            text: DateFormat('HH:mm').format(DateTime.now()),
            fg: theme.ansiRed,
            bg: theme.statusChipBg,
            icon: Icons.schedule,
          ),
        ];

      case PromptChipType.date:
        return [
          StatusChip(
            text: DateFormat('MMM d, y').format(DateTime.now()),
            fg: theme.ansiGreen,
            bg: theme.statusChipBg,
            icon: Icons.calendar_today,
          ),
        ];
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
          // Status chips row — built dynamically from config
          Padding(
            padding: const EdgeInsets.only(
              left: 12, right: 12, top: 10, bottom: 12,
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chipId in widget.promptChips)
                  ..._buildChip(chipId, theme),
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
            aiEnabled: widget.aiEnabled,
            aiProvider: widget.aiProvider,
            geminiModel: widget.geminiModel,
            anthropicMode: widget.anthropicMode,
            commandSuggestions: widget.aiEnabled && widget.commandSuggestions,
            smartHistorySearch: widget.aiEnabled && widget.smartHistorySearch,
            shareHistory: widget.aiEnabled && widget.shareHistory,
          ),
        ],
      ),
    );
  }
}

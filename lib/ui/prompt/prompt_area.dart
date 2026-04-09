import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/prompt_config.dart';
import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../shared/anchored_popover.dart';
import '../shared/bolan_dialog.dart';
import '../shared/popover_menu.dart';
import '../shared/status_chip.dart';
import 'branch_picker.dart';
import 'directory_picker.dart';
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
  final GlobalKey _cwdChipKey = GlobalKey();
  final GlobalKey _branchChipKey = GlobalKey();
  final GlobalKey _nvmChipKey = GlobalKey();
  final GlobalKey _kubeChipKey = GlobalKey();

  void _openDiffOverlay() {
    showBolanDialog<void>(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: GitDiffPanel(
            cwd: widget.session.cwd,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  void _openDirectoryPicker() {
    late AnchoredPopoverHandle handle;
    handle = showAnchoredPopover(
      context: context,
      anchorKey: _cwdChipKey,
      maxWidth: 360,
      maxHeight: 340,
      child: DirectoryPicker(
        initialPath: widget.session.cwd,
        onSelect: (path) {
          // cd into the chosen directory by sending the command to the
          // PTY. Quote to handle paths with spaces.
          widget.session.writeInput("cd '${path.replaceAll("'", "'\\''")}'\n");
        },
        onDismiss: () => handle.dismiss(),
      ),
    );
  }

  void _openBranchPicker() {
    late AnchoredPopoverHandle handle;
    handle = showAnchoredPopover(
      context: context,
      anchorKey: _branchChipKey,
      maxWidth: 320,
      maxHeight: 340,
      child: BranchPicker(
        cwd: widget.session.cwd,
        currentBranch: widget.session.gitBranch,
        onSelect: (branch) {
          widget.session.writeInput("git checkout '${branch.replaceAll("'", "'\\''")}'\n");
        },
        onDismiss: () => handle.dismiss(),
      ),
    );
  }

  /// Opens a popover listing all node versions installed via nvm.
  /// Selecting one writes `nvm use <v>` to the PTY.
  Future<void> _openNvmPicker() async {
    final versions = await _listNvmVersions();
    if (!mounted) return;
    if (versions.isEmpty) {
      widget.session.writeInput('nvm use\n');
      return;
    }
    final requested = widget.session.nvmrcVersion;
    late AnchoredPopoverHandle handle;
    handle = showAnchoredPopover(
      context: context,
      anchorKey: _nvmChipKey,
      maxWidth: 240,
      maxHeight: 320,
      child: PopoverMenuList(
        items: [
          for (final v in versions)
            PopoverMenuItem(
              icon: v == requested
                  ? Icons.check_circle_outline
                  : Icons.circle_outlined,
              label: v == requested ? '$v  (.nvmrc)' : v,
              onTap: () {
                widget.session.writeInput('nvm use $v\n');
                handle.dismiss();
              },
            ),
        ],
      ),
    );
  }

  /// `nvm ls` parsed into a list of bare version strings (e.g.
  /// `20.11.0`). Returns an empty list if nvm isn't installed or
  /// the shell isn't sourced — the caller falls back to writing
  /// `nvm use\n` directly.
  Future<List<String>> _listNvmVersions() async {
    final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    try {
      final result = await Process.run(
        shell,
        ['-l', '-c', 'nvm ls --no-colors --no-alias 2>/dev/null'],
      );
      if (result.exitCode != 0) return const [];
      final out = result.stdout as String;
      final versions = <String>[];
      for (final line in out.split('\n')) {
        final m = RegExp(r'v(\d+\.\d+\.\d+)').firstMatch(line);
        if (m != null) versions.add(m.group(1)!);
      }
      // Dedupe while preserving order, newest last.
      final seen = <String>{};
      return versions.where((v) => seen.add(v)).toList();
    } on ProcessException {
      return const [];
    }
  }

  /// Opens a popover listing all kubectl contexts. Selecting one
  /// runs `kubectl config use-context <name>` in the PTY.
  Future<void> _openKubePicker() async {
    final contexts = await _listKubeContexts();
    if (!mounted) return;
    final current = widget.session.kubeContext;
    late AnchoredPopoverHandle handle;
    handle = showAnchoredPopover(
      context: context,
      anchorKey: _kubeChipKey,
      maxWidth: 320,
      maxHeight: 360,
      child: PopoverMenuList(
        items: [
          for (final ctx in contexts)
            PopoverMenuItem(
              icon: ctx == current
                  ? Icons.check_circle_outline
                  : Icons.circle_outlined,
              label: ctx,
              onTap: () {
                widget.session.writeInput(
                    "kubectl config use-context '${ctx.replaceAll("'", "'\\''")}'\n");
                handle.dismiss();
              },
            ),
        ],
      ),
    );
  }

  Future<List<String>> _listKubeContexts() async {
    try {
      final result = await Process.run(
        'kubectl',
        ['config', 'get-contexts', '-o', 'name'],
      );
      if (result.exitCode != 0) return const [];
      return (result.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } on ProcessException {
      return const [];
    }
  }

  /// Sources the venv's `activate` script in the running shell.
  void _activatePythonVenv() {
    final venvPath = widget.session.pythonVenvPath;
    if (venvPath.isEmpty) return;
    final escaped = venvPath.replaceAll("'", "'\\''");
    widget.session.writeInput("source '$escaped/bin/activate'\n");
  }

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
          GestureDetector(
            key: _cwdChipKey,
            onTap: _openDirectoryPicker,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: StatusChip(
                text: widget.session.abbreviatedCwd,
                fg: theme.statusCwdFg,
                bg: theme.statusChipBg,
                svgIcon: 'assets/icons/ic_folder_code.svg',
              ),
            ),
          ),
        ];

      case PromptChipType.gitBranch:
        if (widget.session.gitBranch.isEmpty) return [];
        return [
          GestureDetector(
            key: _branchChipKey,
            onTap: _openBranchPicker,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: StatusChip(
                text: '${widget.session.gitBranch}${widget.session.gitDirty ? " !" : ""}',
                fg: theme.statusGitFg,
                bg: theme.statusChipBg,
                svgIcon: 'assets/icons/ic_git.svg',
              ),
            ),
          ),
        ];

      case PromptChipType.gitChanges:
        if (!widget.session.hasGitStats) return [];
        return [
          GestureDetector(
            onTap: _openDiffOverlay,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: StatusChip(
                fg: theme.foreground,
                bg: theme.statusChipBg,
                svgIcon: 'assets/icons/ic_diff.svg',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.session.gitFilesChanged}',
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: theme.fontFamily,
                        fontSize: StatusChip.textSizeFor(widget.fontSize),
                        fontWeight: StatusChip.textWeight,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${widget.session.gitInsertions}',
                      style: TextStyle(
                        color: theme.exitSuccessFg,
                        fontFamily: theme.fontFamily,
                        fontSize: StatusChip.textSizeFor(widget.fontSize),
                        fontWeight: StatusChip.textWeight,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '-${widget.session.gitDeletions}',
                      style: TextStyle(
                        color: theme.exitFailureFg,
                        fontFamily: theme.fontFamily,
                        fontSize: StatusChip.textSizeFor(widget.fontSize),
                        fontWeight: StatusChip.textWeight,
                        decoration: TextDecoration.none,
                      ),
                    ),
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

      case PromptChipType.nvm:
        if (!widget.session.hasNvmrc) return [];
        // Show the requested .nvmrc version. If `node --version`
        // returned something different, prepend a small mismatch
        // marker so the user knows they need to switch.
        final requested = widget.session.nvmrcVersion;
        final active = widget.session.nodeVersion.replaceFirst('v', '');
        final mismatch =
            active.isNotEmpty && active != requested;
        final label = mismatch ? '$requested (≠$active)' : 'v$requested';
        return [
          GestureDetector(
            key: _nvmChipKey,
            onTap: _openNvmPicker,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: StatusChip(
                text: label,
                fg: mismatch ? theme.ansiYellow : theme.ansiGreen,
                bg: theme.statusChipBg,
                svgIcon: 'assets/icons/ic_nodejs.svg',
              ),
            ),
          ),
        ];

      case PromptChipType.kubectl:
        if (!widget.session.hasKubeContext) return [];
        final ctx = widget.session.kubeContext;
        final ns = widget.session.kubeNamespace;
        final label = ns.isEmpty ? ctx : '$ctx · $ns';
        return [
          GestureDetector(
            key: _kubeChipKey,
            onTap: _openKubePicker,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: StatusChip(
                text: label,
                fg: theme.ansiBlue,
                bg: theme.statusChipBg,
                svgIcon: 'assets/icons/ic_kubernetes.svg',
              ),
            ),
          ),
        ];

      case PromptChipType.pythonVenv:
        if (!widget.session.hasPythonVenv) return [];
        final name = widget.session.pythonVenvName;
        final ver = widget.session.pythonVenvVersion;
        final label = ver.isNotEmpty ? '$name ($ver)' : name;
        return [
          GestureDetector(
            onTap: _activatePythonVenv,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: StatusChip(
                text: label,
                fg: theme.ansiYellow,
                bg: theme.statusChipBg,
                svgIcon: 'assets/icons/ic_python.svg',
              ),
            ),
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/keybinding.dart';
import '../../core/config/prompt_config.dart';
import '../../core/config/prompt_style.dart';
import 'chip_renderer.dart';
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
  final String cursorStyle;
  final Map<KeyAction, KeyBinding> keybindingOverrides;
  final PromptStyleConfig promptStyle;

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
    this.cursorStyle = 'bar',
    this.keybindingOverrides = const {},
    this.promptStyle = const PromptStyleConfig(),
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
        onSelect: (selection) {
          // For a remote branch we pass the full remote ref to
          // `git checkout -t` and let git derive the tracking local
          // name itself — attempting to strip a "remote prefix" in
          // Bolan is unsafe because branch-name segments can
          // coincidentally match real remote names.
          final quoted = selection.ref.replaceAll("'", "'\\''");
          final cmd = selection.isRemote
              ? "git checkout -t '$quoted'\n"
              : "git checkout '$quoted'\n";
          widget.session.writeInput(cmd);
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
    final requested = widget.session.nvmrcVersion;
    final activeRaw = widget.session.nodeVersion.replaceFirst('v', '');

    late AnchoredPopoverHandle handle;
    handle = showAnchoredPopover(
      context: context,
      anchorKey: _nvmChipKey,
      maxWidth: 260,
      maxHeight: 360,
      child: versions.isEmpty
          ? const _EmptyPopoverMessage(
              text: 'No nvm versions installed.\n'
                  'Install nvm and run `nvm install <v>`.',
            )
          : PopoverMenuList(
              items: [
                for (final v in versions)
                  PopoverMenuItem(
                    icon: v == activeRaw
                        ? Icons.check
                        : (v == requested
                            ? Icons.bookmark_outline
                            : Icons.circle_outlined),
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

  /// Lists installed node versions by reading the directories under
  /// `$NVM_DIR/versions/node/` (or `~/.nvm/versions/node/` if
  /// `$NVM_DIR` is unset). This bypasses the `nvm` shell function,
  /// which isn't available in non-interactive subshells.
  ///
  /// Returns versions sorted newest-first via a numeric semver
  /// comparison. Empty list if no nvm install exists at all.
  Future<List<String>> _listNvmVersions() async {
    final nvmDir = Platform.environment['NVM_DIR'] ??
        '${Platform.environment['HOME'] ?? ''}/.nvm';
    final dir = Directory('$nvmDir/versions/node');
    if (!dir.existsSync()) return const [];
    try {
      final entries = dir
          .listSync(followLinks: false)
          .whereType<Directory>()
          .map((e) => e.path.split('/').last)
          .map((name) => name.startsWith('v') ? name.substring(1) : name)
          .where((v) => RegExp(r'^\d+\.\d+\.\d+').hasMatch(v))
          .toList();
      entries.sort((a, b) => _compareSemver(b, a)); // newest first
      return entries;
    } on FileSystemException {
      return const [];
    }
  }

  /// Numeric semver comparison: 20.11.0 > 18.20.4 > 18.17.1.
  /// Falls back to string comparison if a version doesn't parse.
  int _compareSemver(String a, String b) {
    final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final ai = i < aParts.length ? aParts[i] : 0;
      final bi = i < bParts.length ? bParts[i] : 0;
      if (ai != bi) return ai - bi;
    }
    return 0;
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

  /// Returns chip data for the given chip type, or null if the chip
  /// should be hidden (e.g. no git branch detected).
  ChipData? _chipData(PromptChipType type, BolonTheme theme) {
    final fw = parseFontWeight(widget.promptStyle.fontWeight);
    switch (type) {
      case PromptChipType.shell:
        return ChipData(
          text: widget.session.shellName,
          fg: theme.statusShellFg,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_terminal.svg',
        );
      case PromptChipType.cwd:
        if (widget.session.abbreviatedCwd.isEmpty) return null;
        return ChipData(
          text: widget.session.abbreviatedCwd,
          fg: theme.statusCwdFg,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_folder_code.svg',
        );
      case PromptChipType.gitBranch:
        if (widget.session.gitBranch.isEmpty) return null;
        return ChipData(
          text: '${widget.session.gitBranch}${widget.session.gitDirty ? " !" : ""}',
          fg: theme.statusGitFg,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_git.svg',
        );
      case PromptChipType.gitChanges:
        if (!widget.session.hasGitStats) return null;
        return ChipData(
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
                  fontWeight: fw,
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
                  fontWeight: fw,
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
                  fontWeight: fw,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        );
      case PromptChipType.username:
        return ChipData(
          text: Platform.environment['USER'] ?? 'user',
          fg: theme.ansiYellow,
          bg: theme.statusChipBg,
          icon: Icons.person_outline,
        );
      case PromptChipType.hostname:
        return ChipData(
          text: Platform.localHostname,
          fg: theme.ansiCyan,
          bg: theme.statusChipBg,
          icon: Icons.computer,
        );
      case PromptChipType.time12h:
        return ChipData(
          text: DateFormat('hh:mm a').format(DateTime.now()),
          fg: theme.ansiRed,
          bg: theme.statusChipBg,
          icon: Icons.schedule,
        );
      case PromptChipType.time24h:
        return ChipData(
          text: DateFormat('HH:mm').format(DateTime.now()),
          fg: theme.ansiRed,
          bg: theme.statusChipBg,
          icon: Icons.schedule,
        );
      case PromptChipType.date:
        return ChipData(
          text: DateFormat('MMM d, y').format(DateTime.now()),
          fg: theme.ansiGreen,
          bg: theme.statusChipBg,
          icon: Icons.calendar_today,
        );
      case PromptChipType.nvm:
        if (!widget.session.hasNvmrc) return null;
        final requested = widget.session.nvmrcVersion;
        final active = widget.session.nodeVersion.replaceFirst('v', '');
        final matches = widget.session.nvmVersionMatches;
        final String label;
        if (active.isEmpty) {
          label = 'v$requested';
        } else if (matches) {
          label = 'v$active';
        } else {
          label = '$requested (≠$active)';
        }
        return ChipData(
          text: label,
          fg: matches ? theme.ansiGreen : theme.ansiYellow,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_nodejs.svg',
        );
      case PromptChipType.kubectl:
        if (!widget.session.hasKubeContext) return null;
        final ctx = widget.session.kubeContext;
        final ns = widget.session.kubeNamespace;
        return ChipData(
          text: ns.isEmpty ? ctx : '$ctx · $ns',
          fg: theme.ansiBlue,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_kubernetes.svg',
        );
      case PromptChipType.pythonVenv:
        final activePath = widget.session.activeVirtualEnv;
        final hasActive = activePath.isNotEmpty;
        final hasOnDisk = widget.session.hasPythonVenv;
        if (!hasActive && !hasOnDisk) return null;
        final name = hasActive
            ? activePath.split('/').last
            : widget.session.pythonVenvName;
        final ver = widget.session.pythonVenvVersion;
        return ChipData(
          text: ver.isNotEmpty && !hasActive ? '$name ($ver)' : name,
          fg: theme.ansiYellow,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_python.svg',
        );
      case PromptChipType.awsProfile:
        if (!widget.session.hasAwsProfile) return null;
        return ChipData(
          text: widget.session.awsProfile,
          fg: theme.ansiYellow,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_aws.svg',
        );
      case PromptChipType.gcpProject:
        if (!widget.session.hasGcpProject) return null;
        return ChipData(
          text: widget.session.gcpProject,
          fg: theme.ansiBlue,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_gcp.svg',
        );
      case PromptChipType.terraformWorkspace:
        if (!widget.session.hasTerraformWorkspace) return null;
        return ChipData(
          text: widget.session.terraformWorkspace,
          fg: theme.ansiMagenta,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_terraform.svg',
        );
      case PromptChipType.dockerContext:
        if (!widget.session.hasDockerContext) return null;
        return ChipData(
          text: widget.session.dockerContext,
          fg: theme.ansiCyan,
          bg: theme.statusChipBg,
          svgIcon: 'assets/icons/ic_docker.svg',
        );
    }
  }

  /// Wraps a rendered chip in the interactive wrapper (GestureDetector
  /// + MouseRegion) for chips that support clicking.
  Widget _wrapInteractive(
      PromptChipType type, Widget chip, BolonTheme theme) {
    switch (type) {
      case PromptChipType.cwd:
        return GestureDetector(
          key: _cwdChipKey,
          onTap: _openDirectoryPicker,
          child: MouseRegion(
              cursor: SystemMouseCursors.click, child: chip),
        );
      case PromptChipType.gitBranch:
        return GestureDetector(
          key: _branchChipKey,
          onTap: _openBranchPicker,
          child: MouseRegion(
              cursor: SystemMouseCursors.click, child: chip),
        );
      case PromptChipType.gitChanges:
        return GestureDetector(
          onTap: _openDiffOverlay,
          child: MouseRegion(
              cursor: SystemMouseCursors.click, child: chip),
        );
      case PromptChipType.nvm:
        return GestureDetector(
          key: _nvmChipKey,
          onTap: _openNvmPicker,
          child: MouseRegion(
              cursor: SystemMouseCursors.click, child: chip),
        );
      case PromptChipType.kubectl:
        return GestureDetector(
          key: _kubeChipKey,
          onTap: _openKubePicker,
          child: MouseRegion(
              cursor: SystemMouseCursors.click, child: chip),
        );
      case PromptChipType.pythonVenv:
        final hasActive = widget.session.activeVirtualEnv.isNotEmpty;
        return GestureDetector(
          onTap: hasActive ? null : _activatePythonVenv,
          child: MouseRegion(
            cursor: hasActive
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: chip,
          ),
        );
      default:
        return chip;
    }
  }

  Widget _buildChipsBar(BolonTheme theme) {
    final renderer = PromptChipRenderer.forStyle(widget.promptStyle);
    final fontSize = widget.fontSize;

    // Collect visible chips with their data and types.
    final visibleChips = <(PromptChipType, ChipData)>[];
    for (final chipId in widget.promptChips) {
      final type = PromptChipMeta.fromId(chipId);
      if (type == null) continue;
      final data = _chipData(type, theme);
      if (data == null) continue;
      visibleChips.add((type, data));
    }

    if (visibleChips.isEmpty) return const SizedBox.shrink();

    // For powerline, use inline segment building so each segment
    // knows its neighbor's color for the arrow fill.
    if (renderer is PowerlineChipRenderer) {
      final chips = visibleChips.map((e) => e.$2).toList();
      final types = visibleChips.map((e) => e.$1).toList();
      final segments = <Widget>[];
      for (var i = 0; i < chips.length; i++) {
        final bg = chips[i].fg.withAlpha(40);
        final nextBg = i + 1 < chips.length
            ? chips[i + 1].fg.withAlpha(40)
            : Colors.transparent;
        Widget segment = _PowerlineSegmentWidget(
          data: chips[i],
          bg: bg,
          nextBg: nextBg,
          isFirst: i == 0,
          fontSize: fontSize,
          theme: theme,
          style: widget.promptStyle,
        );
        segment = _wrapInteractive(types[i], segment, theme);
        segments.add(segment);
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: segments,
        ),
      );
    }

    // Default / Starship / Minimal: render each chip individually.
    final rendered = <Widget>[];
    for (final (type, data) in visibleChips) {
      Widget chip = renderer.buildChip(data, fontSize, theme);
      chip = _wrapInteractive(type, chip, theme);
      rendered.add(chip);
    }
    return renderer.buildLayout(rendered);
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
            child: _buildChipsBar(theme),
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
            cursorStyle: widget.cursorStyle,
            keybindingOverrides: widget.keybindingOverrides,
          ),
        ],
      ),
    );
  }
}

/// Centered dim message rendered inside an anchored popover when
/// there are no items to show. Used by the nvm and kubectl pickers
/// when their respective tools have nothing installed yet.
class _EmptyPopoverMessage extends StatelessWidget {
  final String text;
  const _EmptyPopoverMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 12,
            height: 1.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// Inline powerline segment used by PromptArea for the powerline style.
class _PowerlineSegmentWidget extends StatelessWidget {
  final ChipData data;
  final Color bg;
  final Color nextBg;
  final bool isFirst;
  final double fontSize;
  final BolonTheme theme;
  final PromptStyleConfig style;

  const _PowerlineSegmentWidget({
    required this.data,
    required this.bg,
    required this.nextBg,
    required this.isFirst,
    required this.fontSize,
    required this.theme,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final arrowWidth = fontSize * 0.7;
    return CustomPaint(
      painter: _PowerlinePainter(
        bg: bg,
        nextBg: nextBg,
        arrowWidth: arrowWidth,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: isFirst ? style.chipPaddingH : style.chipPaddingH + 4,
          right: style.chipPaddingH + arrowWidth,
          top: style.chipPaddingV,
          bottom: style.chipPaddingV,
        ),
        child: buildChipContent(
          data: data,
          fontSize: fontSize,
          theme: theme,
          fontWeight: parseFontWeight(style.fontWeight),
          showIcon: style.showIcons,
        ),
      ),
    );
  }
}

class _PowerlinePainter extends CustomPainter {
  final Color bg;
  final Color nextBg;
  final double arrowWidth;

  _PowerlinePainter({
    required this.bg,
    required this.nextBg,
    required this.arrowWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyWidth = size.width - arrowWidth;
    final midY = size.height / 2;

    final bodyPaint = Paint()..color = bg;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, bodyWidth, size.height),
      bodyPaint,
    );

    final arrowPath = Path()
      ..moveTo(bodyWidth, 0)
      ..lineTo(bodyWidth + arrowWidth, midY)
      ..lineTo(bodyWidth, size.height)
      ..close();

    if (nextBg != Colors.transparent) {
      final gapPaint = Paint()..color = nextBg;
      final gapPath = Path()
        ..moveTo(bodyWidth, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(bodyWidth, size.height)
        ..close();
      canvas.drawPath(gapPath, gapPaint);
    }

    canvas.drawPath(arrowPath, bodyPaint);
  }

  @override
  bool shouldRepaint(_PowerlinePainter old) =>
      bg != old.bg || nextBg != old.nextBg || arrowWidth != old.arrowWidth;
}

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai/ai_provider_helper.dart';
import '../../core/ai/features/error_explain.dart';
import '../../core/terminal/command_block.dart';
import '../../core/theme/bolan_theme.dart';
import '../shared/anchored_popover.dart';
import '../shared/popover_menu.dart';
import 'ansi_text_parser.dart';
import 'linkified_text.dart';
import 'share_image_dialog.dart';

/// Renders a completed command as a Warp-style block.
///
/// Shows the command text as a header with a subtle left accent border
/// (green for success, red for failure), followed by scrollable output.
/// Large outputs are capped with scroll-to-top/bottom arrow buttons.
class CommandBlockWidget extends StatefulWidget {
  final CommandBlock block;
  final double fontSize;
  final double lineHeight;
  final bool scrollable;
  final String cwd;
  final String shellName;
  final bool aiEnabled;
  final String aiProvider;
  final String geminiModel;
  final String anthropicMode;
  final bool ligatures;
  final RegExp? searchHighlight;
  final int currentMatchIndex;
  final int blockMatchStartIndex;
  final void Function(TapDownDetails)? onSecondaryTap;

  /// Called when the user clicks the "re-run" action button. The
  /// caller is responsible for actually re-executing the command
  /// (typically by writing it to the PTY). If null, the button is
  /// hidden.
  final void Function(String command)? onRerun;

  const CommandBlockWidget({
    super.key,
    required this.block,
    this.fontSize = 13,
    this.lineHeight = 1.2,
    this.scrollable = false,
    this.cwd = '',
    this.shellName = 'zsh',
    this.aiEnabled = false,
    this.aiProvider = 'gemini',
    this.geminiModel = 'gemma-3-27b-it',
    this.anthropicMode = 'claude-code',
    this.ligatures = false,
    this.searchHighlight,
    this.currentMatchIndex = -1,
    this.blockMatchStartIndex = 0,
    this.onSecondaryTap,
    this.onRerun,
  });

  @override
  State<CommandBlockWidget> createState() => _CommandBlockWidgetState();
}

/// Which copy action just completed. Drives the brief checkmark flash
/// on the corresponding action button.
enum _CopyFlash { none, command, output, block }

class _CommandBlockWidgetState extends State<CommandBlockWidget> {
  bool _hovered = false;
  _CopyFlash _copyFlash = _CopyFlash.none;
  bool _explaining = false;
  String? _explanation;
  final GlobalKey _moreMenuKey = GlobalKey();

  static const double _headerHeight = 44;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final block = widget.block;
    // Non-zero exit = failed, but exclude signal kills (Ctrl+C = 130,
    // SIGTERM = 143) — those are intentional, not errors to explain.
    final isFailed = block.exitCode != null &&
        block.exitCode! > 0 &&
        block.exitCode != 130 &&
        block.exitCode != 143;

    // Each block is a SliverMainAxisGroup containing three slivers:
    //   1. The prompt context line (scrolls away normally)
    //   2. A pinned SliverPersistentHeader for the command + action bar
    //      — stays at the top of the viewport while any of this block's
    //      body is in view, then unpins as the next block's header
    //      takes over.
    //   3. The body output + explanation + divider (scrolls normally).
    return SliverMainAxisGroup(
      slivers: [
        // 1. Prompt context line
        SliverToBoxAdapter(
          child: _wrapWithLeftAccent(
            isFailed: isFailed,
            theme: theme,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 9, right: 12, top: 12, bottom: 2,
              ),
              child: _buildPromptContext(block, theme),
            ),
          ),
        ),

        // 2. Pinned command + action bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _BlockHeaderDelegate(
            height: _headerHeight,
            child: _wrapWithLeftAccent(
              isFailed: isFailed,
              theme: theme,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: Container(
                  color: _hovered
                      ? theme.blockBackground
                      : theme.background,
                  padding: const EdgeInsets.only(
                    left: 9, right: 12, top: 8, bottom: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          block.command,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.foreground,
                            fontFamily: theme.fontFamily,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: _hovered ? 1.0 : 0.45,
                        duration: const Duration(milliseconds: 120),
                        child: _buildActionBar(theme, block),
                      ),
                      if (block.duration != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(block.duration!),
                          style: TextStyle(
                            color: theme.dimForeground,
                            fontFamily: theme.fontFamily,
                            fontSize: widget.fontSize - 2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. Body — output, explanation, divider
        SliverToBoxAdapter(
          child: _wrapWithLeftAccent(
            isFailed: isFailed,
            theme: theme,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                onTap: block.hasOutput ? _copyOutput : null,
                child: Container(
                  color: _hovered
                      ? theme.blockBackground
                      : theme.background,
                  padding: const EdgeInsets.only(
                    left: 9, right: 12, top: 0, bottom: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Output body
                      if (block.hasOutput && !widget.block.collapsed)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _buildScrollableOutput(block, theme),
                        ),

                      // Collapsed placeholder
                      if (block.hasOutput && widget.block.collapsed)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text(
                            'Output collapsed',
                            style: TextStyle(
                              color: theme.dimForeground,
                              fontFamily: theme.fontFamily,
                              fontSize: widget.fontSize - 1,
                              fontStyle: FontStyle.italic,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),

                      // Error explanation
                      if (isFailed && _explanation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.statusChipBg,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.blockBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Icon(Icons.auto_awesome,
                                            size: 14,
                                            color: theme.ansiYellow),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: SelectableText(
                                          _explanation!,
                                          style: TextStyle(
                                            color: theme.foreground,
                                            fontFamily: theme.fontFamily,
                                            fontSize:
                                                widget.fontSize - 1,
                                            height: 1.4,
                                            decoration:
                                                TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // "Explain Error" chip for failed commands
                      if (isFailed &&
                          _explanation == null &&
                          widget.aiEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _explaining ? null : _explainError,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.statusChipBg,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                        color: theme.blockBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_explaining)
                                          SizedBox(
                                            width: widget.fontSize,
                                            height: widget.fontSize,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: theme.ansiYellow,
                                            ),
                                          )
                                        else
                                          Icon(Icons.auto_awesome,
                                              size: widget.fontSize,
                                              color: theme.ansiYellow),
                                        const SizedBox(width: 8),
                                        Text(
                                          _explaining
                                              ? 'Explaining...'
                                              : 'Explain this error.',
                                          style: TextStyle(
                                            color: theme.foreground,
                                            fontFamily: theme.fontFamily,
                                            fontSize: widget.fontSize * 0.85,
                                            decoration:
                                                TextDecoration.none,
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

                      // Divider between blocks
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.blockBorder.withAlpha(60),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wraps a sliver child in a Container that paints the failed-block
  /// left accent border. Used by all three slivers in the group so the
  /// red stripe is visually continuous.
  Widget _wrapWithLeftAccent({
    required bool isFailed,
    required BolonTheme theme,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isFailed ? theme.exitFailureFg : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _buildPromptContext(CommandBlock block, BolonTheme theme) {
    final duration = block.duration;
    final durationText = duration != null ? _formatDuration(duration) : '';

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: theme.fontFamily,
          fontSize: widget.fontSize - 2,
          decoration: TextDecoration.none,
        ),
        children: [
          if (block.shellName.isNotEmpty)
            TextSpan(
              text: '${block.shellName} ',
              style: TextStyle(color: theme.dimForeground),
            ),
          if (block.cwd.isNotEmpty)
            TextSpan(
              text: '${block.cwd} ',
              style: TextStyle(color: theme.statusCwdFg),
            ),
          if (block.gitBranch != null)
            TextSpan(
              text: 'git:(${block.gitBranch}) ',
              style: TextStyle(color: theme.statusGitFg),
            ),
          if (durationText.isNotEmpty)
            TextSpan(
              text: '($durationText)',
              style: TextStyle(color: theme.dimForeground),
            ),
        ],
      ),
    );
  }

  /// Overlays search highlights on top of existing styled spans.
  List<TextSpan> _applySearchHighlights(
    String plainText,
    List<TextSpan> coloredSpans,
    TextStyle baseStyle,
    BolonTheme theme,
  ) {
    final regex = widget.searchHighlight!;
    final matches = regex.allMatches(plainText).toList();
    if (matches.isEmpty) return coloredSpans;

    final highlightStyle = baseStyle.copyWith(
      backgroundColor: theme.ansiYellow.withAlpha(60),
    );
    final currentHighlightStyle = baseStyle.copyWith(
      backgroundColor: theme.ansiYellow.withAlpha(150),
      color: theme.background,
    );

    final result = <TextSpan>[];
    var lastEnd = 0;

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final globalIndex = widget.blockMatchStartIndex + i;
      final isCurrent = globalIndex == widget.currentMatchIndex;

      if (match.start > lastEnd) {
        result.add(TextSpan(
          text: plainText.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      result.add(TextSpan(
        text: plainText.substring(match.start, match.end),
        style: isCurrent ? currentHighlightStyle : highlightStyle,
      ));

      lastEnd = match.end;
    }

    if (lastEnd < plainText.length) {
      result.add(TextSpan(
        text: plainText.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return result;
  }

  Widget _buildScrollableOutput(CommandBlock block, BolonTheme theme) {
    final baseStyle = TextStyle(
      color: theme.foreground,
      fontFamily: theme.fontFamily,
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      decoration: TextDecoration.none,
    );

    Widget textWidget;

    // Search highlights take priority over ANSI coloring
    if (widget.searchHighlight != null) {
      List<TextSpan> spans;
      if (block.rawOutput.isNotEmpty) {
        final parser = AnsiTextParser(theme, ligatures: widget.ligatures);
        spans = parser.parse(block.rawOutput, baseStyle: baseStyle);
      } else {
        spans = [TextSpan(text: block.output, style: baseStyle)];
      }
      spans = _applySearchHighlights(block.output, spans, baseStyle, theme);
      textWidget = SelectableText.rich(
        TextSpan(children: spans),
        contextMenuBuilder: (_, __) => const SizedBox.shrink(),
      );
    } else if (block.rawOutput.isNotEmpty) {
      final parser = AnsiTextParser(theme, ligatures: widget.ligatures);
      final spans = parser.parse(block.rawOutput, baseStyle: baseStyle);
      final linkedSpans = LinkifiedText.linkify(
        spans,
        linkColor: theme.ansiCyan,
        cwd: widget.cwd,
      );
      textWidget = SelectableText.rich(
        TextSpan(children: linkedSpans),
        contextMenuBuilder: (_, __) => const SizedBox.shrink(),
      );
    } else {
      textWidget = SelectableText(
        block.output,
        contextMenuBuilder: (_, __) => const SizedBox.shrink(),
        style: baseStyle,
      );
    }

    return GestureDetector(
      onSecondaryTapDown: widget.onSecondaryTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: textWidget,
      ),
    );
  }

  Future<void> _explainError() async {
    if (_explaining) return;
    setState(() => _explaining = true);

    try {
      final provider = await AiProviderHelper.create(
        providerName: widget.aiProvider,
        geminiModel: widget.geminiModel,
        anthropicMode: widget.anthropicMode,
      );
      if (provider == null) throw Exception('No AI provider available.');

      final explainer = ErrorExplainer(provider: provider);

      final result = await explainer.explain(
        command: widget.block.command,
        output: widget.block.output,
        exitCode: widget.block.exitCode ?? 1,
        cwd: widget.cwd,
        shellName: widget.shellName,
      );

      if (!mounted) return;
      setState(() => _explanation = result);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _explanation = 'Error: $e');
    } finally {
      if (mounted) setState(() => _explaining = false);
    }
  }

  Future<void> _flashCopy(_CopyFlash which) async {
    if (!mounted) return;
    setState(() => _copyFlash = which);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted && _copyFlash == which) {
      setState(() => _copyFlash = _CopyFlash.none);
    }
  }

  Future<void> _copyCommand() async {
    await Clipboard.setData(ClipboardData(text: widget.block.command));
    await _flashCopy(_CopyFlash.command);
  }

  Future<void> _copyOutput() async {
    await Clipboard.setData(ClipboardData(text: widget.block.output));
    await _flashCopy(_CopyFlash.output);
  }

  Future<void> _copyBlock() async {
    final text = '${widget.block.command}\n${widget.block.output}';
    await Clipboard.setData(ClipboardData(text: text));
    await _flashCopy(_CopyFlash.block);
  }

  Future<void> _shareAsImage() async {
    final theme = BolonTheme.of(context);
    await showShareImageDialog(
      context,
      command: widget.block.command,
      output: widget.block.output,
      rawOutput: widget.block.rawOutput,
      shellName: widget.shellName,
      theme: theme,
    );
  }

  Future<void> _saveOutput() async {
    final loc = await getSaveLocation(
      suggestedName: 'output.txt',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Text', extensions: ['txt', 'log']),
      ],
    );
    if (loc == null) return;
    try {
      await File(loc.path).writeAsString(widget.block.output);
    } on FileSystemException {
      // Best effort — surface a snackbar later if needed.
    }
  }

  void _showMoreMenu() {
    final isFailed =
        widget.block.exitCode != null &&
        widget.block.exitCode! > 0 &&
        widget.block.exitCode != 130 &&
        widget.block.exitCode != 143;
    final hasOutput = widget.block.hasOutput;
    final canExplain = widget.aiEnabled && isFailed && _explanation == null;

    late AnchoredPopoverHandle handle;
    handle = showAnchoredPopover(
      context: context,
      anchorKey: _moreMenuKey,
      maxWidth: 240,
      maxHeight: 240,
      child: PopoverMenuList(
        items: [
          PopoverMenuItem(
            icon: Icons.content_paste_outlined,
            label: 'Copy command + output',
            onTap: () {
              _copyBlock();
              handle.dismiss();
            },
          ),
          if (hasOutput)
            PopoverMenuItem(
              icon: Icons.save_alt_outlined,
              label: 'Save output to file…',
              onTap: () {
                _saveOutput();
                handle.dismiss();
              },
            ),
          PopoverMenuItem(
            icon: Icons.image_outlined,
            label: 'Share as image…',
            onTap: () {
              handle.dismiss();
              _shareAsImage();
            },
          ),
          if (canExplain)
            PopoverMenuItem(
              icon: Icons.auto_awesome,
              label: 'Explain error with AI',
              onTap: () {
                _explainError();
                handle.dismiss();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BolonTheme theme, CommandBlock block) {
    final hasOutput = block.hasOutput;
    final canRerun = widget.onRerun != null && block.command.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BlockActionButton(
          icon: _copyFlash == _CopyFlash.command
              ? Icons.check
              : Icons.terminal,
          tooltip: 'Copy command',
          theme: theme,
          highlight: _copyFlash == _CopyFlash.command,
          onTap: _copyCommand,
        ),
        if (hasOutput) ...[
          const SizedBox(width: 2),
          _BlockActionButton(
            icon: _copyFlash == _CopyFlash.output
                ? Icons.check
                : Icons.content_copy_outlined,
            tooltip: 'Copy output',
            theme: theme,
            highlight: _copyFlash == _CopyFlash.output,
            onTap: _copyOutput,
          ),
        ],
        if (canRerun) ...[
          const SizedBox(width: 2),
          _BlockActionButton(
            icon: Icons.refresh,
            tooltip: 'Re-run command',
            theme: theme,
            onTap: () => widget.onRerun!(block.command),
          ),
        ],
        if (hasOutput) ...[
          const SizedBox(width: 2),
          _BlockActionButton(
            icon:
                widget.block.collapsed ? Icons.expand_more : Icons.expand_less,
            tooltip: widget.block.collapsed ? 'Expand output' : 'Collapse output',
            theme: theme,
            onTap: () => setState(() =>
                widget.block.collapsed = !widget.block.collapsed),
          ),
        ],
        const SizedBox(width: 2),
        _BlockActionButton(
          key: _moreMenuKey,
          icon: Icons.more_horiz,
          tooltip: 'More actions',
          theme: theme,
          onTap: _showMoreMenu,
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    if (d.inSeconds > 0) {
      return '${d.inSeconds}.${(d.inMilliseconds.remainder(1000) ~/ 100)}s';
    }
    return '${d.inMilliseconds}ms';
  }
}

/// Delegate for [SliverPersistentHeader] that holds a command block's
/// command + action bar. Fixed extent — long commands ellipsize.
class _BlockHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _BlockHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _BlockHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

/// Single icon button used in a command block's action bar.
///
/// 28×28 hit target with a 14px icon. Hover paints a subtle background
/// chip in `statusChipBg`. Wraps the icon in a [Tooltip] with a short
/// reveal delay matching the rest of Bolan's tooltips.
class _BlockActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final BolonTheme theme;
  final VoidCallback onTap;

  /// When true, the icon is rendered in the success color (used for
  /// the brief checkmark flash after a copy action).
  final bool highlight;

  const _BlockActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.theme,
    required this.onTap,
    this.highlight = false,
  });

  @override
  State<_BlockActionButton> createState() => _BlockActionButtonState();
}

class _BlockActionButtonState extends State<_BlockActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final fg = widget.highlight
        ? t.exitSuccessFg
        : (_hovered ? t.foreground : t.dimForeground);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? t.statusChipBg : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Icon(widget.icon, size: 15, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}


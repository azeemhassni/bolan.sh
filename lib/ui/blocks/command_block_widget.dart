import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai/ai_provider_helper.dart';
import '../../core/ai/features/error_explain.dart';
import '../../core/terminal/command_block.dart';
import '../../core/theme/bolan_theme.dart';
import 'ansi_text_parser.dart';
import 'linkified_text.dart';

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
  });

  @override
  State<CommandBlockWidget> createState() => _CommandBlockWidgetState();
}

class _CommandBlockWidgetState extends State<CommandBlockWidget> {
  bool _hovered = false;
  bool _copied = false;
  bool _explaining = false;
  String? _explanation;
  final _scrollController = ScrollController();
  bool _showTopArrow = false;
  bool _showBottomArrow = false;

  static const _fallbackMaxHeight = 500.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atTop = pos.pixels <= 0;
    final atBottom = pos.pixels >= pos.maxScrollExtent;
    final needsScroll = pos.maxScrollExtent > 0;

    if (mounted) {
      setState(() {
        _showTopArrow = needsScroll && !atTop;
        _showBottomArrow = needsScroll && !atBottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final block = widget.block;
    final isFailed = block.exitCode != null && block.exitCode! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prompt context line
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 2),
          child: _buildPromptContext(block, theme),
        ),
        // Block body
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: block.hasOutput ? _copyOutput : null,
            child: Container(
              decoration: BoxDecoration(
                color: _hovered ? theme.blockBackground : theme.background,
                border: Border(
                  left: BorderSide(
                    color: isFailed ? theme.exitFailureFg : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(
                left: 9, right: 12, top: 4, bottom: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Command header
                  Row(
                children: [
                  Expanded(
                    child: Text(
                      block.command,
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: theme.fontFamily,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (_copied)
                    Text(
                      'Copied',
                      style: TextStyle(
                        color: theme.exitSuccessFg,
                        fontSize: 11,
                        fontFamily: theme.fontFamily,
                        decoration: TextDecoration.none,
                      ),
                    )
                  else if (_hovered && block.hasOutput)
                    Icon(
                      Icons.content_copy,
                      size: 13,
                      color: theme.dimForeground,
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

              // Output body
              if (block.hasOutput)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _buildScrollableOutput(block, theme),
                ),

              // Error explanation
              if (isFailed && _explanation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.ansiMagenta.withAlpha(10),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.ansiMagenta.withAlpha(40),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 14, color: theme.ansiMagenta),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            _explanation!,
                            style: TextStyle(
                              color: theme.foreground,
                              fontFamily: theme.fontFamily,
                              fontSize: widget.fontSize - 1,
                              height: 1.4,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // "Explain Error" button for failed commands
              if (isFailed && _explanation == null && widget.aiEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: GestureDetector(
                    onTap: _explaining ? null : _explainError,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_explaining)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: theme.ansiMagenta,
                              ),
                            )
                          else
                            Icon(Icons.auto_awesome,
                                size: 13, color: theme.ansiMagenta),
                          const SizedBox(width: 6),
                          Text(
                            _explaining ? 'Explaining...' : 'Explain Error',
                            style: TextStyle(
                              color: theme.ansiMagenta,
                              fontFamily: theme.fontFamily,
                              fontSize: 12,
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
      ),
    ),
    // Divider between blocks
    Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: theme.blockBorder.withAlpha(60),
      ),
    ),
    ],
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

  Widget _buildPlainOutput(CommandBlock block, BolonTheme theme) {
    final baseStyle = TextStyle(
      color: theme.foreground,
      fontFamily: theme.fontFamily,
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      decoration: TextDecoration.none,
    );

    // Use colored output if available
    List<TextSpan> spans;
    if (block.rawOutput.isNotEmpty) {
      final parser = AnsiTextParser(theme, ligatures: widget.ligatures);
      spans = parser.parse(block.rawOutput, baseStyle: baseStyle);
    } else {
      spans = [TextSpan(text: block.output, style: baseStyle)];
    }

    // Make URLs clickable (Cmd+click / Ctrl+click)
    final linkedSpans = LinkifiedText.linkify(
      spans,
      linkColor: theme.ansiCyan,
    );

    // Apply search highlights if active
    if (widget.searchHighlight != null) {
      spans = _applySearchHighlights(
        block.output, spans, baseStyle, theme,
      );
      return GestureDetector(
        onSecondaryTapDown: widget.onSecondaryTap,
        child: SelectableText.rich(
          TextSpan(children: spans),
          contextMenuBuilder: (_, __) => const SizedBox.shrink(),
        ),
      );
    }

    return GestureDetector(
      onSecondaryTapDown: widget.onSecondaryTap,
      child: SelectableText.rich(
        TextSpan(children: linkedSpans),
        contextMenuBuilder: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  /// Overlays search highlights on top of existing styled spans.
  /// Rebuilds spans from plain text with highlights, preserving colors
  /// from the ANSI parser would be complex — so we use plain text
  /// with highlights for simplicity when search is active.
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

      // Text before match
      if (match.start > lastEnd) {
        result.add(TextSpan(
          text: plainText.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // Highlighted match
      result.add(TextSpan(
        text: plainText.substring(match.start, match.end),
        style: isCurrent ? currentHighlightStyle : highlightStyle,
      ));

      lastEnd = match.end;
    }

    // Remaining text
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
    if (block.rawOutput.isNotEmpty) {
      final parser = AnsiTextParser(theme, ligatures: widget.ligatures);
      final spans = parser.parse(block.rawOutput, baseStyle: baseStyle);
      textWidget = SelectableText.rich(
        TextSpan(children: spans),
        contextMenuBuilder: (_, __) => const SizedBox.shrink(),
      );
    } else {
      textWidget = SelectableText(
        block.output,
        contextMenuBuilder: (_, __) => const SizedBox.shrink(),
        style: baseStyle,
      );
    }

    // Use the window height minus some room for header/prompt
    final maxHeight = MediaQuery.of(context).size.height - 120;

    return Stack(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight > 0 ? maxHeight : _fallbackMaxHeight,
          ),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onSecondaryTapDown: widget.onSecondaryTap,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: textWidget,
              ),
            ),
          ),
        ),
        if (_showTopArrow)
          Positioned(
            top: 0,
            right: 0,
            child: _ScrollArrow(
              icon: Icons.keyboard_arrow_up,
              theme: theme,
              onTap: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ),
            ),
          ),
        if (_showBottomArrow)
          Positioned(
            bottom: 0,
            right: 0,
            child: _ScrollArrow(
              icon: Icons.keyboard_arrow_down,
              theme: theme,
              onTap: () => _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ),
            ),
          ),
      ],
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

  Future<void> _copyOutput() async {
    await Clipboard.setData(ClipboardData(text: widget.block.output));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
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

class _ScrollArrow extends StatelessWidget {
  final IconData icon;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _ScrollArrow({
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: theme.blockBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.blockBorder, width: 1),
          ),
          child: Icon(icon, size: 16, color: theme.dimForeground),
        ),
      ),
    );
  }
}

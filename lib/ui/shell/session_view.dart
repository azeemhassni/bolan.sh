import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/theme/xterm_theme.dart';
import '../../providers/config_provider.dart';
import '../../providers/font_size_provider.dart';
import '../../providers/session_provider.dart';
import '../blocks/command_block_widget.dart';
import '../prompt/prompt_area.dart';
import '../prompt/prompt_input.dart';
import '../shared/font_size_toast.dart';
import 'find_bar.dart';
import 'pane_focus_registry.dart';

/// Renders a terminal session with Warp-style flowing layout.
///
/// Completed commands are rendered as styled block widgets. During command
/// execution, a live TerminalView shows output. The prompt area flows
/// right after the last content.
class SessionView extends ConsumerStatefulWidget {
  final TerminalSession session;
  final bool isFocusedPane;
  final String? paneId;
  final void Function(TapDownDetails)? onSecondaryTap;

  const SessionView({
    super.key,
    required this.session,
    this.isFocusedPane = true,
    this.paneId,
    this.onSecondaryTap,
  });

  @override
  ConsumerState<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<SessionView> {
  final _terminalController = TerminalController();
  final _scrollController = ScrollController();
  late final FocusNode _terminalFocusNode;
  final _promptKey = GlobalKey<PromptInputState>();
  bool _showToast = false;
  bool _wasRunning = false;

  // Find bar state
  final _findBarKey = GlobalKey<FindBarState>();
  bool _showFindBar = false;
  int _findCurrentMatch = 0;
  int _findTotalMatches = 0;
  List<_FindMatch> _findMatches = [];
  FindResult? _lastFindResult;

  @override
  void initState() {
    super.initState();
    _terminalFocusNode = FocusNode(debugLabel: 'terminal-${widget.session.id}');
    widget.session.addListener(_onSessionChanged);
    // Register prompt for global focus forwarding after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.paneId != null && _promptKey.currentState != null) {
        PaneFocusRegistry.register(widget.paneId!, _promptKey.currentState!);
      }
    });
  }

  @override
  void didUpdateWidget(SessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSessionChanged);
      widget.session.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    if (widget.paneId != null) PaneFocusRegistry.unregister(widget.paneId!);
    widget.session.removeListener(_onSessionChanged);
    _terminalController.dispose();
    _scrollController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final isRunning = widget.session.isCommandRunning;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Command just started → focus the terminal
      if (isRunning && !_wasRunning) {
        _terminalFocusNode.requestFocus();
        // Wait two frames for TerminalView to layout and autoResize,
        // then re-send dimensions so the program gets the correct size.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final t = widget.session.terminal;
          widget.session.resize(t.viewHeight, t.viewWidth);
        });
      }

      // Command just finished → focus the prompt input
      if (!isRunning && _wasRunning) {
        _promptKey.currentState?.requestFocus();
      }

      // Auto-scroll blocks list
      if (!isRunning && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }

      _wasRunning = isRunning;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final fontSize = ref.watch(fontSizeProvider);
    final configLoader = ref.watch(configLoaderProvider);
    final lineHeight = configLoader?.config.editor.lineHeight ?? 1.0;
    final fontFamily = configLoader?.config.editor.fontFamily ?? 'Operator Mono';
    final blocks = widget.session.blocks;
    final isRunning = widget.session.isCommandRunning;

    return Listener(
      onPointerDown: (_) {
        // Any click inside this pane updates the focused pane
        if (widget.paneId != null) {
          ref.read(sessionProvider.notifier).setFocusedPane(widget.paneId!);
        }
      },
      child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _toggleFindBar,
        const SingleActivator(LogicalKeyboardKey.equal, meta: true):
            _increaseFontSize,
        const SingleActivator(LogicalKeyboardKey.minus, meta: true):
            _decreaseFontSize,
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            _resetFontSize,
      },
      child: Stack(
        children: [
          // Two modes: full-screen terminal when running, blocks when idle
          if (isRunning)
            TerminalView(
              widget.session.terminal,
              controller: _terminalController,
              theme: bolonToXtermTheme(theme),
              textStyle: TerminalStyle(
                fontSize: fontSize,
                height: 1.2,
                fontFamily: fontFamily,
                fontFamilyFallback: const [
                  'JetBrains Mono',
                  'Menlo',
                  'Monaco',
                  'Consolas',
                  'Liberation Mono',
                  'Courier New',
                ],
              ),
              padding: const EdgeInsets.all(8),
              focusNode: _terminalFocusNode,
              autofocus: true,
              cursorType: TerminalCursorType.block,
              backgroundOpacity: 0,
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _promptKey.currentState?.requestFocus(),
              child: ListView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(top: 8),
              children: [
                for (var i = 0; i < blocks.length; i++)
                  CommandBlockWidget(
                    block: blocks[i],
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                    scrollable: configLoader?.config.editor.scrollableBlocks ?? false,
                    cwd: widget.session.cwd,
                    shellName: widget.session.shellName,
                    aiProvider: configLoader?.config.ai.provider ?? 'gemini',
                    geminiModel: configLoader?.config.ai.geminiModel ?? 'gemma-3-27b-it',
                    anthropicMode: configLoader?.config.ai.anthropicMode ?? 'claude-code',
                    searchHighlight: _buildSearchRegex(),
                    currentMatchIndex: _findCurrentMatch,
                    blockMatchStartIndex: _matchStartIndexForBlock(i),
                    onSecondaryTap: widget.onSecondaryTap,
                  ),
                PromptArea(
                  session: widget.session,
                  fontSize: fontSize,
                  aiProvider: configLoader?.config.ai.provider ?? 'gemini',
                  geminiModel: configLoader?.config.ai.geminiModel ?? 'gemma-3-27b-it',
                  anthropicMode: configLoader?.config.ai.anthropicMode ?? 'claude-code',
                  promptInputKey: _promptKey,
                ),
              ],
            ),
            ),

          // Font size toast
          if (_showToast)
            Center(
              child: FontSizeToast(
                fontSize: fontSize,
                onDismissed: () {
                  if (mounted) setState(() => _showToast = false);
                },
              ),
            ),

          // Find bar — top right, rendered last so it's on top
          if (_showFindBar)
            Positioned(
              top: 0,
              right: 0,
              child: FindBar(
                key: _findBarKey,
                currentMatch: _findCurrentMatch,
                totalMatches: _findTotalMatches,
                onSearch: _onFind,
                onNext: _onFindNext,
                onPrevious: _onFindPrevious,
                onClose: () => setState(() {
                  _showFindBar = false;
                  _findMatches = [];
                  _findTotalMatches = 0;
                  _findCurrentMatch = 0;
                }),
              ),
            ),
        ],
      ),
    ),
    );
  }

  void _toggleFindBar() {
    if (_showFindBar) {
      // Already open — focus it
      _findBarKey.currentState?.requestFocus();
    } else {
      setState(() => _showFindBar = true);
    }
  }

  // --- Find ---

  void _onFind(FindResult result) {
    _lastFindResult = result;
    if (result.query.isEmpty) {
      setState(() {
        _findMatches = [];
        _findTotalMatches = 0;
        _findCurrentMatch = 0;
      });
      return;
    }

    final matches = <_FindMatch>[];
    final blocks = widget.session.blocks;

    RegExp? regex;
    try {
      regex = result.isRegex
          ? RegExp(result.query,
              caseSensitive: result.caseSensitive)
          : RegExp(
              RegExp.escape(result.query),
              caseSensitive: result.caseSensitive,
            );
    } on FormatException {
      // Invalid regex
      setState(() {
        _findMatches = [];
        _findTotalMatches = 0;
        _findCurrentMatch = 0;
      });
      return;
    }

    for (var i = 0; i < blocks.length; i++) {
      final text = blocks[i].output;
      for (final m in regex.allMatches(text)) {
        matches.add(_FindMatch(blockIndex: i, start: m.start, end: m.end));
      }
      // Also search command text
      for (final m in regex.allMatches(blocks[i].command)) {
        matches.add(_FindMatch(blockIndex: i, start: m.start, end: m.end, inCommand: true));
      }
    }

    setState(() {
      _findMatches = matches;
      _findTotalMatches = matches.length;
      _findCurrentMatch = matches.isNotEmpty ? 0 : 0;
    });
  }

  void _onFindNext() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _findCurrentMatch = (_findCurrentMatch + 1) % _findMatches.length;
    });
  }

  void _onFindPrevious() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _findCurrentMatch =
          (_findCurrentMatch - 1 + _findMatches.length) % _findMatches.length;
    });
  }

  RegExp? _buildSearchRegex() {
    if (!_showFindBar || _findMatches.isEmpty || _lastFindResult == null) {
      return null;
    }
    final r = _lastFindResult!;
    try {
      return r.isRegex
          ? RegExp(r.query, caseSensitive: r.caseSensitive)
          : RegExp(RegExp.escape(r.query), caseSensitive: r.caseSensitive);
    } on FormatException {
      return null;
    }
  }

  int _matchStartIndexForBlock(int blockIndex) {
    var count = 0;
    for (final m in _findMatches) {
      if (m.blockIndex < blockIndex) count++;
    }
    return count;
  }

  void _increaseFontSize() {
    ref.read(fontSizeProvider.notifier).increase();
    setState(() => _showToast = true);
  }

  void _decreaseFontSize() {
    ref.read(fontSizeProvider.notifier).decrease();
    setState(() => _showToast = true);
  }

  void _resetFontSize() {
    ref.read(fontSizeProvider.notifier).reset();
    setState(() => _showToast = true);
  }
}

class _FindMatch {
  final int blockIndex;
  final int start;
  final int end;
  final bool inCommand;

  const _FindMatch({
    required this.blockIndex,
    required this.start,
    required this.end,
    this.inCommand = false,
  });
}

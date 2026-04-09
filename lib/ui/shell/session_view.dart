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
  ConsumerState<SessionView> createState() => SessionViewState();
}

/// Public State class so external widgets (e.g. the pane right-click
/// handler) can grab the live terminal selection through a GlobalKey.
class SessionViewState extends ConsumerState<SessionView> {
  final _terminalController = TerminalController();
  final _scrollController = ScrollController();
  late final FocusNode _terminalFocusNode;
  final _promptKey = GlobalKey<PromptInputState>();
  bool _showToast = false;
  bool _wasRunning = false;

  /// Saved value of `terminal.mouseMode` while Alt is held — used to
  /// implement Option+drag-to-select while a TUI app (less, claude,
  /// vim, top, etc.) has mouse tracking enabled. Holding Alt forces
  /// the mode to [MouseMode.none] so xterm.dart's drag-to-select
  /// takes over the gesture; releasing Alt restores the saved mode.
  MouseMode? _savedMouseMode;
  bool _altWasDown = false;

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
    HardwareKeyboard.instance.addHandler(_handleAltForSelection);
    // Register prompt for global focus forwarding after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.paneId != null && _promptKey.currentState != null) {
        PaneFocusRegistry.register(widget.paneId!, _promptKey.currentState!);
      }
    });
  }

  /// Returns the currently selected text from the live terminal,
  /// or `null` if there's no selection. Used by the pane-level
  /// right-click handler to make Copy selection-aware.
  String? getSelectedText() {
    final selection = _terminalController.selection;
    if (selection == null) return null;
    return widget.session.terminal.buffer.getText(selection);
  }

  /// Clears the live terminal's text selection, if any.
  void clearTerminalSelection() {
    _terminalController.clearSelection();
  }

  /// Listens for Alt key state changes and toggles this session's
  /// terminal mouse mode so the user can drag-select text while a
  /// mouse-tracking TUI is running. Returns false to never consume
  /// the event — every other handler still receives it.
  bool _handleAltForSelection(KeyEvent event) {
    final altNow = HardwareKeyboard.instance.isAltPressed;
    if (altNow == _altWasDown) return false;
    _altWasDown = altNow;
    final term = widget.session.terminal;
    if (altNow) {
      // Save and override only if the app currently has mouse
      // tracking on — otherwise selection already works.
      if (term.mouseMode != MouseMode.none) {
        _savedMouseMode = term.mouseMode;
        term.setMouseMode(MouseMode.none);
      }
    } else {
      if (_savedMouseMode != null) {
        term.setMouseMode(_savedMouseMode!);
        _savedMouseMode = null;
      }
    }
    return false;
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
    HardwareKeyboard.instance.removeHandler(_handleAltForSelection);
    // Restore mouseMode if Alt was held when the pane closed.
    if (_savedMouseMode != null) {
      widget.session.terminal.setMouseMode(_savedMouseMode!);
      _savedMouseMode = null;
    }
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

      // Command just finished → scroll blocks to bottom, focus prompt
      if (!isRunning && _wasRunning) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
          _promptKey.currentState?.requestFocus();
        });
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
    final fontFamily = configLoader?.config.editor.fontFamily ?? theme.fontFamily;
    final blocks = widget.session.blocks;
    final isRunning = widget.session.isCommandRunning;

    return Listener(
      onPointerDown: (_) {
        // Any click inside this pane updates the focused pane
        if (widget.paneId != null) {
          ref.read(sessionProvider.notifier).setFocusedPane(widget.paneId!);
        }
      },
      child: Stack(
        children: [
          // Two modes: full-screen terminal when running, blocks when idle.
          // Right-click on either is handled by the parent _LeafPaneWidget
          // via onSecondaryTap so the context menu is consistent across
          // both modes.
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
              child: _BlocksWithStickyPrompt(
                scrollController: _scrollController,
                blocks: [
                  for (var i = 0; i < blocks.length; i++)
                    CommandBlockWidget(
                      block: blocks[i],
                      fontSize: fontSize,
                      lineHeight: lineHeight,
                      scrollable: configLoader?.config.editor.scrollableBlocks ?? false,
                      cwd: widget.session.cwd,
                      shellName: widget.session.shellName,
                      aiEnabled: configLoader?.config.ai.enabled ?? false,
                      aiProvider: configLoader?.config.ai.provider ?? 'gemini',
                      geminiModel: configLoader?.config.ai.geminiModel ?? 'gemma-3-27b-it',
                      anthropicMode: configLoader?.config.ai.anthropicMode ?? 'claude-code',
                      ligatures: configLoader?.config.editor.ligatures ?? false,
                      searchHighlight: _buildSearchRegex(),
                      currentMatchIndex: _findCurrentMatch,
                      blockMatchStartIndex: _matchStartIndexForBlock(i),
                      onSecondaryTap: widget.onSecondaryTap,
                      onRerun: (cmd) => widget.session.writeInput('$cmd\n'),
                    ),
                ],
                prompt: PromptArea(
                  session: widget.session,
                  fontSize: fontSize,
                  aiEnabled: configLoader?.config.ai.enabled ?? false,
                  aiProvider: configLoader?.config.ai.provider ?? 'gemini',
                  geminiModel: configLoader?.config.ai.geminiModel ?? 'gemma-3-27b-it',
                  anthropicMode: configLoader?.config.ai.anthropicMode ?? 'claude-code',
                  commandSuggestions: configLoader?.config.ai.commandSuggestions ?? true,
                  smartHistorySearch: configLoader?.config.ai.smartHistorySearch ?? true,
                  shareHistory: configLoader?.config.ai.shareHistory ?? false,
                  promptChips: configLoader?.config.general.promptChips ??
                      const ['shell', 'cwd', 'gitBranch', 'gitChanges'],
                  promptInputKey: _promptKey,
                ),
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


/// Renders blocks + prompt where the prompt flows inline after blocks
/// until it reaches the viewport bottom, then sticks there.
///
/// Uses a Stack: the prompt is rendered both inline (inside the
/// scrollable column) and pinned (at the bottom of the Stack).
/// Only one is visible at a time based on whether content overflows.
class _BlocksWithStickyPrompt extends StatefulWidget {
  final ScrollController scrollController;
  final List<Widget> blocks;
  final Widget prompt;

  const _BlocksWithStickyPrompt({
    required this.scrollController,
    required this.blocks,
    required this.prompt,
  });

  @override
  State<_BlocksWithStickyPrompt> createState() =>
      _BlocksWithStickyPromptState();
}

class _BlocksWithStickyPromptState extends State<_BlocksWithStickyPrompt> {
  bool _overflows = false;
  final _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(_BlocksWithStickyPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted) return;
    final hasClients = widget.scrollController.hasClients;
    if (!hasClients) return;
    final maxExtent = widget.scrollController.position.maxScrollExtent;
    final nowOverflows = maxExtent > 0;
    if (nowOverflows != _overflows) {
      setState(() => _overflows = nowOverflows);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrollable content: blocks (as slivers) + inline prompt
        // (when not overflowing). Each block builds a SliverMainAxisGroup
        // with a pinned header, so the command + action bar of the
        // currently-visible block stays at the top of the viewport.
        Positioned.fill(
          bottom: _overflows ? 80 : 0,
          child: CustomScrollView(
            key: _contentKey,
            controller: widget.scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ...widget.blocks,
              if (!_overflows) SliverToBoxAdapter(child: widget.prompt),
            ],
          ),
        ),
        // Pinned prompt at bottom (only when overflowing)
        if (_overflows)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: widget.prompt,
          ),
      ],
    );
  }
}


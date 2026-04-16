import 'dart:ui' as ui;

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
  static final Map<String, SessionViewState> _registry = {};

  static SessionViewState? of(String paneId) => _registry[paneId];

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
  final _terminalHighlights = <TerminalHighlight>[];
  List<_FindMatch> _findMatches = [];
  FindResult? _lastFindResult;

  @override
  void initState() {
    super.initState();
    _terminalFocusNode = FocusNode(debugLabel: 'terminal-${widget.session.id}');
    widget.session.addListener(_onSessionChanged);
    HardwareKeyboard.instance.addHandler(_handleAltForSelection);
    if (widget.paneId != null) _registry[widget.paneId!] = this;
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

  /// Intercepts text-editor-style shortcuts (Cmd/Option + arrows and
  /// Delete) when a TUI is running, and transforms them into
  /// readline-compatible byte sequences sent directly to the PTY.
  ///
  /// These are the same bytes Terminal.app and iTerm2 send, so they
  /// work in bash, zsh, fish, Python REPL, Node REPL, Claude Code,
  /// opencode, gemini-cli — anything using readline conventions.
  ///
  /// Returns [KeyEventResult.handled] for intercepted keys (which
  /// prevents xterm's default processing), [ignored] for everything
  /// else so xterm handles it normally.
  KeyEventResult _handleTerminalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;

    // macOS primary modifier: Cmd. Linux/Windows: use Ctrl via shell's
    // own bindings — we only intercept Cmd/Option here to match macOS
    // text-field conventions. On Linux these modifiers usually aren't
    // used for arrow keys, so behavior stays default.
    if (meta) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.session.writeInput('\x01'); // Ctrl+A — beginning-of-line
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        widget.session.writeInput('\x05'); // Ctrl+E — end-of-line
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.backspace) {
        widget.session.writeInput('\x15'); // Ctrl+U — kill line
        return KeyEventResult.handled;
      }
    }

    if (alt) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.session.writeInput('\x1bb'); // ESC+b — backward-word
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        widget.session.writeInput('\x1bf'); // ESC+f — forward-word
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.backspace) {
        widget.session.writeInput('\x1b\x7f'); // ESC+DEL — backward-kill-word
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.delete) {
        widget.session.writeInput('\x1bd'); // ESC+d — kill-word
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
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
    if (widget.paneId case final paneId?) {
      PaneFocusRegistry.unregister(paneId);
      _registry.remove(paneId);
    }
    _clearTerminalHighlights();
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
    ref.watch(configVersionProvider); // rebuild on config file changes
    final configLoader = ref.watch(configLoaderProvider);
    final lineHeight = configLoader?.config.editor.lineHeight ?? 1.0;
    final fontFamily = configLoader?.config.editor.fontFamily ?? theme.fontFamily;
    final cursorStyle = configLoader?.config.editor.cursorStyle ?? 'block';
    final cursorType = switch (cursorStyle) {
      'underline' => TerminalCursorType.underline,
      'bar' => TerminalCursorType.verticalBar,
      _ => TerminalCursorType.block,
    };
    final blocks = widget.session.blocks;
    final isRunning = widget.session.isCommandRunning;

    return Listener(
      onPointerDown: (_) {
        // Any click inside this pane updates the focused pane
        if (widget.paneId != null) {
          ref.read(currentSessionNotifierProvider).setFocusedPane(widget.paneId!);
        }
      },
      child: Stack(
        children: [
          // Modes:
          // 1. No shell integration (fish, nushell, etc.) → always raw terminal
          // 2. Command running → full-screen terminal
          // 3. Awaiting shell response (e.g. continuation prompt) → terminal
          // 4. Idle → blocks + Bolan prompt
          if (!widget.session.hasShellIntegration ||
              isRunning ||
              widget.session.awaitingShellResponse)
            Stack(
              children: [
                TerminalView(
                  widget.session.terminal,
                  controller: _terminalController,
                  theme: bolonToXtermTheme(theme),
                  textStyle: TerminalStyle(
                    fontSize: fontSize,
                    height: lineHeight,
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
                  cursorType: cursorType,
                  backgroundOpacity: 0,
                  onKeyEvent: _handleTerminalKey,
                ),
                // Cursor overlay:
                //  - Block: paints the character under the cursor
                //    in inverted colors (xterm.dart's filled rect
                //    hides the glyph).
                //  - Underline / Bar: paints a thicker, more
                //    visible cursor on top of xterm.dart's 1px line
                //    which is nearly invisible.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CursorCharPainter(
                        terminal: widget.session.terminal,
                        focusNode: _terminalFocusNode,
                        fontSize: fontSize,
                        lineHeight: lineHeight,
                        fontFamily: fontFamily,
                        cursorColor: theme.cursor,
                        bgColor: theme.background,
                        cursorType: cursorType,
                      ),
                    ),
                  ),
                ),
              ],
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
                  cursorStyle: cursorStyle,
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
                  _matchStartIndexCache = const {};
                  _clearTerminalHighlights();
                }),
              ),
            ),
        ],
      ),
    );
  }

  void toggleFindBar() {
    if (_showFindBar) {
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
        _matchStartIndexCache = const {};
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
        _matchStartIndexCache = const {};
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

    // Search the live terminal buffer (nano, vi, streaming output, etc.)
    // and create native xterm highlights for visual feedback.
    _clearTerminalHighlights();
    final buffer = widget.session.terminal.buffer;
    final bufferText = buffer.getText();
    for (final m in regex.allMatches(bufferText)) {
      matches.add(_FindMatch(blockIndex: -1, start: m.start, end: m.end));

      // Convert text offset to buffer (x, y) coordinates
      final start = _textOffsetToCell(bufferText, m.start);
      final end = _textOffsetToCell(bufferText, m.end);
      if (start != null && end != null) {
        try {
          final h = _terminalController.highlight(
            p1: buffer.createAnchor(start.$1, start.$2),
            p2: buffer.createAnchor(end.$1, end.$2),
            color: const Color(0x60FFFF00),
          );
          _terminalHighlights.add(h);
        } on RangeError {
          // Anchor out of bounds — skip
        }
      }
    }

    setState(() {
      _findMatches = matches;
      _findTotalMatches = matches.length;
      _findCurrentMatch = matches.isNotEmpty ? 0 : 0;
      _rebuildMatchStartIndexCache();
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

  // Cache the compiled search regex so we don't rebuild it every
  // frame while the find bar is open. Invalidated whenever the
  // find result changes.
  RegExp? _cachedSearchRegex;
  FindResult? _cachedSearchRegexFor;

  RegExp? _buildSearchRegex() {
    if (!_showFindBar || _findMatches.isEmpty || _lastFindResult == null) {
      return null;
    }
    final r = _lastFindResult!;
    if (identical(_cachedSearchRegexFor, r)) return _cachedSearchRegex;
    try {
      _cachedSearchRegex = r.isRegex
          ? RegExp(r.query, caseSensitive: r.caseSensitive)
          : RegExp(RegExp.escape(r.query), caseSensitive: r.caseSensitive);
      _cachedSearchRegexFor = r;
      return _cachedSearchRegex;
    } on FormatException {
      _cachedSearchRegex = null;
      _cachedSearchRegexFor = r;
      return null;
    }
  }

  /// Precomputed counts of matches that appear before each block index,
  /// so the per-block render loop doesn't re-scan _findMatches every time.
  Map<int, int> _matchStartIndexCache = const {};

  void _rebuildMatchStartIndexCache() {
    // Group match counts by blockIndex in one pass, then sort and prefix-sum.
    final perBlock = <int, int>{};
    for (final m in _findMatches) {
      perBlock[m.blockIndex] = (perBlock[m.blockIndex] ?? 0) + 1;
    }
    final keys = perBlock.keys.toList()..sort();
    final cache = <int, int>{};
    var count = 0;
    for (final idx in keys) {
      cache[idx] = count;
      count += perBlock[idx]!;
    }
    _matchStartIndexCache = cache;
  }

  int _matchStartIndexForBlock(int blockIndex) {
    return _matchStartIndexCache[blockIndex] ?? 0;
  }

  void _clearTerminalHighlights() {
    for (final h in _terminalHighlights) {
      h.dispose();
    }
    _terminalHighlights.clear();
  }

  /// Converts a character offset in the buffer's `getText()` output to
  /// (x, y) cell coordinates, accounting for newlines between lines.
  (int, int)? _textOffsetToCell(String text, int offset) {
    var y = 0;
    var lineStart = 0;
    for (var i = 0; i < text.length; i++) {
      if (i == offset) return (offset - lineStart, y);
      if (text[i] == '\n') {
        y++;
        lineStart = i + 1;
      }
    }
    if (offset == text.length) return (offset - lineStart, y);
    return null;
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
/// Paints the character that sits under the terminal's block cursor
/// in the background color, so the glyph is visible through the
/// opaque cursor rectangle. xterm.dart 4.0.0 draws the cursor as a
/// plain filled rect and doesn't repaint the glyph on top, which
/// makes the character invisible. This overlay fixes that.
///
/// Only draws when the cursor is visible, the terminal has focus,
/// and the cell under the cursor contains a non-empty character.
class _CursorCharPainter extends CustomPainter {
  final Terminal terminal;
  final FocusNode focusNode;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final Color cursorColor;
  final Color bgColor;
  final TerminalCursorType cursorType;

  /// TerminalView uses 8px padding on all sides.
  static const _padding = 8.0;

  _CursorCharPainter({
    required this.terminal,
    required this.focusNode,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.cursorColor,
    required this.bgColor,
    this.cursorType = TerminalCursorType.block,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!focusNode.hasFocus) return;
    if (!terminal.cursorVisibleMode) return;

    final cellSize = _measureCell();
    final cursorX = terminal.buffer.cursorX;
    final cursorY = terminal.buffer.absoluteCursorY;

    if (cursorY < 0 || cursorY >= terminal.buffer.lines.length) return;
    final line = terminal.buffer.lines[cursorY];

    // buffer.cursorY is already viewport-relative.
    final viewRow = terminal.buffer.cursorY;
    if (viewRow < 0 || viewRow >= terminal.viewHeight) return;

    final x = _padding + cursorX * cellSize.width;
    final y = _padding + viewRow * cellSize.height;

    switch (cursorType) {
      case TerminalCursorType.block:
        // Draw the character under the cursor in the background
        // color so it's visible through the opaque filled rect.
        if (cursorX >= 0 && cursorX < line.length) {
          final codePoint = line.getCodePoint(cursorX);
          if (codePoint > 0x1F) {
            final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              height: lineHeight,
            ));
            builder.pushStyle(ui.TextStyle(
              color: bgColor,
              fontFamily: fontFamily,
              fontSize: fontSize,
              height: lineHeight,
            ));
            builder.addText(String.fromCharCode(codePoint));
            final paragraph = builder.build();
            paragraph.layout(
                const ui.ParagraphConstraints(width: double.infinity));
            canvas.drawParagraph(paragraph, Offset(x, y));
            paragraph.dispose();
          }
        }

      case TerminalCursorType.underline:
        // Draw a 2px underline at the bottom of the cell.
        // xterm.dart draws 1px which is nearly invisible.
        final paint = Paint()
          ..color = cursorColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(x, y + cellSize.height - 1),
          Offset(x + cellSize.width, y + cellSize.height - 1),
          paint,
        );

      case TerminalCursorType.verticalBar:
        // Draw a 2px vertical bar at the left edge of the cell.
        // xterm.dart draws 1px which is nearly invisible.
        final paint = Paint()
          ..color = cursorColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + cellSize.height),
          paint,
        );
    }
  }

  /// Cell size depends only on font family, size, and line height —
  /// none of which change between paints in normal use. Cache the
  /// result keyed on those three values to avoid laying out a
  /// paragraph on every paint.
  static Size? _cachedCellSize;
  static String? _cachedFontFamily;
  static double? _cachedFontSize;
  static double? _cachedLineHeight;

  Size _measureCell() {
    if (_cachedCellSize != null &&
        _cachedFontFamily == fontFamily &&
        _cachedFontSize == fontSize &&
        _cachedLineHeight == lineHeight) {
      return _cachedCellSize!;
    }
    const test = 'mmmmmmmmmm';
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeight,
    ));
    builder.pushStyle(ui.TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeight,
    ));
    builder.addText(test);
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    final result = Size(
      paragraph.maxIntrinsicWidth / test.length,
      paragraph.height,
    );
    paragraph.dispose();
    _cachedCellSize = result;
    _cachedFontFamily = fontFamily;
    _cachedFontSize = fontSize;
    _cachedLineHeight = lineHeight;
    return result;
  }

  @override
  bool shouldRepaint(_CursorCharPainter old) => true;
}

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


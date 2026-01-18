import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/completion/completion_engine.dart';
import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import 'completion_popup.dart';
import 'history_search.dart';

/// Prompt input with ghost text from history and tab completion.
///
/// - Arrow Up/Down navigates command history.
/// - Ctrl+R opens inline history search.
/// - While typing, shows closest history match as ghost text.
/// - Tab triggers file/command completion with ghost text cycling.
/// - Right Arrow at end of input accepts ghost text.
class PromptInput extends StatefulWidget {
  final TerminalSession session;
  final double fontSize;

  const PromptInput({
    super.key,
    required this.session,
    this.fontSize = 13.0,
  });

  @override
  State<PromptInput> createState() => PromptInputState();
}

class PromptInputState extends State<PromptInput> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  int _historyIndex = -1;
  String _savedInput = '';

  // Completion state
  List<String> _completions = [];
  int _completionIndex = 0;
  CompletionResult? _activeResult;
  bool _completionLoading = false;

  // History search state
  bool _showHistorySearch = false;

  /// Ghost text: from completions or history match.
  String get _ghostText {
    // Tab completion ghost takes priority
    if (_completions.isNotEmpty && _activeResult != null) {
      final current = _completions[_completionIndex];
      final prefix = _activeResult!.prefix;
      if (current.length > prefix.length) {
        return current.substring(prefix.length);
      }
    }
    // History ghost — show matching command from history
    final text = _controller.text;
    if (text.isNotEmpty && _historyIndex == -1) {
      final match = widget.session.history.findMatch(text);
      if (match != null) {
        return match.substring(text.length);
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _controller.addListener(_onTextChanged);
  }

  void requestFocus() => _focusNode.requestFocus();

  bool get isHistorySearchOpen => _showHistorySearch;

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Dismiss tab completions when typing
    if (_completions.isNotEmpty) {
      setState(() {
        _completions = [];
        _activeResult = null;
        _completionIndex = 0;
      });
    } else {
      // Refresh ghost text from history
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final ghost = _ghostText;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // History search popup
          if (_showHistorySearch)
            HistorySearch(
              fontSize: widget.fontSize,
              onSearch: widget.session.history.search,
              onSelect: _acceptHistorySearch,
              onDismiss: _dismissHistorySearch,
            ),

          // Completion popup
          if (_completions.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: CompletionPopup(
                items: _completions,
                selectedIndex: _completionIndex,
                prefix: _activeResult?.prefix ?? '',
                fontSize: widget.fontSize,
                onSelect: _acceptCompletion,
              ),
            ),

          // Input with ghost text overlay
          Padding(
            padding:
                const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 10),
            child: Stack(
              children: [
                // Ghost text
                if (ghost.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _GhostTextOverlay(
                        controller: _controller,
                        ghostText: ghost,
                        style: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: 'Operator Mono',
                          fontSize: widget.fontSize,
                          height: 1.4,
                          decoration: TextDecoration.none,
                        ),
                        realStyle: TextStyle(
                          color: Colors.transparent,
                          fontFamily: 'Operator Mono',
                          fontSize: widget.fontSize,
                          height: 1.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),

                // Real input
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: null,
                  minLines: 1,
                  contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: 'Operator Mono',
                    fontSize: widget.fontSize,
                    height: 1.4,
                    decoration: TextDecoration.none,
                  ),
                  cursorColor: theme.cursor,
                  cursorWidth: 2,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    // Tab completion popup navigation
    if (_completions.length > 1) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.tab:
        case LogicalKeyboardKey.arrowDown:
          setState(() {
            _completionIndex =
                (_completionIndex + 1) % _completions.length;
          });
          return KeyEventResult.handled;

        case LogicalKeyboardKey.arrowUp:
          setState(() {
            _completionIndex =
                (_completionIndex - 1 + _completions.length) %
                    _completions.length;
          });
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          _acceptCompletion(_completionIndex);
          return KeyEventResult.handled;

        case LogicalKeyboardKey.escape:
          setState(() {
            _completions = [];
            _activeResult = null;
          });
          return KeyEventResult.handled;

        default:
          break;
      }
    }

    switch (event.logicalKey) {
      // Tab — file/command completion
      case LogicalKeyboardKey.tab:
        if (_completions.isEmpty) {
          _requestCompletion();
        } else if (_completions.length == 1) {
          _acceptCompletion(0);
        }
        return KeyEventResult.handled;

      // Right Arrow at end — accept ghost text
      case LogicalKeyboardKey.arrowRight
          when _ghostText.isNotEmpty &&
              _controller.selection.baseOffset == _controller.text.length:
        _acceptGhostText();
        return KeyEventResult.handled;

      // Ctrl+R — open history search
      case LogicalKeyboardKey.keyR when ctrl:
        setState(() => _showHistorySearch = true);
        return KeyEventResult.handled;

      // Escape — dismiss completions/ghost
      case LogicalKeyboardKey.escape:
        if (_completions.isNotEmpty) {
          setState(() {
            _completions = [];
            _activeResult = null;
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;

      // Enter — submit
      case LogicalKeyboardKey.enter when !shift:
        _onSubmit(_controller.text);
        return KeyEventResult.handled;

      // Shift+Enter — newline
      case LogicalKeyboardKey.enter when shift:
        final pos = _controller.selection.baseOffset;
        final text = _controller.text;
        _withoutListener(() {
          _controller.text =
              '${text.substring(0, pos)}\n${text.substring(pos)}';
          _controller.selection = TextSelection.collapsed(offset: pos + 1);
        });
        return KeyEventResult.handled;

      // Arrow Up — history back
      case LogicalKeyboardKey.arrowUp when !ctrl:
        _navigateHistory(back: true);
        return KeyEventResult.handled;

      // Arrow Down — history forward
      case LogicalKeyboardKey.arrowDown when !ctrl:
        _navigateHistory(back: false);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyA when ctrl:
        _controller.selection = const TextSelection.collapsed(offset: 0);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyE when ctrl:
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyU when ctrl:
        final pos = _controller.selection.baseOffset;
        _withoutListener(() {
          _controller.text = _controller.text.substring(pos);
          _controller.selection = const TextSelection.collapsed(offset: 0);
        });
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyK when ctrl:
        final pos = _controller.selection.baseOffset;
        _withoutListener(() {
          _controller.text = _controller.text.substring(0, pos);
          _controller.selection = TextSelection.collapsed(offset: pos);
        });
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyW when ctrl:
        _deleteWordBefore();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyC when ctrl:
        widget.session.writeInput('\x03');
        _controller.clear();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyL when ctrl:
        widget.session.clearBlocks();
        widget.session.writeInput('\x0c');
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  // --- History ---

  void _navigateHistory({required bool back}) {
    final history = widget.session.history;
    if (history.length == 0) return;

    if (back) {
      if (_historyIndex == -1) {
        _savedInput = _controller.text;
        _historyIndex = 0;
      } else if (_historyIndex < history.length - 1) {
        _historyIndex++;
      }
      _withoutListener(() {
        _controller.text = history.entryFromEnd(_historyIndex) ?? '';
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      });
      setState(() {});
    } else {
      if (_historyIndex == -1) return;
      if (_historyIndex > 0) {
        _historyIndex--;
        _withoutListener(() {
          _controller.text = history.entryFromEnd(_historyIndex) ?? '';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
      } else {
        _historyIndex = -1;
        _withoutListener(() {
          _controller.text = _savedInput;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
      }
      setState(() {});
    }
  }

  void _acceptHistorySearch(String command) {
    _withoutListener(() {
      _controller.text = command;
      _controller.selection = TextSelection.collapsed(
        offset: command.length,
      );
    });
    setState(() => _showHistorySearch = false);
    _focusNode.requestFocus();
  }

  void _dismissHistorySearch() {
    setState(() => _showHistorySearch = false);
    _focusNode.requestFocus();
  }

  // --- Ghost text ---

  void _acceptGhostText() {
    final ghost = _ghostText;
    if (ghost.isEmpty) return;

    // If from tab completion, accept that
    if (_completions.isNotEmpty && _activeResult != null) {
      _acceptCompletion(_completionIndex);
      return;
    }

    // Otherwise accept history ghost
    final text = _controller.text;
    _withoutListener(() {
      _controller.text = '$text$ghost';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
    setState(() {});
  }

  // --- Tab completion ---

  Future<void> _requestCompletion() async {
    if (_completionLoading) return;
    _completionLoading = true;

    try {
      final result = await widget.session.requestCompletion(
        _controller.text,
        _controller.selection.baseOffset,
      );

      if (!mounted) return;

      if (result.isSingle) {
        _applyCompletion(result.items.first, result);
      } else if (result.items.isNotEmpty) {
        final lcp = longestCommonPrefix(result.items);
        if (lcp.length > result.prefix.length) {
          _applyCompletion(lcp, result);
        }
        setState(() {
          _completions = result.items;
          _completionIndex = 0;
          _activeResult = result;
        });
      }
    } finally {
      _completionLoading = false;
    }
  }

  void _acceptCompletion(int index) {
    if (_activeResult == null || index >= _completions.length) return;
    _applyCompletion(_completions[index], _activeResult!);
    setState(() {
      _completions = [];
      _activeResult = null;
    });
  }

  void _applyCompletion(String completion, CompletionResult result) {
    final text = _controller.text;
    final before = text.substring(0, result.replaceStart);
    final after = text.substring(result.replaceEnd);
    final suffix = completion.endsWith('/') ? '' : ' ';
    final newText = '$before$completion$suffix$after';
    final newPos = result.replaceStart + completion.length + suffix.length;

    _withoutListener(() {
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: newPos);
    });
    setState(() {
      _completions = [];
      _activeResult = null;
    });
  }

  // --- Submit ---

  void _onSubmit(String text) {
    final command = text.trim();
    if (command.isEmpty) {
      widget.session.writeInput('\n');
    } else {
      widget.session.writeInput('$command\n');
      widget.session.history.add(command);
    }
    _controller.clear();
    _historyIndex = -1;
    _focusNode.requestFocus();
  }

  // --- Helpers ---

  void _deleteWordBefore() {
    final text = _controller.text;
    final pos = _controller.selection.baseOffset;
    if (pos <= 0) return;

    var i = pos - 1;
    while (i > 0 && text[i] == ' ') {
      i--;
    }
    while (i > 0 && text[i - 1] != ' ') {
      i--;
    }

    _withoutListener(() {
      _controller.text = text.substring(0, i) + text.substring(pos);
      _controller.selection = TextSelection.collapsed(offset: i);
    });
  }

  void _withoutListener(VoidCallback fn) {
    _controller.removeListener(_onTextChanged);
    fn();
    _controller.addListener(_onTextChanged);
  }
}

/// Renders ghost/shadow text after the real text content.
class _GhostTextOverlay extends StatelessWidget {
  final TextEditingController controller;
  final String ghostText;
  final TextStyle style;
  final TextStyle realStyle;

  const _GhostTextOverlay({
    required this.controller,
    required this.ghostText,
    required this.style,
    required this.realStyle,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: controller.text, style: realStyle),
          TextSpan(text: ghostText, style: style),
        ],
      ),
    );
  }
}

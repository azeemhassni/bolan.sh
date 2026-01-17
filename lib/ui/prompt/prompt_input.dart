import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/completion/completion_engine.dart';
import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';

/// Prompt input with inline ghost-text completions.
///
/// - Tab or Right Arrow accepts the ghost completion.
/// - When multiple completions exist, Tab cycles through them.
/// - Ghost text shows as dimmed text after the cursor.
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
  final List<String> _history = [];
  int _historyIndex = -1;
  String _savedInput = '';

  // Completion state
  List<String> _completions = [];
  int _completionIndex = 0;
  CompletionResult? _activeResult;
  bool _completionLoading = false;

  /// The ghost text to show after the cursor.
  String get _ghostText {
    if (_completions.isEmpty || _activeResult == null) return '';
    final current = _completions[_completionIndex];
    final prefix = _activeResult!.prefix;
    if (current.length <= prefix.length) return '';
    return current.substring(prefix.length);
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _controller.addListener(_onTextChanged);
  }

  void requestFocus() => _focusNode.requestFocus();

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_completions.isNotEmpty) {
      setState(() {
        _completions = [];
        _activeResult = null;
        _completionIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final ghost = _ghostText;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding:
            const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 10),
        child: Stack(
          children: [
            // Ghost text overlay — positioned after the real text
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
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    switch (event.logicalKey) {
      // Tab — request completions or cycle through them
      case LogicalKeyboardKey.tab:
        if (_completions.isEmpty) {
          _requestCompletion();
        } else {
          // Cycle to next completion
          setState(() {
            _completionIndex =
                (_completionIndex + 1) % _completions.length;
          });
        }
        return KeyEventResult.handled;

      // Right arrow at end of text — accept ghost completion
      case LogicalKeyboardKey.arrowRight
          when _ghostText.isNotEmpty &&
              _controller.selection.baseOffset == _controller.text.length:
        _acceptCurrentCompletion();
        return KeyEventResult.handled;

      // Escape — dismiss completions
      case LogicalKeyboardKey.escape:
        if (_completions.isNotEmpty) {
          setState(() {
            _completions = [];
            _activeResult = null;
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;

      case LogicalKeyboardKey.enter when !shift:
        _onSubmit(_controller.text);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter when shift:
        final pos = _controller.selection.baseOffset;
        final text = _controller.text;
        _controller.removeListener(_onTextChanged);
        _controller.text =
            '${text.substring(0, pos)}\n${text.substring(pos)}';
        _controller.selection = TextSelection.collapsed(offset: pos + 1);
        _controller.addListener(_onTextChanged);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp when !ctrl:
        _navigateHistory(back: true);
        return KeyEventResult.handled;
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
        // Single match — accept immediately
        _applyCompletion(result.items.first, result);
      } else if (result.items.isNotEmpty) {
        // Multiple matches — show ghost text for first item
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

  void _acceptCurrentCompletion() {
    if (_activeResult == null || _completions.isEmpty) return;
    _applyCompletion(_completions[_completionIndex], _activeResult!);
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

  void _onSubmit(String text) {
    final command = text.trim();
    if (command.isEmpty) {
      widget.session.writeInput('\n');
    } else {
      widget.session.writeInput('$command\n');
      _addToHistory(command);
    }
    _controller.clear();
    _historyIndex = -1;
    _focusNode.requestFocus();
  }

  void _addToHistory(String command) {
    if (_history.isNotEmpty && _history.last == command) return;
    _history.add(command);
  }

  void _navigateHistory({required bool back}) {
    if (_history.isEmpty) return;

    if (back) {
      if (_historyIndex == -1) {
        _savedInput = _controller.text;
        _historyIndex = _history.length - 1;
      } else if (_historyIndex > 0) {
        _historyIndex--;
      }
      _controller.text = _history[_historyIndex];
    } else {
      if (_historyIndex == -1) return;
      if (_historyIndex < _history.length - 1) {
        _historyIndex++;
        _controller.text = _history[_historyIndex];
      } else {
        _historyIndex = -1;
        _controller.text = _savedInput;
      }
    }
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

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

  /// Modifies the controller without triggering _onTextChanged.
  void _withoutListener(VoidCallback fn) {
    _controller.removeListener(_onTextChanged);
    fn();
    _controller.addListener(_onTextChanged);
  }
}

/// Renders ghost/shadow text after the real text content.
///
/// Uses a transparent copy of the real text followed by the dimmed ghost text
/// so the ghost aligns exactly after the cursor position.
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
          // Invisible copy of real text to push ghost to the right position
          TextSpan(text: controller.text, style: realStyle),
          // Ghost text in dim color
          TextSpan(text: ghostText, style: style),
        ],
      ),
    );
  }
}

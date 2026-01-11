import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';

/// Seamless prompt input with TextField editing semantics.
///
/// Supports Shift+arrow selection, double-click word select,
/// delete selected text, command history, and shell shortcuts.
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
  final _focusNode = FocusNode();
  final List<String> _history = [];
  int _historyIndex = -1;
  String _savedInput = '';

  /// Requests focus on the input field.
  void requestFocus() => _focusNode.requestFocus();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 10),
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            maxLines: 1,
            style: TextStyle(
              color: theme.foreground,
              fontFamily: 'JetBrainsMono',
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
            onSubmitted: _onSubmit,
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final ctrl = HardwareKeyboard.instance.isControlPressed;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp when !ctrl:
        _navigateHistory(back: true);
      case LogicalKeyboardKey.arrowDown when !ctrl:
        _navigateHistory(back: false);

      case LogicalKeyboardKey.keyA when ctrl:
        _controller.selection = const TextSelection.collapsed(offset: 0);

      case LogicalKeyboardKey.keyE when ctrl:
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );

      case LogicalKeyboardKey.keyU when ctrl:
        final pos = _controller.selection.baseOffset;
        _controller.text = _controller.text.substring(pos);
        _controller.selection = const TextSelection.collapsed(offset: 0);

      case LogicalKeyboardKey.keyK when ctrl:
        final pos = _controller.selection.baseOffset;
        _controller.text = _controller.text.substring(0, pos);
        _controller.selection = TextSelection.collapsed(offset: pos);

      case LogicalKeyboardKey.keyW when ctrl:
        _deleteWordBefore();

      case LogicalKeyboardKey.keyC when ctrl:
        widget.session.writeInput('\x03');
        _controller.clear();

      case LogicalKeyboardKey.keyL when ctrl:
        widget.session.clearBlocks();
        widget.session.writeInput('\x0c');
    }
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

    _controller.text = text.substring(0, i) + text.substring(pos);
    _controller.selection = TextSelection.collapsed(offset: i);
  }
}

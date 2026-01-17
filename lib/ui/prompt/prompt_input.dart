import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/completion/completion_engine.dart';
import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import 'completion_popup.dart';

/// Seamless prompt input with TextField editing semantics.
///
/// Supports Shift+arrow selection, double-click word select,
/// delete selected text, command history, shell shortcuts,
/// and Tab completion with a popup.
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
  List<String> _completionItems = [];
  int _completionIndex = 0;
  CompletionResult? _activeCompletion;
  bool _completionLoading = false;

  bool get _showCompletion => _completionItems.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _controller.addListener(_onTextChanged);
  }

  /// Requests focus on the input field.
  void requestFocus() => _focusNode.requestFocus();

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Dismiss completion popup when the user types
    if (_showCompletion) {
      setState(() {
        _completionItems = [];
        _activeCompletion = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completion popup — shown above the input
          if (_showCompletion)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: CompletionPopup(
                items: _completionItems,
                selectedIndex: _completionIndex,
                prefix: _activeCompletion?.prefix ?? '',
                fontSize: widget.fontSize,
                onSelect: _acceptCompletion,
              ),
            ),

          // Input field
          Padding(
            padding:
                const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 10),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: null,
              minLines: 1,
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

    // When completion popup is open, handle navigation
    if (_showCompletion) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.tab:
        case LogicalKeyboardKey.arrowDown:
          setState(() {
            _completionIndex =
                (_completionIndex + 1) % _completionItems.length;
          });
          return KeyEventResult.handled;

        case LogicalKeyboardKey.arrowUp:
          setState(() {
            _completionIndex =
                (_completionIndex - 1 + _completionItems.length) %
                    _completionItems.length;
          });
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          _acceptCompletion(_completionIndex);
          return KeyEventResult.handled;

        case LogicalKeyboardKey.escape:
          setState(() {
            _completionItems = [];
            _activeCompletion = null;
          });
          return KeyEventResult.handled;

        default:
          break;
      }
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.tab:
        _requestCompletion();
        return KeyEventResult.handled;

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
        _controller.removeListener(_onTextChanged);
        _controller.text = _controller.text.substring(pos);
        _controller.selection = const TextSelection.collapsed(offset: 0);
        _controller.addListener(_onTextChanged);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyK when ctrl:
        final pos = _controller.selection.baseOffset;
        _controller.removeListener(_onTextChanged);
        _controller.text = _controller.text.substring(0, pos);
        _controller.selection = TextSelection.collapsed(offset: pos);
        _controller.addListener(_onTextChanged);
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
        // Single match — inline complete immediately
        _applyCompletion(result.items.first, result);
      } else if (result.items.isNotEmpty) {
        // Multiple matches — insert longest common prefix and show popup
        final lcp = longestCommonPrefix(result.items);
        if (lcp.length > result.prefix.length) {
          _applyCompletion(lcp, result);
        }
        setState(() {
          _completionItems = result.items;
          _completionIndex = 0;
          _activeCompletion = result;
        });
      }
    } finally {
      _completionLoading = false;
    }
  }

  void _acceptCompletion(int index) {
    if (_activeCompletion == null || index >= _completionItems.length) return;
    _applyCompletion(_completionItems[index], _activeCompletion!);
    setState(() {
      _completionItems = [];
      _activeCompletion = null;
    });
  }

  void _applyCompletion(String completion, CompletionResult result) {
    final text = _controller.text;
    final before = text.substring(0, result.replaceStart);
    final after = text.substring(result.replaceEnd);
    final suffix = completion.endsWith('/') ? '' : ' ';
    final newText = '$before$completion$suffix$after';
    final newPos = result.replaceStart + completion.length + suffix.length;

    _controller.removeListener(_onTextChanged);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newPos);
    _controller.addListener(_onTextChanged);
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

    _controller.removeListener(_onTextChanged);
    _controller.text = text.substring(0, i) + text.substring(pos);
    _controller.selection = TextSelection.collapsed(offset: i);
    _controller.addListener(_onTextChanged);
  }
}

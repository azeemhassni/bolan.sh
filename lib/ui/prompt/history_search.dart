import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/bolan_theme.dart';

/// Inline history search popup triggered by Ctrl+R.
///
/// Shows a search box with filtered history results. Selecting an entry
/// populates the prompt input.
class HistorySearch extends StatefulWidget {
  final List<String> Function(String query) onSearch;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;
  final double fontSize;

  const HistorySearch({
    super.key,
    required this.onSearch,
    required this.onSelect,
    required this.onDismiss,
    this.fontSize = 13,
  });

  @override
  State<HistorySearch> createState() => _HistorySearchState();
}

class _HistorySearchState extends State<HistorySearch> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  List<String> _results = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKey);
    _results = widget.onSearch('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final ctrl = HardwareKeyboard.instance.isControlPressed;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onDismiss();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        if (_results.isNotEmpty && _selectedIndex < _results.length) {
          widget.onSelect(_results[_selectedIndex]);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyR when ctrl:
        // Ctrl+R again or Up arrow cycles through results
        if (_results.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % _results.length;
          });
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        if (_results.isNotEmpty) {
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1 + _results.length) % _results.length;
          });
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _results = widget.onSearch(query);
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final itemHeight = widget.fontSize * 1.8;
    final maxVisible = _results.length.clamp(0, 10);

    return Container(
      decoration: BoxDecoration(
        color: theme.promptBackground,
        border: Border(
          top: BorderSide(color: theme.blockBorder, width: 1),
          bottom: BorderSide(color: theme.blockBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  'history: ',
                  style: TextStyle(
                    color: theme.statusShellFg,
                    fontFamily: 'Operator Mono',
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: 'Operator Mono',
                        fontSize: widget.fontSize,
                        decoration: TextDecoration.none,
                      ),
                      cursorColor: theme.cursor,
                      cursorWidth: 2,
                      decoration: InputDecoration(
                        hintText: 'search...',
                        hintStyle: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: 'Operator Mono',
                          fontSize: widget.fontSize,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                Text(
                  'esc to close',
                  style: TextStyle(
                    color: theme.dimForeground,
                    fontFamily: 'Operator Mono',
                    fontSize: widget.fontSize - 2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),

          // Results list
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxVisible * itemHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                itemExtent: itemHeight,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedIndex;
                  return GestureDetector(
                    onTap: () => widget.onSelect(_results[index]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: isSelected
                          ? theme.statusChipBg
                          : Colors.transparent,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _results[index],
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: isSelected
                              ? theme.foreground
                              : theme.blockHeaderFg,
                          fontFamily: 'Operator Mono',
                          fontSize: widget.fontSize,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/actions/app_action.dart';
import '../../core/actions/fuzzy_search.dart';
import '../../core/theme/bolan_theme.dart';

/// Full-screen overlay command palette for searching and executing actions.
///
/// Triggered by Cmd+Shift+P. Shows a text field at the top with a scrollable
/// list of matching actions below. Keyboard navigable with arrow keys.
class CommandPalette extends StatefulWidget {
  final List<AppAction> actions;
  final VoidCallback onDismiss;

  const CommandPalette({
    super.key,
    required this.actions,
    required this.onDismiss,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<AppAction> _filtered = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filtered = widget.actions;
    _controller.addListener(_onQueryChanged);
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

  void _onQueryChanged() {
    setState(() {
      _filtered = FuzzySearch.search(widget.actions, _controller.text);
      _selectedIndex = 0;
    });
  }

  void _execute(AppAction action) {
    widget.onDismiss();
    action.callback();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onDismiss();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        if (_filtered.isNotEmpty) {
          _execute(_filtered[_selectedIndex]);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filtered.length;
        });
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + _filtered.length) % _filtered.length;
        });
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent dismiss when clicking the palette
            child: Material(
              color: Colors.transparent,
              child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 400),
              margin: const EdgeInsets.only(bottom: 100),
              decoration: BoxDecoration(
                color: theme.blockBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.blockBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchField(theme),
                  if (_filtered.isNotEmpty) _buildResultList(theme),
                  if (_filtered.isEmpty && _controller.text.isNotEmpty)
                    _buildEmpty(theme),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BolonTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Focus(
        onKeyEvent: _handleKey,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: TextStyle(
            color: theme.foreground,
            fontFamily: theme.fontFamily,
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
          cursorColor: theme.cursor,
          decoration: InputDecoration(
            hintText: 'Type a command...',
            hintStyle: TextStyle(
              color: theme.dimForeground,
              fontFamily: theme.fontFamily,
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search, color: theme.dimForeground, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildResultList(BolonTheme theme) {
    return Flexible(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 4),
        shrinkWrap: true,
        itemCount: _filtered.length,
        itemExtent: 36,
        itemBuilder: (context, index) {
          final action = _filtered[index];
          final isSelected = index == _selectedIndex;

          return GestureDetector(
            onTap: () => _execute(action),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: isSelected ? theme.statusChipBg : Colors.transparent,
              child: Row(
                children: [
                  if (action.icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        action.icon,
                        size: 16,
                        color: isSelected
                            ? theme.foreground
                            : theme.dimForeground,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      action.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? theme.foreground
                            : theme.blockHeaderFg,
                        fontFamily: theme.fontFamily,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (action.shortcut != null)
                    Text(
                      action.shortcut!,
                      style: TextStyle(
                        color: theme.dimForeground,
                        fontFamily: theme.fontFamily,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BolonTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No matching commands',
        style: TextStyle(
          color: theme.dimForeground,
          fontFamily: theme.fontFamily,
          fontSize: 13,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

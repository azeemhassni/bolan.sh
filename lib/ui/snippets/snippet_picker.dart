import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/snippets/snippet.dart';
import '../../core/theme/bolan_theme.dart';

/// Overlay for searching and inserting saved command snippets.
///
/// Shows a searchable list of snippets. Selected snippet's command
/// text is returned via [onSelect].
class SnippetPicker extends StatefulWidget {
  final List<Snippet> snippets;
  final ValueChanged<Snippet> onSelect;
  final VoidCallback onDismiss;

  const SnippetPicker({
    super.key,
    required this.snippets,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<SnippetPicker> createState() => _SnippetPickerState();
}

class _SnippetPickerState extends State<SnippetPicker> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Snippet> _filtered = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filtered = widget.snippets;
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
    final query = _controller.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.snippets
          : widget.snippets.where((s) {
              return s.name.toLowerCase().contains(query) ||
                  s.command.toLowerCase().contains(query) ||
                  s.tags.any((t) => t.toLowerCase().contains(query));
            }).toList();
      _selectedIndex = 0;
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onDismiss();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        if (_filtered.isNotEmpty) {
          widget.onSelect(_filtered[_selectedIndex]);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (_filtered.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % _filtered.length;
          });
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (_filtered.isNotEmpty) {
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1 + _filtered.length) % _filtered.length;
          });
        }
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
            onTap: () {},
            child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 350),
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
                  if (_filtered.isNotEmpty) _buildList(theme),
                  if (_filtered.isEmpty && _controller.text.isNotEmpty)
                    _buildEmpty(theme),
                  if (_filtered.isEmpty && _controller.text.isEmpty)
                    _buildNoSnippets(theme),
                ],
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
            hintText: 'Search snippets...',
            hintStyle: TextStyle(
              color: theme.dimForeground,
              fontFamily: theme.fontFamily,
              fontSize: 14,
            ),
            prefixIcon:
                Icon(Icons.code, color: theme.dimForeground, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BolonTheme theme) {
    return Flexible(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 4),
        shrinkWrap: true,
        itemCount: _filtered.length,
        itemExtent: 48,
        itemBuilder: (context, index) {
          final snippet = _filtered[index];
          final isSelected = index == _selectedIndex;

          return GestureDetector(
            onTap: () => widget.onSelect(snippet),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: isSelected ? theme.statusChipBg : Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    snippet.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? theme.foreground
                          : theme.blockHeaderFg,
                      fontFamily: theme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    snippet.command,
                    overflow: TextOverflow.ellipsis,
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
        'No matching snippets',
        style: TextStyle(
          color: theme.dimForeground,
          fontFamily: theme.fontFamily,
          fontSize: 13,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildNoSnippets(BolonTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No snippets saved yet.\nAdd snippets in Settings.',
        textAlign: TextAlign.center,
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

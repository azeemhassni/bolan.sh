import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/bolan_theme.dart';

/// Search result from the find bar.
class FindResult {
  final String query;
  final bool isRegex;
  final bool caseSensitive;
  final int currentMatch;
  final int totalMatches;

  const FindResult({
    required this.query,
    this.isRegex = false,
    this.caseSensitive = false,
    this.currentMatch = 0,
    this.totalMatches = 0,
  });
}

/// Find bar widget positioned at the top-right of the terminal.
///
/// Supports regex, case sensitivity, and search-in-selected-block toggles.
/// Shows match count and previous/next navigation.
class FindBar extends StatefulWidget {
  final void Function(FindResult result) onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final int currentMatch;
  final int totalMatches;

  const FindBar({
    super.key,
    required this.onSearch,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    this.currentMatch = 0,
    this.totalMatches = 0,
  });

  @override
  State<FindBar> createState() => FindBarState();
}

class FindBarState extends State<FindBar> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _isRegex = false;
  bool _caseSensitive = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKey);
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void requestFocus() {
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      if (shift) {
        widget.onPrevious();
      } else {
        widget.onNext();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onQueryChanged() {
    _emitSearch();
  }

  void _emitSearch() {
    widget.onSearch(FindResult(
      query: _controller.text,
      isRegex: _isRegex,
      caseSensitive: _caseSensitive,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.promptBackground,
        border: Border(
          bottom: BorderSide(color: theme.blockBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search input
          SizedBox(
            width: 300,
            child: Material(
              color: theme.statusChipBg,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: theme.fontFamily,
                        fontSize: 15,
                        decoration: TextDecoration.none,
                      ),
                      cursorColor: theme.cursor,
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        hintText: 'Find',
                        hintStyle: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: theme.fontFamily,
                          fontSize: 15,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: theme.blockBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: theme.blockBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: theme.cursor),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),

                  // Toggle buttons inside the input area
                  _ToggleButton(
                    label: '.*',
                    active: _isRegex,
                    theme: theme,
                    tooltip: 'Regex',
                    onTap: () {
                      setState(() => _isRegex = !_isRegex);
                      _emitSearch();
                    },
                  ),
                  _ToggleButton(
                    label: 'Aa',
                    active: _caseSensitive,
                    theme: theme,
                    tooltip: 'Case Sensitive',
                    onTap: () {
                      setState(() => _caseSensitive = !_caseSensitive);
                      _emitSearch();
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Match count
          Text(
            '${widget.totalMatches > 0 ? widget.currentMatch + 1 : 0}/${widget.totalMatches}',
            style: TextStyle(
              color: theme.dimForeground,
              fontFamily: theme.fontFamily,
              fontSize: 15,
              decoration: TextDecoration.none,
            ),
          ),

          const SizedBox(width: 4),

          // Previous / Next
          _IconBtn(
            icon: Icons.keyboard_arrow_down,
            size: 20,
            theme: theme,
            onTap: widget.onNext,
          ),
          _IconBtn(
            icon: Icons.keyboard_arrow_up,
            size: 20,
            theme: theme,
            onTap: widget.onPrevious,
          ),

          // Close
          _IconBtn(
            icon: Icons.close,
            size: 18,
            theme: theme,
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool active;
  final BolonTheme theme;
  final String tooltip;
  final VoidCallback onTap;

  const _ToggleButton({
    this.label,
    this.icon, // ignore: unused_element_parameter
    required this.active,
    required this.theme,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: active ? theme.cursor.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: icon != null
                ? Icon(icon, size: 18,
                    color: active ? theme.cursor : theme.dimForeground)
                : Text(
                    label!,
                    style: TextStyle(
                      color: active ? theme.cursor : theme.dimForeground,
                      fontFamily: theme.fontFamily,
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    this.size = 16,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: size, color: theme.dimForeground),
        ),
      ),
    );
  }
}

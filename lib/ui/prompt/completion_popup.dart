import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Floating completion list shown near the prompt input.
///
/// Displays completion candidates in a scrollable list. Supports
/// keyboard navigation (up/down) and mouse click to select.
class CompletionPopup extends StatefulWidget {
  final List<String> items;
  final int selectedIndex;
  final String prefix;
  final ValueChanged<int> onSelect;
  final double fontSize;

  const CompletionPopup({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.prefix,
    required this.onSelect,
    this.fontSize = 13,
  });

  @override
  State<CompletionPopup> createState() => _CompletionPopupState();
}

class _CompletionPopupState extends State<CompletionPopup> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(CompletionPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final itemHeight = widget.fontSize * 1.8;
    final target = widget.selectedIndex * itemHeight;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;

    if (target < current) {
      _scrollController.jumpTo(target);
    } else if (target + itemHeight > current + viewport) {
      _scrollController.jumpTo(target + itemHeight - viewport);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final maxVisible = widget.items.length.clamp(1, 8);
    final itemHeight = widget.fontSize * 1.8;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxVisible * itemHeight,
        maxWidth: 400,
      ),
      decoration: BoxDecoration(
        color: theme.blockBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.blockBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: widget.items.length,
        itemExtent: itemHeight,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final isSelected = index == widget.selectedIndex;

          return GestureDetector(
            onTap: () => widget.onSelect(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: isSelected ? theme.statusChipBg : Colors.transparent,
              alignment: Alignment.centerLeft,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? theme.foreground : theme.blockHeaderFg,
                  fontFamily: theme.fontFamily,
                  fontSize: widget.fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

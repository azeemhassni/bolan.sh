import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Floating completion list shown above the prompt input.
///
/// Displays completion candidates in a scrollable list. Supports
/// keyboard navigation (up/down) and mouse click to select.
class CompletionPopup extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final maxVisible = items.length.clamp(1, 8);
    final itemHeight = fontSize * 1.8;

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
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: items.length,
        itemExtent: itemHeight,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onSelect(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: isSelected ? theme.statusChipBg : Colors.transparent,
              alignment: Alignment.centerLeft,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? theme.foreground : theme.blockHeaderFg,
                  fontFamily: 'JetBrainsMono',
                  fontSize: fontSize,
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/completion/completion_engine.dart';
import '../../core/theme/bolan_theme.dart';

/// Floating completion list shown near the prompt input.
///
/// Displays completion candidates with icons and descriptions.
/// Keyboard navigable with arrow keys. Shows a detail panel for
/// the selected item when it has a description.
class CompletionPopup extends StatefulWidget {
  final List<CompletionItem> items;
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
    final itemHeight = widget.fontSize * 2.2;
    final target = widget.selectedIndex * itemHeight;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;

    if (target < current) {
      _scrollController.jumpTo(target);
    } else if (target + itemHeight > current + viewport) {
      _scrollController.jumpTo(target + itemHeight - viewport);
    }
  }

  Widget _iconForType(CompletionType type, {required Color color, required double size}) {
    if (type == CompletionType.artisanCommand) {
      return SvgPicture.asset(
        'assets/icons/ic_laravel.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    final icon = switch (type) {
      CompletionType.command => Icons.terminal,
      CompletionType.builtin => Icons.code,
      CompletionType.file => Icons.insert_drive_file_outlined,
      CompletionType.directory => Icons.folder_outlined,
      CompletionType.gitSubcommand => Icons.code,
      CompletionType.gitBranch => Icons.call_split,
      CompletionType.gitRemote => Icons.cloud_outlined,
      CompletionType.gitTag => Icons.label_outline,
      CompletionType.npmSubcommand => Icons.code,
      CompletionType.npmScript => Icons.play_arrow,
      CompletionType.npmPackage => Icons.inventory_2_outlined,
      CompletionType.artisanCommand => Icons.code, // unreachable
      CompletionType.composerCommand => Icons.code,
      CompletionType.toolCommand => Icons.code,
    };
    return Icon(icon, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final maxVisible = widget.items.length.clamp(1, 8);
    final itemHeight = widget.fontSize * 2.2;
    final selected =
        widget.items.isNotEmpty ? widget.items[widget.selectedIndex] : null;
    final hasDetail = selected?.description != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main list
        Container(
          constraints: BoxConstraints(
            maxHeight: maxVisible * itemHeight + 8,
            maxWidth: 360,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.cursor.withAlpha(40)
                        : Colors.transparent,
                    border: isSelected
                        ? Border(
                            left: BorderSide(
                                color: theme.cursor, width: 2),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.cursor.withAlpha(30)
                              : theme.statusChipBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _iconForType(
                          item.type,
                          size: 13,
                          color: isSelected
                              ? theme.cursor
                              : theme.dimForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Name
                      Expanded(
                        child: Text(
                          item.text,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? theme.foreground
                                : theme.blockHeaderFg,
                            fontFamily: theme.fontFamily,
                            fontSize: widget.fontSize,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      // Inline description tag
                      if (item.description != null)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              item.description!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.dimForeground,
                                fontFamily: theme.fontFamily,
                                fontSize: widget.fontSize - 2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Detail panel (shows for selected item with description)
        if (hasDetail) ...[
          const SizedBox(width: 4),
          Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.blockBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.blockBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected!.text,
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected.description!,
                  style: TextStyle(
                    color: theme.dimForeground,
                    fontFamily: theme.fontFamily,
                    fontSize: widget.fontSize - 2,
                    height: 1.4,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

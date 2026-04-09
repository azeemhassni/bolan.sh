import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Single row in a [PopoverMenuList]. Plain data class — the visual
/// rendering lives in the list widget.
class PopoverMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// When false, the row is rendered with reduced opacity and does
  /// not respond to clicks. Used for actions that aren't currently
  /// applicable (e.g. "Copy" with no selection).
  final bool enabled;

  /// Optional shortcut hint shown right-aligned in the row, in dim
  /// foreground. Doesn't actually bind a key — just labels the
  /// equivalent global shortcut.
  final String? shortcut;

  const PopoverMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.shortcut,
  });
}

/// Standard menu list rendered inside an anchored popover. Used for
/// every right-click / "more actions" / picker menu in the app, so
/// hover, active, padding, font, and icon styling stay identical
/// across the product.
///
/// Active row treatment matches the completion popover: a translucent
/// `theme.cursor` background with a 2px left accent stripe in the
/// same color.
class PopoverMenuList extends StatelessWidget {
  final List<PopoverMenuItem> items;
  const PopoverMenuList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // ListView (not Column) so menus with many items scroll inside
    // the popover's bounded height instead of overflowing. shrinkWrap
    // keeps short menus rendering at their natural size.
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, i) => _PopoverMenuRow(item: items[i]),
    );
  }
}

class _PopoverMenuRow extends StatefulWidget {
  final PopoverMenuItem item;
  const _PopoverMenuRow({required this.item});

  @override
  State<_PopoverMenuRow> createState() => _PopoverMenuRowState();
}

class _PopoverMenuRowState extends State<_PopoverMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final enabled = widget.item.enabled;
    // "Active" state matches the completion popover so all
    // selection/hover treatments in the app feel consistent.
    final active = _hovered && enabled;

    return GestureDetector(
      onTap: enabled ? widget.item.onTap : null,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          if (enabled) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (enabled) setState(() => _hovered = false);
        },
        child: Container(
          decoration: BoxDecoration(
            color: active
                ? theme.cursor.withAlpha(40)
                : Colors.transparent,
            border: active
                ? Border(
                    left: BorderSide(color: theme.cursor, width: 2),
                  )
                : const Border(
                    left: BorderSide(color: Colors.transparent, width: 2),
                  ),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 14,
                color: enabled
                    ? (active ? theme.cursor : theme.dimForeground)
                    : theme.dimForeground.withAlpha(80),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? theme.foreground
                        : theme.dimForeground.withAlpha(120),
                    fontFamily: theme.fontFamily,
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (widget.item.shortcut != null) ...[
                const SizedBox(width: 10),
                Text(
                  widget.item.shortcut!,
                  style: TextStyle(
                    color: theme.dimForeground.withAlpha(180),
                    fontFamily: theme.fontFamily,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

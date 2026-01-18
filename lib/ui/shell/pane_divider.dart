import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Draggable divider between two panes.
///
/// Renders a thin line that changes cursor on hover and reports
/// drag position as a ratio (0.0–1.0).
class PaneDivider extends StatefulWidget {
  final Axis axis;
  final double thickness;
  final ValueChanged<double> onDrag;
  final double totalSize;

  const PaneDivider({
    super.key,
    required this.axis,
    required this.onDrag,
    required this.totalSize,
    this.thickness = 4,
  });

  @override
  State<PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<PaneDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final isHorizontal = widget.axis == Axis.horizontal;

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: isHorizontal
            ? (d) => _handleDrag(d.delta.dx)
            : null,
        onVerticalDragUpdate: !isHorizontal
            ? (d) => _handleDrag(d.delta.dy)
            : null,
        child: Container(
          width: isHorizontal ? widget.thickness : double.infinity,
          height: isHorizontal ? double.infinity : widget.thickness,
          color: _hovered ? theme.cursor.withAlpha(100) : theme.blockBorder,
        ),
      ),
    );
  }

  void _handleDrag(double delta) {
    if (widget.totalSize <= 0) return;
    final ratioDelta = delta / widget.totalSize;
    widget.onDrag(ratioDelta);
  }
}

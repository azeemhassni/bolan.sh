import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/prompt_config.dart';
import '../../core/theme/bolan_theme.dart';

/// Visual editor for prompt bar chip configuration.
///
/// Drag chips from available pool into active area, reorder by dragging,
/// remove with ×.
class PromptEditor extends StatefulWidget {
  final List<String> activeChipIds;
  final ValueChanged<List<String>> onChanged;

  const PromptEditor({
    super.key,
    required this.activeChipIds,
    required this.onChanged,
  });

  @override
  State<PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<PromptEditor> {
  late List<String> _active;
  int? _dragInsertIndex;

  @override
  void initState() {
    super.initState();
    _active = List.from(widget.activeChipIds);
  }

  @override
  void didUpdateWidget(PromptEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChipIds != widget.activeChipIds) {
      _active = List.from(widget.activeChipIds);
    }
  }

  List<PromptChipType> get _available {
    return PromptChipType.values
        .where((t) => !_active.contains(t.id))
        .toList();
  }

  void _add(String chipId, [int? index]) {
    if (_active.contains(chipId)) return;
    setState(() {
      if (index != null) {
        _active.insert(index.clamp(0, _active.length), chipId);
      } else {
        _active.add(chipId);
      }
    });
    widget.onChanged(_active);
  }

  void _remove(int index) {
    setState(() => _active.removeAt(index));
    widget.onChanged(_active);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _active.removeAt(oldIndex);
      _active.insert(newIndex, item);
    });
    widget.onChanged(_active);
  }

  void _restoreDefaults() {
    setState(() {
      _active = defaultPromptChips.map((t) => t.id).toList();
    });
    widget.onChanged(_active);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Active Chips',
              style: TextStyle(
                color: theme.foreground,
                fontFamily: theme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _restoreDefaults,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'Restore default',
                  style: TextStyle(
                    color: theme.cursor,
                    fontFamily: theme.fontFamily,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Active chips — drop target + reorderable
        DragTarget<String>(
          onWillAcceptWithDetails: (details) =>
              !_active.contains(details.data),
          onAcceptWithDetails: (details) {
            _add(details.data, _dragInsertIndex);
            setState(() => _dragInsertIndex = null);
          },
          onLeave: (_) => setState(() => _dragInsertIndex = null),
          onMove: (details) {
            // Calculate insert position from pointer location
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(minHeight: 50),
              decoration: BoxDecoration(
                color: theme.statusChipBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHovering
                      ? theme.cursor.withAlpha(80)
                      : theme.blockBorder,
                  width: isHovering ? 2 : 1,
                ),
              ),
              child: _active.isEmpty
                  ? Text(
                      isHovering
                          ? 'Drop here to add'
                          : 'No chips selected. Drag from below.',
                      style: TextStyle(
                        color: theme.dimForeground,
                        fontFamily: theme.fontFamily,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _active.length; i++)
                          MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: LongPressDraggable<_ReorderData>(
                            data: _ReorderData(_active[i], i),
                            delay: const Duration(milliseconds: 150),
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.8,
                                child: _buildChip(
                                    _active[i], theme, null),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildChip(
                                  _active[i], theme, null),
                            ),
                            child: DragTarget<_ReorderData>(
                              onWillAcceptWithDetails: (details) =>
                                  details.data.index != i,
                              onAcceptWithDetails: (details) {
                                _reorder(details.data.index, i);
                              },
                              builder: (ctx, candidates, _) {
                                return Container(
                                  decoration: candidates.isNotEmpty
                                      ? BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: theme.cursor,
                                              width: 2,
                                            ),
                                          ),
                                        )
                                      : null,
                                  child: _buildChip(
                                      _active[i], theme, () => _remove(i)),
                                );
                              },
                            ),
                          ),
                          ),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Available chips pool
        Text(
          'Available Chips',
          style: TextStyle(
            color: theme.foreground,
            fontFamily: theme.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.statusChipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.blockBorder, width: 1),
          ),
          child: _available.isEmpty
              ? Text(
                  'All chips are active.',
                  style: TextStyle(
                    color: theme.dimForeground,
                    fontFamily: theme.fontFamily,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _available)
                      MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Draggable<String>(
                        data: type.id,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.8,
                            child: _buildAvailableChip(type, theme),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildAvailableChip(type, theme),
                        ),
                        child: GestureDetector(
                          onTap: () => _add(type.id),
                          child: _buildAvailableChip(type, theme),
                        ),
                      ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildChip(String id, BolonTheme theme, VoidCallback? onRemove) {
    final type = PromptChipMeta.fromId(id);
    final color = type?.fg(theme) ?? theme.foreground;
    final example = type?.example ?? id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.statusChipBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chipIcon(type, color, 14),
          const SizedBox(width: 5),
          Text(
            example,
            style: TextStyle(
              color: color,
              fontFamily: theme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child:
                    Icon(Icons.close, size: 13, color: theme.dimForeground),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableChip(PromptChipType type, BolonTheme theme) {
    final color = type.fg(theme);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.statusChipBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withAlpha(30), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chipIcon(type, color, 14),
            const SizedBox(width: 5),
            Text(
              type.label,
              style: TextStyle(
                color: color,
                fontFamily: theme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.add, size: 13, color: color.withAlpha(120)),
          ],
        ),
      ),
    );
  }
}

class _ReorderData {
  final String chipId;
  final int index;

  _ReorderData(this.chipId, this.index);
}

Widget _chipIcon(PromptChipType? type, Color color, double size) {
  if (type == null) return SizedBox(width: size, height: size);

  final svg = type.svgIcon;
  if (svg != null) {
    return SvgPicture.asset(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  final icon = type.materialIcon;
  if (icon != null) {
    return Icon(icon, size: size, color: color);
  }

  return SizedBox(width: size, height: size);
}

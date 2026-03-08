import 'package:flutter/material.dart';

import '../../core/config/prompt_config.dart';
import '../../core/theme/bolan_theme.dart';

/// Visual editor for prompt bar chip configuration.
///
/// Shows active chips (removable, reorderable) and available chips pool.
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

  void _add(PromptChipType type) {
    setState(() => _active.add(type.id));
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
                fontFamily: 'Operator Mono',
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
                    fontFamily: 'Operator Mono',
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Active chips — reorderable
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.statusChipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.blockBorder, width: 1),
          ),
          child: _active.isEmpty
              ? Text(
                  'No chips selected. Add from below.',
                  style: TextStyle(
                    color: theme.dimForeground,
                    fontFamily: 'Operator Mono',
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                )
              : ReorderableWrap(
                  chips: _active,
                  theme: theme,
                  onRemove: _remove,
                  onReorder: _reorder,
                ),
        ),
        const SizedBox(height: 20),

        // Available chips pool
        Text(
          'Available Chips',
          style: TextStyle(
            color: theme.foreground,
            fontFamily: 'Operator Mono',
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
            border: Border.all(
              color: theme.blockBorder,
              width: 1,
            ),
          ),
          child: _available.isEmpty
              ? Text(
                  'All chips are active.',
                  style: TextStyle(
                    color: theme.dimForeground,
                    fontFamily: 'Operator Mono',
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _available)
                      _AvailableChip(
                        type: type,
                        theme: theme,
                        onAdd: () => _add(type),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Wrap that supports reordering via drag.
class ReorderableWrap extends StatelessWidget {
  final List<String> chips;
  final BolonTheme theme;
  final void Function(int) onRemove;
  final void Function(int, int) onReorder;

  const ReorderableWrap({
    super.key,
    required this.chips,
    required this.theme,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < chips.length; i++)
          _ActiveChip(
            id: chips[i],
            index: i,
            theme: theme,
            onRemove: () => onRemove(i),
          ),
      ],
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String id;
  final int index;
  final BolonTheme theme;
  final VoidCallback onRemove;

  const _ActiveChip({
    required this.id,
    required this.index,
    required this.theme,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final type = PromptChipMeta.fromId(id);
    final label = type?.label ?? id;
    final example = type?.example ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.blockBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.blockBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: $example',
            style: TextStyle(
              color: theme.foreground,
              fontFamily: 'Operator Mono',
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(Icons.close, size: 14, color: theme.exitFailureFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableChip extends StatelessWidget {
  final PromptChipType type;
  final BolonTheme theme;
  final VoidCallback onAdd;

  const _AvailableChip({
    required this.type,
    required this.theme,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.blockBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.cursor.withAlpha(40), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: theme.cursor),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: TextStyle(
                  color: theme.cursor,
                  fontFamily: 'Operator Mono',
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

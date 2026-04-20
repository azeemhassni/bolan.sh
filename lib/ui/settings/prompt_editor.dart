import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/prompt_config.dart';
import '../../core/config/prompt_style.dart';
import '../../core/theme/bolan_theme.dart';

/// Visual editor for prompt bar chip configuration.
///
/// Drag chips from available pool into active area, reorder by dragging,
/// remove with ×. Includes a preset picker for prompt style.
class PromptEditor extends StatefulWidget {
  final List<String> activeChipIds;
  final ValueChanged<List<String>> onChanged;
  final PromptStyleConfig promptStyle;
  final ValueChanged<PromptStyleConfig> onStyleChanged;

  const PromptEditor({
    super.key,
    required this.activeChipIds,
    required this.onChanged,
    this.promptStyle = const PromptStyleConfig(),
    required this.onStyleChanged,
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
        // ── Prompt style preset picker ──
        Text(
          'Prompt Style',
          style: TextStyle(
            color: theme.foreground,
            fontFamily: theme.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),
        _PromptStylePicker(
          selected: widget.promptStyle.preset,
          theme: theme,
          onChanged: (preset) {
            widget.onStyleChanged(
                PromptStyleConfig.fromPreset(preset));
          },
        ),
        const SizedBox(height: 24),

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
        borderRadius: BorderRadius.circular(4),
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
          borderRadius: BorderRadius.circular(4),
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

// ── Preset picker ───────────────────────────────────────────

class _PromptStylePicker extends StatelessWidget {
  final PromptPreset selected;
  final BolonTheme theme;
  final ValueChanged<PromptPreset> onChanged;

  const _PromptStylePicker({
    required this.selected,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in PromptPreset.values)
          if (preset != PromptPreset.custom)
            _PresetCard(
              preset: preset,
              isSelected: selected == preset,
              theme: theme,
              onTap: () => onChanged(preset),
            ),
      ],
    );
  }
}

class _PresetCard extends StatefulWidget {
  final PromptPreset preset;
  final bool isSelected;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_PresetCard> createState() => _PresetCardState();
}

class _PresetCardState extends State<_PresetCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? t.cursor.withAlpha(15)
                : _hovered
                    ? t.statusChipBg
                    : t.blockBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? t.cursor : t.blockBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini preview
              _PresetPreview(
                preset: widget.preset,
                theme: t,
              ),
              const SizedBox(height: 8),
              Text(
                _presetLabel(widget.preset),
                style: TextStyle(
                  color: isSelected ? t.cursor : t.foreground,
                  fontFamily: t.fontFamily,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _presetDescription(widget.preset),
                style: TextStyle(
                  color: t.dimForeground,
                  fontFamily: t.fontFamily,
                  fontSize: 10,
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

String _presetLabel(PromptPreset p) => switch (p) {
      PromptPreset.bolan => 'Bolan',
      PromptPreset.powerline => 'Powerline',
      PromptPreset.starship => 'Starship',
      PromptPreset.minimal => 'Minimal',
      PromptPreset.custom => 'Custom',
    };

String _presetDescription(PromptPreset p) => switch (p) {
      PromptPreset.bolan => 'Outlined rectangles',
      PromptPreset.powerline => 'Filled segments with arrows',
      PromptPreset.starship => 'Rounded pill shapes',
      PromptPreset.minimal => 'Plain text, no chrome',
      PromptPreset.custom => 'Full control',
    };

/// Tiny schematic preview of a prompt style.
class _PresetPreview extends StatelessWidget {
  final PromptPreset preset;
  final BolonTheme theme;

  const _PresetPreview({required this.preset, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: switch (preset) {
        PromptPreset.bolan => _bolanPreview(),
        PromptPreset.powerline => _powerlinePreview(),
        PromptPreset.starship => _starshipPreview(),
        PromptPreset.minimal => _minimalPreview(),
        PromptPreset.custom => _bolanPreview(),
      },
    );
  }

  Widget _bolanPreview() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniChip(theme.statusGitFg, 4),
        const SizedBox(width: 4),
        _miniChip(theme.statusCwdFg, 4),
      ],
    );
  }

  Widget _powerlinePreview() {
    return CustomPaint(
      size: const Size(80, 18),
      painter: _PowerlinePreviewPainter(
        colors: [
          theme.statusGitFg.withAlpha(60),
          theme.statusCwdFg.withAlpha(60),
          theme.statusShellFg.withAlpha(60),
        ],
      ),
    );
  }

  Widget _starshipPreview() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniChip(theme.statusGitFg, 999, filled: true),
        const SizedBox(width: 4),
        _miniChip(theme.statusCwdFg, 999, filled: true),
      ],
    );
  }

  Widget _minimalPreview() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('main', style: _miniText(theme.statusGitFg)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('│', style: _miniText(theme.dimForeground)),
        ),
        Text('~/Code', style: _miniText(theme.statusCwdFg)),
      ],
    );
  }

  Widget _miniChip(Color color, double radius, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color.withAlpha(25) : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Text('abc', style: _miniText(color)),
    );
  }

  TextStyle _miniText(Color color) => TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w600,
        fontFamily: theme.fontFamily,
        decoration: TextDecoration.none,
      );
}

class _PowerlinePreviewPainter extends CustomPainter {
  final List<Color> colors;

  _PowerlinePreviewPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final segWidth = size.width / colors.length;
    const arrowW = 6.0;
    final midY = size.height / 2;

    for (var i = 0; i < colors.length; i++) {
      final x = i * segWidth;
      final paint = Paint()..color = colors[i];

      // Body
      canvas.drawRect(
        Rect.fromLTWH(x, 0, segWidth - arrowW, size.height),
        paint,
      );

      // Arrow
      final arrowPath = Path()
        ..moveTo(x + segWidth - arrowW, 0)
        ..lineTo(x + segWidth, midY)
        ..lineTo(x + segWidth - arrowW, size.height)
        ..close();
      canvas.drawPath(arrowPath, paint);
    }
  }

  @override
  bool shouldRepaint(_PowerlinePreviewPainter old) => colors != old.colors;
}

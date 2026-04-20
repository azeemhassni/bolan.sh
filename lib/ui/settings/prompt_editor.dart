import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/prompt_config.dart';
import '../../core/config/prompt_style.dart';
import '../../core/theme/bolan_theme.dart';
import '../prompt/chip_renderer.dart';
import '../shared/bolan_components.dart';

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
            if (preset == PromptPreset.custom) {
              // Seed custom from the current style so the user
              // starts editing from the current look.
              widget.onStyleChanged(
                  widget.promptStyle.copyWith(preset: PromptPreset.custom));
            } else {
              widget.onStyleChanged(PromptStyleConfig.fromPreset(preset));
            }
          },
        ),
        if (widget.promptStyle.preset == PromptPreset.custom) ...[
          const SizedBox(height: 16),
          _CustomStyleControls(
            style: widget.promptStyle,
            theme: theme,
            onChanged: widget.onStyleChanged,
          ),
        ],
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

// ── Custom style controls ───────────────────────────────────

class _CustomStyleControls extends StatelessWidget {
  final PromptStyleConfig style;
  final BolonTheme theme;
  final ValueChanged<PromptStyleConfig> onChanged;

  const _CustomStyleControls({
    required this.style,
    required this.theme,
    required this.onChanged,
  });

  /// Whether the current shape has a visible container (background/border).
  bool get _hasContainer =>
      style.chipShape == ChipShape.roundedRect ||
      style.chipShape == ChipShape.pill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.blockBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.blockBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Live preview ──
          _CustomStylePreview(
            key: ValueKey('preview_${style.chipShape.name}_${style.separator.name}'),
            style: style,
            theme: theme,
          ),
          const SizedBox(height: 16),
          Divider(color: theme.blockBorder, height: 1),
          const SizedBox(height: 16),

          // ── Shape ──
          BolanField(
            label: 'Chip shape',
            child: BolanSegmentedControl(
              value: style.chipShape.name,
              options: ChipShape.values.map((s) => s.name).toList(),
              onChanged: (v) => onChanged(style.copyWith(
                chipShape: ChipShape.values.byName(v),
              )),
            ),
          ),

          // Corner radius: only for roundedRect (pill is always 999,
          // trapezoid/none have no radius).
          if (style.chipShape == ChipShape.roundedRect)
            BolanField(
              label: 'Corner radius',
              child: BolanSlider(
                value: style.cornerRadius,
                min: 0,
                max: 20,
                step: 1,
                suffix: 'px',
                onChanged: (v) =>
                    onChanged(style.copyWith(cornerRadius: v)),
              ),
            ),

          // Border: not relevant for trapezoid or none.
          if (_hasContainer)
            BolanField(
              label: 'Border width',
              child: BolanSlider(
                value: style.borderWidth,
                min: 0,
                max: 3,
                step: 0.5,
                suffix: 'px',
                onChanged: (v) =>
                    onChanged(style.copyWith(borderWidth: v)),
              ),
            ),

          // Spacing: not relevant for trapezoid (segments are joined).
          if (style.chipShape != ChipShape.trapezoid)
            BolanField(
              label: 'Chip spacing',
              child: BolanSlider(
                value: style.chipSpacing,
                min: 0,
                max: 20,
                step: 1,
                suffix: 'px',
                onChanged: (v) =>
                    onChanged(style.copyWith(chipSpacing: v)),
              ),
            ),

          // Padding: relevant for all shapes with containers.
          if (style.chipShape != ChipShape.none)
            Row(
              children: [
                Expanded(
                  child: BolanField(
                    label: 'Horizontal padding',
                    child: BolanSlider(
                      value: style.chipPaddingH,
                      min: 0,
                      max: 16,
                      step: 1,
                      suffix: 'px',
                      onChanged: (v) =>
                          onChanged(style.copyWith(chipPaddingH: v)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: BolanField(
                    label: 'Vertical padding',
                    child: BolanSlider(
                      value: style.chipPaddingV,
                      min: 0,
                      max: 8,
                      step: 1,
                      suffix: 'px',
                      onChanged: (v) =>
                          onChanged(style.copyWith(chipPaddingV: v)),
                    ),
                  ),
                ),
              ],
            ),

          // Separator: not relevant for trapezoid (uses arrows).
          if (style.chipShape != ChipShape.trapezoid)
            BolanField(
              label: 'Separator',
              child: BolanSegmentedControl(
                value: style.separator.name,
                options:
                    SeparatorKind.values.map((s) => s.name).toList(),
                onChanged: (v) => onChanged(style.copyWith(
                  separator: SeparatorKind.values.byName(v),
                )),
              ),
            ),

          if (style.separator == SeparatorKind.character &&
              style.chipShape != ChipShape.trapezoid) ...[
            BolanField(
              label: 'Separator character',
              child: BolanTextField(
                value: style.separatorChar,
                hint: '│',
                onChanged: (v) =>
                    onChanged(style.copyWith(separatorChar: v)),
              ),
            ),
            BolanField(
              label: 'Separator color',
              help: 'Hex color (e.g. #7AA2F7). Leave empty for theme default.',
              child: BolanTextField(
                value: style.separatorColorHex,
                hint: '#888888',
                onChanged: (v) =>
                    onChanged(style.copyWith(separatorColorHex: v)),
              ),
            ),
          ],

          // ── Typography ──
          BolanField(
            label: 'Font weight',
            child: BolanSegmentedControl(
              value: style.fontWeight,
              options: const ['normal', 'w500', 'bold'],
              onChanged: (v) =>
                  onChanged(style.copyWith(fontWeight: v)),
            ),
          ),

          // ── Toggles ──
          // Filled background: not relevant for none (no container)
          // or trapezoid (always filled).
          if (_hasContainer)
            BolanToggle(
              label: 'Filled background',
              help: 'Fill chips with a tinted background color',
              value: style.filledBackground,
              onChanged: (v) =>
                  onChanged(style.copyWith(filledBackground: v)),
            ),
          if (_hasContainer)
            BolanToggle(
              label: 'Show border',
              value: style.showBorder,
              onChanged: (v) =>
                  onChanged(style.copyWith(showBorder: v)),
            ),
          BolanToggle(
            label: 'Show icons',
            value: style.showIcons,
            onChanged: (v) =>
                onChanged(style.copyWith(showIcons: v)),
          ),
          // Per-segment colors: only relevant for trapezoid.
          if (style.chipShape == ChipShape.trapezoid)
            BolanToggle(
              label: 'Per-segment colors',
              help: 'Each chip gets a distinct background color',
              value: style.perSegmentColors,
              onChanged: (v) =>
                  onChanged(style.copyWith(perSegmentColors: v)),
          ),
        ],
      ),
    );
  }
}

/// Live preview of the custom prompt style with sample chip data.
class _CustomStylePreview extends StatelessWidget {
  final PromptStyleConfig style;
  final BolonTheme theme;

  const _CustomStylePreview({super.key, required this.style, required this.theme});

  @override
  Widget build(BuildContext context) {
    const fontSize = 13.0;
    final sampleChips = [
      ChipData(
        text: 'zsh',
        fg: theme.statusShellFg,
        bg: theme.statusChipBg,
        svgIcon: 'assets/icons/ic_terminal.svg',
      ),
      ChipData(
        text: '~/Code/project',
        fg: theme.statusCwdFg,
        bg: theme.statusChipBg,
        svgIcon: 'assets/icons/ic_folder_code.svg',
      ),
      ChipData(
        text: 'main',
        fg: theme.statusGitFg,
        bg: theme.statusChipBg,
        svgIcon: 'assets/icons/ic_git.svg',
      ),
    ];

    final renderer = PromptChipRenderer.forStyle(style);

    // Powerline needs special handling for interlocking segments.
    if (renderer is PowerlineChipRenderer) {
      final promptBg = theme.promptBackground;
      final usePerSegment = style.perSegmentColors;
      final defaultBg =
          Color.lerp(promptBg, theme.statusChipBg, 0.3) ?? theme.statusChipBg;
      final segments = <Widget>[];
      for (var i = 0; i < sampleChips.length; i++) {
        final bg = usePerSegment
            ? Color.lerp(promptBg, sampleChips[i].fg, 0.16)!
            : defaultBg;
        final arrowWidth = fontSize * 0.7;
        segments.add(
          CustomPaint(
            painter: _PowerlinePreviewSegmentPainter(
              bg: bg,
              arrowWidth: arrowWidth,
              isFirst: i == 0,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0
                    ? style.chipPaddingH
                    : style.chipPaddingH + arrowWidth,
                right: style.chipPaddingH + arrowWidth,
                top: style.chipPaddingV,
                bottom: style.chipPaddingV,
              ),
              child: buildChipContent(
                data: sampleChips[i],
                fontSize: fontSize,
                theme: theme,
                fontWeight: parseFontWeight(style.fontWeight),
                showIcon: style.showIcons,
              ),
            ),
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.promptBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments,
              ),
            ),
          ),
        ),
      );
    }

    // Default / Starship / Minimal renderers.
    final rendered = sampleChips
        .map((data) => renderer.buildChip(data, fontSize, theme))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.promptBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: renderer.buildLayout(rendered),
    );
  }
}

/// Simplified powerline segment painter for the preview.
class _PowerlinePreviewSegmentPainter extends CustomPainter {
  final Color bg;
  final double arrowWidth;
  final bool isFirst;

  _PowerlinePreviewSegmentPainter({
    required this.bg,
    required this.arrowWidth,
    required this.isFirst,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final rightEdge = size.width - arrowWidth;
    final path = Path();
    if (isFirst) {
      path.moveTo(0, 0);
      path.lineTo(rightEdge, 0);
      path.lineTo(size.width, midY);
      path.lineTo(rightEdge, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(arrowWidth, midY);
      path.lineTo(0, size.height);
      path.lineTo(rightEdge, size.height);
      path.lineTo(size.width, midY);
      path.lineTo(rightEdge, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = bg);
  }

  @override
  bool shouldRepaint(_PowerlinePreviewSegmentPainter old) =>
      bg != old.bg || arrowWidth != old.arrowWidth || isFirst != old.isFirst;
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
          height: 105,
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

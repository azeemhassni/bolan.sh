import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/bolan_theme.dart';

// ─── Design System: Buttons ────────────────────────────────────
//
// Every interactive control in Bolan should use one of these five
// variants. Do NOT use TextButton, ElevatedButton, or raw
// GestureDetector+Container for new buttons — use these instead.
//
// ┌─────────────┬──────────────────────────────────────────────┐
// │ Variant      │ Usage                                        │
// ├─────────────┼──────────────────────────────────────────────┤
// │ Primary      │ Main action: Save, Create, Download, Update  │
// │ Secondary    │ Cancel, Not Now, Background, Close           │
// │ Danger       │ Delete, Restore Defaults, destructive ops    │
// │ Ghost        │ Low-emphasis text links: + Add row, inline   │
// │ Icon         │ Toolbar icons: tab close, block actions      │
// └─────────────┴──────────────────────────────────────────────┘
//
// Sizing:
//   Text buttons:  height 32, horizontal padding 14, font 12
//   Icon buttons:  28×28, icon size 15, border radius 5
//   All:           border radius 5, font weight w500
//
// Hover:
//   All non-primary: background → theme.statusChipBg
//   Primary:         10% brighter fill
//   Icon:            background → theme.statusChipBg
//
// Colors:
//   Primary bg:      theme.cursor (accent)
//   Primary fg:      theme.background (contrast)
//   Secondary bg:    theme.statusChipBg
//   Secondary fg:    theme.foreground
//   Danger bg:       transparent
//   Danger fg:       theme.exitFailureFg
//   Ghost fg:        theme.dimForeground
//   Icon fg:         theme.dimForeground (default), theme.foreground (hover)
//
// ────────────────────────────────────────────────────────────────

enum BolanButtonKind { primary, secondary, danger, ghost }

/// Standard text button used across all Bolan UI surfaces.
class BolanButton extends StatefulWidget {
  final String label;
  final BolanButtonKind kind;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool autofocus;

  const BolanButton({
    super.key,
    required this.label,
    this.kind = BolanButtonKind.secondary,
    this.icon,
    this.onTap,
    this.autofocus = false,
  });

  const BolanButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.autofocus = false,
  }) : kind = BolanButtonKind.primary;

  const BolanButton.danger({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.autofocus = false,
  }) : kind = BolanButtonKind.danger;

  const BolanButton.ghost({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.autofocus = false,
  }) : kind = BolanButtonKind.ghost;

  @override
  State<BolanButton> createState() => _BolanButtonState();
}

class _BolanButtonState extends State<BolanButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final colors = _resolveColors(theme);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? colors.hoverBg : colors.bg,
            borderRadius: BorderRadius.circular(5),
            border: widget.kind == BolanButtonKind.danger
                ? Border.all(
                    color: theme.exitFailureFg.withAlpha(60), width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 13, color: colors.fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: colors.fg,
                  fontFamily: theme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ButtonColors _resolveColors(BolonTheme theme) {
    switch (widget.kind) {
      case BolanButtonKind.primary:
        return _ButtonColors(
          bg: theme.cursor,
          hoverBg: theme.cursor.withAlpha(220),
          fg: theme.background,
        );
      case BolanButtonKind.secondary:
        return _ButtonColors(
          bg: theme.statusChipBg,
          hoverBg: theme.blockBorder,
          fg: theme.foreground,
        );
      case BolanButtonKind.danger:
        return _ButtonColors(
          bg: Colors.transparent,
          hoverBg: theme.exitFailureFg.withAlpha(20),
          fg: theme.exitFailureFg,
        );
      case BolanButtonKind.ghost:
        return _ButtonColors(
          bg: Colors.transparent,
          hoverBg: theme.statusChipBg,
          fg: theme.dimForeground,
        );
    }
  }
}

class _ButtonColors {
  final Color bg;
  final Color hoverBg;
  final Color fg;
  const _ButtonColors({
    required this.bg,
    required this.hoverBg,
    required this.fg,
  });
}

/// Standard icon button: 28×28, 15px icon, hover bg, optional tooltip.
/// Used for toolbar actions (tab close, block copy, expand/collapse, etc.).
class BolanIconButton extends StatefulWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;

  const BolanIconButton({
    super.key,
    this.icon,
    this.iconWidget,
    this.tooltip,
    this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  State<BolanIconButton> createState() => _BolanIconButtonState();
}

class _BolanIconButtonState extends State<BolanIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final fg = widget.active
        ? (widget.activeColor ?? theme.foreground)
        : _hovered
            ? theme.foreground
            : theme.dimForeground;
    final bg = widget.active
        ? theme.statusChipBg
        : _hovered
            ? theme.statusChipBg
            : Colors.transparent;

    Widget child = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: widget.iconWidget ??
            Icon(widget.icon, size: 15, color: fg),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: child,
      );
    }

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}

/// SVG variant of [BolanIconButton]. Same 28×28 sizing, same hover behavior.
class BolanSvgIconButton extends StatefulWidget {
  final String assetPath;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool active;

  const BolanSvgIconButton({
    super.key,
    required this.assetPath,
    this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  State<BolanSvgIconButton> createState() => _BolanSvgIconButtonState();
}

class _BolanSvgIconButtonState extends State<BolanSvgIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final fg = widget.active || _hovered
        ? theme.foreground
        : theme.dimForeground;
    final bg = widget.active
        ? theme.background
        : _hovered
            ? theme.statusChipBg
            : Colors.transparent;

    Widget child = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: SvgPicture.asset(
          widget.assetPath,
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: child,
      );
    }

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}

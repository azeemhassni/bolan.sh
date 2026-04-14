import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/bolan_theme.dart';
import '../../providers/font_size_provider.dart';

/// A compact outlined chip used in the prompt area.
///
/// Pass either [text] (single-color label) or [child] (custom inline
/// content like multi-color counts). All chips share the same chrome:
/// padding, border radius, icon size, and font size — touch them in
/// one place and every chip in the app updates.
///
/// Chip text and icon size scale with the global terminal font size
/// (`fontSizeProvider`) so the Cmd/Ctrl + and - shortcuts grow and
/// shrink chips together with terminal text.
class StatusChip extends ConsumerWidget {
  final String? text;

  /// Alternative to [text] when the chip needs richer inline content
  /// (e.g. multiple colors in a single chip). Renders to the right
  /// of the icon, in the same row.
  final Widget? child;

  final Color fg;
  final Color bg;
  final IconData? icon;
  final String? svgIcon;

  /// Static chip metrics that don't scale with font size.
  static const FontWeight textWeight = FontWeight.w700;
  static const double iconGap = 5;
  static const EdgeInsets padding =
      EdgeInsets.symmetric(horizontal: 4, vertical: 2);
  static const double cornerRadius = 4;

  /// Chip text matches the current terminal font size exactly.
  /// The only visual distinction from terminal text is [textWeight]
  /// (bold) — same family, same size.
  static double textSizeFor(double baseFontSize) => baseFontSize;

  /// Chip icon size matches the chip text size so icons stay
  /// proportional to their label.
  static double iconSizeFor(double baseFontSize) => baseFontSize;

  const StatusChip({
    super.key,
    this.text,
    this.child,
    required this.fg,
    required this.bg,
    this.icon,
    this.svgIcon,
  }) : assert(text != null || child != null,
            'StatusChip needs either text or child');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseFontSize = ref.watch(fontSizeProvider);
    final textSize = textSizeFor(baseFontSize);
    final iconSize = iconSizeFor(baseFontSize);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: fg.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (svgIcon != null) ...[
            SvgPicture.asset(
              svgIcon!,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
            ),
            const SizedBox(width: iconGap),
          ] else if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: iconGap),
          ],
          child ??
              Text(
                text!,
                style: TextStyle(
                  color: fg,
                  fontSize: textSize,
                  fontFamily: BolonTheme.of(context).fontFamily,
                  fontWeight: textWeight,
                  decoration: TextDecoration.none,
                ),
              ),
        ],
      ),
    );
  }
}

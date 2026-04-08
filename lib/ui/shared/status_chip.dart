import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/bolan_theme.dart';

/// A compact outlined chip used in the prompt area.
///
/// Pass either [text] (single-color label) or [child] (custom inline
/// content like multi-color counts). All chips share the same chrome:
/// padding, border radius, icon size, and font size — touch them in
/// one place and every chip in the app updates.
class StatusChip extends StatelessWidget {
  final String? text;

  /// Alternative to [text] when the chip needs richer inline content
  /// (e.g. multiple colors in a single chip). Renders to the right
  /// of the icon, in the same row.
  final Widget? child;

  final Color fg;
  final Color bg;
  final IconData? icon;
  final String? svgIcon;

  /// Standard chip metrics. Touch these and every chip updates.
  static const double textSize = 18;
  static const FontWeight textWeight = FontWeight.w700;
  static const double iconSize = 18;
  static const double iconGap = 6;
  static const EdgeInsets padding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  static const double cornerRadius = 6;

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
  Widget build(BuildContext context) {
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

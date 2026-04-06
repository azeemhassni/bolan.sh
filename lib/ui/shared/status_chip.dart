import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/bolan_theme.dart';

/// A compact outlined chip used in the prompt area.
///
/// Supports both Material Icons and SVG asset icons.
class StatusChip extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;
  final String? svgIcon;

  const StatusChip({
    super.key,
    required this.text,
    required this.fg,
    required this.bg,
    this.icon,
    this.svgIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (svgIcon != null) ...[
            SvgPicture.asset(
              svgIcon!,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 16,
              fontFamily: BolonTheme.of(context).fontFamily,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

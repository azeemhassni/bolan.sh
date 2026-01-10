import 'package:flutter/material.dart';

/// A compact pill-shaped chip used in the status bar.
///
/// Displays an optional icon and text with custom foreground/background colors.
class StatusChip extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.text,
    required this.fg,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A compact outlined chip used in the prompt area, styled like Warp's chips.
///
/// Displays an optional icon and text with a bordered outline style.
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontFamily: 'Operator Mono',
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

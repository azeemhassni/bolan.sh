import 'package:flutter/material.dart';

import '../../../core/theme/bolan_theme.dart';

/// A row in the Overrides tab: checkbox to enable the override +
/// the control widget when enabled.
class OverrideRow extends StatelessWidget {
  final String label;
  final bool isOverridden;
  final BolonTheme theme;
  final ValueChanged<bool> onToggle;
  final Widget? child;

  const OverrideRow({
    super.key,
    required this.label,
    required this.isOverridden,
    required this.theme,
    required this.onToggle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOverridden
              ? theme.cursor.withAlpha(8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOverridden
                ? theme.cursor.withAlpha(40)
                : theme.blockBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isOverridden,
                    onChanged: (v) => onToggle(v ?? false),
                    activeColor: theme.cursor,
                    side: BorderSide(color: theme.dimForeground),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (!isOverridden) ...[
                  const SizedBox(width: 12),
                  Text(
                    'uses global',
                    style: TextStyle(
                      color: theme.dimForeground,
                      fontFamily: theme.fontFamily,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
            if (isOverridden && child != null) ...[
              const SizedBox(height: 10),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

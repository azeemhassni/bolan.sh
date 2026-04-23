import 'package:flutter/material.dart';

import '../../../core/theme/bolan_theme.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final BolonTheme theme;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: theme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

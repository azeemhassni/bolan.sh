import 'package:flutter/material.dart';

import '../../../core/theme/bolan_theme.dart';

class SidebarTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final BolonTheme theme;
  final VoidCallback onTap;

  const SidebarTab({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isSelected ? theme.blockBackground : Colors.transparent,
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isSelected ? theme.foreground : theme.dimForeground),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? theme.foreground : theme.dimForeground,
                  fontFamily: theme.fontFamily,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w500 : FontWeight.normal,
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

import 'package:flutter/material.dart';

import '../../../core/theme/bolan_theme.dart';

class ThemeCard extends StatelessWidget {
  final BolonTheme theme;
  final bool isActive;
  final BolonTheme currentTheme;
  final VoidCallback onTap;

  const ThemeCard({
    super.key,
    required this.theme,
    required this.isActive,
    required this.currentTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 120,
          height: 90,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? currentTheme.cursor
                  : currentTheme.blockBorder,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewLine('\$ ', theme.dimForeground, 'ls -la', theme.ansiGreen),
                      _previewLine('  ', theme.foreground, 'src/ lib/', theme.foreground),
                      _previewLine('\$ ', theme.dimForeground, 'git push', theme.ansiBlue),
                      _previewLine('  ', theme.exitSuccessFg, '✓ done', theme.exitSuccessFg),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.tabBarBackground,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
                child: Text(
                  theme.displayName,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewLine(String prefix, Color prefixColor, String text, Color textColor) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: TextStyle(color: prefixColor, fontFamily: theme.fontFamily, fontSize: 7, height: 1.4),
          ),
          TextSpan(
            text: text,
            style: TextStyle(color: textColor, fontFamily: theme.fontFamily, fontSize: 7, height: 1.4),
          ),
        ],
      ),
    );
  }
}

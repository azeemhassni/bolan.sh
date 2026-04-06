import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/platform_shortcuts.dart';
import '../../core/theme/bolan_theme.dart';

/// Shown when all tabs are closed. Displays ASCII art and a
/// "New Session" button to get started.
class EmptyState extends StatelessWidget {
  final VoidCallback onNewSession;

  const EmptyState({super.key, required this.onNewSession});

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final mod = Platform.isMacOS ? '⌘' : 'Ctrl+';

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyT &&
            isPrimaryModifierPressed) {
          onNewSession();
          return KeyEventResult.handled;
        }
        // Enter or Space also works
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          onNewSession();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            SvgPicture.asset(
              'assets/logo-text.svg',
              width: 480,
            ),
            const SizedBox(height: 32),
            Text(
              'No open sessions',
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 32),
            // New Session button — hand-drawn style
            GestureDetector(
              onTap: onNewSession,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: CustomPaint(
                  painter: _HandDrawnButtonPainter(
                    color: const Color(0xFF00FF92),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '>_ ',
                          style: TextStyle(
                            color: const Color(0xFF00FF92),
                            fontFamily: theme.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          'New Session',
                          style: TextStyle(
                            color: const Color(0xFF00FF92),
                            fontFamily: theme.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${mod}T',
              style: TextStyle(
                color: theme.dimForeground.withAlpha(120),
                fontFamily: theme.fontFamily,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a rough, hand-drawn rounded rectangle border.
///
/// Uses slightly offset strokes and uneven corners to
/// give a sketchy, organic feel.
class _HandDrawnButtonPainter extends CustomPainter {
  final Color color;

  _HandDrawnButtonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const r = 12.0; // corner radius
    const j = 1.5; // jitter amount

    // First pass — main border with slight offsets
    final path1 = Path()
      ..moveTo(r + j, -j)
      ..lineTo(w - r - j, j)
      ..quadraticBezierTo(w + j, -j, w + j, r + j)
      ..lineTo(w - j, h - r - j)
      ..quadraticBezierTo(w + j, h + j, w - r - j, h + j)
      ..lineTo(r + j, h - j)
      ..quadraticBezierTo(-j, h + j, -j, h - r - j)
      ..lineTo(j, r + j)
      ..quadraticBezierTo(-j, -j, r + j, -j);

    canvas.drawPath(path1, paint);

    // Second pass — lighter, slightly offset for hand-drawn feel
    final paint2 = Paint()
      ..color = color.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final path2 = Path()
      ..moveTo(r - j, j)
      ..lineTo(w - r + j, -j)
      ..quadraticBezierTo(w - j, j, w - j, r - j)
      ..lineTo(w + j, h - r + j)
      ..quadraticBezierTo(w - j, h - j, w - r + j, h - j)
      ..lineTo(r - j, h + j)
      ..quadraticBezierTo(j, h - j, j, h - r + j)
      ..lineTo(-j, r - j)
      ..quadraticBezierTo(j, j, r - j, j);

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

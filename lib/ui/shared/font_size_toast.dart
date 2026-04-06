import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Brief animated toast shown when font size changes.
///
/// Displays "Font: 14px" in the center of the window, then fades out
/// after 1.2 seconds.
class FontSizeToast extends StatefulWidget {
  final double fontSize;
  final VoidCallback onDismissed;

  const FontSizeToast({
    super.key,
    required this.fontSize,
    required this.onDismissed,
  });

  @override
  State<FontSizeToast> createState() => _FontSizeToastState();
}

class _FontSizeToastState extends State<FontSizeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 1200), _fadeOut);
  }

  @override
  void didUpdateWidget(FontSizeToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      _dismissTimer?.cancel();
      _controller.forward(from: 0);
      _dismissTimer = Timer(const Duration(milliseconds: 1200), _fadeOut);
    }
  }

  void _fadeOut() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: theme.statusChipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.blockBorder, width: 1),
        ),
        child: Text(
          'Font: ${widget.fontSize.round()}px',
          style: TextStyle(
            color: theme.foreground,
            fontFamily: theme.fontFamily,
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

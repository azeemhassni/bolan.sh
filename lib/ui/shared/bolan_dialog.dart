import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/bolan_theme.dart';

/// Standard dialog frame for Bolan. All popups/dialogs in the app
/// should use this so visual treatment (size, border, padding, shadow,
/// typography, button styles) stays identical across the product.
///
/// Use [BolanDialogTitle], [BolanDialogText], and [BolanDialogButton]
/// for content so type sizes and weights match the rest of the app.
class BolanDialog extends StatelessWidget {
  final Widget child;
  final double width;

  /// Standard dialog metrics. Touch these and you change every dialog
  /// in the app — that's the whole point.
  static const double standardWidth = 420;
  static const double cornerRadius = 8;
  static const EdgeInsets contentPadding = EdgeInsets.all(20);

  const BolanDialog({
    super.key,
    required this.child,
    this.width = standardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          padding: contentPadding,
          decoration: BoxDecoration(
            color: theme.blockBackground,
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(color: theme.blockBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Standard dialog title row. Optional [icon] is rendered to the left
/// of the [text] in the same accent color used for the title.
class BolanDialogTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? iconColor;

  const BolanDialogTitle({
    super.key,
    required this.text,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: iconColor ?? theme.foreground),
          const SizedBox(width: 10),
        ],
        Text(
          text,
          style: TextStyle(
            color: theme.foreground,
            fontFamily: theme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

/// Standard dialog body text. Use this for paragraphs, descriptions,
/// helper copy. For inline emphasis or status, drop a Text widget with
/// matching font but different color.
class BolanDialogText extends StatelessWidget {
  final String text;
  final int? maxLines;
  final TextOverflow overflow;

  const BolanDialogText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        color: theme.dimForeground,
        fontFamily: theme.fontFamily,
        fontSize: 13,
        height: 1.5,
        decoration: TextDecoration.none,
      ),
    );
  }
}

/// Visual variant for [BolanDialogButton]. Two-tier system:
/// affirmative actions get the accent color, destructive actions
/// get red. Anything that "could go wrong" — including overriding
/// safety checks — counts as destructive.
enum BolanButtonKind {
  /// Default — neutral chip-style button. Use for "Cancel", "Close".
  secondary,

  /// Filled accent — primary affirmative action. Use for "Download",
  /// "Confirm", "Done", etc.
  primary,

  /// Filled red — destructive or potentially destabilising action.
  /// Use for "Delete", "Quit", "Discard", "Proceed Anyway" when
  /// proceeding could crash or corrupt something.
  danger,
}

/// Standard dialog button. Use this for every button inside a
/// [BolanDialog] so padding, radius, font, and colors all match.
///
/// Supports keyboard navigation: Tab to focus, Enter/Space to
/// activate. When focused, a 2px ring in the theme cursor color
/// appears around the button.
class BolanDialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final BolanButtonKind kind;

  /// Set to true on exactly one button per dialog (typically the
  /// primary or danger action) so the keyboard lands there by
  /// default.
  final bool autofocus;

  const BolanDialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = BolanButtonKind.secondary,
    this.autofocus = false,
  });

  @override
  State<BolanDialogButton> createState() => _BolanDialogButtonState();
}

class _BolanDialogButtonState extends State<BolanDialogButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    final bg = switch (widget.kind) {
      BolanButtonKind.secondary => theme.statusChipBg,
      BolanButtonKind.primary => theme.cursor,
      BolanButtonKind.danger => theme.exitFailureFg,
    };
    final fg = widget.kind == BolanButtonKind.secondary
        ? theme.foreground
        : theme.background;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _focused
                  ? Color.alphaBlend(Colors.white.withAlpha(40), bg)
                  : _hovered
                      ? Color.alphaBlend(Colors.white.withAlpha(20), bg)
                      : bg,
              borderRadius: BorderRadius.circular(5),
              border: _focused
                  ? Border.all(
                      color: theme.foreground.withAlpha(120), width: 1.5)
                  : Border.all(color: Colors.transparent, width: 1.5),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: fg,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience wrapper around [showDialog] that uses Bolan's standard
/// barrier color and dismiss behaviour. Returns whatever the builder's
/// `Navigator.pop` is called with.
///
/// Critically, this helper captures (or accepts) a [BolonTheme] and
/// re-provides it inside the dialog. `showDialog` mounts the builder
/// under the root Navigator, which is above [BolonThemeProvider] in
/// the tree, so descendants would otherwise fail their
/// `BolonTheme.of(context)` lookup.
///
/// Pass [theme] explicitly when the calling [BuildContext] is itself
/// above the theme provider — for example, from a `StatefulWidget`'s
/// State.context where the provider is created inside `build()`. In
/// those cases, read the theme from somewhere else (Riverpod's
/// `activeThemeProvider`) and pass it in.
Future<T?> showBolanDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BolonTheme? theme,
  bool barrierDismissible = true,
}) {
  final resolvedTheme = theme ?? BolonTheme.of(context);
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black54,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => BolonThemeProvider(
      theme: resolvedTheme,
      child: Builder(builder: builder),
    ),
  );
}

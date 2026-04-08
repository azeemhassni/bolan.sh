import 'package:flutter/material.dart';

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
class BolanDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final BolanButtonKind kind;

  const BolanDialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = BolanButtonKind.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    final bg = switch (kind) {
      BolanButtonKind.secondary => theme.statusChipBg,
      BolanButtonKind.primary => theme.cursor,
      BolanButtonKind.danger => theme.exitFailureFg,
    };
    final fg = kind == BolanButtonKind.secondary
        ? theme.foreground
        : theme.background;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
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

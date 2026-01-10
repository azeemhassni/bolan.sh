import 'package:flutter/material.dart';

/// Complete theme data model for the Bolan terminal emulator.
///
/// Contains colors for every UI element: window chrome, blocks, status bar,
/// prompt, terminal text, and ANSI colors.
class BolonTheme {
  // Window
  final Color background;
  final Color tabBarBackground;
  final Color statusBarBackground;
  final Color promptBackground;

  // Blocks
  final Color blockBackground;
  final Color blockBorder;
  final Color blockHeaderFg;
  final Color exitSuccessFg;
  final Color exitFailureFg;

  // Status chips
  final Color statusChipBg;
  final Color statusCwdFg;
  final Color statusGitFg;
  final Color statusShellFg;
  final Color dimForeground;

  // Terminal text
  final Color foreground;
  final Color cursor;
  final Color selectionColor;

  // ANSI 16 colors
  final Color ansiBlack;
  final Color ansiRed;
  final Color ansiGreen;
  final Color ansiYellow;
  final Color ansiBlue;
  final Color ansiMagenta;
  final Color ansiCyan;
  final Color ansiWhite;
  final Color ansiBrightBlack;
  final Color ansiBrightRed;
  final Color ansiBrightGreen;
  final Color ansiBrightYellow;
  final Color ansiBrightBlue;
  final Color ansiBrightMagenta;
  final Color ansiBrightCyan;
  final Color ansiBrightWhite;

  const BolonTheme({
    required this.background,
    required this.tabBarBackground,
    required this.statusBarBackground,
    required this.promptBackground,
    required this.blockBackground,
    required this.blockBorder,
    required this.blockHeaderFg,
    required this.exitSuccessFg,
    required this.exitFailureFg,
    required this.statusChipBg,
    required this.statusCwdFg,
    required this.statusGitFg,
    required this.statusShellFg,
    required this.dimForeground,
    required this.foreground,
    required this.cursor,
    required this.selectionColor,
    required this.ansiBlack,
    required this.ansiRed,
    required this.ansiGreen,
    required this.ansiYellow,
    required this.ansiBlue,
    required this.ansiMagenta,
    required this.ansiCyan,
    required this.ansiWhite,
    required this.ansiBrightBlack,
    required this.ansiBrightRed,
    required this.ansiBrightGreen,
    required this.ansiBrightYellow,
    required this.ansiBrightBlue,
    required this.ansiBrightMagenta,
    required this.ansiBrightCyan,
    required this.ansiBrightWhite,
  });

  /// Retrieves the [BolonTheme] from the nearest [BolonThemeProvider] ancestor.
  static BolonTheme of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<BolonThemeProvider>();
    assert(provider != null, 'No BolonThemeProvider found in widget tree');
    return provider!.theme;
  }
}

/// InheritedWidget that propagates [BolonTheme] down the widget tree.
class BolonThemeProvider extends InheritedWidget {
  final BolonTheme theme;

  const BolonThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  @override
  bool updateShouldNotify(BolonThemeProvider oldWidget) =>
      theme != oldWidget.theme;
}

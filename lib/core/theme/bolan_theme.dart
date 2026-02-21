import 'package:flutter/material.dart';

/// Complete theme data model for the Bolan terminal emulator.
///
/// Contains colors for every UI element: window chrome, blocks, status bar,
/// prompt, terminal text, ANSI colors, and search highlights.
class BolonTheme {
  // Metadata
  final String name;
  final String displayName;
  final Brightness brightness;
  final bool isBuiltIn;

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

  // Search highlights
  final Color searchHitBackground;
  final Color searchHitBackgroundCurrent;
  final Color searchHitForeground;

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
    this.name = 'default-dark',
    this.displayName = 'Default Dark',
    this.brightness = Brightness.dark,
    this.isBuiltIn = true,
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
    this.searchHitBackground = const Color(0xFF50A0FF),
    this.searchHitBackgroundCurrent = const Color(0xFF78B4FF),
    this.searchHitForeground = const Color(0xFF0D0E12),
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

  /// Creates a copy with the given fields replaced.
  BolonTheme copyWith({
    String? name,
    String? displayName,
    Brightness? brightness,
    bool? isBuiltIn,
    Color? background,
    Color? tabBarBackground,
    Color? statusBarBackground,
    Color? promptBackground,
    Color? blockBackground,
    Color? blockBorder,
    Color? blockHeaderFg,
    Color? exitSuccessFg,
    Color? exitFailureFg,
    Color? statusChipBg,
    Color? statusCwdFg,
    Color? statusGitFg,
    Color? statusShellFg,
    Color? dimForeground,
    Color? foreground,
    Color? cursor,
    Color? selectionColor,
    Color? searchHitBackground,
    Color? searchHitBackgroundCurrent,
    Color? searchHitForeground,
    Color? ansiBlack,
    Color? ansiRed,
    Color? ansiGreen,
    Color? ansiYellow,
    Color? ansiBlue,
    Color? ansiMagenta,
    Color? ansiCyan,
    Color? ansiWhite,
    Color? ansiBrightBlack,
    Color? ansiBrightRed,
    Color? ansiBrightGreen,
    Color? ansiBrightYellow,
    Color? ansiBrightBlue,
    Color? ansiBrightMagenta,
    Color? ansiBrightCyan,
    Color? ansiBrightWhite,
  }) {
    return BolonTheme(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      brightness: brightness ?? this.brightness,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      background: background ?? this.background,
      tabBarBackground: tabBarBackground ?? this.tabBarBackground,
      statusBarBackground: statusBarBackground ?? this.statusBarBackground,
      promptBackground: promptBackground ?? this.promptBackground,
      blockBackground: blockBackground ?? this.blockBackground,
      blockBorder: blockBorder ?? this.blockBorder,
      blockHeaderFg: blockHeaderFg ?? this.blockHeaderFg,
      exitSuccessFg: exitSuccessFg ?? this.exitSuccessFg,
      exitFailureFg: exitFailureFg ?? this.exitFailureFg,
      statusChipBg: statusChipBg ?? this.statusChipBg,
      statusCwdFg: statusCwdFg ?? this.statusCwdFg,
      statusGitFg: statusGitFg ?? this.statusGitFg,
      statusShellFg: statusShellFg ?? this.statusShellFg,
      dimForeground: dimForeground ?? this.dimForeground,
      foreground: foreground ?? this.foreground,
      cursor: cursor ?? this.cursor,
      selectionColor: selectionColor ?? this.selectionColor,
      searchHitBackground: searchHitBackground ?? this.searchHitBackground,
      searchHitBackgroundCurrent:
          searchHitBackgroundCurrent ?? this.searchHitBackgroundCurrent,
      searchHitForeground: searchHitForeground ?? this.searchHitForeground,
      ansiBlack: ansiBlack ?? this.ansiBlack,
      ansiRed: ansiRed ?? this.ansiRed,
      ansiGreen: ansiGreen ?? this.ansiGreen,
      ansiYellow: ansiYellow ?? this.ansiYellow,
      ansiBlue: ansiBlue ?? this.ansiBlue,
      ansiMagenta: ansiMagenta ?? this.ansiMagenta,
      ansiCyan: ansiCyan ?? this.ansiCyan,
      ansiWhite: ansiWhite ?? this.ansiWhite,
      ansiBrightBlack: ansiBrightBlack ?? this.ansiBrightBlack,
      ansiBrightRed: ansiBrightRed ?? this.ansiBrightRed,
      ansiBrightGreen: ansiBrightGreen ?? this.ansiBrightGreen,
      ansiBrightYellow: ansiBrightYellow ?? this.ansiBrightYellow,
      ansiBrightBlue: ansiBrightBlue ?? this.ansiBrightBlue,
      ansiBrightMagenta: ansiBrightMagenta ?? this.ansiBrightMagenta,
      ansiBrightCyan: ansiBrightCyan ?? this.ansiBrightCyan,
      ansiBrightWhite: ansiBrightWhite ?? this.ansiBrightWhite,
    );
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

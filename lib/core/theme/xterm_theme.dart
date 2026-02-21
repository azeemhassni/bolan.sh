import 'package:xterm/xterm.dart';

import 'bolan_theme.dart';

/// Converts a [BolonTheme] to an xterm [TerminalTheme] for rendering.
TerminalTheme bolonToXtermTheme(BolonTheme t) => TerminalTheme(
      cursor: t.cursor,
      selection: t.selectionColor,
      foreground: t.foreground,
      background: t.background,
      black: t.ansiBlack,
      red: t.ansiRed,
      green: t.ansiGreen,
      yellow: t.ansiYellow,
      blue: t.ansiBlue,
      magenta: t.ansiMagenta,
      cyan: t.ansiCyan,
      white: t.ansiWhite,
      brightBlack: t.ansiBrightBlack,
      brightRed: t.ansiBrightRed,
      brightGreen: t.ansiBrightGreen,
      brightYellow: t.ansiBrightYellow,
      brightBlue: t.ansiBrightBlue,
      brightMagenta: t.ansiBrightMagenta,
      brightCyan: t.ansiBrightCyan,
      brightWhite: t.ansiBrightWhite,
      searchHitBackground: t.searchHitBackground,
      searchHitBackgroundCurrent: t.searchHitBackgroundCurrent,
      searchHitForeground: t.searchHitForeground,
    );

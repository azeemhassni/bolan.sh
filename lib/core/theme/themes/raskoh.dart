import 'dart:ui';

import '../bolan_theme.dart';

const raskohTheme = BolonTheme(
  name: 'raskoh',
  displayName: 'Raskoh',
  brightness: Brightness.dark,
  isBuiltIn: true,

  // Window
  background: Color(0xFF253238),
  tabBarBackground: Color(0xFF1C272C),
  statusBarBackground: Color(0xFF1A2328),
  promptBackground: Color(0xFF2C3B42),

  // Blocks
  blockBackground: Color(0xFF2C3B42),
  blockBorder: Color(0xFF3D5058),
  blockHeaderFg: Color(0xFFEEFFE3),
  exitSuccessFg: Color(0xFFBDE18A),
  exitFailureFg: Color(0xFFDC322F),

  // Status chips
  statusChipBg: Color(0xFF34464E),
  statusCwdFg: Color(0xFF268BD2),
  statusGitFg: Color(0xFFC792E9),
  statusShellFg: Color(0xFFBDE18A),
  dimForeground: Color(0xFF657B83),

  // Terminal
  foreground: Color(0xFFEEFFE3),
  cursor: Color(0xFF82AAFF),
  selectionColor: Color(0x4082AAFF),

  // Search
  searchHitBackground: Color(0xFFC3E88D),
  searchHitBackgroundCurrent: Color(0xFF82AAFF),
  searchHitForeground: Color(0xFF253238),

  // ANSI
  ansiBlack: Color(0xFF253238),
  ansiRed: Color(0xFFDC322F),
  ansiGreen: Color(0xFFBDE18A),
  ansiYellow: Color(0xFFC3E88D),
  ansiBlue: Color(0xFF268BD2),
  ansiMagenta: Color(0xFFC792E9),
  ansiCyan: Color(0xFF2AA198),
  ansiWhite: Color(0xFFEEE8D5),
  ansiBrightBlack: Color(0xFF002B36),
  ansiBrightRed: Color(0xFFCB4B16),
  ansiBrightGreen: Color(0xFF586E75),
  ansiBrightYellow: Color(0xFF657B83),
  ansiBrightBlue: Color(0xFF839496),
  ansiBrightMagenta: Color(0xFF6C71C4),
  ansiBrightCyan: Color(0xFF93A1A1),
  ansiBrightWhite: Color(0xFFFDF6E3),
);

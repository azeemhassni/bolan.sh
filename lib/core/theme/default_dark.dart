import 'dart:ui';

import 'bolan_theme.dart';

/// The compiled-in default dark theme for Bolan.
const bolonDefaultDark = BolonTheme(
  name: 'default-dark',
  displayName: 'Default Dark',
  brightness: Brightness.dark,
  isBuiltIn: true,

  // Window
  background: Color(0xFF0D0E12),
  tabBarBackground: Color(0xFF0A0B0F),
  statusBarBackground: Color(0xFF12141A),
  promptBackground: Color(0xFF14161E),

  // Blocks
  blockBackground: Color(0xFF14161E),
  blockBorder: Color(0xFF262A3A),
  blockHeaderFg: Color(0xFFB4B9D2),
  exitSuccessFg: Color(0xFF50DC8C),
  exitFailureFg: Color(0xFFF05050),

  // Status chips
  statusChipBg: Color(0xFF1E2332),
  statusCwdFg: Color(0xFF78B4FF),
  statusGitFg: Color(0xFFAA82FF),
  statusShellFg: Color(0xFF64C8B4),
  dimForeground: Color(0xFF50556E),

  // Terminal text
  foreground: Color(0xFFDCE1F0),
  cursor: Color(0xFF78B4FF),
  selectionColor: Color(0x4050A0FF),

  // Search highlights
  searchHitBackground: Color(0xFF50A0FF),
  searchHitBackgroundCurrent: Color(0xFF78B4FF),
  searchHitForeground: Color(0xFF0D0E12),

  // ANSI 16 colors
  ansiBlack: Color(0xFF1E2028),
  ansiRed: Color(0xFFF05050),
  ansiGreen: Color(0xFF50DC8C),
  ansiYellow: Color(0xFFF0C850),
  ansiBlue: Color(0xFF5096F0),
  ansiMagenta: Color(0xFFB464F0),
  ansiCyan: Color(0xFF50D2DC),
  ansiWhite: Color(0xFFC8CDE0),
  ansiBrightBlack: Color(0xFF50556E),
  ansiBrightRed: Color(0xFFFF7878),
  ansiBrightGreen: Color(0xFF78F0AA),
  ansiBrightYellow: Color(0xFFFFDC78),
  ansiBrightBlue: Color(0xFF78B4FF),
  ansiBrightMagenta: Color(0xFFD28CFF),
  ansiBrightCyan: Color(0xFF78E6F0),
  ansiBrightWhite: Color(0xFFF0F2FF),
);

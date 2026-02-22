import 'dart:ui';

import '../bolan_theme.dart';

const raskohTheme = BolonTheme(
  name: 'raskoh',
  displayName: 'Raskoh',
  brightness: Brightness.dark,
  isBuiltIn: true,

  // Window — dark charcoal from background
  background: Color(0xFF2D3239),
  tabBarBackground: Color(0xFF262B31),
  statusBarBackground: Color(0xFF22272C),
  promptBackground: Color(0xFF323840),

  // Blocks
  blockBackground: Color(0xFF323840),
  blockBorder: Color(0xFF454D56),
  blockHeaderFg: Color(0xFFCDD3DA),
  exitSuccessFg: Color(0xFF8EBD6B),
  exitFailureFg: Color(0xFFCC6666),

  // Status chips
  statusChipBg: Color(0xFF3A4048),
  statusCwdFg: Color(0xFF6B9DC8),
  statusGitFg: Color(0xFFB294BB),
  statusShellFg: Color(0xFF8EBD6B),
  dimForeground: Color(0xFF6B7280),

  // Terminal
  foreground: Color(0xFFCDD3DA),
  cursor: Color(0xFFCDD3DA),
  selectionColor: Color(0x40556677),

  // Search
  searchHitBackground: Color(0xFFD1C078),
  searchHitBackgroundCurrent: Color(0xFF6B9DC8),
  searchHitForeground: Color(0xFF2D3239),

  // ANSI — from the color blocks in your screenshot
  ansiBlack: Color(0xFF2D3239),
  ansiRed: Color(0xFFCC6666),
  ansiGreen: Color(0xFF8EBD6B),
  ansiYellow: Color(0xFFD1C078),
  ansiBlue: Color(0xFF6B9DC8),
  ansiMagenta: Color(0xFFB294BB),
  ansiCyan: Color(0xFF7EBFB1),
  ansiWhite: Color(0xFFCDD3DA),
  ansiBrightBlack: Color(0xFF6B7280),
  ansiBrightRed: Color(0xFFDE8585),
  ansiBrightGreen: Color(0xFFA3D184),
  ansiBrightYellow: Color(0xFFE0D18E),
  ansiBrightBlue: Color(0xFF85B5D6),
  ansiBrightMagenta: Color(0xFFC9AACC),
  ansiBrightCyan: Color(0xFF96D0C4),
  ansiBrightWhite: Color(0xFFE8ECF0),
);

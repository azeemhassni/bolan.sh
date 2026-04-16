import 'dart:convert';
import 'dart:ui';

import '../ai_provider.dart';
import '../../theme/bolan_theme.dart';

/// Generates a complete [BolonTheme] from a natural-language description
/// using AI. Returns a theme ready for preview and save.
class ThemeGenerator {
  final AiProvider _provider;

  ThemeGenerator({required AiProvider provider}) : _provider = provider;

  Future<BolonTheme> generate(String description) async {
    final prompt = _buildPrompt(description);
    final response = await _provider.generateContent(prompt);
    return _parseResponse(response, description);
  }

  String _buildPrompt(String description) => '''
You are a terminal color theme designer. Generate a complete color theme for a dark terminal emulator based on this description: "$description"

Return ONLY a JSON object with these exact keys, all values as hex color strings (e.g. "#1A1B26"). No markdown, no explanation, no comments — just the JSON.

{
  "background": "#...",
  "tabBarBackground": "#... (slightly darker than background)",
  "statusBarBackground": "#... (slightly darker than tabBarBackground)",
  "promptBackground": "#... (slightly lighter than background)",
  "blockBackground": "#... (slightly lighter than background)",
  "blockBorder": "#... (subtle border, between background and foreground)",
  "blockHeaderFg": "#... (readable text on blockBackground)",
  "foreground": "#... (main text color, high contrast on background)",
  "dimForeground": "#... (muted text, ~50% between background and foreground)",
  "cursor": "#... (accent color, vibrant, matches the theme mood)",
  "selectionColor": "#... (cursor color at 40% opacity, as solid hex)",
  "exitSuccessFg": "#... (green-ish success indicator)",
  "exitFailureFg": "#... (red-ish failure indicator)",
  "statusChipBg": "#... (subtle bg for chips, between background and blockBackground)",
  "statusCwdFg": "#... (blue-ish, for current directory)",
  "statusGitFg": "#... (purple/magenta-ish, for git branch)",
  "statusShellFg": "#... (green-ish, for shell name)",
  "searchHitBackground": "#... (bright highlight for search matches)",
  "searchHitBackgroundCurrent": "#... (even brighter for current match)",
  "searchHitForeground": "#... (dark text on search highlight)",
  "ansiBlack": "#... (same as background)",
  "ansiRed": "#...",
  "ansiGreen": "#...",
  "ansiYellow": "#...",
  "ansiBlue": "#...",
  "ansiMagenta": "#...",
  "ansiCyan": "#...",
  "ansiWhite": "#...",
  "ansiBrightBlack": "#... (dimForeground equivalent)",
  "ansiBrightRed": "#...",
  "ansiBrightGreen": "#...",
  "ansiBrightYellow": "#...",
  "ansiBrightBlue": "#...",
  "ansiBrightMagenta": "#...",
  "ansiBrightCyan": "#...",
  "ansiBrightWhite": "#... (brightest white)"
}

Rules:
- Background must be dark (terminal themes are always dark)
- Foreground must have high contrast against background (WCAG AA minimum)
- ANSI colors must be distinct and readable on the background
- The theme should feel cohesive and match "$description"
- Return ONLY the JSON object, nothing else''';

  BolonTheme _parseResponse(String response, String description) {
    var json = response.trim();

    // Strip markdown code fences if present
    if (json.contains('```')) {
      final lines = json.split('\n');
      final inner = <String>[];
      var inFence = false;
      for (final line in lines) {
        if (line.trim().startsWith('```')) {
          inFence = !inFence;
          continue;
        }
        if (inFence) inner.add(line);
      }
      if (inner.isNotEmpty) json = inner.join('\n').trim();
    }

    final map = jsonDecode(json) as Map<String, dynamic>;

    Color hex(String key) {
      final raw = (map[key] as String).replaceFirst('#', '');
      final v = int.parse(raw, radix: 16);
      return Color(0xFF000000 | v);
    }

    final name = description
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return BolonTheme(
      name: 'ai-$name',
      displayName: description.length > 30
          ? '${description.substring(0, 30)}...'
          : description,
      brightness: Brightness.dark,
      isBuiltIn: false,
      background: hex('background'),
      tabBarBackground: hex('tabBarBackground'),
      statusBarBackground: hex('statusBarBackground'),
      promptBackground: hex('promptBackground'),
      blockBackground: hex('blockBackground'),
      blockBorder: hex('blockBorder'),
      blockHeaderFg: hex('blockHeaderFg'),
      foreground: hex('foreground'),
      dimForeground: hex('dimForeground'),
      cursor: hex('cursor'),
      selectionColor: hex('selectionColor'),
      exitSuccessFg: hex('exitSuccessFg'),
      exitFailureFg: hex('exitFailureFg'),
      statusChipBg: hex('statusChipBg'),
      statusCwdFg: hex('statusCwdFg'),
      statusGitFg: hex('statusGitFg'),
      statusShellFg: hex('statusShellFg'),
      searchHitBackground: hex('searchHitBackground'),
      searchHitBackgroundCurrent: hex('searchHitBackgroundCurrent'),
      searchHitForeground: hex('searchHitForeground'),
      ansiBlack: hex('ansiBlack'),
      ansiRed: hex('ansiRed'),
      ansiGreen: hex('ansiGreen'),
      ansiYellow: hex('ansiYellow'),
      ansiBlue: hex('ansiBlue'),
      ansiMagenta: hex('ansiMagenta'),
      ansiCyan: hex('ansiCyan'),
      ansiWhite: hex('ansiWhite'),
      ansiBrightBlack: hex('ansiBrightBlack'),
      ansiBrightRed: hex('ansiBrightRed'),
      ansiBrightGreen: hex('ansiBrightGreen'),
      ansiBrightYellow: hex('ansiBrightYellow'),
      ansiBrightBlue: hex('ansiBrightBlue'),
      ansiBrightMagenta: hex('ansiBrightMagenta'),
      ansiBrightCyan: hex('ansiBrightCyan'),
      ansiBrightWhite: hex('ansiBrightWhite'),
    );
  }
}

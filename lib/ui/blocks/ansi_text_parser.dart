import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Parses ANSI escape sequences in terminal output and produces
/// colored [TextSpan]s for rich text rendering.
///
/// Handles SGR (Select Graphic Rendition) codes for:
/// - Standard 8 colors (30-37 fg, 40-47 bg)
/// - Bright colors (90-97 fg, 100-107 bg)
/// - 256-color palette (38;5;N / 48;5;N)
/// - 24-bit true color (38;2;R;G;B / 48;2;R;G;B)
/// - Bold, dim, italic, underline, strikethrough
/// - Reset (0)
class AnsiTextParser {
  final BolonTheme theme;
  final bool ligatures;

  const AnsiTextParser(this.theme, {this.ligatures = false});

  /// Parses [input] containing ANSI escape sequences and returns
  /// a list of styled [TextSpan]s.
  List<TextSpan> parse(String input, {required TextStyle baseStyle}) {
    final spans = <TextSpan>[];
    var currentFg = baseStyle.color;
    var currentBg = baseStyle.backgroundColor;
    var bold = false;
    var dim = false;
    var italic = false;
    var underline = false;
    var strikethrough = false;

    // Match SGR sequences and text between them
    final re = RegExp(r'\x1B\[([0-9;]*)m');
    var lastEnd = 0;

    for (final match in re.allMatches(input)) {
      // Text before this escape sequence
      if (match.start > lastEnd) {
        final text = input.substring(lastEnd, match.start);
        if (text.isNotEmpty) {
          spans.add(TextSpan(
            text: text,
            style: _buildStyle(
              baseStyle, currentFg, currentBg,
              bold, dim, italic, underline, strikethrough,
            ),
          ));
        }
      }
      lastEnd = match.end;

      // Parse SGR parameters
      final params = match.group(1) ?? '0';
      final codes = params.isEmpty
          ? [0]
          : params.split(';').map((s) => int.tryParse(s) ?? 0).toList();

      for (var i = 0; i < codes.length; i++) {
        final code = codes[i];
        switch (code) {
          case 0: // Reset
            currentFg = baseStyle.color;
            currentBg = null;
            bold = false;
            dim = false;
            italic = false;
            underline = false;
            strikethrough = false;
          case 1:
            bold = true;
          case 2:
            dim = true;
          case 3:
            italic = true;
          case 4:
            underline = true;
          case 9:
            strikethrough = true;
          case 22:
            bold = false;
            dim = false;
          case 23:
            italic = false;
          case 24:
            underline = false;
          case 29:
            strikethrough = false;
          // Standard foreground colors
          case 30:
            currentFg = theme.ansiBlack;
          case 31:
            currentFg = theme.ansiRed;
          case 32:
            currentFg = theme.ansiGreen;
          case 33:
            currentFg = theme.ansiYellow;
          case 34:
            currentFg = theme.ansiBlue;
          case 35:
            currentFg = theme.ansiMagenta;
          case 36:
            currentFg = theme.ansiCyan;
          case 37:
            currentFg = theme.ansiWhite;
          case 39: // Default fg
            currentFg = baseStyle.color;
          // Standard background colors
          case 40:
            currentBg = theme.ansiBlack;
          case 41:
            currentBg = theme.ansiRed;
          case 42:
            currentBg = theme.ansiGreen;
          case 43:
            currentBg = theme.ansiYellow;
          case 44:
            currentBg = theme.ansiBlue;
          case 45:
            currentBg = theme.ansiMagenta;
          case 46:
            currentBg = theme.ansiCyan;
          case 47:
            currentBg = theme.ansiWhite;
          case 49: // Default bg
            currentBg = null;
          // Bright foreground colors
          case 90:
            currentFg = theme.ansiBrightBlack;
          case 91:
            currentFg = theme.ansiBrightRed;
          case 92:
            currentFg = theme.ansiBrightGreen;
          case 93:
            currentFg = theme.ansiBrightYellow;
          case 94:
            currentFg = theme.ansiBrightBlue;
          case 95:
            currentFg = theme.ansiBrightMagenta;
          case 96:
            currentFg = theme.ansiBrightCyan;
          case 97:
            currentFg = theme.ansiBrightWhite;
          // Bright background colors
          case 100:
            currentBg = theme.ansiBrightBlack;
          case 101:
            currentBg = theme.ansiBrightRed;
          case 102:
            currentBg = theme.ansiBrightGreen;
          case 103:
            currentBg = theme.ansiBrightYellow;
          case 104:
            currentBg = theme.ansiBrightBlue;
          case 105:
            currentBg = theme.ansiBrightMagenta;
          case 106:
            currentBg = theme.ansiBrightCyan;
          case 107:
            currentBg = theme.ansiBrightWhite;
          // 256-color and true color
          case 38: // Set fg
            final result = _parseExtendedColor(codes, i + 1);
            if (result != null) {
              currentFg = result.color;
              i = result.nextIndex - 1;
            }
          case 48: // Set bg
            final result = _parseExtendedColor(codes, i + 1);
            if (result != null) {
              currentBg = result.color;
              i = result.nextIndex - 1;
            }
        }
      }
    }

    // Remaining text after last escape sequence
    if (lastEnd < input.length) {
      final text = input.substring(lastEnd);
      if (text.isNotEmpty) {
        spans.add(TextSpan(
          text: text,
          style: _buildStyle(
            baseStyle, currentFg, currentBg,
            bold, dim, italic, underline, strikethrough,
          ),
        ));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: input, style: baseStyle));
    }

    return spans;
  }

  /// Strips non-SGR escape sequences (CSI, OSC, etc.) but preserves
  /// SGR color codes for the parser.
  static String stripNonSgrEscapes(String input) {
    return input.replaceAll(
      RegExp(
        r'\x1B\[[0-9;?]*[a-ln-zA-Z]'  // CSI sequences except 'm' (SGR)
        r'|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)'  // OSC
        r'|\x1B[()*/+][0-9A-Z%]?'  // Charset
        r'|\x1B[@-Z\\^_]',  // Single-char Fe
      ),
      '',
    );
  }

  TextStyle _buildStyle(
    TextStyle base,
    Color? fg,
    Color? bg,
    bool bold,
    bool dim,
    bool italic,
    bool underline,
    bool strikethrough,
  ) {
    var color = fg ?? base.color;
    if (dim && color != null) {
      color = color.withAlpha((color.a * 0.5 * 255).round());
    }

    return base.copyWith(
      color: color,
      backgroundColor: bg,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.combine([
        if (underline) TextDecoration.underline,
        if (strikethrough) TextDecoration.lineThrough,
      ]),
      fontFeatures: ligatures
          ? const [FontFeature.enable('liga'), FontFeature.enable('calt')]
          : const [FontFeature.disable('liga'), FontFeature.disable('calt')],
    );
  }

  _ExtendedColorResult? _parseExtendedColor(List<int> codes, int index) {
    if (index >= codes.length) return null;

    if (codes[index] == 5 && index + 1 < codes.length) {
      // 256-color: 38;5;N
      final color = _color256(codes[index + 1]);
      return _ExtendedColorResult(color, index + 2);
    }

    if (codes[index] == 2 && index + 3 < codes.length) {
      // True color: 38;2;R;G;B
      final color = Color.fromARGB(
        255,
        codes[index + 1].clamp(0, 255),
        codes[index + 2].clamp(0, 255),
        codes[index + 3].clamp(0, 255),
      );
      return _ExtendedColorResult(color, index + 4);
    }

    return null;
  }

  Color _color256(int index) {
    if (index < 0 || index > 255) return theme.foreground;

    // Standard 16 colors
    const standard = [
      0xFF000000, 0xFFAA0000, 0xFF00AA00, 0xFFAA5500,
      0xFF0000AA, 0xFFAA00AA, 0xFF00AAAA, 0xFFAAAAAA,
      0xFF555555, 0xFFFF5555, 0xFF55FF55, 0xFFFFFF55,
      0xFF5555FF, 0xFFFF55FF, 0xFF55FFFF, 0xFFFFFFFF,
    ];
    if (index < 16) return Color(standard[index]);

    // 216-color cube (indices 16-231)
    if (index < 232) {
      final i = index - 16;
      final r = (i ~/ 36) * 51;
      final g = ((i % 36) ~/ 6) * 51;
      final b = (i % 6) * 51;
      return Color.fromARGB(255, r, g, b);
    }

    // Grayscale (indices 232-255)
    final gray = (index - 232) * 10 + 8;
    return Color.fromARGB(255, gray, gray, gray);
  }
}

class _ExtendedColorResult {
  final Color color;
  final int nextIndex;

  _ExtendedColorResult(this.color, this.nextIndex);
}

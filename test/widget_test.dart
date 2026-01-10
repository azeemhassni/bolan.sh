import 'package:bolan/core/theme/default_dark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BolonTheme', () {
    test('default dark theme has correct background color', () {
      expect(bolonDefaultDark.background.toARGB32(), 0xFF0D0E12);
    });

    test('default dark theme has all ANSI colors defined', () {
      // ignore: prefer_const_declarations
      final theme = bolonDefaultDark;
      // ignore: prefer_const_declarations
      final ansiColors = [
        theme.ansiBlack,
        theme.ansiRed,
        theme.ansiGreen,
        theme.ansiYellow,
        theme.ansiBlue,
        theme.ansiMagenta,
        theme.ansiCyan,
        theme.ansiWhite,
        theme.ansiBrightBlack,
        theme.ansiBrightRed,
        theme.ansiBrightGreen,
        theme.ansiBrightYellow,
        theme.ansiBrightBlue,
        theme.ansiBrightMagenta,
        theme.ansiBrightCyan,
        theme.ansiBrightWhite,
      ];
      expect(ansiColors.length, 16);
      for (final color in ansiColors) {
        expect(color.a, greaterThan(0));
      }
    });

    test('default dark theme foreground is light', () {
      expect(
        bolonDefaultDark.foreground.toARGB32(),
        0xFFDCE1F0,
      );
    });
  });
}

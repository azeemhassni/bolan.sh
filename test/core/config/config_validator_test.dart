import 'package:bolan/core/config/config_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ConfigValidator();

  group('ConfigValidator', () {
    test('returns defaults for empty map', () {
      final config = validator.validate({});
      expect(config.activeTheme, 'default-dark');
      expect(config.editor.fontSize, 13.0);
      expect(config.editor.fontFamily, 'Operator Mono');
      expect(config.editor.cursorStyle, 'block');
      expect(config.ai.provider, 'ollama');
      expect(config.ai.enabled, false);
    });

    test('parses valid editor config', () {
      final config = validator.validate({
        'editor': {
          'font_size': 16.0,
          'font_family': 'Fira Code',
          'cursor_style': 'bar',
          'scrollback_lines': 5000,
        },
      });
      expect(config.editor.fontSize, 16.0);
      expect(config.editor.fontFamily, 'Fira Code');
      expect(config.editor.cursorStyle, 'bar');
      expect(config.editor.scrollbackLines, 5000);
    });

    test('clamps font size to valid range', () {
      final tooSmall = validator.validate({
        'editor': {'font_size': 2.0},
      });
      expect(tooSmall.editor.fontSize, 8.0);

      final tooLarge = validator.validate({
        'editor': {'font_size': 100.0},
      });
      expect(tooLarge.editor.fontSize, 32.0);
    });

    test('rejects invalid cursor style', () {
      final config = validator.validate({
        'editor': {'cursor_style': 'rainbow'},
      });
      expect(config.editor.cursorStyle, 'block');
    });

    test('rejects invalid AI provider', () {
      final config = validator.validate({
        'ai': {'provider': 'skynet'},
      });
      expect(config.ai.provider, 'ollama');
    });

    test('handles wrong types gracefully', () {
      final config = validator.validate({
        'editor': {
          'font_size': 'not a number',
          'cursor_blink': 'yes',
        },
      });
      expect(config.editor.fontSize, 13.0);
      expect(config.editor.cursorBlink, true);
    });
  });
}

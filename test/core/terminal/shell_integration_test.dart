import 'package:bolan/core/terminal/shell_integration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseOsc133', () {
    test('parses PromptStart (A)', () {
      final event = parseOsc133(['A']);
      expect(event, isA<PromptStart>());
    });

    test('parses PromptEnd (B)', () {
      final event = parseOsc133(['B']);
      expect(event, isA<PromptEnd>());
    });

    test('parses CommandStart (C) with command text', () {
      final event = parseOsc133(['C', 'ls -la']);
      expect(event, isA<CommandStart>());
      expect((event! as CommandStart).command, 'ls -la');
    });

    test('parses CommandStart (C) without command text', () {
      final event = parseOsc133(['C']);
      expect(event, isA<CommandStart>());
      expect((event! as CommandStart).command, '');
    });

    test('parses CommandEnd (D) with exit code', () {
      final event = parseOsc133(['D', '0']);
      expect(event, isA<CommandEnd>());
      expect((event! as CommandEnd).exitCode, 0);
    });

    test('parses CommandEnd (D) with non-zero exit code', () {
      final event = parseOsc133(['D', '127']);
      expect(event, isA<CommandEnd>());
      expect((event! as CommandEnd).exitCode, 127);
    });

    test('parses CommandEnd (D) without exit code defaults to 0', () {
      final event = parseOsc133(['D']);
      expect(event, isA<CommandEnd>());
      expect((event! as CommandEnd).exitCode, 0);
    });

    test('returns null for empty args', () {
      expect(parseOsc133([]), isNull);
    });

    test('returns null for unknown sub-command', () {
      expect(parseOsc133(['X']), isNull);
    });
  });
}

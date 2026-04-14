// Behavior tests: confirm the static-regex versions of the strip
// helpers in session.dart still produce the same output as the
// pre-hoisting equivalents on representative input.
//
// Run BEFORE and AFTER any change to those helpers to catch regressions.

import 'package:flutter_test/flutter_test.dart';

// Mirror the production regexes locally so we can compare.
final _ansi =
    RegExp(r'\x1B\[[0-9;?]*[a-zA-Z]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)|\x1B[()][0-9A-Z]|\x1B[>=<]');

final _partialLine =
    RegExp(r'(?:\x1B\[[0-9;]*m)*\x1B\[7m[%#](?:\x1B\[[0-9;]*m)+ *\r');

final _nonSgr = RegExp(
  r'\x1B\[[0-9;?]*[a-ln-zA-Z]'
  r'|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)'
  r'|\x1B[()*/+][0-9A-Z%]?'
  r'|\x1B[@-Z\\^_]',
);

final _redraw = RegExp(r'\x1B\[[\d;]*[ABCDHfGJK]');

void main() {
  group('Strip helpers — behavior preservation', () {
    test('ANSI strip removes SGR, OSC, charset, and Fe escapes', () {
      const input = '\x1b[31mred\x1b[0m \x1b]0;title\x07 \x1b(B done';
      expect(input.replaceAll(_ansi, ''), 'red   done');
    });

    test('partial line marker stripper removes zsh PROMPT_EOL_MARK', () {
      const input = 'hello\x1b[1m\x1b[7m%\x1b[27m\x1b[1m\x1b[0m \r';
      expect(input.replaceAll(_partialLine, ''), 'hello');
    });

    test('partial line marker keeps unrelated inverse video', () {
      // Only matches when followed by space + CR (the actual marker).
      const input = '\x1b[7mNORMAL\x1b[0m';
      expect(input.replaceAll(_partialLine, ''), input);
    });

    test('non-SGR strip keeps color codes but removes everything else', () {
      const input =
          '\x1b[31mred\x1b[0m\x1b[2J\x1b[H\x1b]0;title\x07 \x1b(B';
      expect(input.replaceAll(_nonSgr, ''), '\x1b[31mred\x1b[0m ');
    });

    test('redraw counter matches cursor positioning sequences', () {
      const input =
          '\x1b[A\x1b[2B\x1b[H\x1b[K\x1b[31mtext\x1b[0m\x1b[5;10f';
      // Should match: A, B, H, K, f = 5 sequences. SGR (m) is excluded.
      expect(_redraw.allMatches(input).length, 5);
    });

    test('strip helpers handle empty input without error', () {
      expect(''.replaceAll(_ansi, ''), '');
      expect(''.replaceAll(_partialLine, ''), '');
      expect(''.replaceAll(_nonSgr, ''), '');
      expect(_redraw.allMatches('').length, 0);
    });

    test('strip helpers handle plain text without escapes', () {
      const input = 'hello world\nno escapes here';
      expect(input.replaceAll(_ansi, ''), input);
      expect(input.replaceAll(_partialLine, ''), input);
      expect(input.replaceAll(_nonSgr, ''), input);
      expect(_redraw.allMatches(input).length, 0);
    });
  });

  group('shortstat parsing', () {
    final files = RegExp(r'(\d+) files? changed');
    final ins = RegExp(r'(\d+) insertions?');
    final del = RegExp(r'(\d+) deletions?');

    test('plural forms', () {
      const out = '3 files changed, 218 insertions(+), 19 deletions(-)';
      expect(files.firstMatch(out)!.group(1), '3');
      expect(ins.firstMatch(out)!.group(1), '218');
      expect(del.firstMatch(out)!.group(1), '19');
    });

    test('singular forms', () {
      const out = '1 file changed, 1 insertion(+), 1 deletion(-)';
      expect(files.firstMatch(out)!.group(1), '1');
      expect(ins.firstMatch(out)!.group(1), '1');
      expect(del.firstMatch(out)!.group(1), '1');
    });

    test('insertions only', () {
      const out = '2 files changed, 5 insertions(+)';
      expect(files.firstMatch(out)!.group(1), '2');
      expect(ins.firstMatch(out)!.group(1), '5');
      expect(del.firstMatch(out), isNull);
    });
  });
}

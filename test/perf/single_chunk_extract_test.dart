// Behavior test for the single-chunk OSC 133 lifecycle extractor.
// Mirrors the helper in session.dart so we can verify the slicing
// logic without spinning up a full PTY.

import 'package:flutter_test/flutter_test.dart';

String? extractSingleChunkOutput(String chunk) {
  final cIdx = chunk.indexOf('\x1b]133;C');
  if (cIdx < 0) return null;
  final cBel = chunk.indexOf('\x07', cIdx);
  if (cBel < 0) return null;
  final outputStart = cBel + 1;
  final dIdx = chunk.indexOf('\x1b]133;D', outputStart);
  if (dIdx < outputStart) return null;
  return chunk.substring(outputStart, dIdx);
}

void main() {
  group('single-chunk output extractor', () {
    test('extracts output between C and D markers in same chunk', () {
      const chunk =
          '\x1b]133;C;pwd\x07/Users/azeemhassni\n\x1b]133;D;0\x07';
      expect(extractSingleChunkOutput(chunk), '/Users/azeemhassni\n');
    });

    test('handles C marker without command argument', () {
      const chunk =
          '\x1b]133;C\x07hello\n\x1b]133;D;0\x07';
      expect(extractSingleChunkOutput(chunk), 'hello\n');
    });

    test('handles preamble and trailer around the lifecycle', () {
      const chunk =
          'PROMPT\x1b]133;A\x07\x1b]133;B\x07\x1b]133;C;ls\x07'
          'a.txt b.txt\n\x1b]133;D;0\x07'
          '\x1b]133;A\x07\$ ';
      expect(extractSingleChunkOutput(chunk), 'a.txt b.txt\n');
    });

    test('returns null when only C marker is present (multi-chunk case)', () {
      const chunk = '\x1b]133;C;long\x07partial output...';
      expect(extractSingleChunkOutput(chunk), isNull);
    });

    test('returns null when no markers present', () {
      const chunk = 'plain output\n';
      expect(extractSingleChunkOutput(chunk), isNull);
    });

    test('returns null when only D marker is present', () {
      const chunk = 'tail of output\n\x1b]133;D;0\x07';
      expect(extractSingleChunkOutput(chunk), isNull);
    });

    test('returns empty string for command with no output', () {
      const chunk = '\x1b]133;C;true\x07\x1b]133;D;0\x07';
      expect(extractSingleChunkOutput(chunk), '');
    });

    test('handles multi-line output', () {
      const chunk =
          '\x1b]133;C;echo\x07line1\nline2\nline3\n\x1b]133;D;0\x07';
      expect(extractSingleChunkOutput(chunk), 'line1\nline2\nline3\n');
    });

    test('preserves ANSI codes inside the captured slice', () {
      const chunk =
          '\x1b]133;C;ls\x07\x1b[34mfile.txt\x1b[0m\n\x1b]133;D;0\x07';
      expect(extractSingleChunkOutput(chunk),
          '\x1b[34mfile.txt\x1b[0m\n');
    });
  });
}

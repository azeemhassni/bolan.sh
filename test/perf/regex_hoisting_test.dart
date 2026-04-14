import 'package:flutter_test/flutter_test.dart';

/// Microbench: confirm that hoisting regexes to static finals
/// actually saves time vs allocating a fresh RegExp on every call.
///
/// This isn't a unit test of correctness — it's a sanity check that
/// the hoisting pattern saves measurable time. If this regresses,
/// the production hot paths using these patterns regress too.
void main() {
  // A typical PTY chunk with several SGR + cursor sequences.
  const sample =
      '\x1b[?25l\x1b[2J\x1b[H\x1b[38;2;200;100;50m hello \x1b[0m'
      '\x1b[1;1H\x1b[K\x1b[38;2;100;200;50m world \x1b[0m'
      '\x1b[2;1H\x1b[7m%\x1b[27m\x1b[1m\x1b[0m \r'
      '\x1b]133;C;ls\x07\nfile1\nfile2\nfile3\n\x1b]133;D;0\x07';
  const iterations = 5000;

  test('hoisted regex is faster than per-call allocation', () {
    final hoistedRe = RegExp(r'\x1B\[[\d;]*[ABCDHfGJK]');

    // Per-call allocation (the old pattern)
    final swPerCall = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      RegExp(r'\x1B\[[\d;]*[ABCDHfGJK]').allMatches(sample).length;
    }
    swPerCall.stop();

    // Hoisted (the new pattern)
    final swHoisted = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      hoistedRe.allMatches(sample).length;
    }
    swHoisted.stop();

    // ignore: avoid_print
    print('  per-call: ${swPerCall.elapsedMicroseconds}us');
    // ignore: avoid_print
    print('  hoisted:  ${swHoisted.elapsedMicroseconds}us');
    // ignore: avoid_print
    print('  speedup:  ${(swPerCall.elapsedMicroseconds / swHoisted.elapsedMicroseconds).toStringAsFixed(2)}x');

    // Hoisted should be at least 1.5x faster — typically 3-10x.
    expect(swHoisted.elapsedMicroseconds * 3 / 2,
        lessThan(swPerCall.elapsedMicroseconds),
        reason: 'Hoisted regex should be at least 1.5x faster');
  });
}

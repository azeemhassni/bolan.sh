import 'package:bolan/core/terminal/path_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathDetector', () {
    test('detects absolute paths', () {
      final matches = PathDetector.detectPaths('Error in /usr/local/bin/foo');
      expect(matches.length, 1);
      expect(matches[0].path, '/usr/local/bin/foo');
    });

    test('detects home-relative paths', () {
      final matches = PathDetector.detectPaths('Config at ~/.config/bolan/config.toml');
      expect(matches.length, 1);
      expect(matches[0].path, '~/.config/bolan/config.toml');
    });

    test('detects relative paths with extensions', () {
      final matches = PathDetector.detectPaths('See lib/main.dart for details');
      expect(matches.length, 1);
      expect(matches[0].path, 'lib/main.dart');
    });

    test('detects ./relative paths', () {
      final matches = PathDetector.detectPaths('Run ./build/output.js');
      expect(matches.length, 1);
      expect(matches[0].path, './build/output.js');
    });

    test('detects ../parent paths', () {
      final matches = PathDetector.detectPaths('See ../src/index.ts');
      expect(matches.length, 1);
      expect(matches[0].path, '../src/index.ts');
    });

    test('detects paths with line numbers', () {
      final matches = PathDetector.detectPaths('Error at lib/main.dart:42');
      expect(matches.length, 1);
      expect(matches[0].path, 'lib/main.dart');
      expect(matches[0].line, 42);
    });

    test('detects paths with line and column', () {
      final matches = PathDetector.detectPaths('src/app.ts:10:5: error');
      expect(matches.length, 1);
      expect(matches[0].path, 'src/app.ts');
      expect(matches[0].line, 10);
      expect(matches[0].column, 5);
    });

    test('does not match URLs', () {
      final matches =
          PathDetector.detectPaths('Visit https://github.com/foo/bar');
      // Should not pick up the github.com/foo/bar part as a path
      expect(matches, isEmpty);
    });

    test('detects multiple paths in one line', () {
      final matches = PathDetector.detectPaths(
          'Copy /src/a.txt to /dst/b.txt');
      expect(matches.length, 2);
    });

    test('skips very short paths', () {
      // A bare "/" or "./" shouldn't match
      final matches = PathDetector.detectPaths('use / for root');
      expect(matches, isEmpty);
    });

    test('handles paths with dots and hyphens', () {
      final matches = PathDetector.detectPaths(
          'File: /home/user/.my-config/settings.json');
      expect(matches.length, 1);
      expect(matches[0].path, '/home/user/.my-config/settings.json');
    });
  });
}

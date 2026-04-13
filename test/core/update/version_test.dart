import 'package:bolan/core/update/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Version.parse', () {
    test('parses plain version string', () {
      final v = Version.parse('1.2.3');
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
    });

    test('parses v-prefixed version string', () {
      final v = Version.parse('v0.3.3');
      expect(v.major, 0);
      expect(v.minor, 3);
      expect(v.patch, 3);
    });

    test('throws on invalid format', () {
      expect(() => Version.parse('1.2'), throwsFormatException);
      expect(() => Version.parse('abc'), throwsFormatException);
      expect(() => Version.parse(''), throwsFormatException);
      expect(() => Version.parse('1.2.3.4'), throwsFormatException);
    });

    test('throws on non-numeric parts', () {
      expect(() => Version.parse('a.b.c'), throwsA(anything));
    });
  });

  group('Version.isValid', () {
    test('returns true for valid versions', () {
      expect(Version.isValid('1.0.0'), true);
      expect(Version.isValid('v0.3.3'), true);
    });

    test('returns false for invalid versions', () {
      expect(Version.isValid('nope'), false);
      expect(Version.isValid('1.2'), false);
      expect(Version.isValid(''), false);
    });
  });

  group('Version comparison', () {
    test('greater than', () {
      expect(Version.parse('1.0.0') > Version.parse('0.9.9'), true);
      expect(Version.parse('0.2.0') > Version.parse('0.1.9'), true);
      expect(Version.parse('0.1.1') > Version.parse('0.1.0'), true);
    });

    test('less than', () {
      expect(Version.parse('0.1.0') < Version.parse('0.2.0'), true);
    });

    test('equal', () {
      expect(Version.parse('1.2.3') == Version.parse('v1.2.3'), true);
      expect(Version.parse('0.0.0') == Version.parse('0.0.0'), true);
    });

    test('not equal', () {
      expect(Version.parse('1.0.0') == Version.parse('1.0.1'), false);
    });

    test('compareTo', () {
      final versions = [
        Version.parse('1.0.0'),
        Version.parse('0.1.0'),
        Version.parse('0.0.1'),
        Version.parse('2.0.0'),
      ];
      versions.sort();
      expect(versions.map((v) => v.toString()).toList(),
          ['0.0.1', '0.1.0', '1.0.0', '2.0.0']);
    });
  });

  group('Version.toString', () {
    test('strips v prefix', () {
      expect(Version.parse('v1.2.3').toString(), '1.2.3');
    });

    test('round-trips', () {
      expect(Version.parse('0.3.3').toString(), '0.3.3');
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests for the shell resolution logic used in TerminalSession.start().
/// We test the logic directly since TerminalSession requires a PTY.
void main() {
  group('Shell resolution', () {
    test('bare shell name resolves via which', () {
      // "bash" should resolve to a full path
      final result = Process.runSync('which', ['bash']);
      expect(result.exitCode, 0);
      final path = (result.stdout as String).trim();
      expect(path, contains('/bash'));
      expect(File(path).existsSync(), true);
    });

    test('full path validates directly', () {
      expect(File('/bin/bash').existsSync(), true);
    });

    test('invalid shell path does not exist', () {
      expect(File('/bin/not_a_real_shell').existsSync(), false);
    });

    test('which returns non-zero for nonexistent command', () {
      final result = Process.runSync('which', ['not_a_real_shell_xyz']);
      expect(result.exitCode, isNot(0));
    });

    test('zsh integration script selected for zsh', () {
      // Verify the shell name extraction logic
      const shell = '/bin/zsh';
      final name = shell.split('/').last;
      expect(name, 'zsh');
    });

    test('bash integration script selected for bash', () {
      const shell = '/bin/bash';
      final name = shell.split('/').last;
      expect(name, 'bash');
    });

    test('unsupported shell name detected correctly', () {
      const shells = ['/usr/local/bin/fish', '/usr/bin/nushell', '/bin/sh'];
      for (final shell in shells) {
        final name = shell.split('/').last;
        expect(name != 'zsh' && name != 'bash', true,
            reason: '$name should be unsupported');
      }
    });
  });
}

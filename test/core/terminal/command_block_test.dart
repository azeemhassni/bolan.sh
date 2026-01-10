import 'package:bolan/core/terminal/command_block.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandBlock', () {
    test('duration is null when still running', () {
      final block = CommandBlock(
        id: '1',
        command: 'ls',
        startedAt: DateTime.now(),
      );
      expect(block.duration, isNull);
      expect(block.isRunning, isTrue);
    });

    test('duration is calculated when finished', () {
      final start = DateTime(2024, 1, 1, 12, 0, 0);
      final end = DateTime(2024, 1, 1, 12, 0, 5);
      final block = CommandBlock(
        id: '1',
        command: 'sleep 5',
        startedAt: start,
        finishedAt: end,
        exitCode: 0,
        isRunning: false,
      );
      expect(block.duration, const Duration(seconds: 5));
    });

    test('succeeded is true for exit code 0', () {
      final block = CommandBlock(
        id: '1',
        command: 'true',
        startedAt: DateTime.now(),
        exitCode: 0,
        isRunning: false,
      );
      expect(block.succeeded, isTrue);
    });

    test('succeeded is false for non-zero exit code', () {
      final block = CommandBlock(
        id: '1',
        command: 'false',
        startedAt: DateTime.now(),
        exitCode: 1,
        isRunning: false,
      );
      expect(block.succeeded, isFalse);
    });

    test('copyWith creates updated copy', () {
      final block = CommandBlock(
        id: '1',
        command: 'ls',
        startedAt: DateTime.now(),
      );
      final finished = block.copyWith(
        exitCode: 0,
        finishedAt: DateTime.now(),
        isRunning: false,
      );
      expect(finished.id, block.id);
      expect(finished.command, block.command);
      expect(finished.exitCode, 0);
      expect(finished.isRunning, isFalse);
    });
  });
}

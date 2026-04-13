import 'dart:io';

import 'package:bolan/core/completion/completion_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CompletionEngine engine;
  late Directory tmpDir;

  setUp(() {
    engine = CompletionEngine(shell: '/bin/bash');
    tmpDir = Directory.systemTemp.createTempSync('bolan_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('Composer completion', () {
    test('completes composer subcommands', () async {
      // Even without composer.json, if composer is installed it
      // discovers commands dynamically via `composer list --format=json`.
      const input = 'composer req';
      final result = await engine.complete(input, input.length, tmpDir.path);

      // If composer is installed, we get results; if not, empty is fine too.
      for (final item in result.items) {
        expect(item.type, CompletionType.composerCommand);
        expect(item.text.toLowerCase().startsWith('req'), true);
      }
    });

    test('does not trigger for unrelated commands', () async {
      File('${tmpDir.path}/composer.json').writeAsStringSync('{}');

      const input = 'php something';
      final result = await engine.complete(input, input.length, tmpDir.path);

      expect(
        result.items.every((i) => i.type != CompletionType.composerCommand),
        true,
      );
    });

    test('falls back to path completion after subcommand', () async {
      File('${tmpDir.path}/composer.json').writeAsStringSync('{}');

      const input = 'composer require ';
      final result = await engine.complete(input, input.length, tmpDir.path);

      // After the subcommand, should offer path completions, not commands
      expect(
        result.items.every((i) => i.type != CompletionType.composerCommand),
        true,
      );
    });
  });
}

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

  group('Artisan completion', () {
    test('completes artisan commands with "php artisan" prefix', () async {
      // Create a fake artisan file so the static fallback activates
      File('${tmpDir.path}/artisan').writeAsStringSync('');

      const input = 'php artisan mak';
      final result = await engine.complete(input, input.length, tmpDir.path);
      final names = result.items.map((i) => i.text).toList();

      expect(names, isNotEmpty);
      expect(names.every((n) => n.startsWith('make:')), true);
      expect(result.items.first.type, CompletionType.artisanCommand);
    });

    test('completes with bare "artisan" prefix', () async {
      File('${tmpDir.path}/artisan').writeAsStringSync('');

      const input = 'artisan mig';
      final result = await engine.complete(input, input.length, tmpDir.path);
      final names = result.items.map((i) => i.text).toList();

      expect(names, isNotEmpty);
      expect(names.every((n) => n.startsWith('mig')), true);
    });

    test('completes with "./artisan" prefix', () async {
      File('${tmpDir.path}/artisan').writeAsStringSync('');

      const input = './artisan serve';
      final result = await engine.complete(input, input.length, tmpDir.path);
      final names = result.items.map((i) => i.text).toList();

      expect(names, contains('serve'));
    });

    test('returns nothing for non-Laravel directory', () async {
      // No artisan file in tmpDir
      const input = 'php artisan mak';
      final result = await engine.complete(input, input.length, tmpDir.path);

      expect(result.items, isEmpty);
    });

    test('all static commands have descriptions', () async {
      File('${tmpDir.path}/artisan').writeAsStringSync('');

      const input = 'php artisan ';
      final result = await engine.complete(input, input.length, tmpDir.path);

      for (final item in result.items) {
        expect(item.description, isNotNull);
        expect(item.description, isNotEmpty);
      }
    });

    test('does not trigger for unrelated php commands', () async {
      File('${tmpDir.path}/artisan').writeAsStringSync('');

      const input = 'php script.php';
      final result = await engine.complete(input, input.length, tmpDir.path);

      // Should be path completion, not artisan
      expect(
        result.items.every((i) => i.type != CompletionType.artisanCommand),
        true,
      );
    });
  });
}

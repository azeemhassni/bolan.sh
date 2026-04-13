import 'package:bolan/core/completion/completion_engine.dart';
import 'package:bolan/core/completion/tool_completer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSymfonyConsoleJson', () {
    test('parses valid Symfony Console JSON', () {
      const json = '''
{
  "commands": [
    {"name": "require", "description": "Adds packages to composer.json"},
    {"name": "update", "description": "Updates packages"},
    {"name": "install", "description": "Installs project dependencies"}
  ]
}''';
      final commands = parseSymfonyConsoleJson(json);

      expect(commands.length, 3);
      expect(commands[0].name, 'require');
      expect(commands[0].description, 'Adds packages to composer.json');
      expect(commands[1].name, 'update');
      expect(commands[2].name, 'install');
    });

    test('skips entries with empty names', () {
      const json = '{"commands": [{"name": "", "description": "empty"}]}';
      final commands = parseSymfonyConsoleJson(json);

      expect(commands, isEmpty);
    });

    test('handles missing description gracefully', () {
      const json = '{"commands": [{"name": "test"}]}';
      final commands = parseSymfonyConsoleJson(json);

      expect(commands.length, 1);
      expect(commands[0].name, 'test');
      expect(commands[0].description, '');
    });

    test('handles missing commands array', () {
      const json = '{}';
      final commands = parseSymfonyConsoleJson(json);

      expect(commands, isEmpty);
    });

    test('truncates long descriptions', () {
      final longDesc = 'x' * 100;
      final json = '{"commands": [{"name": "test", "description": "$longDesc"}]}';
      final commands = parseSymfonyConsoleJson(json);

      expect(commands[0].description!.length, 63); // 60 + "..."
      expect(commands[0].description!.endsWith('...'), true);
    });
  });

  group('parseLinePerCommand', () {
    test('parses name-only lines', () {
      const output = 'build\ntest\nrun\n';
      final commands = parseLinePerCommand(output);

      expect(commands.length, 3);
      expect(commands[0].name, 'build');
      expect(commands[0].description, isNull);
    });

    test('parses name + description lines', () {
      const output = 'build   Compile the project\ntest    Run tests\n';
      final commands = parseLinePerCommand(output);

      expect(commands.length, 2);
      expect(commands[0].name, 'build');
      expect(commands[0].description, 'Compile the project');
    });

    test('skips empty lines', () {
      const output = '\nbuild\n\ntest\n\n';
      final commands = parseLinePerCommand(output);

      expect(commands.length, 2);
    });

    test('handles mixed format', () {
      const output = 'build   Compile the project\nclean\n';
      final commands = parseLinePerCommand(output);

      expect(commands.length, 2);
      expect(commands[0].description, 'Compile the project');
      expect(commands[1].description, isNull);
    });
  });

  group('ToolCompleter.matches', () {
    test('matches registered names', () {
      const completer = ToolCompleter(
        names: ['composer', 'comp'],
        type: _dummyType,
        discover: _dummyDiscover,
      );

      expect(completer.matches(['composer', 'require']), true);
      expect(completer.matches(['comp', 'install']), true);
      expect(completer.matches(['npm', 'install']), false);
      expect(completer.matches([]), false);
    });
  });
}

// Test helpers — these are never called, just needed for ToolCompleter construction.
const _dummyType = CompletionType.toolCommand;
const _dummyDiscover = DiscoverCommand(
  executable: 'echo',
  args: ['{}'],
  parse: _dummyParse,
);
List<DiscoveredCommand> _dummyParse(String _) => [];

import 'package:bolan/core/config/config_validator.dart';
import 'package:bolan/core/config/keybinding.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyBinding.parse', () {
    test('parses simple binding', () {
      final b = KeyBinding.parse('meta+keyT');
      expect(b, isNotNull);
      expect(b!.meta, true);
      expect(b.ctrl, false);
      expect(b.shift, false);
      expect(b.alt, false);
      expect(b.key, LogicalKeyboardKey.keyT);
    });

    test('parses binding with multiple modifiers', () {
      final b = KeyBinding.parse('meta+shift+keyP');
      expect(b, isNotNull);
      expect(b!.meta, true);
      expect(b.shift, true);
      expect(b.ctrl, false);
      expect(b.key, LogicalKeyboardKey.keyP);
    });

    test('parses ctrl-only binding', () {
      final b = KeyBinding.parse('ctrl+digit1');
      expect(b, isNotNull);
      expect(b!.ctrl, true);
      expect(b.meta, false);
      expect(b.key, LogicalKeyboardKey.digit1);
    });

    test('parses all four modifiers', () {
      final b = KeyBinding.parse('meta+ctrl+shift+alt+keyA');
      expect(b, isNotNull);
      expect(b!.meta, true);
      expect(b.ctrl, true);
      expect(b.shift, true);
      expect(b.alt, true);
      expect(b.key, LogicalKeyboardKey.keyA);
    });

    test('returns null for empty string', () {
      expect(KeyBinding.parse(''), isNull);
    });

    test('returns null for unknown key', () {
      expect(KeyBinding.parse('meta+nonsenseKey'), isNull);
    });

    test('parses special keys', () {
      expect(KeyBinding.parse('ctrl+tab')!.key, LogicalKeyboardKey.tab);
      expect(KeyBinding.parse('arrowUp')!.key, LogicalKeyboardKey.arrowUp);
      expect(KeyBinding.parse('meta+comma')!.key, LogicalKeyboardKey.comma);
      expect(
          KeyBinding.parse('meta+backslash')!.key, LogicalKeyboardKey.backslash);
    });
  });

  group('KeyBinding.serialize', () {
    test('round-trips through parse', () {
      final original = KeyBinding(
        meta: true,
        shift: true,
        key: LogicalKeyboardKey.keyD,
      );
      final serialized = original.serialize();
      final parsed = KeyBinding.parse(serialized);
      expect(parsed, isNotNull);
      expect(parsed!.meta, original.meta);
      expect(parsed.shift, original.shift);
      expect(parsed.ctrl, original.ctrl);
      expect(parsed.alt, original.alt);
      expect(parsed.key, original.key);
    });

    test('serializes modifiers in stable order', () {
      final b = KeyBinding(
        meta: true,
        ctrl: true,
        shift: true,
        alt: true,
        key: LogicalKeyboardKey.keyA,
      );
      expect(b.serialize(), 'meta+ctrl+shift+alt+keyA');
    });

    test('omits unset modifiers', () {
      final b = KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyR);
      expect(b.serialize(), 'ctrl+keyR');
    });
  });

  group('KeyBinding.label', () {
    test('includes spaces between parts', () {
      final b = KeyBinding(
        meta: true,
        shift: true,
        key: LogicalKeyboardKey.keyP,
      );
      final label = b.label;
      expect(label.contains(' '), true);
    });

    test('no leading space', () {
      final b = KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyA);
      expect(b.label.startsWith(' '), false);
    });
  });

  group('KeyBinding.matches', () {
    test('matches exact modifier + key combo', () {
      final b = KeyBinding(meta: true, key: LogicalKeyboardKey.keyT);
      expect(
        b.matches(
          metaDown: true,
          ctrlDown: false,
          shiftDown: false,
          altDown: false,
          pressed: LogicalKeyboardKey.keyT,
        ),
        true,
      );
    });

    test('rejects extra modifier', () {
      final b = KeyBinding(meta: true, key: LogicalKeyboardKey.keyT);
      expect(
        b.matches(
          metaDown: true,
          ctrlDown: true,
          shiftDown: false,
          altDown: false,
          pressed: LogicalKeyboardKey.keyT,
        ),
        false,
      );
    });

    test('rejects wrong key', () {
      final b = KeyBinding(meta: true, key: LogicalKeyboardKey.keyT);
      expect(
        b.matches(
          metaDown: true,
          ctrlDown: false,
          shiftDown: false,
          altDown: false,
          pressed: LogicalKeyboardKey.keyW,
        ),
        false,
      );
    });

    test('rejects missing modifier', () {
      final b =
          KeyBinding(meta: true, shift: true, key: LogicalKeyboardKey.keyP);
      expect(
        b.matches(
          metaDown: true,
          ctrlDown: false,
          shiftDown: false,
          altDown: false,
          pressed: LogicalKeyboardKey.keyP,
        ),
        false,
      );
    });
  });

  group('KeyBinding equality', () {
    test('equal bindings are equal', () {
      final a = KeyBinding(meta: true, key: LogicalKeyboardKey.keyT);
      final b = KeyBinding(meta: true, key: LogicalKeyboardKey.keyT);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different bindings are not equal', () {
      final a = KeyBinding(meta: true, key: LogicalKeyboardKey.keyT);
      final b = KeyBinding(meta: true, key: LogicalKeyboardKey.keyW);
      expect(a, isNot(equals(b)));
    });
  });

  group('matchAction', () {
    test('finds action for default binding', () {
      final result = matchAction(
        metaDown: false,
        ctrlDown: true,
        shiftDown: false,
        altDown: false,
        pressed: LogicalKeyboardKey.keyR,
        overrides: {},
      );
      expect(result, KeyAction.historySearch);
    });

    test('override takes precedence over default', () {
      final overrides = {
        KeyAction.historySearch:
            KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyH),
      };
      // New binding should match.
      final newResult = matchAction(
        metaDown: false,
        ctrlDown: true,
        shiftDown: false,
        altDown: false,
        pressed: LogicalKeyboardKey.keyH,
        overrides: overrides,
      );
      expect(newResult, KeyAction.historySearch);
    });

    test('scope limits which actions are checked', () {
      final result = matchAction(
        metaDown: false,
        ctrlDown: true,
        shiftDown: false,
        altDown: false,
        pressed: LogicalKeyboardKey.keyR,
        overrides: {},
        scope: [KeyAction.zoomIn, KeyAction.zoomOut],
      );
      expect(result, isNull);
    });

    test('returns null when no action matches', () {
      final result = matchAction(
        metaDown: false,
        ctrlDown: false,
        shiftDown: false,
        altDown: false,
        pressed: LogicalKeyboardKey.f12,
        overrides: {},
      );
      expect(result, isNull);
    });
  });

  group('defaultKeyBindings', () {
    test('every KeyAction has a default', () {
      for (final action in KeyAction.values) {
        expect(defaultKeyBindings.containsKey(action), true,
            reason: '${action.name} missing default binding');
      }
    });

    test('all defaults round-trip through serialize/parse', () {
      for (final entry in defaultKeyBindings.entries) {
        final serialized = entry.value.serialize();
        final parsed = KeyBinding.parse(serialized);
        expect(parsed, isNotNull,
            reason: '${entry.key.name} failed to parse: $serialized');
        expect(parsed!.key, entry.value.key,
            reason: '${entry.key.name} key mismatch after round-trip');
        expect(parsed.meta, entry.value.meta);
        expect(parsed.ctrl, entry.value.ctrl);
        expect(parsed.shift, entry.value.shift);
        expect(parsed.alt, entry.value.alt);
      }
    });
  });

  group('KeyAction metadata', () {
    test('every action has a non-empty display name', () {
      for (final action in KeyAction.values) {
        expect(action.displayName.isNotEmpty, true);
      }
    });

    test('every action has a valid category', () {
      for (final action in KeyAction.values) {
        expect(
          ['Global', 'Workspaces', 'Prompt'].contains(action.category),
          true,
          reason: '${action.name} has unexpected category: ${action.category}',
        );
      }
    });
  });

  group('ConfigValidator keybindings', () {
    const validator = ConfigValidator();

    test('parses keybindings from config map', () {
      final config = validator.validate({
        'keybindings': {
          'newTab': 'meta+shift+keyN',
          'quit': 'ctrl+keyQ',
        },
      });
      expect(config.keybindingOverrides.length, 2);
      expect(config.keybindingOverrides[KeyAction.newTab]!.shift, true);
      expect(config.keybindingOverrides[KeyAction.newTab]!.meta, true);
      expect(config.keybindingOverrides[KeyAction.quit]!.ctrl, true);
    });

    test('ignores unknown action names', () {
      final config = validator.validate({
        'keybindings': {
          'fakeAction': 'meta+keyX',
          'quit': 'ctrl+keyQ',
        },
      });
      expect(config.keybindingOverrides.length, 1);
      expect(config.keybindingOverrides.containsKey(KeyAction.quit), true);
    });

    test('ignores unparseable bindings', () {
      final config = validator.validate({
        'keybindings': {
          'quit': 'meta+unknownKey99',
        },
      });
      expect(config.keybindingOverrides.isEmpty, true);
    });

    test('returns empty map when keybindings section is absent', () {
      final config = validator.validate({});
      expect(config.keybindingOverrides.isEmpty, true);
    });
  });
}

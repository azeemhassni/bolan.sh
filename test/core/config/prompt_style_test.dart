import 'package:bolan/core/config/config_validator.dart';
import 'package:bolan/core/config/prompt_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ConfigValidator();

  group('PromptStyleConfig presets', () {
    test('bolan is the default', () {
      const style = PromptStyleConfig();
      expect(style.preset, PromptPreset.bolan);
      expect(style.chipShape, ChipShape.roundedRect);
      expect(style.cornerRadius, 4);
      expect(style.borderWidth, 1);
      expect(style.chipSpacing, 6);
      expect(style.showBorder, true);
      expect(style.showIcons, true);
      expect(style.filledBackground, false);
    });

    test('powerline preset', () {
      const style = PromptStyleConfig.powerline();
      expect(style.preset, PromptPreset.powerline);
      expect(style.chipShape, ChipShape.trapezoid);
      expect(style.chipSpacing, 0);
      expect(style.separator, SeparatorKind.powerlineArrow);
      expect(style.filledBackground, true);
      expect(style.perSegmentColors, true);
      expect(style.showBorder, false);
    });

    test('starship preset', () {
      const style = PromptStyleConfig.starship();
      expect(style.preset, PromptPreset.starship);
      expect(style.chipShape, ChipShape.pill);
      expect(style.cornerRadius, 999);
      expect(style.chipSpacing, 8);
      expect(style.filledBackground, true);
      expect(style.showBorder, true);
    });

    test('minimal preset', () {
      const style = PromptStyleConfig.minimal();
      expect(style.preset, PromptPreset.minimal);
      expect(style.chipShape, ChipShape.none);
      expect(style.separator, SeparatorKind.character);
      expect(style.separatorChar, '│');
      expect(style.showIcons, false);
      expect(style.fontWeight, 'normal');
    });

    test('fromPreset factory returns correct preset', () {
      for (final p in PromptPreset.values) {
        final style = PromptStyleConfig.fromPreset(p);
        expect(style.preset, p);
      }
    });
  });

  group('PromptStyleConfig.copyWith', () {
    test('copies all fields', () {
      const original = PromptStyleConfig();
      final modified = original.copyWith(
        chipSpacing: 12,
        showIcons: false,
        preset: PromptPreset.custom,
      );
      expect(modified.chipSpacing, 12);
      expect(modified.showIcons, false);
      expect(modified.preset, PromptPreset.custom);
      // Unmodified fields stay the same.
      expect(modified.cornerRadius, original.cornerRadius);
      expect(modified.borderWidth, original.borderWidth);
    });
  });

  group('PromptStyleConfig equality', () {
    test('equal configs are equal', () {
      const a = PromptStyleConfig();
      const b = PromptStyleConfig();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different configs are not equal', () {
      const a = PromptStyleConfig();
      const b = PromptStyleConfig.powerline();
      expect(a, isNot(equals(b)));
    });
  });

  group('PromptStyleConfig.toMap', () {
    test('non-custom preset writes only preset name', () {
      const style = PromptStyleConfig.powerline();
      final map = style.toMap();
      expect(map['preset'], 'powerline');
      expect(map.length, 1);
    });

    test('custom preset writes all fields', () {
      final style = const PromptStyleConfig().copyWith(
        preset: PromptPreset.custom,
      );
      final map = style.toMap();
      expect(map['preset'], 'custom');
      expect(map.containsKey('chip_shape'), true);
      expect(map.containsKey('corner_radius'), true);
      expect(map.containsKey('show_icons'), true);
    });
  });

  group('ConfigValidator prompt_style', () {
    test('absent section returns bolan default', () {
      final config = validator.validate({
        'general': <String, dynamic>{},
      });
      expect(config.general.promptStyle.preset, PromptPreset.bolan);
    });

    test('parses preset name', () {
      final config = validator.validate({
        'general': {
          'prompt_style': {'preset': 'powerline'},
        },
      });
      expect(config.general.promptStyle.preset, PromptPreset.powerline);
      expect(config.general.promptStyle.chipShape, ChipShape.trapezoid);
    });

    test('parses custom with all fields', () {
      final config = validator.validate({
        'general': {
          'prompt_style': {
            'preset': 'custom',
            'chip_shape': 'pill',
            'corner_radius': 12.0,
            'border_width': 0.5,
            'chip_spacing': 10.0,
            'chip_padding_h': 8.0,
            'chip_padding_v': 4.0,
            'separator': 'character',
            'separator_char': '|',
            'filled_background': true,
            'per_segment_colors': false,
            'show_border': false,
            'show_icons': false,
            'font_weight': 'normal',
          },
        },
      });
      final ps = config.general.promptStyle;
      expect(ps.preset, PromptPreset.custom);
      expect(ps.chipShape, ChipShape.pill);
      expect(ps.cornerRadius, 12.0);
      expect(ps.borderWidth, 0.5);
      expect(ps.chipSpacing, 10.0);
      expect(ps.chipPaddingH, 8.0);
      expect(ps.chipPaddingV, 4.0);
      expect(ps.separator, SeparatorKind.character);
      expect(ps.separatorChar, '|');
      expect(ps.filledBackground, true);
      expect(ps.perSegmentColors, false);
      expect(ps.showBorder, false);
      expect(ps.showIcons, false);
      expect(ps.fontWeight, 'normal');
    });

    test('invalid preset falls back to bolan', () {
      final config = validator.validate({
        'general': {
          'prompt_style': {'preset': 'notreal'},
        },
      });
      expect(config.general.promptStyle.preset, PromptPreset.bolan);
    });

    test('custom with invalid chip_shape falls back to roundedRect', () {
      final config = validator.validate({
        'general': {
          'prompt_style': {
            'preset': 'custom',
            'chip_shape': 'hexagon',
          },
        },
      });
      expect(config.general.promptStyle.chipShape, ChipShape.roundedRect);
    });

    test('clamps corner_radius to valid range', () {
      final config = validator.validate({
        'general': {
          'prompt_style': {
            'preset': 'custom',
            'corner_radius': 2000.0,
          },
        },
      });
      expect(config.general.promptStyle.cornerRadius, 999);
    });
  });
}

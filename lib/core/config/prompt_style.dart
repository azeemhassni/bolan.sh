/// Prompt style presets and customization model.
///
/// Controls the visual chrome of status chips in the prompt area:
/// shape, spacing, separators, colors, and typography. Ships with
/// four presets (Bolan, Powerline, Starship, Minimal) and a custom
/// mode that exposes every parameter.

enum PromptPreset { bolan, powerline, starship, minimal, custom }

enum ChipShape { roundedRect, pill, trapezoid, none }

enum SeparatorKind { gap, powerlineArrow, character, none }

class PromptStyleConfig {
  final PromptPreset preset;
  final ChipShape chipShape;
  final double cornerRadius;
  final double borderWidth;
  final double chipSpacing;
  final double chipPaddingH;
  final double chipPaddingV;
  final SeparatorKind separator;
  final String separatorChar;
  final String separatorColorHex; // '' = use theme dimForeground
  final bool filledBackground;
  final bool perSegmentColors;
  final bool showBorder;
  final bool showIcons;
  final String fontWeight;

  const PromptStyleConfig({
    this.preset = PromptPreset.bolan,
    this.chipShape = ChipShape.roundedRect,
    this.cornerRadius = 4,
    this.borderWidth = 1,
    this.chipSpacing = 6,
    this.chipPaddingH = 4,
    this.chipPaddingV = 2,
    this.separator = SeparatorKind.gap,
    this.separatorChar = '',
    this.separatorColorHex = '',
    this.filledBackground = false,
    this.perSegmentColors = false,
    this.showBorder = true,
    this.showIcons = true,
    this.fontWeight = 'bold',
  });

  const PromptStyleConfig.powerline()
      : preset = PromptPreset.powerline,
        chipShape = ChipShape.trapezoid,
        cornerRadius = 0,
        borderWidth = 0,
        chipSpacing = 0,
        chipPaddingH = 6,
        chipPaddingV = 2,
        separator = SeparatorKind.powerlineArrow,
        separatorChar = '\uE0B0', //
        separatorColorHex = '',
        filledBackground = true,
        perSegmentColors = true,
        showBorder = false,
        showIcons = true,
        fontWeight = 'bold';

  const PromptStyleConfig.starship()
      : preset = PromptPreset.starship,
        chipShape = ChipShape.pill,
        cornerRadius = 999,
        borderWidth = 0.5,
        chipSpacing = 8,
        chipPaddingH = 8,
        chipPaddingV = 4,
        separator = SeparatorKind.gap,
        separatorChar = '',
        separatorColorHex = '',
        filledBackground = true,
        perSegmentColors = false,
        showBorder = true,
        showIcons = true,
        fontWeight = 'w500';

  const PromptStyleConfig.minimal()
      : preset = PromptPreset.minimal,
        chipShape = ChipShape.none,
        cornerRadius = 0,
        borderWidth = 0,
        chipSpacing = 0,
        chipPaddingH = 0,
        chipPaddingV = 0,
        separator = SeparatorKind.character,
        separatorChar = '│',
        separatorColorHex = '',
        filledBackground = false,
        perSegmentColors = false,
        showBorder = false,
        showIcons = false,
        fontWeight = 'normal';

  factory PromptStyleConfig.fromPreset(PromptPreset p) => switch (p) {
        PromptPreset.bolan => const PromptStyleConfig(),
        PromptPreset.powerline => const PromptStyleConfig.powerline(),
        PromptPreset.starship => const PromptStyleConfig.starship(),
        PromptPreset.minimal => const PromptStyleConfig.minimal(),
        PromptPreset.custom => const PromptStyleConfig(
            preset: PromptPreset.custom),
      };

  PromptStyleConfig copyWith({
    PromptPreset? preset,
    ChipShape? chipShape,
    double? cornerRadius,
    double? borderWidth,
    double? chipSpacing,
    double? chipPaddingH,
    double? chipPaddingV,
    SeparatorKind? separator,
    String? separatorChar,
    String? separatorColorHex,
    bool? filledBackground,
    bool? perSegmentColors,
    bool? showBorder,
    bool? showIcons,
    String? fontWeight,
  }) =>
      PromptStyleConfig(
        preset: preset ?? this.preset,
        chipShape: chipShape ?? this.chipShape,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        borderWidth: borderWidth ?? this.borderWidth,
        chipSpacing: chipSpacing ?? this.chipSpacing,
        chipPaddingH: chipPaddingH ?? this.chipPaddingH,
        chipPaddingV: chipPaddingV ?? this.chipPaddingV,
        separator: separator ?? this.separator,
        separatorChar: separatorChar ?? this.separatorChar,
        separatorColorHex: separatorColorHex ?? this.separatorColorHex,
        filledBackground: filledBackground ?? this.filledBackground,
        perSegmentColors: perSegmentColors ?? this.perSegmentColors,
        showBorder: showBorder ?? this.showBorder,
        showIcons: showIcons ?? this.showIcons,
        fontWeight: fontWeight ?? this.fontWeight,
      );

  /// Serialize to a TOML-friendly map.
  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{'preset': preset.name};
    if (preset != PromptPreset.custom) return m;
    m['chip_shape'] = chipShape.name;
    m['corner_radius'] = cornerRadius;
    m['border_width'] = borderWidth;
    m['chip_spacing'] = chipSpacing;
    m['chip_padding_h'] = chipPaddingH;
    m['chip_padding_v'] = chipPaddingV;
    m['separator'] = separator.name;
    if (separatorChar.isNotEmpty) m['separator_char'] = separatorChar;
    if (separatorColorHex.isNotEmpty) {
      m['separator_color'] = separatorColorHex;
    }
    m['filled_background'] = filledBackground;
    m['per_segment_colors'] = perSegmentColors;
    m['show_border'] = showBorder;
    m['show_icons'] = showIcons;
    m['font_weight'] = fontWeight;
    return m;
  }

  @override
  bool operator ==(Object other) =>
      other is PromptStyleConfig &&
      preset == other.preset &&
      chipShape == other.chipShape &&
      cornerRadius == other.cornerRadius &&
      borderWidth == other.borderWidth &&
      chipSpacing == other.chipSpacing &&
      chipPaddingH == other.chipPaddingH &&
      chipPaddingV == other.chipPaddingV &&
      separator == other.separator &&
      separatorChar == other.separatorChar &&
      separatorColorHex == other.separatorColorHex &&
      filledBackground == other.filledBackground &&
      perSegmentColors == other.perSegmentColors &&
      showBorder == other.showBorder &&
      showIcons == other.showIcons &&
      fontWeight == other.fontWeight;

  @override
  int get hashCode => Object.hash(
        preset,
        chipShape,
        cornerRadius,
        borderWidth,
        chipSpacing,
        chipPaddingH,
        chipPaddingV,
        separator,
        separatorChar,
        separatorColorHex,
        filledBackground,
        perSegmentColors,
        showBorder,
        showIcons,
        fontWeight,
      );
}

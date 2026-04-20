import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/prompt_style.dart';
import '../../core/theme/bolan_theme.dart';

/// Data for a single chip, extracted by PromptArea before rendering.
class ChipData {
  final String? text;
  final Widget? child;
  final Color fg;
  final Color bg;
  final IconData? icon;
  final String? svgIcon;

  const ChipData({
    this.text,
    this.child,
    required this.fg,
    required this.bg,
    this.icon,
    this.svgIcon,
  });
}

/// Strategy for rendering prompt chips according to a [PromptStyleConfig].
abstract class PromptChipRenderer {
  /// Wraps a list of rendered chip widgets in the style's layout.
  Widget buildLayout(List<Widget> chips);

  /// Wraps chip content in the style's chrome (container, border, etc.).
  Widget buildChip(ChipData data, double fontSize, BolonTheme theme);

  /// Factory that selects the right renderer for a given style.
  static PromptChipRenderer forStyle(PromptStyleConfig style) =>
      switch (style.preset) {
        PromptPreset.bolan => DefaultChipRenderer(style),
        PromptPreset.starship => StarshipChipRenderer(style),
        PromptPreset.minimal => MinimalChipRenderer(style),
        PromptPreset.powerline => PowerlineChipRenderer(style),
        PromptPreset.custom => _rendererForCustom(style),
      };

  static PromptChipRenderer _rendererForCustom(PromptStyleConfig style) {
    if (style.chipShape == ChipShape.trapezoid ||
        style.separator == SeparatorKind.powerlineArrow) {
      return PowerlineChipRenderer(style);
    }
    if (style.chipShape == ChipShape.none) {
      return MinimalChipRenderer(style);
    }
    return DefaultChipRenderer(style);
  }
}

/// Builds the icon + text content row shared by most renderers.
Widget buildChipContent({
  required ChipData data,
  required double fontSize,
  required BolonTheme theme,
  required FontWeight fontWeight,
  bool showIcon = true,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showIcon && data.svgIcon != null) ...[
        SvgPicture.asset(
          data.svgIcon!,
          width: fontSize,
          height: fontSize,
          colorFilter: ColorFilter.mode(data.fg, BlendMode.srcIn),
        ),
        const SizedBox(width: 5),
      ] else if (showIcon && data.icon != null) ...[
        Icon(data.icon, size: fontSize, color: data.fg),
        const SizedBox(width: 5),
      ],
      data.child ??
          Text(
            data.text ?? '',
            style: TextStyle(
              color: data.fg,
              fontSize: fontSize,
              fontFamily: theme.fontFamily,
              fontWeight: fontWeight,
              decoration: TextDecoration.none,
            ),
          ),
    ],
  );
}

FontWeight parseFontWeight(String w) => switch (w) {
      'normal' => FontWeight.normal,
      'w500' => FontWeight.w500,
      'bold' => FontWeight.w700,
      _ => FontWeight.w700,
    };

// ── Default (Bolan) renderer ──────────────────────────────────

class DefaultChipRenderer extends PromptChipRenderer {
  final PromptStyleConfig style;
  DefaultChipRenderer(this.style);

  @override
  Widget buildLayout(List<Widget> chips) {
    return Wrap(
      spacing: style.chipSpacing,
      runSpacing: style.chipSpacing,
      children: chips,
    );
  }

  @override
  Widget buildChip(ChipData data, double fontSize, BolonTheme theme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: style.chipPaddingH,
        vertical: style.chipPaddingV,
      ),
      decoration: BoxDecoration(
        color: style.filledBackground ? data.fg.withAlpha(25) : data.bg,
        borderRadius: BorderRadius.circular(style.cornerRadius),
        border: style.showBorder
            ? Border.all(
                color: data.fg.withAlpha(60),
                width: style.borderWidth,
              )
            : null,
      ),
      child: buildChipContent(
        data: data,
        fontSize: fontSize,
        theme: theme,
        fontWeight: parseFontWeight(style.fontWeight),
        showIcon: style.showIcons,
      ),
    );
  }
}

// ── Starship renderer ─────────────────────────────────────────

class StarshipChipRenderer extends PromptChipRenderer {
  final PromptStyleConfig style;
  StarshipChipRenderer(this.style);

  @override
  Widget buildLayout(List<Widget> chips) {
    return Wrap(
      spacing: style.chipSpacing,
      runSpacing: style.chipSpacing,
      children: chips,
    );
  }

  @override
  Widget buildChip(ChipData data, double fontSize, BolonTheme theme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: style.chipPaddingH,
        vertical: style.chipPaddingV,
      ),
      decoration: BoxDecoration(
        color: style.filledBackground
            ? data.fg.withAlpha(25)
            : data.bg,
        borderRadius: BorderRadius.circular(style.cornerRadius),
        border: style.showBorder
            ? Border.all(
                color: data.fg.withAlpha(40),
                width: style.borderWidth,
              )
            : null,
      ),
      child: buildChipContent(
        data: data,
        fontSize: fontSize,
        theme: theme,
        fontWeight: parseFontWeight(style.fontWeight),
        showIcon: style.showIcons,
      ),
    );
  }
}

// ── Minimal renderer ──────────────────────────────────────────

class MinimalChipRenderer extends PromptChipRenderer {
  final PromptStyleConfig style;
  MinimalChipRenderer(this.style);

  @override
  Widget buildLayout(List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final gap = style.chipSpacing > 0 ? style.chipSpacing : 6.0;
    final separated = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      separated.add(chips[i]);
      if (i < chips.length - 1) {
        if (style.separator == SeparatorKind.character &&
            style.separatorChar.isNotEmpty) {
          separated.add(_SeparatorText(
            char: style.separatorChar,
            colorHex: style.separatorColorHex,
            gap: gap,
          ));
        } else {
          separated.add(SizedBox(width: gap));
        }
      }
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: separated,
    );
  }

  @override
  Widget buildChip(ChipData data, double fontSize, BolonTheme theme) {
    return buildChipContent(
      data: data,
      fontSize: fontSize,
      theme: theme,
      fontWeight: parseFontWeight(style.fontWeight),
      showIcon: style.showIcons,
    );
  }
}

// ── Powerline renderer ────────────────────────────────────────

class PowerlineChipRenderer extends PromptChipRenderer {
  final PromptStyleConfig style;
  PowerlineChipRenderer(this.style);

  @override
  Widget buildLayout(List<Widget> chips) {
    // Powerline is inherently single-line; scroll on overflow.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: chips,
      ),
    );
  }

  @override
  Widget buildChip(ChipData data, double fontSize, BolonTheme theme) {
    // Powerline segments are built as a group in PromptArea so each
    // segment knows its neighbor's color. This single-chip fallback
    // renders one standalone segment.
    return _PowerlineSegment(
      bg: data.fg.withAlpha(40),
      nextBg: Colors.transparent,
      arrowWidth: fontSize * 0.7,
      padding: EdgeInsets.symmetric(
        horizontal: style.chipPaddingH,
        vertical: style.chipPaddingV,
      ),
      child: buildChipContent(
        data: data,
        fontSize: fontSize,
        theme: theme,
        fontWeight: parseFontWeight(style.fontWeight),
        showIcon: style.showIcons,
      ),
    );
  }

  /// Builds a full powerline bar where each segment flows into the next.
  Widget buildPowerlineBar(
    List<ChipData> chips,
    double fontSize,
    BolonTheme theme,
    List<Widget?> wrappers,
  ) {
    final segments = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      final bg = chips[i].fg.withAlpha(40);
      final nextBg = i + 1 < chips.length
          ? chips[i + 1].fg.withAlpha(40)
          : Colors.transparent;

      Widget segment = _PowerlineSegment(
        bg: bg,
        nextBg: nextBg,
        arrowWidth: fontSize * 0.7,
        isFirst: i == 0,
        padding: EdgeInsets.only(
          left: i == 0 ? style.chipPaddingH : style.chipPaddingH + 4,
          right: style.chipPaddingH,
          top: style.chipPaddingV,
          bottom: style.chipPaddingV,
        ),
        child: buildChipContent(
          data: chips[i],
          fontSize: fontSize,
          theme: theme,
          fontWeight: parseFontWeight(style.fontWeight),
          showIcon: style.showIcons,
        ),
      );

      if (wrappers[i] != null) {
        // Wrap in GestureDetector/MouseRegion for interactive chips.
        // The wrapper is a builder function disguised as a widget —
        // actually we just check if we need wrapping.
      }
      segments.add(segment);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments,
      ),
    );
  }
}

class _PowerlineSegment extends StatelessWidget {
  final Color bg;
  final Color nextBg;
  final double arrowWidth;
  final bool isFirst;
  final EdgeInsets padding;
  final Widget child;

  const _PowerlineSegment({
    required this.bg,
    required this.nextBg,
    required this.arrowWidth,
    this.isFirst = false,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PowerlinePainter(
        bg: bg,
        nextBg: nextBg,
        arrowWidth: arrowWidth,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: padding.left,
          right: padding.right + arrowWidth,
          top: padding.top,
          bottom: padding.bottom,
        ),
        child: child,
      ),
    );
  }
}

class _PowerlinePainter extends CustomPainter {
  final Color bg;
  final Color nextBg;
  final double arrowWidth;

  _PowerlinePainter({
    required this.bg,
    required this.nextBg,
    required this.arrowWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyWidth = size.width - arrowWidth;
    final midY = size.height / 2;

    // Body rectangle.
    final bodyPaint = Paint()..color = bg;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, bodyWidth, size.height),
      bodyPaint,
    );

    // Arrow triangle.
    final arrowPath = Path()
      ..moveTo(bodyWidth, 0)
      ..lineTo(bodyWidth + arrowWidth, midY)
      ..lineTo(bodyWidth, size.height)
      ..close();
    canvas.drawPath(arrowPath, bodyPaint);

    // Fill the arrow gap area behind with nextBg so colors
    // blend when segments sit side-by-side.
    if (nextBg != Colors.transparent) {
      final gapPaint = Paint()..color = nextBg;
      final gapPath = Path()
        ..moveTo(bodyWidth, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(bodyWidth, size.height)
        ..close();
      // Draw behind the arrow.
      canvas.drawPath(gapPath, gapPaint);
      // Redraw arrow on top.
      canvas.drawPath(arrowPath, bodyPaint);
    }
  }

  @override
  bool shouldRepaint(_PowerlinePainter old) =>
      bg != old.bg || nextBg != old.nextBg || arrowWidth != old.arrowWidth;
}

// ── Separator text widget ─────────────────────────────────────

/// Renders the separator character between chips in minimal/custom styles.
/// Uses [colorHex] if set, otherwise falls back to [BolonTheme.dimForeground].
class _SeparatorText extends StatelessWidget {
  final String char;
  final String colorHex;
  final double gap;

  const _SeparatorText({
    required this.char,
    required this.colorHex,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final color = _parseHexColor(colorHex) ?? theme.dimForeground;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gap),
      child: Text(
        char,
        style: TextStyle(
          color: color,
          fontFamily: theme.fontFamily,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// Parses a hex color string like "#7AA2F7" into a [Color].
/// Returns null if the string is empty or malformed.
Color? _parseHexColor(String hex) {
  if (hex.isEmpty) return null;
  final clean = hex.replaceFirst('#', '');
  if (clean.length != 6) return null;
  final v = int.tryParse(clean, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

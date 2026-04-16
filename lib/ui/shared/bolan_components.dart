import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

// ─── Design System: Components ─────────────────────────────────
//
// Shared UI primitives that read BolonTheme from context. Use these
// instead of hand-building TextStyle / BoxDecoration / InputDecoration
// across settings screens, dialogs, and workspace UI.
//
// See also:
//   bolan_button.dart   — BolanButton, BolanIconButton, BolanSvgIconButton
//   bolan_dialog.dart   — BolanDialog, BolanDialogButton
//
// Sizing constants (shared across all components):
//   Border radius:  5px
//   Font body:      13px
//   Font caption:   11px
//   Font heading:   15px w600
//   Input height:   36px
//   Toggle spacing: 16px bottom
//   Field spacing:  20px bottom
//
// ────────────────────────────────────────────────────────────────

// ─── Text Styles ───────────────────────────────────────────────

/// Theme-aware text style factory. Reads [BolonTheme] from context.
class BolanText extends StatelessWidget {
  final String text;
  final _BolanTextVariant _variant;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;

  const BolanText.heading(this.text, {super.key, this.color, this.maxLines, this.overflow})
      : _variant = _BolanTextVariant.heading;
  const BolanText.body(this.text, {super.key, this.color, this.maxLines, this.overflow})
      : _variant = _BolanTextVariant.body;
  const BolanText.label(this.text, {super.key, this.color, this.maxLines, this.overflow})
      : _variant = _BolanTextVariant.label;
  const BolanText.caption(this.text, {super.key, this.color, this.maxLines, this.overflow})
      : _variant = _BolanTextVariant.caption;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final style = switch (_variant) {
      _BolanTextVariant.heading => TextStyle(
          color: color ?? theme.foreground,
          fontFamily: theme.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      _BolanTextVariant.body => TextStyle(
          color: color ?? theme.foreground,
          fontFamily: theme.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.normal,
          decoration: TextDecoration.none,
        ),
      _BolanTextVariant.label => TextStyle(
          color: color ?? theme.foreground,
          fontFamily: theme.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      _BolanTextVariant.caption => TextStyle(
          color: color ?? theme.dimForeground,
          fontFamily: theme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.normal,
          decoration: TextDecoration.none,
        ),
    };
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

enum _BolanTextVariant { heading, body, label, caption }

// ─── Section Header ────────────────────────────────────────────

/// Dim uppercase label used to group related fields or list items.
/// Consistent 10px font, w600, 0.5px letter spacing, dimForeground.
class BolanSectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsets padding;

  const BolanSectionHeader(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          color: theme.dimForeground,
          fontFamily: theme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ─── Card ──────────────────────────────────────────────────────

/// Dark panel with border used for blocks, settings sections, and
/// workspace rows. Standardized: blockBackground fill, blockBorder
/// stroke, 8px radius.
class BolanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const BolanCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.blockBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.blockBorder, width: 1),
      ),
      child: child,
    );
  }
}

// ─── Text Field ────────────────────────────────────────────────

/// Themed text input: blockBorder stroke, statusChipBg fill, cursor
/// accent on focus. 13px body font, 36px height, 5px radius.
class BolanTextField extends StatefulWidget {
  final String value;
  final String? hint;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const BolanTextField({
    super.key,
    required this.value,
    this.hint,
    this.obscure = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<BolanTextField> createState() => _BolanTextFieldState();
}

class _BolanTextFieldState extends State<BolanTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(BolanTextField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Material(
      color: theme.statusChipBg,
      borderRadius: BorderRadius.circular(5),
      child: TextField(
        controller: _controller,
        obscureText: widget.obscure,
        style: TextStyle(
          color: theme.foreground,
          fontFamily: theme.fontFamily,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: theme.dimForeground, fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: theme.blockBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: theme.blockBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: theme.cursor),
          ),
          isDense: true,
        ),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

// ─── Dropdown ──────────────────────────────────────────────────

/// Themed dropdown select. 32px height, 5px radius, blockBackground
/// fill. Items render in theme font at 12px.
class BolanDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String>? onChanged;

  const BolanDropdown({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final effectiveValue = options.contains(value) ? value : options.first;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.blockBackground,
        border: Border.all(color: theme.blockBorder),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButton<String>(
        value: effectiveValue,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: theme.blockBackground,
        style: TextStyle(
          color: theme.foreground,
          fontFamily: theme.fontFamily,
          fontSize: 12,
        ),
        icon: Icon(Icons.expand_more, size: 16, color: theme.dimForeground),
        items: [
          for (final opt in options)
            DropdownMenuItem(value: opt, child: Text(opt)),
        ],
        onChanged: onChanged == null
            ? null
            : (v) {
                if (v != null) onChanged!(v);
              },
      ),
    );
  }
}

// ─── Segmented Control ─────────────────────────────────────────

/// Horizontal radio group styled as connected pills. Active segment
/// uses cursor accent; inactive uses statusChipBg. 5px end radius.
class BolanSegmentedControl extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String>? onChanged;

  const BolanSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Row(
      children: [
        for (var i = 0; i < options.length; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(options[i]),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: value == options[i]
                      ? theme.cursor.withAlpha(25)
                      : theme.statusChipBg,
                  border: Border.all(
                    color: value == options[i]
                        ? theme.cursor.withAlpha(80)
                        : theme.blockBorder,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0
                        ? const Radius.circular(5)
                        : Radius.zero,
                    right: i == options.length - 1
                        ? const Radius.circular(5)
                        : Radius.zero,
                  ),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    color: value == options[i]
                        ? theme.cursor
                        : theme.dimForeground,
                    fontFamily: theme.fontFamily,
                    fontSize: 12,
                    fontWeight: value == options[i]
                        ? FontWeight.w600
                        : FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Toggle ────────────────────────────────────────────────────

/// Label + optional help text + Switch. 16px bottom spacing.
/// Switch uses cursor accent for active track.
class BolanToggle extends StatelessWidget {
  final String label;
  final String? help;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const BolanToggle({
    super.key,
    required this.label,
    this.help,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (help != null)
                  Text(
                    help!,
                    style: TextStyle(
                      color: theme.dimForeground,
                      fontFamily: theme.fontFamily,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.cursor,
            inactiveTrackColor: theme.statusChipBg,
          ),
        ],
      ),
    );
  }
}

// ─── Field ─────────────────────────────────────────────────────

/// Label + optional help/error + child widget. 20px bottom spacing.
/// Used to wrap BolanTextField, BolanDropdown, BolanSegmentedControl,
/// BolanSlider, or any custom input.
class BolanField extends StatelessWidget {
  final String label;
  final String? help;
  final String? error;
  final Widget child;

  const BolanField({
    super.key,
    required this.label,
    this.help,
    this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (help != null && error == null) ...[
            const SizedBox(height: 2),
            Text(
              help!,
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 2),
            Text(
              error!,
              style: TextStyle(
                color: theme.exitFailureFg,
                fontFamily: theme.fontFamily,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─── Slider ────────────────────────────────────────────────────

/// Themed slider with value readout. Cursor accent for active track
/// and thumb.
class BolanSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final String? suffix;
  final ValueChanged<double>? onChanged;

  const BolanSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final divisions = ((max - min) / step).round();
    final displayValue = value == value.roundToDouble()
        ? '${value.round()}'
        : value.toStringAsFixed(1);

    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: theme.cursor,
              inactiveTrackColor: theme.statusChipBg,
              thumbColor: theme.cursor,
              overlayColor: theme.cursor.withAlpha(30),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged == null
                  ? null
                  : (v) {
                      final snapped = (v / step).round() * step;
                      onChanged!(snapped);
                    },
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '$displayValue${suffix ?? ''}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';
import 'color_picker.dart';

/// Grouped color editor for a theme.
/// Shows all color fields organized by category with clickable swatches.
class ThemeEditor extends StatelessWidget {
  final BolonTheme theme;
  final bool editable;
  final void Function(BolonTheme updated)? onChanged;

  const ThemeEditor({
    super.key,
    required this.theme,
    this.editable = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = BolonTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Duplicate this theme to edit colors',
              style: TextStyle(
                color: t.dimForeground,
                fontFamily: t.fontFamily,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                decoration: TextDecoration.none,
              ),
            ),
          ),

        _section('Window', t, [
          _row('Background', theme.background, t, (c) => theme.copyWith(background: c)),
          _row('Tab Bar', theme.tabBarBackground, t, (c) => theme.copyWith(tabBarBackground: c)),
          _row('Status Bar', theme.statusBarBackground, t, (c) => theme.copyWith(statusBarBackground: c)),
          _row('Prompt', theme.promptBackground, t, (c) => theme.copyWith(promptBackground: c)),
        ]),

        _section('Blocks', t, [
          _row('Background', theme.blockBackground, t, (c) => theme.copyWith(blockBackground: c)),
          _row('Border', theme.blockBorder, t, (c) => theme.copyWith(blockBorder: c)),
          _row('Header Text', theme.blockHeaderFg, t, (c) => theme.copyWith(blockHeaderFg: c)),
          _row('Success', theme.exitSuccessFg, t, (c) => theme.copyWith(exitSuccessFg: c)),
          _row('Failure', theme.exitFailureFg, t, (c) => theme.copyWith(exitFailureFg: c)),
        ]),

        _section('Status', t, [
          _row('Chip Background', theme.statusChipBg, t, (c) => theme.copyWith(statusChipBg: c)),
          _row('CWD', theme.statusCwdFg, t, (c) => theme.copyWith(statusCwdFg: c)),
          _row('Git', theme.statusGitFg, t, (c) => theme.copyWith(statusGitFg: c)),
          _row('Shell', theme.statusShellFg, t, (c) => theme.copyWith(statusShellFg: c)),
          _row('Dim Text', theme.dimForeground, t, (c) => theme.copyWith(dimForeground: c)),
        ]),

        _section('Terminal', t, [
          _row('Foreground', theme.foreground, t, (c) => theme.copyWith(foreground: c)),
          _row('Cursor', theme.cursor, t, (c) => theme.copyWith(cursor: c)),
          _row('Selection', theme.selectionColor, t, (c) => theme.copyWith(selectionColor: c)),
        ]),

        _section('ANSI Colors', t, []),
        _ansiGrid(t),
      ],
    );
  }

  Widget _section(String title, BolonTheme t, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: t.foreground,
              fontFamily: t.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _row(String label, Color color, BolonTheme t, BolonTheme Function(Color) updater) {
    return Builder(builder: (context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: TextStyle(
                  color: t.blockHeaderFg,
                  fontFamily: t.fontFamily,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: editable ? () => _pickColor(context, color, updater) : null,
              child: MouseRegion(
                cursor: editable ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: t.blockBorder, width: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _hex(color),
              style: TextStyle(
                color: t.dimForeground,
                fontFamily: t.fontFamily,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _ansiGrid(BolonTheme t) {
    final colors = [
      ('Black', theme.ansiBlack, (Color c) => theme.copyWith(ansiBlack: c)),
      ('Red', theme.ansiRed, (Color c) => theme.copyWith(ansiRed: c)),
      ('Green', theme.ansiGreen, (Color c) => theme.copyWith(ansiGreen: c)),
      ('Yellow', theme.ansiYellow, (Color c) => theme.copyWith(ansiYellow: c)),
      ('Blue', theme.ansiBlue, (Color c) => theme.copyWith(ansiBlue: c)),
      ('Magenta', theme.ansiMagenta, (Color c) => theme.copyWith(ansiMagenta: c)),
      ('Cyan', theme.ansiCyan, (Color c) => theme.copyWith(ansiCyan: c)),
      ('White', theme.ansiWhite, (Color c) => theme.copyWith(ansiWhite: c)),
    ];
    final bright = [
      ('Black', theme.ansiBrightBlack, (Color c) => theme.copyWith(ansiBrightBlack: c)),
      ('Red', theme.ansiBrightRed, (Color c) => theme.copyWith(ansiBrightRed: c)),
      ('Green', theme.ansiBrightGreen, (Color c) => theme.copyWith(ansiBrightGreen: c)),
      ('Yellow', theme.ansiBrightYellow, (Color c) => theme.copyWith(ansiBrightYellow: c)),
      ('Blue', theme.ansiBrightBlue, (Color c) => theme.copyWith(ansiBrightBlue: c)),
      ('Magenta', theme.ansiBrightMagenta, (Color c) => theme.copyWith(ansiBrightMagenta: c)),
      ('Cyan', theme.ansiBrightCyan, (Color c) => theme.copyWith(ansiBrightCyan: c)),
      ('White', theme.ansiBrightWhite, (Color c) => theme.copyWith(ansiBrightWhite: c)),
    ];

    return Builder(builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Normal row
          Row(
            children: [
              for (final (label, color, updater) in colors)
                _ansiSwatch(context, label, color, t, updater),
            ],
          ),
          const SizedBox(height: 4),
          // Bright row
          Row(
            children: [
              for (final (label, color, updater) in bright)
                _ansiSwatch(context, label, color, t, updater),
            ],
          ),
        ],
      );
    });
  }

  Widget _ansiSwatch(
    BuildContext context,
    String label,
    Color color,
    BolonTheme t,
    BolonTheme Function(Color) updater,
  ) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: editable ? () => _pickColor(context, color, updater) : null,
        child: MouseRegion(
          cursor: editable ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.blockBorder, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    Color current,
    BolonTheme Function(Color) updater,
  ) async {
    final t = BolonTheme.of(context);
    final result = await showDialog<Color>(
      context: context,
      builder: (_) => BolonThemeProvider(
        theme: t,
        child: ColorPickerDialog(initialColor: current, theme: t),
      ),
    );
    if (result != null) {
      onChanged?.call(updater(result));
    }
  }

  String _hex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

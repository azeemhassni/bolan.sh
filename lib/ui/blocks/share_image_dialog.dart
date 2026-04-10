import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/bolan_theme.dart';
import '../shared/bolan_dialog.dart';
import 'ansi_text_parser.dart';

/// Generates a styled "screenshot" PNG of a command + output, suitable
/// for sharing on social media. Renders entirely client-side via a
/// [RepaintBoundary]; nothing is uploaded.
///
/// Layout: a fixed 1200px-wide canvas with generous padding around a
/// rounded dark terminal window. Title bar has macOS-style traffic
/// lights. Background is a vibrant flat color.
Future<void> showShareImageDialog(
  BuildContext context, {
  required String command,
  required String output,
  required String rawOutput,
  required String shellName,
  required BolonTheme theme,
}) async {
  await showBolanDialog<void>(
    context: context,
    theme: theme,
    builder: (ctx) => _ShareImageDialog(
      command: command,
      output: output,
      rawOutput: rawOutput,
      shellName: shellName,
    ),
  );
}

class _ShareImageDialog extends StatefulWidget {
  final String command;
  final String output;
  final String rawOutput;
  final String shellName;

  const _ShareImageDialog({
    required this.command,
    required this.output,
    required this.rawOutput,
    required this.shellName,
  });

  @override
  State<_ShareImageDialog> createState() => _ShareImageDialogState();
}

class _ShareImageDialogState extends State<_ShareImageDialog> {
  final GlobalKey _captureKey = GlobalKey();
  bool _saving = false;
  String? _error;

  /// Index into [_backgrounds]. User can cycle through preset colors.
  int _bgIndex = 0;

  /// Curated palette of vibrant flat backgrounds for the share canvas.
  /// Picked to look good against a dark terminal window.
  static const List<Color> _backgrounds = [
    Color(0xFF6366F1), // indigo
    Color(0xFF7C3AED), // violet
    Color(0xFFDB2777), // pink
    Color(0xFFF59E0B), // amber
    Color(0xFF10B981), // emerald
    Color(0xFF0EA5E9), // sky
    Color(0xFF1F2937), // slate (dark, for muted look)
  ];

  /// Caps output at a reasonable line count so the image stays
  /// readable on social platforms. Preserves ANSI escape sequences
  /// so the captured image keeps the original colors. Long outputs
  /// get a "(truncated)" hint at the bottom, with an explicit
  /// `\x1B[0m` reset so the hint doesn't inherit a dangling color.
  String _displayRawOutput() {
    final raw = widget.rawOutput.isNotEmpty ? widget.rawOutput : widget.output;
    final lines = raw.split('\n');
    const maxLines = 30;
    if (lines.length <= maxLines) return raw.trimRight();
    final visible = lines.take(maxLines).join('\n');
    final hidden = lines.length - maxLines;
    return '$visible\n\x1B[0m… ($hidden more line${hidden == 1 ? '' : 's'} hidden)';
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final boundary = _captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('toByteData returned null');
      }
      final bytes = byteData.buffer.asUint8List();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final location = await getSaveLocation(
        suggestedName: 'bolan-share-$ts.png',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PNG', extensions: ['png']),
        ],
      );
      if (location == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      await File(location.path).writeAsBytes(bytes);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return BolanDialog(
      width: 720,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BolanDialogTitle(
            text: 'Share as image',
            icon: Icons.image_outlined,
          ),
          const SizedBox(height: 14),

          // Preview — actual capture target wrapped in FittedBox so
          // it scales to fit the dialog while still rendering at its
          // full 1200px natural width for the capture.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: theme.background,
              child: SizedBox(
                height: 360,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: _ShareCanvas(
                        command: widget.command,
                        rawOutput: _displayRawOutput(),
                        shellName: widget.shellName,
                        backgroundColor: _backgrounds[_bgIndex],
                        theme: theme,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Background color swatches
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Background',
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: theme.fontFamily,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
              for (var i = 0; i < _backgrounds.length; i++)
                _Swatch(
                  color: _backgrounds[i],
                  selected: i == _bgIndex,
                  onTap: () => setState(() => _bgIndex = i),
                ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              'Save failed: $_error',
              style: TextStyle(
                color: theme.exitFailureFg,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BolanDialogButton(
                label: 'Cancel',
                autofocus: true,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              BolanDialogButton(
                label: _saving ? 'Saving…' : 'Save PNG',
                kind: BolanButtonKind.primary,
                onTap: _saving ? () {} : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The actual canvas that gets rendered into a PNG. Fixed 1200px wide;
/// height grows with content.
///
/// Pulls colors and font from the user's [BolonTheme] so the captured
/// image is a faithful reproduction of what the user sees in their
/// terminal. ANSI color sequences in [rawOutput] are parsed via
/// [AnsiTextParser] so the output keeps its original colors.
class _ShareCanvas extends StatelessWidget {
  final String command;
  final String rawOutput;
  final String shellName;
  final Color backgroundColor;
  final BolonTheme theme;

  const _ShareCanvas({
    required this.command,
    required this.rawOutput,
    required this.shellName,
    required this.backgroundColor,
    required this.theme,
  });

  static const double _width = 1200;
  static const double _outerPadding = 80;
  static const double _windowRadius = 12;
  static const double _commandFontSize = 22;
  static const double _outputFontSize = 20;

  @override
  Widget build(BuildContext context) {
    final font = theme.fontFamily;
    final winBg = theme.background;
    final titleBarBg = theme.tabBarBackground;
    final textColor = theme.foreground;
    final dimColor = theme.dimForeground;
    final promptColor = theme.cursor;

    final outputBaseStyle = TextStyle(
      color: textColor,
      fontFamily: font,
      fontSize: _outputFontSize,
      height: 1.45,
      decoration: TextDecoration.none,
    );

    // Parse ANSI escape sequences in the raw output so the captured
    // image keeps the original colors (red errors, green success, etc.).
    final outputSpans = rawOutput.isEmpty
        ? const <TextSpan>[]
        : AnsiTextParser(theme).parse(rawOutput, baseStyle: outputBaseStyle);

    return Container(
      width: _width,
      padding: const EdgeInsets.all(_outerPadding),
      color: backgroundColor,
      child: Container(
        decoration: BoxDecoration(
          color: winBg,
          borderRadius: BorderRadius.circular(_windowRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar with traffic lights
            Container(
              color: titleBarBg,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  _trafficLight(const Color(0xFFFF5F57)),
                  const SizedBox(width: 9),
                  _trafficLight(const Color(0xFFFEBC2E)),
                  const SizedBox(width: 9),
                  _trafficLight(const Color(0xFF28C840)),
                  const Spacer(),
                  Text(
                    shellName,
                    style: TextStyle(
                      color: dimColor,
                      fontFamily: font,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  // Spacer to balance the traffic lights horizontally.
                  const SizedBox(width: 51),
                ],
              ),
            ),

            // Body — command + output
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Prompt + command
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: _commandFontSize,
                        height: 1.4,
                        decoration: TextDecoration.none,
                      ),
                      children: [
                        TextSpan(
                          text: '\$ ',
                          style: TextStyle(
                            color: promptColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: command,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (outputSpans.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    RichText(
                      text: TextSpan(children: outputSpans),
                    ),
                  ],
                ],
              ),
            ),

            // Footer — Bolan watermark
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
              child: Row(
                children: [
                  Text(
                    'bolan.sh',
                    style: TextStyle(
                      color: dimColor,
                      fontFamily: font,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trafficLight(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withAlpha(120),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

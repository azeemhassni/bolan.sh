import 'package:flutter/material.dart';

import '../../../core/theme/bolan_theme.dart';
import '../../shared/bolan_button.dart';
import '../../shared/bolan_components.dart';

class AiThemeGenerator extends StatefulWidget {
  final bool generating;
  final String? error;
  final BolonTheme? previewTheme;
  final ValueChanged<String> onGenerate;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const AiThemeGenerator({
    super.key,
    required this.generating,
    this.error,
    this.previewTheme,
    required this.onGenerate,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  State<AiThemeGenerator> createState() => _AiThemeGeneratorState();
}

class _AiThemeGeneratorState extends State<AiThemeGenerator> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BolanSectionHeader('Generate with AI'),
        Row(
          children: [
            Expanded(
              child: Material(
                color: theme.statusChipBg,
                borderRadius: BorderRadius.circular(5),
                child: TextField(
                  controller: _controller,
                  enabled: !widget.generating,
                  onSubmitted: (_) => widget.onGenerate(_controller.text),
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe your theme... (e.g. "ocean sunset")',
                    hintStyle: TextStyle(
                        color: theme.dimForeground, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                ),
              ),
            ),
            const SizedBox(width: 8),
            BolanButton.primary(
              label: widget.generating ? 'Generating...' : 'Generate',
              icon: widget.generating ? null : Icons.auto_awesome,
              onTap: widget.generating
                  ? null
                  : () => widget.onGenerate(_controller.text),
            ),
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: TextStyle(
              color: theme.exitFailureFg,
              fontFamily: theme.fontFamily,
              fontSize: 11,
            ),
          ),
        ],
        if (widget.previewTheme != null) ...[
          const SizedBox(height: 12),
          _ThemePreview(theme: widget.previewTheme!),
          const SizedBox(height: 8),
          Row(
            children: [
              BolanButton.primary(
                label: 'Save & Apply',
                icon: Icons.check,
                onTap: widget.onSave,
              ),
              const SizedBox(width: 8),
              BolanButton(
                label: 'Discard',
                onTap: widget.onDiscard,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final BolonTheme theme;
  const _ThemePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = BolonTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.blockBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theme.displayName,
            style: TextStyle(
              color: theme.foreground,
              fontFamily: t.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$ git status',
            style: TextStyle(
              color: theme.foreground,
              fontFamily: t.fontFamily,
              fontSize: 12,
            ),
          ),
          Text(
            'On branch main',
            style: TextStyle(
              color: theme.ansiGreen,
              fontFamily: t.fontFamily,
              fontSize: 12,
            ),
          ),
          Text(
            'modified:   src/app.dart',
            style: TextStyle(
              color: theme.ansiRed,
              fontFamily: t.fontFamily,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final c in [
                theme.ansiBlack, theme.ansiRed, theme.ansiGreen,
                theme.ansiYellow, theme.ansiBlue, theme.ansiMagenta,
                theme.ansiCyan, theme.ansiWhite,
              ])
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final c in [
                theme.ansiBrightBlack, theme.ansiBrightRed,
                theme.ansiBrightGreen, theme.ansiBrightYellow,
                theme.ansiBrightBlue, theme.ansiBrightMagenta,
                theme.ansiBrightCyan, theme.ansiBrightWhite,
              ])
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.cursor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'cursor / accent',
                  style: TextStyle(
                    color: theme.background,
                    fontFamily: t.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'dim text',
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: t.fontFamily,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/terminal/command_block.dart';
import '../../core/theme/bolan_theme.dart';

/// Renders a completed command as a Warp-style block.
///
/// Shows the command text as a header with a subtle left accent border
/// (green for success, red for failure), followed by the output text.
/// Click to copy output.
class CommandBlockWidget extends StatefulWidget {
  final CommandBlock block;
  final double fontSize;
  final double lineHeight;

  const CommandBlockWidget({
    super.key,
    required this.block,
    this.fontSize = 13,
    this.lineHeight = 1.2,
  });

  @override
  State<CommandBlockWidget> createState() => _CommandBlockWidgetState();
}

class _CommandBlockWidgetState extends State<CommandBlockWidget> {
  bool _hovered = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final block = widget.block;
    // Only show red left accent for explicit failures (exit code > 0)
    final isFailed = block.exitCode != null && block.exitCode! > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: block.hasOutput ? _copyOutput : null,
        child: Container(
          decoration: BoxDecoration(
            color: _hovered
                ? theme.blockBackground
                : theme.background,
            border: Border(
              left: BorderSide(
                color: isFailed
                    ? theme.exitFailureFg
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.only(
            left: 9, right: 12, top: 4, bottom: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Command header line
              Row(
                children: [
                  Expanded(
                    child: Text(
                      block.command,
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: 'JetBrainsMono',
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  // Copy indicator
                  if (_copied)
                    Text(
                      'Copied',
                      style: TextStyle(
                        color: theme.exitSuccessFg,
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono',
                        decoration: TextDecoration.none,
                      ),
                    )
                  else if (_hovered && block.hasOutput)
                    Icon(
                      Icons.content_copy,
                      size: 13,
                      color: theme.dimForeground,
                    ),
                  if (block.duration != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(block.duration!),
                      style: TextStyle(
                        color: theme.dimForeground,
                        fontFamily: 'JetBrainsMono',
                        fontSize: widget.fontSize - 2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),

              // Output body — pre-formatted, preserves whitespace alignment
              if (block.hasOutput)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      block.output,
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar.editableText(
                          editableTextState: editableTextState,
                        );
                      },
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: 'JetBrainsMono',
                        fontSize: widget.fontSize,
                        height: widget.lineHeight,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyOutput() async {
    await Clipboard.setData(ClipboardData(text: widget.block.output));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    if (d.inSeconds > 0) {
      return '${d.inSeconds}.${(d.inMilliseconds.remainder(1000) ~/ 100)}s';
    }
    return '${d.inMilliseconds}ms';
  }
}

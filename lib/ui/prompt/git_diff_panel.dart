import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/bolan_theme.dart';

/// Panel showing git diff with colored additions/deletions.
class GitDiffPanel extends StatefulWidget {
  final String cwd;
  final VoidCallback onClose;

  const GitDiffPanel({
    super.key,
    required this.cwd,
    required this.onClose,
  });

  @override
  State<GitDiffPanel> createState() => _GitDiffPanelState();
}

class _GitDiffPanelState extends State<GitDiffPanel> {
  String? _diff;
  bool _loading = true;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKey);
    _loadDiff();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadDiff() async {
    try {
      final result = await Process.run(
        'git',
        ['diff', '--stat', '--patch'],
        workingDirectory: widget.cwd,
      );
      if (mounted) {
        setState(() {
          _diff = (result.stdout as String).trim();
          _loading = false;
        });
        _focusNode.requestFocus();
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _diff = 'Failed to load diff';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final media = MediaQuery.of(context).size;

    return Focus(
      focusNode: _focusNode,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: media.width * 0.85,
          maxHeight: media.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: theme.blockBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.blockBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.difference_outlined,
                      size: 16, color: theme.foreground),
                  const SizedBox(width: 8),
                  Text(
                    'Changes',
                    style: TextStyle(
                      color: theme.foreground,
                      fontFamily: theme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'esc to close',
                    style: TextStyle(
                      color: theme.dimForeground,
                      fontFamily: theme.fontFamily,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(Icons.close,
                          size: 16, color: theme.dimForeground),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: theme.blockBorder),

            // Diff content
            Flexible(
              child: _loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: theme.cursor,
                          ),
                        ),
                      ),
                    )
                  : _diff == null || _diff!.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No changes',
                            style: TextStyle(
                              color: theme.dimForeground,
                              fontFamily: theme.fontFamily,
                              fontSize: 13,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: _buildDiff(theme),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiff(BolonTheme theme) {
    final lines = _diff!.split('\n');
    final spans = <TextSpan>[];

    for (final line in lines) {
      Color color;
      if (line.startsWith('+') && !line.startsWith('+++')) {
        color = theme.exitSuccessFg;
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        color = theme.exitFailureFg;
      } else if (line.startsWith('@@')) {
        color = theme.ansiCyan;
      } else if (line.startsWith('diff ') || line.startsWith('index ') ||
          line.startsWith('---') || line.startsWith('+++')) {
        color = theme.dimForeground;
      } else {
        color = theme.foreground;
      }

      spans.add(TextSpan(
        text: '$line\n',
        style: TextStyle(
          color: color,
          fontFamily: theme.fontFamily,
          fontSize: 12,
          height: 1.4,
          decoration: TextDecoration.none,
        ),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}

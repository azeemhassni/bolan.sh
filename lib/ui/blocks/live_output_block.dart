import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import 'ansi_text_parser.dart';

/// Renders streaming command output inline in the blocks layout while
/// a command is running. Replaces the full-screen TerminalView for
/// non-TUI commands, eliminating the layout shift.
class LiveOutputBlock extends StatefulWidget {
  final TerminalSession session;
  final double fontSize;
  final double lineHeight;
  final bool ligatures;
  final VoidCallback? onContentGrew;

  const LiveOutputBlock({
    super.key,
    required this.session,
    required this.fontSize,
    this.lineHeight = 1.3,
    this.ligatures = false,
    this.onContentGrew,
  });

  @override
  State<LiveOutputBlock> createState() => _LiveOutputBlockState();
}

class _LiveOutputBlockState extends State<LiveOutputBlock> {
  final StringBuffer _buffer = StringBuffer();
  StreamSubscription<String>? _sub;
  Timer? _throttle;
  bool _dirty = false;
  int _lineCount = 0;

  static const _maxDisplayLines = 5000;
  static const _throttleMs = 66; // ~15fps

  @override
  void initState() {
    super.initState();
    // Seed with any output that arrived before we subscribed.
    _buffer.write(widget.session.liveOutputSnapshot);
    _lineCount = '\n'.allMatches(_buffer.toString()).length;
    _sub = widget.session.liveOutput.listen(_onChunk);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _throttle?.cancel();
    super.dispose();
  }

  void _onChunk(String chunk) {
    _buffer.write(chunk);
    _lineCount += '\n'.allMatches(chunk).length;
    _dirty = true;
    // Throttle rebuilds to avoid overwhelming the UI during
    // high-volume output like compilation or npm install.
    _throttle ??= Timer(
      const Duration(milliseconds: _throttleMs),
      _flush,
    );
  }

  void _flush() {
    _throttle = null;
    if (!_dirty || !mounted) return;
    _dirty = false;
    setState(() {});
    widget.onContentGrew?.call();
  }

  @override
  void didUpdateWidget(LiveOutputBlock old) {
    super.didUpdateWidget(old);
    // When the parent rebuilds (e.g. session notifyListeners), refresh
    // from the snapshot in case we missed chunks during init.
    final snapshot = widget.session.liveOutputSnapshot;
    if (snapshot.length > _buffer.length) {
      _buffer.clear();
      _buffer.write(snapshot);
      _lineCount = '\n'.allMatches(snapshot).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final block = widget.session.activeBlock;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Prompt context line ──
            if (block != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    if (block.shellName.isNotEmpty) ...[
                      Text(
                        block.shellName,
                        style: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: theme.fontFamily,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (block.cwd.isNotEmpty)
                      Text(
                        block.cwd,
                        style: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: theme.fontFamily,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    if (block.gitBranch != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        block.gitBranch!,
                        style: TextStyle(
                          color: theme.statusGitFg.withAlpha(150),
                          fontFamily: theme.fontFamily,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Command header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.cursor,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      block?.command ?? '',
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: theme.fontFamily,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.cursor.withAlpha(120),
                    ),
                  ),
                ],
              ),
            ),

            // ── Streaming output body ──
            if (_buffer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _buildOutput(theme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutput(BolonTheme theme) {
    var text = _buffer.toString();

    // Collapse carriage returns (progress bars).
    text = _collapseCarriageReturns(text);
    // Collapse runs of blank lines left over from stripped markers.
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n');
    // Trim leading/trailing whitespace.
    text = text.trim();

    // Tail only for very long output.
    if (_lineCount > _maxDisplayLines) {
      final lines = text.split('\n');
      text = lines.skip(lines.length - _maxDisplayLines).join('\n');
    }

    final parser = AnsiTextParser(
      BolonTheme.of(context),
      ligatures: widget.ligatures,
    );
    final baseStyle = TextStyle(
      color: theme.foreground,
      fontFamily: theme.fontFamily,
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      decoration: TextDecoration.none,
    );

    final spans = parser.parse(text, baseStyle: baseStyle);

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }

  String _collapseCarriageReturns(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    for (final line in lines) {
      if (line.contains('\r')) {
        final parts = line.split('\r');
        result.add(parts.last);
      } else {
        result.add(line);
      }
    }
    return result.join('\n');
  }
}

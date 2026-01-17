import 'package:flutter/material.dart';

import '../../core/terminal/command_block.dart';
import '../../core/theme/bolan_theme.dart';

/// Header row for a command block — shows the command text, exit code badge,
/// execution duration, and optional copy indicator.
class BlockHeader extends StatelessWidget {
  final CommandBlock block;
  final bool showCopyHint;
  final bool copied;

  const BlockHeader({
    super.key,
    required this.block,
    this.showCopyHint = false,
    this.copied = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Prompt marker
          Text(
            '\$ ',
            style: TextStyle(
              color: theme.dimForeground,
              fontFamily: 'Operator Mono',
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
          // Command text
          Expanded(
            child: Text(
              block.command,
              style: TextStyle(
                color: theme.blockHeaderFg,
                fontFamily: 'Operator Mono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

          // Copy indicator
          if (copied)
            Text(
              'Copied',
              style: TextStyle(
                color: theme.exitSuccessFg,
                fontSize: 11,
                fontFamily: 'Operator Mono',
              ),
            )
          else if (showCopyHint)
            Icon(
              Icons.content_copy,
              size: 13,
              color: theme.dimForeground,
            ),

          const SizedBox(width: 8),

          // Running indicator or exit code
          if (block.isRunning)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: theme.cursor,
              ),
            )
          else if (block.exitCode != null)
            _ExitBadge(exitCode: block.exitCode!, theme: theme),

          // Duration
          if (block.duration != null) ...[
            const SizedBox(width: 8),
            Text(
              _formatDuration(block.duration!),
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: 'Operator Mono',
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
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

class _ExitBadge extends StatelessWidget {
  final int exitCode;
  final BolonTheme theme;

  const _ExitBadge({required this.exitCode, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isSuccess = exitCode == 0;
    final color = isSuccess ? theme.exitSuccessFg : theme.exitFailureFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80), width: 0.5),
      ),
      child: Text(
        isSuccess ? '0' : '$exitCode',
        style: TextStyle(
          color: color,
          fontFamily: 'Operator Mono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

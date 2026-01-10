import 'package:flutter/material.dart';

import '../../core/terminal/command_block.dart';
import '../../core/theme/bolan_theme.dart';

/// Header row for a command block — shows the command text, exit code badge,
/// and execution duration.
class BlockHeader extends StatelessWidget {
  final CommandBlock block;

  const BlockHeader({super.key, required this.block});

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
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
            ),
          ),
          // Command text
          Expanded(
            child: Text(
              block.command,
              style: TextStyle(
                color: theme.blockHeaderFg,
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
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
                fontFamily: 'JetBrainsMono',
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
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Small bottom-right toast showing update download progress
/// when the update dialog has been backgrounded.
class UpdateToast extends StatelessWidget {
  final int received;
  final int total;
  final bool isReady;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onRestart;

  const UpdateToast({
    super.key,
    required this.received,
    required this.total,
    this.isReady = false,
    required this.onTap,
    this.onDismiss,
    this.onRestart,
  });

  double get _progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Positioned(
      bottom: 16,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.blockBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.blockBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isReady
                ? _buildReady(theme)
                : _buildDownloading(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloading(BolonTheme theme) {
    final percent = (_progress * 100).toStringAsFixed(0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                value: total > 0 ? _progress : null,
                color: theme.cursor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Downloading update  $percent%',
                style: TextStyle(
                  color: theme.foreground,
                  fontFamily: theme.fontFamily,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(Icons.close, size: 14,
                      color: theme.dimForeground),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? _progress : null,
            minHeight: 3,
            backgroundColor: theme.statusChipBg,
            valueColor: AlwaysStoppedAnimation<Color>(theme.cursor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatBytes(received)} / ${total > 0 ? _formatBytes(total) : '?'}',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 10,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildReady(BolonTheme theme) {
    return Row(
      children: [
        Icon(Icons.check_circle_outline, size: 16,
            color: theme.ansiGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Update ready',
            style: TextStyle(
              color: theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        GestureDetector(
          onTap: onRestart,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.cursor.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Restart',
                style: TextStyle(
                  color: theme.cursor,
                  fontFamily: theme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onDismiss,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(Icons.close, size: 14,
                color: theme.dimForeground),
          ),
        ),
      ],
    );
  }
}

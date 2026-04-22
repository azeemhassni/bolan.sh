import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bolan_theme.dart';
import '../../providers/update_provider.dart';
import '../shared/bolan_dialog.dart';

/// Modal dialog for the update lifecycle.
///
/// Transitions through: available → downloading → verifying →
/// installing → readyToRestart, with error handling at each stage.
class UpdateDialog extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onBackgrounded;

  const UpdateDialog({
    super.key,
    required this.onDismiss,
    required this.onBackgrounded,
  });

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  DateTime? _startTime;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(int received) {
    if (_startTime == null || received == 0) return '';
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    if (elapsed == 0) return '';
    final bytesPerSec = received / elapsed;
    return '${_formatBytes(bytesPerSec.round())}/s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final s = ref.watch(updateProvider).state;

    final Widget content = switch (s.status) {
      UpdateStatus.available => _buildAvailable(theme, s),
      UpdateStatus.downloading => _buildDownloading(theme, s),
      UpdateStatus.verifying => _buildIndeterminate(theme, 'Verifying update...'),
      UpdateStatus.installing => _buildIndeterminate(theme, 'Installing update...'),
      UpdateStatus.readyToRestart => _buildReadyToRestart(theme),
      UpdateStatus.error => _buildError(theme, s.error ?? 'Unknown error'),
      _ => const SizedBox.shrink(),
    };

    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black54,
        child: BolanDialog(child: content),
      ),
    );
  }

  Widget _buildAvailable(BolonTheme theme, UpdateState s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BolanDialogTitle(
          text: 'Update Available',
          icon: Icons.system_update_outlined,
          iconColor: theme.cursor,
        ),
        const SizedBox(height: 16),
        BolanDialogText('Version ${s.latestVersion} is available.'),
        if (s.releaseNotes != null && s.releaseNotes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.blockBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.blockBorder, width: 1),
            ),
            child: SingleChildScrollView(
              child: Text(
                s.releaseNotes!,
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: theme.fontFamily,
                  fontSize: 12,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BolanDialogButton(
              label: 'Skip This Version',
              onTap: () {
                ref.read(updateProvider).skipVersion();
                widget.onDismiss();
              },
            ),
            const SizedBox(width: 10),
            BolanDialogButton(
              label: 'Not Now',
              autofocus: true,
              onTap: () {
                ref.read(updateProvider).dismiss();
                widget.onDismiss();
              },
            ),
            const SizedBox(width: 10),
            BolanDialogButton(
              label: 'Update Now',
              kind: BolanButtonKind.primary,
              onTap: () {
                setState(() => _startTime = DateTime.now());
                ref.read(updateProvider).download();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloading(BolonTheme theme, UpdateState s) {
    final progress = s.progress;
    final percent = (progress * 100).toStringAsFixed(0);
    final speed = _formatSpeed(s.received);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BolanDialogTitle(text: 'Downloading update...'),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: s.total > 0 ? progress : null,
            minHeight: 6,
            backgroundColor: theme.statusChipBg,
            valueColor: AlwaysStoppedAnimation<Color>(theme.cursor),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_formatBytes(s.received)}${s.total > 0 ? ' / ${_formatBytes(s.total)}' : ''}',
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              s.total > 0 ? '$percent%  $speed' : speed,
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BolanDialogButton(
              label: 'Cancel',
              autofocus: true,
              onTap: () {
                ref.read(updateProvider).cancelDownload();
                widget.onDismiss();
              },
            ),
            const SizedBox(width: 10),
            BolanDialogButton(
              label: 'Continue in Background',
              onTap: widget.onBackgrounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIndeterminate(BolonTheme theme, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BolanDialogTitle(text: message),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 6,
            backgroundColor: theme.statusChipBg,
            valueColor: AlwaysStoppedAnimation<Color>(theme.cursor),
          ),
        ),
      ],
    );
  }

  Widget _buildReadyToRestart(BolonTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, size: 48, color: theme.cursor),
        const SizedBox(height: 16),
        const BolanDialogTitle(text: 'Update installed'),
        const SizedBox(height: 8),
        const BolanDialogText('Restart Bolan to use the new version.'),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BolanDialogButton(
              label: 'Later',
              onTap: widget.onDismiss,
            ),
            const SizedBox(width: 8),
            BolanDialogButton(
              label: 'Restart Now',
              autofocus: true,
              kind: BolanButtonKind.primary,
              onTap: () => ref.read(updateProvider).restart(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError(BolonTheme theme, String error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BolanDialogTitle(
          text: 'Update failed',
          icon: Icons.error_outline,
          iconColor: theme.exitFailureFg,
        ),
        const SizedBox(height: 12),
        BolanDialogText(error, maxLines: 5, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BolanDialogButton(
              label: 'Close',
              autofocus: true,
              onTap: () {
                ref.read(updateProvider).dismiss();
                widget.onDismiss();
              },
            ),
            const SizedBox(width: 10),
            BolanDialogButton(
              label: 'Retry',
              kind: BolanButtonKind.primary,
              onTap: () {
                setState(() => _startTime = DateTime.now());
                ref.read(updateProvider).download();
              },
            ),
          ],
        ),
      ],
    );
  }
}

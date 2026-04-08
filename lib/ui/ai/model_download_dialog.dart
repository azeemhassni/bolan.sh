import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/model_manager.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/model_download_provider.dart';
import '../shared/bolan_dialog.dart';

/// Modal dialog for downloading the local AI model.
///
/// Shows privacy messaging, download progress with speed/size,
/// and a "Continue in background" option.
class ModelDownloadDialog extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onBackgrounded;

  const ModelDownloadDialog({
    super.key,
    required this.onDismiss,
    required this.onBackgrounded,
  });

  @override
  ConsumerState<ModelDownloadDialog> createState() =>
      ModelDownloadDialogState();
}

class ModelDownloadDialogState extends ConsumerState<ModelDownloadDialog> {
  bool _promptShown = true;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    final dl = ref.read(modelDownloadProvider);
    // If a download is already in progress (e.g. started from Settings),
    // skip the prompt and go straight to progress.
    if (dl.state.downloading || dl.state.paused) {
      _promptShown = false;
    }
  }

  void _startDownload() {
    setState(() {
      _promptShown = false;
      _startTime = DateTime.now();
    });
    ref.read(modelDownloadProvider).start(ModelSize.small);
  }

  void _cancel() {
    ref.read(modelDownloadProvider).cancel();
    widget.onDismiss();
  }

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
    final dl = ref.watch(modelDownloadProvider);
    final s = dl.state;

    final Widget content;
    if (_promptShown && !s.downloading && !s.complete && s.error == null) {
      content = _buildPrompt(theme);
    } else if (s.complete) {
      content = _buildComplete(theme);
    } else if (s.error != null) {
      content = _buildError(theme, s.error!);
    } else {
      content = _buildProgress(theme, s);
    }

    // This dialog is mounted inline by [TerminalShell], not via
    // showDialog, so it provides its own backdrop.
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black54,
        child: BolanDialog(child: content),
      ),
    );
  }

  Widget _buildPrompt(BolonTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BolanDialogTitle(
          text: 'Local AI Model',
          icon: Icons.shield_outlined,
          iconColor: theme.cursor,
        ),
        const SizedBox(height: 16),
        const BolanDialogText(
          'Bolan uses a local AI model for command generation. '
          'Everything runs on your machine — no data leaves your computer.',
        ),
        const SizedBox(height: 8),
        const BolanDialogText('Download size: ~1.3 GB'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BolanDialogButton(
              label: 'Not Now',
              onTap: widget.onDismiss,
            ),
            const SizedBox(width: 10),
            BolanDialogButton(
              label: 'Download',
              kind: BolanButtonKind.primary,
              onTap: _startDownload,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgress(BolonTheme theme, ModelDownloadState s) {
    final progress = s.progress;
    final percent = (progress * 100).toStringAsFixed(0);
    final speed = _formatSpeed(s.received);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BolanDialogTitle(text: 'Downloading AI model...'),
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
              onTap: _cancel,
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

  Widget _buildComplete(BolonTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, size: 48, color: theme.cursor),
        const SizedBox(height: 16),
        const BolanDialogTitle(text: 'Model downloaded'),
        const SizedBox(height: 8),
        const BolanDialogText(
          'Local AI is ready. Type # followed by what you want to do.',
        ),
        const SizedBox(height: 20),
        BolanDialogButton(
          label: 'Done',
          kind: BolanButtonKind.primary,
          onTap: () {
            ref.read(modelDownloadProvider).clearComplete();
            widget.onDismiss();
          },
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
          text: 'Download failed',
          icon: Icons.error_outline,
          iconColor: theme.exitFailureFg,
        ),
        const SizedBox(height: 12),
        BolanDialogText(error, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BolanDialogButton(label: 'Close', onTap: widget.onDismiss),
            const SizedBox(width: 10),
            BolanDialogButton(
              label: 'Retry',
              kind: BolanButtonKind.primary,
              onTap: () {
                setState(() => _startTime = DateTime.now());
                ref.read(modelDownloadProvider).start(ModelSize.small);
              },
            ),
          ],
        ),
      ],
    );
  }
}

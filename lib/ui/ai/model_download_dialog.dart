import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/model_manager.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/model_download_provider.dart';

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

    // Determine which view to show
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

    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.blockBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.blockBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrompt(BolonTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined,
                size: 20, color: const Color(0xFF00FF92)),
            const SizedBox(width: 10),
            Text(
              'Local AI Model',
              style: TextStyle(
                color: theme.foreground,
                fontFamily: theme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Bolan uses a local AI model for command generation. '
          'Everything runs on your machine — no data leaves your computer.',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 13,
            height: 1.5,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Download size: ~1.3 GB',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Button(
              label: 'Not Now',
              theme: theme,
              onTap: widget.onDismiss,
            ),
            const SizedBox(width: 10),
            _Button(
              label: 'Download',
              theme: theme,
              isPrimary: true,
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
        Text(
          'Downloading AI model...',
          style: TextStyle(
            color: theme.foreground,
            fontFamily: theme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: s.total > 0 ? progress : null,
            minHeight: 6,
            backgroundColor: theme.statusChipBg,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF00FF92)),
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
            _Button(
              label: 'Cancel',
              theme: theme,
              onTap: _cancel,
            ),
            const SizedBox(width: 10),
            _Button(
              label: 'Continue in Background',
              theme: theme,
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
      children: [
        Icon(Icons.check_circle_outline,
            size: 48, color: const Color(0xFF00FF92)),
        const SizedBox(height: 16),
        Text(
          'Model downloaded',
          style: TextStyle(
            color: theme.foreground,
            fontFamily: theme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Local AI is ready. Type # followed by what you want to do.',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 20),
        _Button(
          label: 'Done',
          theme: theme,
          isPrimary: true,
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
        Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: theme.exitFailureFg),
            const SizedBox(width: 8),
            Text(
              'Download failed',
              style: TextStyle(
                color: theme.foreground,
                fontFamily: theme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          error,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Button(label: 'Close', theme: theme, onTap: widget.onDismiss),
            const SizedBox(width: 10),
            _Button(
              label: 'Retry',
              theme: theme,
              isPrimary: true,
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

class _Button extends StatelessWidget {
  final String label;
  final BolonTheme theme;
  final bool isPrimary;
  final VoidCallback onTap;

  const _Button({
    required this.label,
    required this.theme,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF00FF92)
                : theme.statusChipBg,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? theme.background : theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

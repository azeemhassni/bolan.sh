import 'package:flutter/material.dart';

import '../../core/ai/model_manager.dart';
import '../../core/theme/bolan_theme.dart';

/// Modal dialog for downloading the local AI model.
///
/// Shows privacy messaging, download progress with speed/size,
/// and a "Continue in background" option.
class ModelDownloadDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onBackgrounded;

  const ModelDownloadDialog({
    super.key,
    required this.onDismiss,
    required this.onBackgrounded,
  });

  @override
  State<ModelDownloadDialog> createState() => ModelDownloadDialogState();
}

class ModelDownloadDialogState extends State<ModelDownloadDialog> {
  _DownloadState _state = _DownloadState.prompt;
  ModelDownload? _download;
  int _received = 0;
  int _total = -1;
  String? _error;
  DateTime? _startTime;

  @override
  void dispose() {
    if (_state == _DownloadState.downloading) {
      _download?.cancel();
    }
    super.dispose();
  }

  void _startDownload() {
    setState(() {
      _state = _DownloadState.downloading;
      _startTime = DateTime.now();
    });

    _download = ModelManager.download(
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _received = received;
          _total = total;
        });
      },
      onComplete: () {
        if (!mounted) return;
        setState(() => _state = _DownloadState.complete);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _state = _DownloadState.error;
          _error = error;
        });
      },
    );
  }

  void _cancel() {
    _download?.cancel();
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

  String _formatSpeed() {
    if (_startTime == null || _received == 0) return '';
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    if (elapsed == 0) return '';
    final bytesPerSec = _received / elapsed;
    return '${_formatBytes(bytesPerSec.round())}/s';
  }

  double get _progress {
    if (_total <= 0) return 0;
    return (_received / _total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

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
              child: switch (_state) {
                _DownloadState.prompt => _buildPrompt(theme),
                _DownloadState.downloading => _buildProgress(theme),
                _DownloadState.complete => _buildComplete(theme),
                _DownloadState.error => _buildError(theme),
              },
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

  Widget _buildProgress(BolonTheme theme) {
    final percent = (_progress * 100).toStringAsFixed(0);
    final speed = _formatSpeed();

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
            value: _total > 0 ? _progress : null,
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
              '${_formatBytes(_received)}${_total > 0 ? ' / ${_formatBytes(_total)}' : ''}',
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              _total > 0 ? '$percent%  $speed' : speed,
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
          onTap: widget.onDismiss,
        ),
      ],
    );
  }

  Widget _buildError(BolonTheme theme) {
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
          _error ?? 'Unknown error',
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
              onTap: _startDownload,
            ),
          ],
        ),
      ],
    );
  }
}

enum _DownloadState { prompt, downloading, complete, error }

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/model_manager.dart';
import '../../../core/theme/bolan_theme.dart';
import '../../../providers/model_download_provider.dart';

/// Inline card for local model size selection, download, and status.
class LocalModelCard extends ConsumerStatefulWidget {
  final BolonTheme theme;
  final String activeSize;
  final VoidCallback onChanged;
  final ValueChanged<String> onSizeChanged;

  const LocalModelCard({
    super.key,
    required this.theme,
    required this.activeSize,
    required this.onChanged,
    required this.onSizeChanged,
  });

  @override
  ConsumerState<LocalModelCard> createState() => _LocalModelCardState();
}

class _LocalModelCardState extends ConsumerState<LocalModelCard> {
  ModelSize _selectedSize = ModelSize.small;
  VoidCallback? _onCompleteCallback;
  // Cached notifier reference. Riverpod forbids `ref` access in
  // dispose, so we save the notifier from initState and use this
  // reference to detach our callback at teardown.
  ModelDownloadNotifier? _downloadNotifier;

  @override
  void initState() {
    super.initState();
    final dl = ref.read(modelDownloadProvider);
    _downloadNotifier = dl;
    if (dl.state.downloading || dl.state.paused) {
      _selectedSize = dl.state.size;
    } else {
      _selectedSize = ModelSize.values.firstWhere(
        (s) => s.name == widget.activeSize,
        orElse: () => ModelManager.downloadedSize() ?? ModelSize.small,
      );
    }
    _onCompleteCallback = () {
      // The download notifier is global and outlives this card. If
      // the user navigates away from Settings before the download
      // finishes, the closure can fire on a disposed widget — guard
      // and bail.
      if (!mounted) return;
      widget.onSizeChanged(_selectedSize.name);
      widget.onChanged();
    };
    dl.onComplete = _onCompleteCallback;
  }

  @override
  void dispose() {
    // Detach our completion callback from the global notifier so it
    // doesn't reach back into a defunct State after the user leaves
    // Settings while a download is still running. Identity check
    // prevents clearing a newer instance's callback if the card was
    // recreated after we registered ours.
    final dl = _downloadNotifier;
    if (dl != null && identical(dl.onComplete, _onCompleteCallback)) {
      dl.onComplete = null;
    }
    super.dispose();
  }

  bool get _isSelectedDownloaded =>
      ModelManager.isModelDownloaded(_selectedSize);

  bool get _hasPartial => hasPartialDownload(_selectedSize);

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final dl = ref.watch(modelDownloadProvider);
    final dlState = dl.state;
    final isActiveDownload =
        (dlState.downloading || dlState.paused) && dlState.size == _selectedSize;
    final t = widget.theme;
    final info = modelInfoMap[_selectedSize]!;
    final configuredSize = ModelSize.values.firstWhere(
      (s) => s.name == widget.activeSize,
      orElse: () => ModelSize.small,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.statusChipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final size in ModelSize.values) ...[
                if (size != ModelSize.values.first)
                  const SizedBox(width: 6),
                _ModelSizeChip(
                  size: size,
                  isSelected: _selectedSize == size,
                  isDownloaded: ModelManager.isModelDownloaded(size),
                  theme: t,
                  onTap: dlState.downloading
                      ? null
                      : () {
                          setState(() => _selectedSize = size);
                          if (ModelManager.isModelDownloaded(size)) {
                            widget.onSizeChanged(size.name);
                          }
                        },
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          Text(
            info.description,
            style: TextStyle(
              color: t.foreground,
              fontFamily: t.fontFamily,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Download: ${info.downloadSize}  ·  RAM: ${info.ramRequired}',
            style: TextStyle(
              color: t.dimForeground,
              fontFamily: t.fontFamily,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
          if (_selectedSize == ModelSize.xl)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: t.ansiYellow),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This model requires more memory and may be noticeably slower on machines with limited RAM or no dedicated GPU.',
                      style: TextStyle(
                        color: t.ansiYellow,
                        fontFamily: t.fontFamily,
                        fontSize: 10,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          Row(
            children: [
              if (_isSelectedDownloaded && configuredSize == _selectedSize)
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: Color(0xFF00FF92)),
                    const SizedBox(width: 6),
                    Text(
                      'Active  ·  ${_formatBytes(ModelManager.modelFileSize(_selectedSize))}',
                      style: TextStyle(
                        color: t.dimForeground,
                        fontFamily: t.fontFamily,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                )
              else if (_isSelectedDownloaded)
                Text(
                  'Downloaded  ·  ${_formatBytes(ModelManager.modelFileSize(_selectedSize))}',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                )
              else if (_hasPartial && !isActiveDownload)
                Text(
                  'Paused  ·  ${_formatBytes(partialDownloadSize(_selectedSize))} downloaded',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              const Spacer(),
              if (_isSelectedDownloaded && !isActiveDownload)
                GestureDetector(
                  onTap: () async {
                    await ModelManager.deleteModel(_selectedSize);
                    setState(() {});
                    widget.onChanged();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: t.exitFailureFg,
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              if (!_isSelectedDownloaded && !isActiveDownload)
                GestureDetector(
                  onTap: () {
                    final n = ref.read(modelDownloadProvider);
                    // Reuse the mounted-guarded closure from initState
                    // (also tracked for cleanup in dispose) instead of
                    // installing a fresh unguarded one on every click.
                    n.onComplete = _onCompleteCallback;
                    if (dlState.paused && dlState.size == _selectedSize) {
                      n.resume();
                    } else {
                      n.start(_selectedSize);
                    }
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF92),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (dlState.paused && dlState.size == _selectedSize) || _hasPartial
                            ? 'Resume'
                            : 'Download',
                        style: TextStyle(
                          color: t.background,
                          fontFamily: t.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isActiveDownload && dlState.downloading) ...[
                GestureDetector(
                  onTap: () => ref.read(modelDownloadProvider).pause(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Pause',
                      style: TextStyle(
                        color: t.dimForeground,
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => ref.read(modelDownloadProvider).cancel(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: t.exitFailureFg,
                        fontFamily: t.fontFamily,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (isActiveDownload) ...[
            const SizedBox(height: 10),
            if (dlState.phaseCount > 1 && dlState.phase != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Step ${dlState.phaseIndex} of ${dlState.phaseCount}  ·  ${dlState.phaseLabel}',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: dlState.total > 0 ? dlState.progress : null,
                minHeight: 4,
                backgroundColor: t.blockBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00FF92)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatBytes(dlState.received)}${dlState.total > 0 ? ' / ${_formatBytes(dlState.total)}  ${(dlState.progress * 100).toStringAsFixed(0)}%' : ''}',
              style: TextStyle(
                color: t.dimForeground,
                fontFamily: t.fontFamily,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          ],

          if (dlState.error != null && dlState.size == _selectedSize)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 14, color: t.exitFailureFg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Download failed. Tap Download to retry.\n${dlState.error}',
                      style: TextStyle(
                        color: t.exitFailureFg,
                        fontFamily: t.fontFamily,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelSizeChip extends StatelessWidget {
  final ModelSize size;
  final bool isSelected;
  final bool isDownloaded;
  final BolonTheme theme;
  final VoidCallback? onTap;

  const _ModelSizeChip({
    required this.size,
    required this.isSelected,
    required this.isDownloaded,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = modelInfoMap[size]!;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor:
            onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? theme.blockBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00FF92)
                  : theme.blockBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDownloaded)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child:
                      Icon(Icons.check, size: 12, color: Color(0xFF00FF92)),
                ),
              Text(
                info.label,
                style: TextStyle(
                  color: isSelected ? theme.foreground : theme.dimForeground,
                  fontFamily: theme.fontFamily,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

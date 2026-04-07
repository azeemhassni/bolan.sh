import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai/model_manager.dart';

/// Download progress state exposed to UI.
class ModelDownloadState {
  final bool downloading;
  final bool paused;
  final int received;
  final int total;
  final String? error;
  final ModelSize size;
  final bool complete;

  const ModelDownloadState({
    this.downloading = false,
    this.paused = false,
    this.received = 0,
    this.total = -1,
    this.error,
    this.size = ModelSize.small,
    this.complete = false,
  });

  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;

  ModelDownloadState copyWith({
    bool? downloading,
    bool? paused,
    int? received,
    int? total,
    String? error,
    ModelSize? size,
    bool? complete,
    bool clearError = false,
  }) {
    return ModelDownloadState(
      downloading: downloading ?? this.downloading,
      paused: paused ?? this.paused,
      received: received ?? this.received,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
      size: size ?? this.size,
      complete: complete ?? this.complete,
    );
  }
}

/// App-wide notifier that owns the model download lifecycle.
///
/// Lives in the Riverpod provider tree so downloads survive navigation
/// between screens (Settings, terminal, etc.).
class ModelDownloadNotifier extends ChangeNotifier {
  ModelDownloadState _state = const ModelDownloadState();
  ModelDownload? _download;

  /// Callback invoked when a download completes, so the caller can
  /// persist the selected size into config, etc.
  VoidCallback? onComplete;

  ModelDownloadState get state => _state;

  void _update(ModelDownloadState s) {
    _state = s;
    notifyListeners();
  }

  void start(ModelSize size) {
    _download?.cancel();
    final hasPartial = hasPartialDownload(size);
    _update(ModelDownloadState(
      downloading: true,
      size: size,
      received: hasPartial ? partialDownloadSize(size) : 0,
    ));

    _download = ModelManager.download(
      size: size,
      onProgress: (received, total) {
        _update(_state.copyWith(received: received, total: total));
      },
      onComplete: () {
        _update(_state.copyWith(downloading: false, complete: true));
        onComplete?.call();
      },
      onError: (error) {
        _update(_state.copyWith(downloading: false, error: error));
      },
    );
  }

  void pause() {
    _download?.pause();
    _update(_state.copyWith(downloading: false, paused: true));
  }

  void resume() {
    if (_download != null) {
      _download!.resume();
      _update(_state.copyWith(
        downloading: true,
        paused: false,
        clearError: true,
      ));
    } else {
      // Download handle was lost — restart with resume support
      start(_state.size);
    }
  }

  void cancel() {
    _download?.cancel();
    _download = null;
    _update(const ModelDownloadState());
  }

  /// Reset state after the UI has acknowledged completion.
  void clearComplete() {
    if (_state.complete) {
      _update(const ModelDownloadState());
    }
  }

  @override
  void dispose() {
    _download?.pause();
    super.dispose();
  }
}

final modelDownloadProvider =
    ChangeNotifierProvider<ModelDownloadNotifier>((ref) {
  return ModelDownloadNotifier();
});

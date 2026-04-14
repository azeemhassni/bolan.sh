import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai/model_manager.dart';

/// Which artifact is currently being downloaded.
enum DownloadPhase {
  /// The shared llamafile binary (downloaded once, reused across sizes).
  runtime,

  /// The GGUF model weights for the selected [ModelSize].
  model,
}

/// Download progress state exposed to UI.
class ModelDownloadState {
  final bool downloading;
  final bool paused;
  final int received;
  final int total;
  final String? error;
  final ModelSize size;
  final bool complete;

  /// The file currently downloading. `null` before start and after the
  /// last phase completes.
  final DownloadPhase? phase;

  /// 1-based index of [phase] within the sequence (1 or 2).
  final int phaseIndex;

  /// Total number of phases the sequence will run. Usually 1 (just the
  /// model — runtime already installed) or 2 (runtime + model).
  final int phaseCount;

  const ModelDownloadState({
    this.downloading = false,
    this.paused = false,
    this.received = 0,
    this.total = -1,
    this.error,
    this.size = ModelSize.small,
    this.complete = false,
    this.phase,
    this.phaseIndex = 0,
    this.phaseCount = 0,
  });

  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;

  /// Human label for the current phase, e.g. "Runtime" / "Model".
  String get phaseLabel {
    switch (phase) {
      case DownloadPhase.runtime:
        return 'Runtime';
      case DownloadPhase.model:
        return 'Model';
      case null:
        return '';
    }
  }

  ModelDownloadState copyWith({
    bool? downloading,
    bool? paused,
    int? received,
    int? total,
    String? error,
    ModelSize? size,
    bool? complete,
    DownloadPhase? phase,
    int? phaseIndex,
    int? phaseCount,
    bool clearError = false,
    bool clearPhase = false,
  }) {
    return ModelDownloadState(
      downloading: downloading ?? this.downloading,
      paused: paused ?? this.paused,
      received: received ?? this.received,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
      size: size ?? this.size,
      complete: complete ?? this.complete,
      phase: clearPhase ? null : (phase ?? this.phase),
      phaseIndex: phaseIndex ?? this.phaseIndex,
      phaseCount: phaseCount ?? this.phaseCount,
    );
  }
}

/// App-wide notifier that owns the model download lifecycle.
///
/// Lives in the Riverpod provider tree so downloads survive navigation
/// between screens (Settings, terminal, etc.).
///
/// Runs as a sequence of phases — [DownloadPhase.runtime] (if the
/// llamafile binary is missing) followed by [DownloadPhase.model] (if
/// the requested size isn't on disk). Phases that are already
/// satisfied are skipped, so users who already have a model on disk
/// but are missing the runtime only re-download the runtime.
class ModelDownloadNotifier extends ChangeNotifier {
  ModelDownloadState _state = const ModelDownloadState();
  ModelDownload? _current;
  List<DownloadPhase> _phases = const [];
  int _phaseIdx = 0;

  /// Callback invoked when the whole sequence completes, so the caller
  /// can persist the selected size into config, etc.
  VoidCallback? onComplete;

  ModelDownloadState get state => _state;

  void _update(ModelDownloadState s) {
    _state = s;
    notifyListeners();
  }

  /// Begins the phased download for [size]. Phases already satisfied
  /// on disk are skipped. If everything is already present, the state
  /// is flipped to `complete` and [onComplete] fires immediately.
  void start(ModelSize size) {
    _current?.cancel();

    final phases = <DownloadPhase>[];
    if (!ModelManager.isRuntimeDownloaded()) phases.add(DownloadPhase.runtime);
    if (!hasModelOnDisk(size)) phases.add(DownloadPhase.model);

    if (phases.isEmpty) {
      _update(_state.copyWith(
        downloading: false,
        complete: true,
        size: size,
        clearPhase: true,
        phaseIndex: 0,
        phaseCount: 0,
        clearError: true,
      ));
      onComplete?.call();
      return;
    }

    _phases = phases;
    _phaseIdx = 0;
    _update(ModelDownloadState(
      downloading: true,
      size: size,
      phase: phases.first,
      phaseIndex: 1,
      phaseCount: phases.length,
      received: _partialBytesFor(phases.first, size),
    ));
    _runCurrentPhase();
  }

  void _runCurrentPhase() {
    final phase = _phases[_phaseIdx];
    final isLast = _phaseIdx == _phases.length - 1;

    void handleComplete() {
      if (isLast) {
        _current = null;
        _update(_state.copyWith(
          downloading: false,
          complete: true,
          clearPhase: true,
          phaseIndex: 0,
          phaseCount: 0,
        ));
        onComplete?.call();
      } else {
        _phaseIdx++;
        final next = _phases[_phaseIdx];
        _update(_state.copyWith(
          phase: next,
          phaseIndex: _phaseIdx + 1,
          received: _partialBytesFor(next, _state.size),
          total: -1,
        ));
        _runCurrentPhase();
      }
    }

    void handleProgress(int received, int total) {
      _update(_state.copyWith(received: received, total: total));
    }

    void handleError(String error) {
      _current = null;
      _update(_state.copyWith(downloading: false, error: error));
    }

    switch (phase) {
      case DownloadPhase.runtime:
        _current = ModelManager.downloadRuntime(
          onProgress: handleProgress,
          onComplete: handleComplete,
          onError: handleError,
        );
      case DownloadPhase.model:
        _current = ModelManager.download(
          size: _state.size,
          onProgress: handleProgress,
          onComplete: handleComplete,
          onError: handleError,
        );
    }
  }

  int _partialBytesFor(DownloadPhase phase, ModelSize size) {
    switch (phase) {
      case DownloadPhase.runtime:
        return hasPartialRuntimeDownload() ? partialRuntimeDownloadSize() : 0;
      case DownloadPhase.model:
        return hasPartialDownload(size) ? partialDownloadSize(size) : 0;
    }
  }

  void pause() {
    _current?.pause();
    _update(_state.copyWith(downloading: false, paused: true));
  }

  void resume() {
    if (_current != null) {
      _current!.resume();
      _update(_state.copyWith(
        downloading: true,
        paused: false,
        clearError: true,
      ));
    } else {
      // Sub-download handle was lost — restart the sequence; unfinished
      // phases will pick up from their .part files automatically.
      start(_state.size);
    }
  }

  void cancel() {
    _current?.cancel();
    _current = null;
    _phases = const [];
    _phaseIdx = 0;
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
    _current?.pause();
    super.dispose();
  }
}

/// Whether a completed model file exists on disk for [size]. Lighter
/// than [ModelManager.isModelDownloaded] because it does not require
/// the runtime to also be present.
bool hasModelOnDisk(ModelSize size) {
  return File(ModelManager.modelPath(size)).existsSync();
}

final modelDownloadProvider =
    ChangeNotifierProvider<ModelDownloadNotifier>((ref) {
  return ModelDownloadNotifier();
});

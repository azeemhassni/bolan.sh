import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/config_loader.dart';
import '../core/update/update_checker.dart';
import '../core/update/update_downloader.dart';
import '../core/update/update_installer.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  verifying,
  installing,
  readyToRestart,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final String? latestVersion;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? checksumUrl;
  final int received;
  final int total;
  final String? error;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.latestVersion,
    this.releaseNotes,
    this.downloadUrl,
    this.checksumUrl,
    this.received = 0,
    this.total = -1,
    this.error,
  });

  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;

  UpdateState copyWith({
    UpdateStatus? status,
    String? latestVersion,
    String? releaseNotes,
    String? downloadUrl,
    String? checksumUrl,
    int? received,
    int? total,
    String? error,
    bool clearError = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      checksumUrl: checksumUrl ?? this.checksumUrl,
      received: received ?? this.received,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// App-wide notifier that owns the update lifecycle.
///
/// Lives in the Riverpod provider tree so state survives navigation.
class UpdateNotifier extends ChangeNotifier {
  UpdateState _state = const UpdateState();
  final UpdateChecker _checker = UpdateChecker();
  UpdateDownload? _download;
  ConfigLoader? _configLoader;

  UpdateState get state => _state;

  void _update(UpdateState s) {
    _state = s;
    notifyListeners();
  }

  void setConfigLoader(ConfigLoader loader) {
    _configLoader = loader;
  }

  /// Check GitHub for a newer release.
  Future<void> check({bool force = false}) async {
    if (_configLoader == null) return;
    if (_state.status == UpdateStatus.checking) return;

    _update(const UpdateState(status: UpdateStatus.checking));

    try {
      final info = await _checker.check(_configLoader!, force: force);
      if (info == null) {
        _update(const UpdateState(status: UpdateStatus.idle));
      } else {
        _update(UpdateState(
          status: UpdateStatus.available,
          latestVersion: info.version,
          releaseNotes: info.releaseNotes,
          downloadUrl: info.downloadUrl,
          checksumUrl: info.checksumUrl,
        ));
      }
    } on Exception catch (e) {
      if (force) {
        // Only show errors on manual checks
        _update(UpdateState(
          status: UpdateStatus.error,
          error: 'Could not check for updates: $e',
        ));
      } else {
        _update(const UpdateState(status: UpdateStatus.idle));
      }
    }
  }

  /// Start downloading the update artifact.
  void download() {
    if (_state.downloadUrl == null) return;

    final fileName = Uri.parse(_state.downloadUrl!).pathSegments.last;
    final home = Platform.environment['HOME'] ?? '';
    final targetPath = '$home/.config/bolan/updates/$fileName';

    _update(_state.copyWith(status: UpdateStatus.downloading, received: 0));

    _download = UpdateDownload(
      url: _state.downloadUrl!,
      targetPath: targetPath,
      onProgress: (received, total) {
        _update(_state.copyWith(received: received, total: total));
      },
      onComplete: () {
        _update(_state.copyWith(status: UpdateStatus.verifying));
        _verify(targetPath);
      },
      onError: (error) {
        _update(_state.copyWith(
          status: UpdateStatus.error,
          error: 'Download failed: $error',
        ));
      },
    );
  }

  Future<void> _verify(String filePath) async {
    try {
      final ok = await UpdateInstaller.verify(
        filePath: filePath,
        checksumUrl: _state.checksumUrl,
      );
      if (!ok) {
        // Delete the bad download
        final f = File(filePath);
        if (f.existsSync()) f.deleteSync();
        _update(_state.copyWith(
          status: UpdateStatus.error,
          error: Platform.isMacOS
              ? 'The update could not be verified. The code signature '
                  'or team identity does not match. This may indicate '
                  'a tampered download.'
              : 'Checksum verification failed. The download may be '
                  'corrupted. Please try again.',
        ));
        return;
      }
      _update(_state.copyWith(status: UpdateStatus.installing));
      await _install(filePath);
    } on Exception catch (e) {
      _update(_state.copyWith(
        status: UpdateStatus.error,
        error: 'Verification failed: $e',
      ));
    }
  }

  Future<void> _install(String filePath) async {
    try {
      await UpdateInstaller.install(filePath: filePath);
      _update(_state.copyWith(status: UpdateStatus.readyToRestart));
    } on Exception catch (e) {
      _update(_state.copyWith(
        status: UpdateStatus.error,
        error: 'Installation failed: $e',
      ));
    }
  }

  /// Restart the app into the newly installed version.
  Future<void> restart() async {
    await UpdateInstaller.restart();
  }

  /// Mark this version as skipped so the user isn't prompted again.
  Future<void> skipVersion() async {
    if (_configLoader != null && _state.latestVersion != null) {
      final config = _configLoader!.config;
      await _configLoader!.save(config.copyWith(
        update: config.update.copyWith(
          skippedVersion: _state.latestVersion ?? '',
        ),
      ));
    }
    _update(const UpdateState(status: UpdateStatus.idle));
  }

  /// Dismiss the update dialog without skipping.
  void dismiss() {
    _download?.cancel();
    _download = null;
    _update(const UpdateState(status: UpdateStatus.idle));
  }

  void cancelDownload() {
    _download?.cancel();
    _download = null;
    _update(_state.copyWith(
      status: UpdateStatus.available,
      received: 0,
      total: -1,
    ));
  }

  @override
  void dispose() {
    _download?.pause();
    super.dispose();
  }
}

final updateProvider = ChangeNotifierProvider<UpdateNotifier>((ref) {
  return UpdateNotifier();
});

import 'dart:async';
import 'dart:io';

/// Manages the local AI model — download, status, path.
///
/// The model is stored at `~/.config/bolan/models/bolan-ai.llamafile`.
/// It's a single executable file containing the LLM runtime and weights.
class ModelManager {
  ModelManager._();

  static const _modelFileName = 'bolan-ai.llamafile';
  static const defaultDownloadUrl =
      'https://github.com/azeemhassni/ai.bolan.sh/releases/latest/download/$_modelFileName';

  /// Returns the full path to the model file.
  static String modelPath() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/bolan/models/$_modelFileName';
  }

  /// Whether the model file exists on disk.
  static bool isModelDownloaded() {
    return File(modelPath()).existsSync();
  }

  /// Returns the model file size in bytes, or 0 if not downloaded.
  static int modelSize() {
    final file = File(modelPath());
    return file.existsSync() ? file.lengthSync() : 0;
  }

  /// Deletes the downloaded model.
  static Future<void> deleteModel() async {
    final file = File(modelPath());
    if (file.existsSync()) await file.delete();
  }

  /// Downloads the model from [url] with progress reporting.
  ///
  /// [onProgress] receives (bytesReceived, totalBytes). If totalBytes
  /// is -1, the content length is unknown.
  ///
  /// Returns a [ModelDownload] handle that can be used to cancel.
  static ModelDownload download({
    String url = defaultDownloadUrl,
    required void Function(int received, int total) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) {
    final download = ModelDownload._(
      url: url,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );
    download._start();
    return download;
  }
}

/// Handle for an in-progress model download. Supports cancellation.
class ModelDownload {
  final String _url;
  final void Function(int received, int total) _onProgress;
  final void Function() _onComplete;
  final void Function(String error) _onError;
  bool _cancelled = false;
  HttpClient? _client;

  ModelDownload._({
    required String url,
    required void Function(int received, int total) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  })  : _url = url,
        _onProgress = onProgress,
        _onComplete = onComplete,
        _onError = onError;

  /// Cancels the download and deletes any partial file.
  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<void> _start() async {
    try {
      final path = ModelManager.modelPath();
      final dir = Directory(File(path).parent.path);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      _client = HttpClient();
      final uri = Uri.parse(_url);
      var request = await _client!.getUrl(uri);
      var response = await request.close();

      // Follow redirects manually (GitHub releases redirect)
      while (response.isRedirect) {
        final location = response.headers.value('location');
        if (location == null) break;
        request = await _client!.getUrl(Uri.parse(location));
        response = await request.close();
      }

      final total = response.contentLength;
      var received = 0;

      final file = File(path);
      final sink = file.openWrite();

      await for (final chunk in response) {
        if (_cancelled) {
          await sink.close();
          if (file.existsSync()) file.deleteSync();
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        _onProgress(received, total);
      }

      await sink.close();
      _client?.close();

      if (_cancelled) {
        if (file.existsSync()) file.deleteSync();
        return;
      }

      // Make executable
      if (Platform.isMacOS || Platform.isLinux) {
        await Process.run('chmod', ['+x', path]);
      }

      _onComplete();
    } on Exception catch (e) {
      if (!_cancelled) {
        _onError(e.toString());
      }
    }
  }
}

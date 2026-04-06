import 'dart:async';
import 'dart:io';

/// Manages the local AI model — download, status, path.
///
/// The model is stored at `~/.config/bolan/models/bolan-ai.llamafile`.
/// It's a single executable file containing the LLM runtime and weights.
class ModelManager {
  ModelManager._();

  static const _runtimeFileName = 'llamafile';
  static const _modelFileName = 'bolan-ai.gguf';
  static const defaultRuntimeUrl =
      'https://github.com/azeemhassni/ai.bolan.sh/releases/latest/download/$_runtimeFileName';
  static const defaultModelUrl =
      'https://github.com/azeemhassni/ai.bolan.sh/releases/latest/download/$_modelFileName';

  /// Returns the directory for model files.
  static String modelsDir() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/bolan/models';
  }

  /// Returns the full path to the llamafile runtime binary.
  static String runtimePath() => '${modelsDir()}/$_runtimeFileName';

  /// Returns the full path to the GGUF model weights.
  static String modelPath() => '${modelsDir()}/$_modelFileName';

  /// Whether both the runtime and model exist on disk.
  static bool isModelDownloaded() {
    return File(runtimePath()).existsSync() &&
        File(modelPath()).existsSync();
  }

  /// Returns the combined size of runtime + model in bytes.
  static int modelSize() {
    var size = 0;
    final runtime = File(runtimePath());
    final model = File(modelPath());
    if (runtime.existsSync()) size += runtime.lengthSync();
    if (model.existsSync()) size += model.lengthSync();
    return size;
  }

  /// Deletes both the runtime and model files.
  static Future<void> deleteModel() async {
    final runtime = File(runtimePath());
    final model = File(modelPath());
    if (runtime.existsSync()) await runtime.delete();
    if (model.existsSync()) await model.delete();
  }

  /// Downloads the model from [url] with progress reporting.
  ///
  /// [onProgress] receives (bytesReceived, totalBytes). If totalBytes
  /// is -1, the content length is unknown.
  ///
  /// Returns a [ModelDownload] handle that can be used to cancel.
  static ModelDownload download({
    String url = defaultModelUrl,
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

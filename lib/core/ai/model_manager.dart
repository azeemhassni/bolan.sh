import 'dart:async';
import 'dart:io';

/// Available local model sizes.
enum ModelSize {
  small,
  medium,
  large,
}

/// Metadata for each model size.
class ModelInfo {
  final String label;
  final String modelName;
  final String fileName;
  final String downloadUrl;
  final String downloadSize;
  final String ramRequired;
  final String description;

  const ModelInfo({
    required this.label,
    required this.modelName,
    required this.fileName,
    required this.downloadUrl,
    required this.downloadSize,
    required this.ramRequired,
    required this.description,
  });
}

/// Model definitions for each size tier.
const modelInfoMap = <ModelSize, ModelInfo>{
  ModelSize.small: ModelInfo(
    label: 'Small',
    modelName: 'Qwen2.5-Coder-0.5B-Instruct-GGUF',
    fileName: 'qwen2.5-coder-0.5b-instruct-q8_0.gguf',
    downloadUrl:
        'https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q8_0.gguf',
    downloadSize: '~530 MB',
    ramRequired: '~1.2 GB',
    description: 'Fastest, lowest resource usage',
  ),
  ModelSize.medium: ModelInfo(
    label: 'Medium',
    modelName: 'Qwen2.5-Coder-1.5B-Instruct-GGUF',
    fileName: 'qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
    downloadUrl:
        'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
    downloadSize: '~1.0 GB',
    ramRequired: '~1.8 GB',
    description: 'Balanced speed and quality',
  ),
  ModelSize.large: ModelInfo(
    label: 'Large',
    modelName: 'Qwen2.5-Coder-3B-Instruct-GGUF',
    fileName: 'qwen2.5-coder-3b-instruct-q4_k_m.gguf',
    downloadUrl:
        'https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf',
    downloadSize: '~1.9 GB',
    ramRequired: '~3.2 GB',
    description: 'Best quality, needs more RAM',
  ),
};

/// Manages the local AI model — download, status, path.
///
/// Supports multiple model sizes. The runtime (llamafile binary) is shared,
/// only the GGUF model weights differ per size.
class ModelManager {
  ModelManager._();

  static const _runtimeFileName = 'llamafile';
  static const _runtimeUrl =
      'https://github.com/Mozilla-Ocho/llamafile/releases/latest/download/llamafile';

  /// Returns the directory for model files.
  static String modelsDir() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/bolan/models';
  }

  /// Returns the full path to the llamafile runtime binary.
  static String runtimePath() => '${modelsDir()}/$_runtimeFileName';

  /// Returns the full path to the GGUF model weights for [size].
  static String modelPath([ModelSize size = ModelSize.small]) {
    return '${modelsDir()}/${modelInfoMap[size]!.fileName}';
  }

  /// Whether the runtime and model for [size] exist on disk.
  static bool isModelDownloaded([ModelSize size = ModelSize.small]) {
    return File(runtimePath()).existsSync() &&
        File(modelPath(size)).existsSync();
  }

  /// Returns which model size is currently downloaded, or null.
  static ModelSize? downloadedSize() {
    if (!File(runtimePath()).existsSync()) return null;
    for (final entry in modelInfoMap.entries) {
      if (File(modelPath(entry.key)).existsSync()) return entry.key;
    }
    return null;
  }

  /// Returns the model file size in bytes for [size], or 0 if not downloaded.
  static int modelFileSize([ModelSize size = ModelSize.small]) {
    final file = File(modelPath(size));
    return file.existsSync() ? file.lengthSync() : 0;
  }

  /// Deletes the model file for [size]. Keeps the runtime.
  static Future<void> deleteModel([ModelSize size = ModelSize.small]) async {
    final file = File(modelPath(size));
    if (file.existsSync()) await file.delete();
  }

  /// Deletes all model files and the runtime.
  static Future<void> deleteAll() async {
    final dir = Directory(modelsDir());
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Download URL for a model size (from HuggingFace).
  static String downloadUrl(ModelSize size) =>
      modelInfoMap[size]!.downloadUrl;

  /// Download URL for the llamafile runtime.
  static String get runtimeUrl => _runtimeUrl;

  /// Downloads the model for [size] with progress reporting.
  ///
  /// [onProgress] receives (bytesReceived, totalBytes). If totalBytes
  /// is -1, the content length is unknown.
  ///
  /// Returns a [ModelDownload] handle that can be used to cancel.
  static ModelDownload download({
    ModelSize size = ModelSize.small,
    required void Function(int received, int total) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) {
    final download = ModelDownload._(
      url: downloadUrl(size),
      targetPath: modelPath(size),
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
  final String _targetPath;
  final void Function(int received, int total) _onProgress;
  final void Function() _onComplete;
  final void Function(String error) _onError;
  bool _cancelled = false;
  HttpClient? _client;

  ModelDownload._({
    required String url,
    required String targetPath,
    required void Function(int received, int total) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  })  : _url = url,
        _targetPath = targetPath,
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
      final path = _targetPath;
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

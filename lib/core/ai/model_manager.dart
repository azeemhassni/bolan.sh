import 'dart:async';
import 'dart:io';

/// Available local model sizes.
enum ModelSize {
  small,
  medium,
  large,
  xl,
}

/// Metadata for each model size.
class ModelInfo {
  final String label;
  final String modelName;
  final String fileName;
  final String downloadUrl;
  final String downloadSize;
  final String ramRequired;
  final int ramRequiredBytes;
  final String description;

  const ModelInfo({
    required this.label,
    required this.modelName,
    required this.fileName,
    required this.downloadUrl,
    required this.downloadSize,
    required this.ramRequired,
    required this.ramRequiredBytes,
    required this.description,
  });
}

const _gb = 1024 * 1024 * 1024;

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
    ramRequiredBytes: _gb + _gb ~/ 5, // 1.2 GB
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
    ramRequiredBytes: _gb + (_gb * 4) ~/ 5, // 1.8 GB
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
    ramRequiredBytes: _gb * 3 + _gb ~/ 5, // 3.2 GB
    description: 'Best quality, needs more RAM',
  ),
  ModelSize.xl: ModelInfo(
    label: 'XL',
    modelName: 'Qwen2.5-Coder-7B-Instruct-GGUF',
    fileName: 'qwen2.5-coder-7b-instruct-q4_k_m.gguf',
    downloadUrl:
        'https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf',
    downloadSize: '~4.7 GB',
    ramRequired: '~6 GB',
    ramRequiredBytes: _gb * 6, // 6 GB
    description: 'Highest quality, best for complex tasks',
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

/// Handle for an in-progress model download.
///
/// Supports pause, resume, and cancellation. Downloads to a `.part`
/// file and renames on completion. Resume uses HTTP Range headers.
class ModelDownload {
  final String _url;
  final String _targetPath;
  final void Function(int received, int total) _onProgress;
  final void Function() _onComplete;
  final void Function(String error) _onError;
  bool _cancelled = false;
  bool _paused = false;
  HttpClient? _client;
  int _resumeOffset = 0;

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

  String get _partPath => '$_targetPath.part';

  /// Whether the download is currently paused.
  bool get isPaused => _paused;

  /// Pauses the download. The partial file is kept for resuming.
  void pause() {
    _paused = true;
    _client?.close(force: true);
    _client = null;
  }

  /// Resumes a paused download from where it left off.
  void resume() {
    if (!_paused) return;
    _paused = false;
    _cancelled = false;
    _start();
  }

  /// Cancels the download and deletes any partial file.
  void cancel() {
    _cancelled = true;
    _paused = false;
    _client?.close(force: true);
    _client = null;
    final part = File(_partPath);
    if (part.existsSync()) part.deleteSync();
  }

  Future<void> _start() async {
    try {
      final dir = Directory(File(_targetPath).parent.path);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final partFile = File(_partPath);
      _resumeOffset = partFile.existsSync() ? partFile.lengthSync() : 0;

      _client = HttpClient();
      _client!.autoUncompress = false;

      // Resolve the final URL (follow redirects) before setting Range
      var finalUrl = _url;
      final headClient = HttpClient();
      try {
        final headRequest = await headClient.headUrl(Uri.parse(_url));
        headRequest.followRedirects = true;
        headRequest.maxRedirects = 5;
        final headResponse = await headRequest.close().timeout(
              const Duration(seconds: 10),
            );
        finalUrl = headResponse.redirects.isNotEmpty
            ? headResponse.redirects.last.location.toString()
            : _url;
        await headResponse.drain<void>();
      } on Exception {
        // Use original URL if HEAD fails
      } finally {
        headClient.close();
      }

      final request = await _client!.getUrl(Uri.parse(finalUrl));
      if (_resumeOffset > 0) {
        request.headers.set('Range', 'bytes=$_resumeOffset-');
      }
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close();

      // Determine total size
      int total;
      if (response.statusCode == 206) {
        // Partial content — server supports resume
        final range = response.headers.value('content-range');
        if (range != null && range.contains('/')) {
          total = int.tryParse(range.split('/').last) ?? -1;
        } else {
          total = _resumeOffset + response.contentLength;
        }
      } else if (response.statusCode == 200) {
        // Full content — server ignored Range or fresh download
        _resumeOffset = 0;
        total = response.contentLength;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }

      var received = _resumeOffset;
      final sink = partFile.openWrite(
        mode: _resumeOffset > 0 && response.statusCode == 206
            ? FileMode.append
            : FileMode.write,
      );

      await for (final chunk in response) {
        if (_cancelled || _paused) {
          await sink.close();
          _client?.close();
          _client = null;
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        _onProgress(received, total);
      }

      await sink.close();
      _client?.close();
      _client = null;

      if (_cancelled || _paused) return;

      // Rename .part to final path
      final target = File(_targetPath);
      if (target.existsSync()) target.deleteSync();
      partFile.renameSync(_targetPath);

      // Make executable
      if (Platform.isMacOS || Platform.isLinux) {
        await Process.run('chmod', ['+x', _targetPath]);
      }

      _onComplete();
    } on Exception catch (e) {
      if (!_cancelled && !_paused) {
        _onError(e.toString());
      }
    }
  }
}

/// Checks if a partial download exists for [size].
bool hasPartialDownload(ModelSize size) {
  final partPath = '${ModelManager.modelPath(size)}.part';
  return File(partPath).existsSync();
}

/// Returns the size of the partial download in bytes, or 0.
int partialDownloadSize(ModelSize size) {
  final partFile = File('${ModelManager.modelPath(size)}.part');
  return partFile.existsSync() ? partFile.lengthSync() : 0;
}

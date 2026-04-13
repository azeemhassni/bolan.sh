import 'dart:io';

/// Downloads an update artifact with resume support.
///
/// Follows the same pattern as `ModelDownload` in `model_manager.dart`:
/// .part file for resume, HTTP Range headers, pause/resume/cancel.
class UpdateDownload {
  final String _url;
  final String _targetPath;
  final void Function(int received, int total) _onProgress;
  final void Function() _onComplete;
  final void Function(String error) _onError;

  HttpClient? _client;
  bool _paused = false;
  bool _cancelled = false;
  int _resumeOffset = 0;

  String get _partPath => '$_targetPath.part';

  UpdateDownload({
    required String url,
    required String targetPath,
    required void Function(int received, int total) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  })  : _url = url,
        _targetPath = targetPath,
        _onProgress = onProgress,
        _onComplete = onComplete,
        _onError = onError {
    _start();
  }

  void pause() {
    _paused = true;
    _client?.close(force: true);
    _client = null;
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _cancelled = false;
    _start();
  }

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

      // Resolve the final URL (follow GitHub redirects)
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

      int total;
      if (response.statusCode == 206) {
        final range = response.headers.value('content-range');
        if (range != null && range.contains('/')) {
          total = int.tryParse(range.split('/').last) ?? -1;
        } else {
          total = _resumeOffset + response.contentLength;
        }
      } else if (response.statusCode == 200) {
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

      _onComplete();
    } on Exception catch (e) {
      if (!_cancelled && !_paused) {
        _onError(e.toString());
      }
    }
  }
}

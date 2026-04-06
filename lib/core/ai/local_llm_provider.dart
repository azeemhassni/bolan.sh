import 'dart:io';

import 'ai_provider.dart';
import 'model_manager.dart';
import 'openai_compatible_provider.dart';

/// AI provider that runs a local llamafile LLM server.
///
/// On first query, starts the llamafile as an HTTP server on port 8847.
/// Subsequent queries reuse the running server. The server is stopped
/// when [dispose] is called (typically on app exit).
///
/// The llamafile exposes an OpenAI-compatible `/v1/chat/completions`
/// endpoint, so inference is delegated to [OpenAiCompatibleProvider].
class LocalLlmProvider implements AiProvider {
  static const _port = 8847;
  static const _baseUrl = 'http://127.0.0.1:$_port';

  final ModelSize _preferredSize;

  /// The model size this provider is configured to use.
  ModelSize get preferredSize => _preferredSize;
  Process? _serverProcess;
  bool _starting = false;
  OpenAiCompatibleProvider? _client;

  LocalLlmProvider({ModelSize preferredSize = ModelSize.small})
      : _preferredSize = preferredSize;

  @override
  String get displayName => 'Local LLM';

  @override
  Future<bool> isAvailable() async {
    return ModelManager.downloadedSize() != null;
  }

  @override
  Future<String> generateContent(String prompt) async {
    // ignore: avoid_print
    print('[AI] LocalLLM preferredSize=${_preferredSize.name} '
        'activeSize=${ModelManager.downloadedSize()?.name}');
    await _ensureServerRunning();
    return _client!.generateContent(prompt);
  }

  /// Starts the llamafile server if not already running.
  Future<void> _ensureServerRunning() async {
    if (_client != null && await _client!.isAvailable()) return;
    if (_starting) {
      // Wait for another caller's start to finish
      while (_starting) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      return;
    }

    _starting = true;
    try {
      final runtimePath = ModelManager.runtimePath();
      // Use preferred size if downloaded, fall back to any available
      final size = ModelManager.isModelDownloaded(_preferredSize)
          ? _preferredSize
          : ModelManager.downloadedSize();
      if (size == null || !File(runtimePath).existsSync()) {
        throw Exception(
          'Local AI model not downloaded. Go to Settings > AI to download it.',
        );
      }

      // Kill any stale server on the same port
      await _killStaleServer();

      _serverProcess = await Process.start(
        runtimePath,
        [
          '--server',
          '--port', '$_port',
          '--host', '127.0.0.1',
          '-m', ModelManager.modelPath(size),
        ],
        mode: ProcessStartMode.detached,
      );

      _client = OpenAiCompatibleProvider(
        baseUrl: _baseUrl,
        model: 'local',
        name: 'Local LLM',
        temperature: 0,
      );

      // Wait for the server to be ready (health check)
      await _waitForServer();
    } finally {
      _starting = false;
    }
  }

  /// Polls the server until it responds or times out.
  Future<void> _waitForServer() async {
    const maxWait = Duration(seconds: 30);
    const pollInterval = Duration(milliseconds: 500);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      if (await _client!.isAvailable()) return;
      await Future<void>.delayed(pollInterval);
    }

    throw Exception('Local LLM server failed to start within 30s');
  }

  /// Kills any process already listening on the port.
  Future<void> _killStaleServer() async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run(
          'lsof',
          ['-ti', ':$_port'],
        );
        final pids = (result.stdout as String)
            .trim()
            .split('\n')
            .where((s) => s.isNotEmpty);
        for (final pid in pids) {
          Process.killPid(int.parse(pid));
        }
      }
    } on Exception {
      // Best effort
    }
  }

  /// Stops the server process.
  void dispose() {
    _serverProcess?.kill();
    _serverProcess = null;
    _client = null;
  }
}

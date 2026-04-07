import 'dart:io';

import '../system/system_memory.dart';
import 'ai_provider.dart';
import 'model_manager.dart';
import 'openai_compatible_provider.dart';

/// Async confirmation hook invoked by [LocalLlmProvider] when the model
/// is about to be loaded into memory and available RAM is below the
/// model's recommended requirement. Should return `true` to proceed,
/// `false` to abort. Typically registered by the UI layer.
typedef MemoryConfirmCallback = Future<bool> Function({
  required String modelLabel,
  required int requiredBytes,
  required int availableBytes,
  int? totalBytes,
});

/// AI provider that runs a local llamafile LLM server.
///
/// On first query, starts the llamafile as an HTTP server on port 8847.
/// Subsequent queries reuse the running server. The server is stopped
/// when [dispose] is called (typically on app exit).
///
/// The llamafile exposes an OpenAI-compatible `/v1/chat/completions`
/// endpoint, so inference is delegated to [OpenAiCompatibleProvider].
class LocalLlmProvider implements AiProvider {
  /// Set by the UI to handle low-memory confirmations before the
  /// server starts. If null, the check is skipped (no UI to ask).
  static MemoryConfirmCallback? memoryConfirmCallback;

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

    // Try once; if the server died externally (killed in Activity
    // Monitor, OOM, etc.) the request will fail with a connection
    // error. Reset state and retry once before surfacing the error.
    for (var attempt = 0; attempt < 2; attempt++) {
      await _ensureServerRunning();
      try {
        return await _client!.generateContent(prompt);
      } on SocketException {
        _invalidate();
        if (attempt == 1) rethrow;
      } on HttpException {
        _invalidate();
        if (attempt == 1) rethrow;
      } on Exception catch (e) {
        // Heuristic: connection-refused style errors can surface as
        // generic Exception messages. Retry only if it looks like one.
        final msg = e.toString().toLowerCase();
        final looksLikeConnFailure = msg.contains('connection') ||
            msg.contains('refused') ||
            msg.contains('closed') ||
            msg.contains('reset by peer') ||
            msg.contains('broken pipe');
        if (!looksLikeConnFailure || attempt == 1) rethrow;
        _invalidate();
      }
    }
    // Unreachable — the loop either returns or rethrows.
    throw StateError('LocalLlmProvider.generateContent: unreachable');
  }

  /// Drops cached server/client state so the next request starts fresh.
  void _invalidate() {
    try {
      _serverProcess?.kill();
    } on Exception {
      // Best effort — process may already be dead.
    }
    _serverProcess = null;
    _client = null;
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

      // Memory safety guard. Two tiers:
      //   - Hard floor: available < model file size + 256 MB headroom →
      //     refuse outright (loading would almost certainly fail/freeze).
      //   - Soft warning: available < ramRequiredBytes (the recommended
      //     working-set figure) → ask the UI to confirm with the user.
      final available = await SystemMemory.availableBytes();
      if (available != null) {
        final info = modelInfoMap[size]!;
        final modelBytes = ModelManager.modelFileSize(size);
        const headroom = 256 * 1024 * 1024; // 256 MB
        if (available < modelBytes + headroom) {
          throw Exception(
            'Not enough free memory to load the local model. '
            '${SystemMemory.format(available)} available, '
            'need at least ${SystemMemory.format(modelBytes + headroom)}. '
            'Close some apps and try again, or pick a smaller model in Settings > AI.',
          );
        }
        if (available < info.ramRequiredBytes &&
            memoryConfirmCallback != null) {
          final total = await SystemMemory.totalBytes();
          final proceed = await memoryConfirmCallback!(
            modelLabel: info.label,
            requiredBytes: info.ramRequiredBytes,
            availableBytes: available,
            totalBytes: total,
          );
          if (!proceed) {
            throw Exception('Local model load cancelled by user.');
          }
        }
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
  Future<void> _killStaleServer() => killStaleLocalLlmServer();

  /// Kills any orphan llamafile server left over from a previous Bolan
  /// run (e.g. force-quit, crash, OS reboot interrupted). Safe to call
  /// at app startup. No-op on Windows.
  static Future<void> killStaleLocalLlmServer() async {
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

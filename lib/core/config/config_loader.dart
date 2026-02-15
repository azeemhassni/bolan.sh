import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toml/toml.dart';

import 'app_config.dart';
import 'config_validator.dart';

/// Loads, watches, and saves the TOML config file.
///
/// Config lives at `~/.config/bolan/config.toml`. If the file doesn't exist,
/// defaults are used. The file is watched for changes and the config is
/// reloaded automatically.
class ConfigLoader extends ChangeNotifier {
  static const _validator = ConfigValidator();

  AppConfig _config = const AppConfig();
  Timer? _watchTimer;

  AppConfig get config => _config;

  /// Loads the config from disk. Creates the config directory if needed.
  Future<void> load() async {
    final file = await _configFile();
    if (await file.exists()) {
      _config = _parseFile(await file.readAsString());
    } else {
      _config = const AppConfig();
    }
    notifyListeners();
  }

  /// Starts watching the config file for changes (polls every 2 seconds).
  void startWatching() {
    _watchTimer?.cancel();
    DateTime? lastModified;

    _watchTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final file = await _configFile();
      if (!await file.exists()) return;

      final modified = await file.lastModified();
      if (lastModified != null && modified != lastModified) {
        await load();
      }
      lastModified = modified;
    });
  }

  /// Stops watching the config file.
  void stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  /// Saves the current config to disk as TOML.
  Future<void> save(AppConfig newConfig) async {
    _config = newConfig;
    final file = await _configFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(_toToml(newConfig));
    notifyListeners();
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }

  AppConfig _parseFile(String content) {
    try {
      final doc = TomlDocument.parse(content);
      final map = doc.toMap();
      return _validator.validate(map);
    } on Exception catch (e) {
      debugPrint('Failed to parse config.toml: $e');
      return const AppConfig();
    }
  }

  Future<File> _configFile() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return File('$home/.config/bolan/config.toml');
    }
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/config.toml');
  }

  String _toToml(AppConfig c) {
    final sb = StringBuffer();
    sb.writeln('theme = "${c.activeTheme}"');
    sb.writeln();

    sb.writeln('[general]');
    if (c.general.shell.isNotEmpty) {
      sb.writeln('shell = "${c.general.shell}"');
    }
    if (c.general.workingDirectory.isNotEmpty) {
      sb.writeln('working_directory = "${c.general.workingDirectory}"');
    }
    sb.writeln('restore_sessions = ${c.general.restoreSessions}');
    sb.writeln();

    sb.writeln('[editor]');
    sb.writeln('font_family = "${c.editor.fontFamily}"');
    sb.writeln('font_size = ${c.editor.fontSize}');
    sb.writeln('line_height = ${c.editor.lineHeight}');
    sb.writeln('cursor_style = "${c.editor.cursorStyle}"');
    sb.writeln('cursor_blink = ${c.editor.cursorBlink}');
    sb.writeln('scrollback_lines = ${c.editor.scrollbackLines}');
    sb.writeln('block_mode = ${c.editor.blockMode}');
    sb.writeln();

    sb.writeln('[ai]');
    sb.writeln('provider = "${c.ai.provider}"');
    if (c.ai.model.isNotEmpty) sb.writeln('model = "${c.ai.model}"');
    sb.writeln('ollama_url = "${c.ai.ollamaUrl}"');
    sb.writeln('gemini_model = "${c.ai.geminiModel}"');
    sb.writeln('openai_model = "${c.ai.openaiModel}"');
    sb.writeln('anthropic_model = "${c.ai.anthropicModel}"');
    sb.writeln('anthropic_mode = "${c.ai.anthropicMode}"');
    sb.writeln('enabled = ${c.ai.enabled}');
    sb.writeln('command_suggestions = ${c.ai.commandSuggestions}');
    sb.writeln('share_history = ${c.ai.shareHistory}');

    return sb.toString();
  }
}

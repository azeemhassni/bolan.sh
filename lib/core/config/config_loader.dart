import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:toml/toml.dart';

import '../workspace/workspace_paths.dart';
import 'app_config.dart';
import 'config_validator.dart';
import 'prompt_style.dart';

/// Loads, watches, and saves the TOML config file.
///
/// Config lives at `~/.config/bolan/config.toml`. If the file doesn't exist,
/// defaults are used. The file is watched for changes and the config is
/// reloaded automatically.
class ConfigLoader extends ChangeNotifier {
  static const _validator = ConfigValidator();

  /// Optional override for the config file path. Used in tests to
  /// avoid touching the user's real config at `~/.config/bolan/config.toml`.
  final String? configPathOverride;

  AppConfig _config = const AppConfig();
  Timer? _watchTimer;

  ConfigLoader({this.configPathOverride});

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
    if (configPathOverride != null) {
      return File(configPathOverride!);
    }
    return WorkspacePaths.configFile();
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
    sb.writeln('notify_long_running = ${c.general.notifyLongRunning}');
    sb.writeln('confirm_on_quit = ${c.general.confirmOnQuit}');
    sb.writeln('inherit_working_directory = ${c.general.inheritWorkingDirectory}');
    sb.writeln('hide_prompt_while_running = ${c.general.hidePromptWhileRunning}');
    sb.writeln('long_running_threshold_seconds = ${c.general.longRunningThresholdSeconds}');
    sb.writeln('prompt_chips = [${c.general.promptChips.map((e) => '"$e"').join(', ')}]');
    if (c.general.startupCommands.isNotEmpty) {
      sb.writeln('startup_commands = [${c.general.startupCommands.map((e) => '"$e"').join(', ')}]');
    }
    sb.writeln();

    sb.writeln('[general.prompt_style]');
    final ps = c.general.promptStyle;
    sb.writeln('preset = "${ps.preset.name}"');
    if (ps.preset == PromptPreset.custom) {
      sb.writeln('chip_shape = "${ps.chipShape.name}"');
      sb.writeln('corner_radius = ${ps.cornerRadius}');
      sb.writeln('border_width = ${ps.borderWidth}');
      sb.writeln('chip_spacing = ${ps.chipSpacing}');
      sb.writeln('chip_padding_h = ${ps.chipPaddingH}');
      sb.writeln('chip_padding_v = ${ps.chipPaddingV}');
      sb.writeln('separator = "${ps.separator.name}"');
      if (ps.separatorChar.isNotEmpty) {
        sb.writeln('separator_char = "${ps.separatorChar}"');
      }
      if (ps.separatorColorHex.isNotEmpty) {
        sb.writeln('separator_color = "${ps.separatorColorHex}"');
      }
      sb.writeln('filled_background = ${ps.filledBackground}');
      sb.writeln('per_segment_colors = ${ps.perSegmentColors}');
      sb.writeln('show_border = ${ps.showBorder}');
      sb.writeln('show_icons = ${ps.showIcons}');
      sb.writeln('font_weight = "${ps.fontWeight}"');
      sb.writeln('inline_input = ${ps.inlineInput}');
      if (ps.promptSymbol.isNotEmpty) {
        sb.writeln('prompt_symbol = "${ps.promptSymbol}"');
      }
    }
    sb.writeln();

    sb.writeln('[editor]');
    sb.writeln('font_family = "${c.editor.fontFamily}"');
    sb.writeln('font_size = ${c.editor.fontSize}');
    sb.writeln('line_height = ${c.editor.lineHeight}');
    sb.writeln('cursor_style = "${c.editor.cursorStyle}"');
    sb.writeln('cursor_blink = ${c.editor.cursorBlink}');
    sb.writeln('scrollback_lines = ${c.editor.scrollbackLines}');
    sb.writeln('block_mode = ${c.editor.blockMode}');
    sb.writeln('ligatures = ${c.editor.ligatures}');
    sb.writeln();

    sb.writeln('[ai]');
    sb.writeln('provider = "${c.ai.provider}"');
    sb.writeln('local_model_size = "${c.ai.localModelSize}"');
    if (c.ai.model.isNotEmpty) sb.writeln('model = "${c.ai.model}"');
    sb.writeln('ollama_url = "${c.ai.ollamaUrl}"');
    sb.writeln('gemini_model = "${c.ai.geminiModel}"');
    sb.writeln('openai_model = "${c.ai.openaiModel}"');
    sb.writeln('anthropic_model = "${c.ai.anthropicModel}"');
    sb.writeln('huggingface_model = "${c.ai.huggingfaceModel}"');
    sb.writeln('anthropic_mode = "${c.ai.anthropicMode}"');
    sb.writeln('enabled = ${c.ai.enabled}');
    sb.writeln('command_suggestions = ${c.ai.commandSuggestions}');
    sb.writeln('smart_history_search = ${c.ai.smartHistorySearch}');
    sb.writeln('share_history = ${c.ai.shareHistory}');
    sb.writeln();

    sb.writeln('[updates]');
    sb.writeln('auto_check = ${c.update.autoCheck}');
    if (c.update.lastCheckTime.isNotEmpty) {
      sb.writeln('last_check_time = "${c.update.lastCheckTime}"');
    }
    if (c.update.skippedVersion.isNotEmpty) {
      sb.writeln('skipped_version = "${c.update.skippedVersion}"');
    }

    if (c.keybindingOverrides.isNotEmpty) {
      sb.writeln();
      sb.writeln('[keybindings]');
      for (final entry in c.keybindingOverrides.entries) {
        sb.writeln('${entry.key.name} = "${entry.value.serialize()}"');
      }
    }

    // Per-workspace overrides for global settings.
    final o = c.overrides;
    if (!o.isEmpty) {
      sb.writeln();
      sb.writeln('[overrides]');
      if (o.themeOverride != null) {
        sb.writeln('theme = "${o.themeOverride}"');
      }
      if (o.fontFamilyOverride != null) {
        sb.writeln('font_family = "${o.fontFamilyOverride}"');
      }
      if (o.fontSizeOverride != null) {
        sb.writeln('font_size = ${o.fontSizeOverride}');
      }
      if (o.lineHeightOverride != null) {
        sb.writeln('line_height = ${o.lineHeightOverride}');
      }
      if (o.keybindingOverrides != null &&
          o.keybindingOverrides!.isNotEmpty) {
        sb.writeln();
        sb.writeln('[overrides.keybindings]');
        for (final entry in o.keybindingOverrides!.entries) {
          sb.writeln('${entry.key.name} = "${entry.value.serialize()}"');
        }
      }
    }

    return sb.toString();
  }
}

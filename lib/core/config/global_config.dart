import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:toml/toml.dart';

import '../workspace/workspace_paths.dart';
import 'app_config.dart';
import 'keybinding.dart';

/// Global settings shared across all workspaces.
///
/// Stored at `~/.config/bolan/global.toml`. Contains editor defaults,
/// theme, keybindings, and update settings. Per-workspace configs can
/// optionally override any of these fields.
class GlobalConfig {
  final EditorConfig editor;
  final String activeTheme;
  final Map<KeyAction, KeyBinding> keybindingOverrides;
  final UpdateConfig update;
  final bool confirmOnQuit;
  final bool notifyLongRunning;
  final int longRunningThresholdSeconds;

  const GlobalConfig({
    this.editor = const EditorConfig(),
    this.activeTheme = 'midnight-cove',
    this.keybindingOverrides = const {},
    this.update = const UpdateConfig(),
    this.confirmOnQuit = true,
    this.notifyLongRunning = true,
    this.longRunningThresholdSeconds = 10,
  });

  GlobalConfig copyWith({
    EditorConfig? editor,
    String? activeTheme,
    Map<KeyAction, KeyBinding>? keybindingOverrides,
    UpdateConfig? update,
    bool? confirmOnQuit,
    bool? notifyLongRunning,
    int? longRunningThresholdSeconds,
  }) =>
      GlobalConfig(
        editor: editor ?? this.editor,
        activeTheme: activeTheme ?? this.activeTheme,
        keybindingOverrides: keybindingOverrides ?? this.keybindingOverrides,
        update: update ?? this.update,
        confirmOnQuit: confirmOnQuit ?? this.confirmOnQuit,
        notifyLongRunning: notifyLongRunning ?? this.notifyLongRunning,
        longRunningThresholdSeconds:
            longRunningThresholdSeconds ?? this.longRunningThresholdSeconds,
      );
}

/// Per-workspace overrides for global settings. Null fields mean
/// "use the global default".
class WorkspaceOverrides {
  final String? themeOverride;
  final String? fontFamilyOverride;
  final double? fontSizeOverride;
  final double? lineHeightOverride;
  final Map<KeyAction, KeyBinding>? keybindingOverrides;

  const WorkspaceOverrides({
    this.themeOverride,
    this.fontFamilyOverride,
    this.fontSizeOverride,
    this.lineHeightOverride,
    this.keybindingOverrides,
  });

  bool get isEmpty =>
      themeOverride == null &&
      fontFamilyOverride == null &&
      fontSizeOverride == null &&
      lineHeightOverride == null &&
      keybindingOverrides == null;

  WorkspaceOverrides copyWith({
    String? themeOverride,
    String? fontFamilyOverride,
    double? fontSizeOverride,
    double? lineHeightOverride,
    Map<KeyAction, KeyBinding>? keybindingOverrides,
    // Sentinel values to clear overrides back to null.
    bool clearTheme = false,
    bool clearFontFamily = false,
    bool clearFontSize = false,
    bool clearLineHeight = false,
    bool clearKeybindings = false,
  }) =>
      WorkspaceOverrides(
        themeOverride:
            clearTheme ? null : (themeOverride ?? this.themeOverride),
        fontFamilyOverride: clearFontFamily
            ? null
            : (fontFamilyOverride ?? this.fontFamilyOverride),
        fontSizeOverride: clearFontSize
            ? null
            : (fontSizeOverride ?? this.fontSizeOverride),
        lineHeightOverride: clearLineHeight
            ? null
            : (lineHeightOverride ?? this.lineHeightOverride),
        keybindingOverrides: clearKeybindings
            ? null
            : (keybindingOverrides ?? this.keybindingOverrides),
      );
}

/// Loads, watches, and saves the global config file.
class GlobalConfigLoader extends ChangeNotifier {
  GlobalConfig _config = const GlobalConfig();
  Timer? _watchTimer;

  GlobalConfig get config => _config;

  static File _file() => File('${WorkspacePaths.rootPath()}/global.toml');

  Future<void> load() async {
    final file = _file();
    if (await file.exists()) {
      _config = _parse(await file.readAsString());
    } else {
      _config = const GlobalConfig();
    }
    notifyListeners();
  }

  /// Creates the global config from an existing per-workspace config
  /// during migration. Only called when `global.toml` doesn't exist.
  Future<void> migrateFrom(AppConfig workspace) async {
    _config = GlobalConfig(
      editor: workspace.editor,
      activeTheme: workspace.activeTheme,
      keybindingOverrides: workspace.keybindingOverrides,
      update: workspace.update,
      confirmOnQuit: workspace.general.confirmOnQuit,
      notifyLongRunning: workspace.general.notifyLongRunning,
      longRunningThresholdSeconds:
          workspace.general.longRunningThresholdSeconds,
    );
    await save(_config);
  }

  Future<void> save(GlobalConfig newConfig) async {
    _config = newConfig;
    final file = _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(_toToml(newConfig));
    notifyListeners();
  }

  void startWatching() {
    _watchTimer?.cancel();
    DateTime? lastModified;
    _watchTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final file = _file();
      if (!await file.exists()) return;
      final modified = await file.lastModified();
      if (lastModified != null && modified != lastModified) {
        await load();
      }
      lastModified = modified;
    });
  }

  void stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }

  GlobalConfig _parse(String content) {
    try {
      final doc = TomlDocument.parse(content).toMap();
      return _validate(doc);
    } on Exception catch (e) {
      debugPrint('Failed to parse global.toml: $e');
      return const GlobalConfig();
    }
  }

  GlobalConfig _validate(Map<String, dynamic> raw) {
    final editor = raw['editor'] as Map<String, dynamic>?;
    final updates = raw['updates'] as Map<String, dynamic>?;
    final keybindings = raw['keybindings'] as Map<String, dynamic>?;

    return GlobalConfig(
      editor: editor != null
          ? EditorConfig(
              fontFamily: _str(editor['font_family'], 'JetBrains Mono'),
              fontSize: _dbl(editor['font_size'], 15.0, min: 8, max: 32),
              lineHeight: _dbl(editor['line_height'], 1.3, min: 1.0, max: 2.5),
              cursorStyle: _oneOf(
                  editor['cursor_style'], ['block', 'underline', 'bar'], 'block'),
              cursorBlink: _bool(editor['cursor_blink'], true),
              scrollbackLines:
                  _int(editor['scrollback_lines'], 15000, min: 100, max: 100000),
              blockMode: _bool(editor['block_mode'], false),
              scrollableBlocks: _bool(editor['scrollable_blocks'], false),
              ligatures: _bool(editor['ligatures'], true),
            )
          : const EditorConfig(),
      activeTheme: _str(raw['theme'], 'midnight-cove'),
      keybindingOverrides: _parseKeybindings(keybindings),
      update: updates != null
          ? UpdateConfig(
              autoCheck: _bool(updates['auto_check'], true),
              lastCheckTime: _str(updates['last_check_time'], ''),
              skippedVersion: _str(updates['skipped_version'], ''),
            )
          : const UpdateConfig(),
      confirmOnQuit: _bool(raw['confirm_on_quit'], true),
      notifyLongRunning: _bool(raw['notify_long_running'], true),
      longRunningThresholdSeconds:
          _int(raw['long_running_threshold_seconds'], 10, min: 1, max: 3600),
    );
  }

  Map<KeyAction, KeyBinding> _parseKeybindings(Map<String, dynamic>? raw) {
    if (raw == null) return const {};
    final result = <KeyAction, KeyBinding>{};
    for (final entry in raw.entries) {
      KeyAction? action;
      for (final a in KeyAction.values) {
        if (a.name == entry.key) {
          action = a;
          break;
        }
      }
      if (action == null) continue;
      final binding = KeyBinding.parse(entry.value as String);
      if (binding == null) continue;
      result[action] = binding;
    }
    return result;
  }

  String _toToml(GlobalConfig c) {
    final sb = StringBuffer();
    sb.writeln('theme = "${c.activeTheme}"');
    sb.writeln('confirm_on_quit = ${c.confirmOnQuit}');
    sb.writeln('notify_long_running = ${c.notifyLongRunning}');
    sb.writeln('long_running_threshold_seconds = ${c.longRunningThresholdSeconds}');
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

    return sb.toString();
  }

  // ── Validation helpers ──

  String _str(Object? v, String fallback) =>
      v is String ? v : fallback;

  double _dbl(Object? v, double fallback, {double? min, double? max}) {
    double r = v is num ? v.toDouble() : fallback;
    if (min != null && r < min) r = min;
    if (max != null && r > max) r = max;
    return r;
  }

  int _int(Object? v, int fallback, {int? min, int? max}) {
    int r = v is num ? v.toInt() : fallback;
    if (min != null && r < min) r = min;
    if (max != null && r > max) r = max;
    return r;
  }

  bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

  String _oneOf(Object? v, List<String> allowed, String fallback) =>
      v is String && allowed.contains(v) ? v : fallback;
}

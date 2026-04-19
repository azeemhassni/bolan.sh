import 'keybinding.dart';

/// Application configuration data model.
///
/// Loaded from `~/.config/bolan/config.toml`. Every field has a sensible
/// default so the app runs without any config file present.
class AppConfig {
  final GeneralConfig general;
  final EditorConfig editor;
  final AiConfig ai;
  final UpdateConfig update;
  final String activeTheme;

  /// User overrides for key bindings. Only non-default bindings are stored.
  final Map<KeyAction, KeyBinding> keybindingOverrides;

  const AppConfig({
    this.general = const GeneralConfig(),
    this.editor = const EditorConfig(),
    this.ai = const AiConfig(),
    this.update = const UpdateConfig(),
    this.activeTheme = 'default-dark',
    this.keybindingOverrides = const {},
  });

  AppConfig copyWith({
    GeneralConfig? general,
    EditorConfig? editor,
    AiConfig? ai,
    UpdateConfig? update,
    String? activeTheme,
    Map<KeyAction, KeyBinding>? keybindingOverrides,
  }) {
    return AppConfig(
      general: general ?? this.general,
      editor: editor ?? this.editor,
      ai: ai ?? this.ai,
      update: update ?? this.update,
      activeTheme: activeTheme ?? this.activeTheme,
      keybindingOverrides: keybindingOverrides ?? this.keybindingOverrides,
    );
  }
}

class GeneralConfig {
  final String shell;
  final String workingDirectory;
  final bool restoreSessions;
  final List<String> promptChips;

  /// Send a system notification when a command runs longer than this
  /// many seconds and the app is not focused.
  final bool notifyLongRunning;
  final int longRunningThresholdSeconds;

  /// Commands to run automatically when a new session starts.
  final List<String> startupCommands;

  /// Whether to show a confirmation dialog before quitting the app.
  final bool confirmOnQuit;

  const GeneralConfig({
    this.shell = '',
    this.workingDirectory = '',
    this.restoreSessions = false,
    this.promptChips = const ['shell', 'cwd', 'gitBranch', 'gitChanges'],
    this.notifyLongRunning = true,
    this.longRunningThresholdSeconds = 10,
    this.startupCommands = const [],
    this.confirmOnQuit = true,
  });
}

class EditorConfig {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final String cursorStyle;
  final bool cursorBlink;
  final int scrollbackLines;
  final bool blockMode;
  final bool scrollableBlocks;

  /// Whether to enable OpenType ligatures in block output and prompt.
  /// Only works with ligature-supporting fonts (JetBrains Mono, Fira Code).
  /// Does not apply to the live terminal view (xterm.dart limitation).
  final bool ligatures;

  const EditorConfig({
    this.fontFamily = 'JetBrains Mono',
    this.fontSize = 15.0,
    this.lineHeight = 1.3,
    this.cursorStyle = 'block',
    this.cursorBlink = true,
    this.scrollbackLines = 15000,
    this.blockMode = false,
    this.scrollableBlocks = false,
    this.ligatures = true,
  });
}

class AiConfig {
  final String provider;
  final String localModelSize;
  final String model;
  final String ollamaUrl;
  final String geminiModel;
  final String openaiModel;
  final String anthropicModel;
  final String huggingfaceModel;
  final String anthropicMode; // 'api' or 'claude-code'
  final bool enabled;
  final bool commandSuggestions;
  final bool smartHistorySearch;
  final bool shareHistory; // consent to send history to AI for better suggestions

  const AiConfig({
    this.provider = 'local',
    this.localModelSize = 'small',
    this.model = '',
    this.ollamaUrl = 'http://127.0.0.1:11434',
    this.geminiModel = 'gemini-2.5-flash',
    this.openaiModel = 'gpt-4o',
    this.anthropicModel = 'claude-sonnet-4-20250514',
    this.huggingfaceModel = 'moonshotai/Kimi-K2-Instruct-0905',
    this.anthropicMode = 'claude-code',
    this.enabled = true,
    this.commandSuggestions = true,
    this.smartHistorySearch = true,
    this.shareHistory = false,
  });
}

class UpdateConfig {
  final bool autoCheck;
  final String lastCheckTime;
  final String skippedVersion;

  const UpdateConfig({
    this.autoCheck = true,
    this.lastCheckTime = '',
    this.skippedVersion = '',
  });

  UpdateConfig copyWith({
    bool? autoCheck,
    String? lastCheckTime,
    String? skippedVersion,
  }) {
    return UpdateConfig(
      autoCheck: autoCheck ?? this.autoCheck,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      skippedVersion: skippedVersion ?? this.skippedVersion,
    );
  }
}

/// Application configuration data model.
///
/// Loaded from `~/.config/bolan/config.toml`. Every field has a sensible
/// default so the app runs without any config file present.
class AppConfig {
  final GeneralConfig general;
  final EditorConfig editor;
  final AiConfig ai;
  final String activeTheme;

  const AppConfig({
    this.general = const GeneralConfig(),
    this.editor = const EditorConfig(),
    this.ai = const AiConfig(),
    this.activeTheme = 'default-dark',
  });
}

class GeneralConfig {
  final String shell;
  final String workingDirectory;
  final bool restoreSessions;

  const GeneralConfig({
    this.shell = '',
    this.workingDirectory = '',
    this.restoreSessions = false,
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

  const EditorConfig({
    this.fontFamily = 'Operator Mono',
    this.fontSize = 13.0,
    this.lineHeight = 1.0,
    this.cursorStyle = 'block',
    this.cursorBlink = true,
    this.scrollbackLines = 10000,
    this.blockMode = false,
    this.scrollableBlocks = false,
  });
}

class AiConfig {
  final String provider;
  final String model;
  final String ollamaUrl;
  final String geminiModel;
  final String openaiModel;
  final String anthropicModel;
  final String anthropicMode; // 'api' or 'claude-code'
  final bool enabled;
  final bool commandSuggestions;
  final bool shareHistory; // consent to send history to AI for better suggestions

  const AiConfig({
    this.provider = 'gemini',
    this.model = '',
    this.ollamaUrl = 'http://127.0.0.1:11434',
    this.geminiModel = 'gemma-3-27b-it',
    this.openaiModel = 'gpt-4o',
    this.anthropicModel = 'claude-sonnet-4-20250514',
    this.anthropicMode = 'claude-code',
    this.enabled = false,
    this.commandSuggestions = true,
    this.shareHistory = false,
  });
}

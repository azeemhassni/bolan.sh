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

  const EditorConfig({
    this.fontFamily = 'Operator Mono',
    this.fontSize = 13.0,
    this.lineHeight = 1.0,
    this.cursorStyle = 'block',
    this.cursorBlink = true,
    this.scrollbackLines = 10000,
    this.blockMode = false,
  });
}

class AiConfig {
  final String provider;
  final String model;
  final String ollamaUrl;
  final bool enabled;

  const AiConfig({
    this.provider = 'ollama',
    this.model = '',
    this.ollamaUrl = 'http://127.0.0.1:11434',
    this.enabled = false,
  });
}

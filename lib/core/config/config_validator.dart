import 'app_config.dart';

/// Validates and sanitizes config values, falling back to defaults for
/// any field that is out of range or the wrong type.
class ConfigValidator {
  const ConfigValidator();

  AppConfig validate(Map<String, dynamic> raw) {
    return AppConfig(
      general: _validateGeneral(raw['general'] as Map<String, dynamic>?),
      editor: _validateEditor(raw['editor'] as Map<String, dynamic>?),
      ai: _validateAi(raw['ai'] as Map<String, dynamic>?),
      activeTheme: _string(raw['theme'], 'default-dark'),
    );
  }

  GeneralConfig _validateGeneral(Map<String, dynamic>? raw) {
    if (raw == null) return const GeneralConfig();
    return GeneralConfig(
      shell: _string(raw['shell'], ''),
      workingDirectory: _string(raw['working_directory'], ''),
      restoreSessions: _bool(raw['restore_sessions'], false),
      promptChips: _stringList(raw['prompt_chips'],
          const ['shell', 'cwd', 'gitBranch', 'gitChanges']),
      notifyLongRunning: _bool(raw['notify_long_running'], true),
      longRunningThresholdSeconds: _int(
          raw['long_running_threshold_seconds'], 10, min: 1, max: 3600),
      startupCommands: _stringList(raw['startup_commands'], const []),
      confirmOnQuit: _bool(raw['confirm_on_quit'], true),
    );
  }

  EditorConfig _validateEditor(Map<String, dynamic>? raw) {
    if (raw == null) return const EditorConfig();
    return EditorConfig(
      fontFamily: _string(raw['font_family'], 'JetBrains Mono'),
      fontSize: _double(raw['font_size'], 13.0, min: 8, max: 32),
      lineHeight: _double(raw['line_height'], 1.2, min: 1.0, max: 2.5),
      cursorStyle: _oneOf(raw['cursor_style'], ['block', 'underline', 'bar'], 'block'),
      cursorBlink: _bool(raw['cursor_blink'], true),
      scrollbackLines: _int(raw['scrollback_lines'], 10000, min: 100, max: 100000),
      blockMode: _bool(raw['block_mode'], false),
      ligatures: _bool(raw['ligatures'], false),
    );
  }

  AiConfig _validateAi(Map<String, dynamic>? raw) {
    if (raw == null) return const AiConfig();
    return AiConfig(
      provider: _oneOf(raw['provider'], ['local', 'gemini', 'ollama', 'openai', 'anthropic'], 'local'),
      model: _string(raw['model'], ''),
      ollamaUrl: _string(raw['ollama_url'], 'http://127.0.0.1:11434'),
      geminiModel: _string(raw['gemini_model'], 'gemma-3-27b-it'),
      openaiModel: _string(raw['openai_model'], 'gpt-4o'),
      anthropicModel: _string(raw['anthropic_model'], 'claude-sonnet-4-20250514'),
      anthropicMode: _oneOf(raw['anthropic_mode'], ['api', 'claude-code'], 'claude-code'),
      enabled: _bool(raw['enabled'], false),
      commandSuggestions: _bool(raw['command_suggestions'], true),
      smartHistorySearch: _bool(raw['smart_history_search'], true),
      shareHistory: _bool(raw['share_history'], false),
    );
  }

  String _string(Object? value, String fallback) {
    if (value is String) return value;
    return fallback;
  }

  double _double(Object? value, double fallback, {double? min, double? max}) {
    double v = fallback;
    if (value is num) v = value.toDouble();
    if (min != null && v < min) v = min;
    if (max != null && v > max) v = max;
    return v;
  }

  int _int(Object? value, int fallback, {int? min, int? max}) {
    int v = fallback;
    if (value is num) v = value.toInt();
    if (min != null && v < min) v = min;
    if (max != null && v > max) v = max;
    return v;
  }

  List<String> _stringList(Object? value, List<String> fallback) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return fallback;
  }

  bool _bool(Object? value, bool fallback) {
    if (value is bool) return value;
    return fallback;
  }

  String _oneOf(Object? value, List<String> allowed, String fallback) {
    if (value is String && allowed.contains(value)) return value;
    return fallback;
  }
}

import 'app_config.dart';
import 'keybinding.dart';
import 'prompt_style.dart';

/// Validates and sanitizes config values, falling back to defaults for
/// any field that is out of range or the wrong type.
class ConfigValidator {
  const ConfigValidator();

  AppConfig validate(Map<String, dynamic> raw) {
    return AppConfig(
      general: _validateGeneral(raw['general'] as Map<String, dynamic>?),
      editor: _validateEditor(raw['editor'] as Map<String, dynamic>?),
      ai: _validateAi(raw['ai'] as Map<String, dynamic>?),
      update: _validateUpdate(raw['updates'] as Map<String, dynamic>?),
      activeTheme: _string(raw['theme'], 'default-dark'),
      keybindingOverrides:
          _validateKeybindings(raw['keybindings'] as Map<String, dynamic>?),
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
      promptStyle: _validatePromptStyle(
          _toStringMap(raw['prompt_style'])),
    );
  }

  PromptStyleConfig _validatePromptStyle(Map<String, dynamic>? raw) {
    if (raw == null) return const PromptStyleConfig();
    final presetStr = _oneOf(raw['preset'],
        ['bolan', 'powerline', 'starship', 'minimal', 'custom'], 'bolan');
    final preset = PromptPreset.values.byName(presetStr);
    if (preset != PromptPreset.custom) {
      return PromptStyleConfig.fromPreset(preset);
    }
    return PromptStyleConfig(
      preset: PromptPreset.custom,
      chipShape: _enumByName(
          raw['chip_shape'], ChipShape.values, ChipShape.roundedRect),
      cornerRadius: _double(raw['corner_radius'], 4, min: 0, max: 999),
      borderWidth: _double(raw['border_width'], 1, min: 0, max: 4),
      chipSpacing: _double(raw['chip_spacing'], 6, min: 0, max: 24),
      chipPaddingH: _double(raw['chip_padding_h'], 4, min: 0, max: 24),
      chipPaddingV: _double(raw['chip_padding_v'], 2, min: 0, max: 12),
      separator: _enumByName(
          raw['separator'], SeparatorKind.values, SeparatorKind.gap),
      separatorChar: _string(raw['separator_char'], ''),
      separatorColorHex: _string(raw['separator_color'], ''),
      filledBackground: _bool(raw['filled_background'], false),
      perSegmentColors: _bool(raw['per_segment_colors'], false),
      showBorder: _bool(raw['show_border'], true),
      showIcons: _bool(raw['show_icons'], true),
      fontWeight: _oneOf(
          raw['font_weight'], ['normal', 'w500', 'bold'], 'bold'),
    );
  }

  Map<String, dynamic>? _toStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  T _enumByName<T extends Enum>(Object? value, List<T> values, T fallback) {
    if (value is String) {
      for (final v in values) {
        if (v.name == value) return v;
      }
    }
    return fallback;
  }

  EditorConfig _validateEditor(Map<String, dynamic>? raw) {
    if (raw == null) return const EditorConfig();
    return EditorConfig(
      fontFamily: _string(raw['font_family'], 'JetBrains Mono'),
      fontSize: _double(raw['font_size'], 15.0, min: 8, max: 32),
      lineHeight: _double(raw['line_height'], 1.3, min: 1.0, max: 2.5),
      cursorStyle: _oneOf(raw['cursor_style'], ['block', 'underline', 'bar'], 'block'),
      cursorBlink: _bool(raw['cursor_blink'], true),
      scrollbackLines: _int(raw['scrollback_lines'], 10000, min: 100, max: 100000),
      blockMode: _bool(raw['block_mode'], false),
      scrollableBlocks: _bool(raw['scrollable_blocks'], false),
      ligatures: _bool(raw['ligatures'], false),
    );
  }

  AiConfig _validateAi(Map<String, dynamic>? raw) {
    if (raw == null) return const AiConfig();
    return AiConfig(
      provider: _oneOf(raw['provider'], ['local', 'google', 'gemini', 'huggingface', 'ollama', 'openai', 'anthropic'], 'local'),
      localModelSize: _oneOf(raw['local_model_size'], ['small', 'medium', 'large', 'xl'], 'small'),
      model: _string(raw['model'], ''),
      ollamaUrl: _string(raw['ollama_url'], 'http://127.0.0.1:11434'),
      geminiModel: _string(raw['gemini_model'], 'gemini-2.5-flash'),
      openaiModel: _string(raw['openai_model'], 'gpt-4o'),
      anthropicModel: _string(raw['anthropic_model'], 'claude-sonnet-4-20250514'),
      huggingfaceModel: _string(raw['huggingface_model'], 'moonshotai/Kimi-K2-Instruct-0905'),
      anthropicMode: _oneOf(raw['anthropic_mode'], ['api', 'claude-code'], 'claude-code'),
      enabled: _bool(raw['enabled'], true),
      commandSuggestions: _bool(raw['command_suggestions'], true),
      smartHistorySearch: _bool(raw['smart_history_search'], true),
      shareHistory: _bool(raw['share_history'], false),
    );
  }

  UpdateConfig _validateUpdate(Map<String, dynamic>? raw) {
    if (raw == null) return const UpdateConfig();
    return UpdateConfig(
      autoCheck: _bool(raw['auto_check'], true),
      lastCheckTime: _string(raw['last_check_time'], ''),
      skippedVersion: _string(raw['skipped_version'], ''),
    );
  }

  Map<KeyAction, KeyBinding> _validateKeybindings(Map<String, dynamic>? raw) {
    if (raw == null) return const {};
    final result = <KeyAction, KeyBinding>{};
    for (final entry in raw.entries) {
      final action = _actionFromId(entry.key);
      if (action == null) continue;
      final binding = KeyBinding.parse(entry.value as String);
      if (binding == null) continue;
      result[action] = binding;
    }
    return result;
  }

  KeyAction? _actionFromId(String id) {
    for (final a in KeyAction.values) {
      if (a.name == id) return a;
    }
    return null;
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

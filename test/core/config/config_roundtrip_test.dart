import 'dart:io';

import 'package:bolan/core/config/app_config.dart';
import 'package:bolan/core/config/config_loader.dart';
import 'package:bolan/core/config/config_validator.dart';
import 'package:bolan/core/config/prompt_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Config round-trip', () {
    late Directory tmpDir;
    late String configPath;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bolan_config_test_');
      configPath = '${tmpDir.path}/config.toml';
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('save → load preserves all fields', () async {
      const original = AppConfig(
        general: GeneralConfig(
          shell: '/bin/bash',
          workingDirectory: '~/projects',
          restoreSessions: true,
          confirmOnQuit: false,
          notifyLongRunning: false,
          longRunningThresholdSeconds: 30,
          promptChips: ['shell', 'cwd'],
          startupCommands: ['echo hello'],
        ),
        editor: EditorConfig(
          fontFamily: 'Fira Code',
          fontSize: 18.0,
          lineHeight: 1.5,
          cursorStyle: 'bar',
          cursorBlink: false,
          scrollbackLines: 5000,
          blockMode: true,
          ligatures: true,
        ),
        ai: AiConfig(
          provider: 'gemini',
          enabled: true,
          shareHistory: true,
        ),
        update: UpdateConfig(
          autoCheck: false,
          lastCheckTime: '2026-04-13T10:00:00Z',
          skippedVersion: '1.0.0',
        ),
        activeTheme: 'monokai',
      );

      final writer = ConfigLoader(configPathOverride: configPath);
      await writer.save(original);

      final reader = ConfigLoader(configPathOverride: configPath);
      await reader.load();
      final loaded = reader.config;

      expect(loaded.activeTheme, 'monokai');
      expect(loaded.general.shell, '/bin/bash');
      expect(loaded.general.workingDirectory, '~/projects');
      expect(loaded.general.restoreSessions, true);
      expect(loaded.general.confirmOnQuit, false);
      expect(loaded.general.notifyLongRunning, false);
      expect(loaded.general.longRunningThresholdSeconds, 30);
      expect(loaded.general.promptChips, ['shell', 'cwd']);
      expect(loaded.editor.fontFamily, 'Fira Code');
      expect(loaded.editor.fontSize, 18.0);
      expect(loaded.ai.provider, 'gemini');
      expect(loaded.update.autoCheck, false);
      expect(loaded.update.skippedVersion, '1.0.0');
    });

    test('validator parses known map', () {
      const validator = ConfigValidator();
      final parsed = validator.validate({
        'theme': 'monokai',
        'general': {
          'shell': '/bin/bash',
          'working_directory': '~/projects',
          'restore_sessions': true,
          'confirm_on_quit': false,
          'notify_long_running': false,
          'long_running_threshold_seconds': 30,
          'prompt_chips': ['shell', 'cwd'],
          'startup_commands': ['echo hello'],
        },
        'editor': {
          'font_family': 'Fira Code',
          'font_size': 18.0,
          'line_height': 1.5,
          'cursor_style': 'bar',
          'cursor_blink': false,
          'scrollback_lines': 5000,
          'block_mode': true,
          'ligatures': true,
        },
        'ai': {
          'provider': 'gemini',
          'local_model_size': 'medium',
          'model': 'custom-model',
          'ollama_url': 'http://localhost:11434',
          'enabled': true,
          'command_suggestions': false,
          'smart_history_search': false,
          'share_history': true,
        },
        'updates': {
          'auto_check': false,
          'last_check_time': '2026-04-13T10:00:00Z',
          'skipped_version': '1.0.0',
        },
      });

      expect(parsed.activeTheme, 'monokai');
      expect(parsed.general.shell, '/bin/bash');
      expect(parsed.general.workingDirectory, '~/projects');
      expect(parsed.general.restoreSessions, true);
      expect(parsed.general.confirmOnQuit, false);
      expect(parsed.general.notifyLongRunning, false);
      expect(parsed.general.longRunningThresholdSeconds, 30);
      expect(parsed.general.promptChips, ['shell', 'cwd']);
      expect(parsed.general.startupCommands, ['echo hello']);
      expect(parsed.editor.fontFamily, 'Fira Code');
      expect(parsed.editor.fontSize, 18.0);
      expect(parsed.editor.lineHeight, 1.5);
      expect(parsed.editor.cursorStyle, 'bar');
      expect(parsed.editor.cursorBlink, false);
      expect(parsed.editor.scrollbackLines, 5000);
      expect(parsed.editor.ligatures, true);
      expect(parsed.ai.provider, 'gemini');
      expect(parsed.ai.enabled, true);
      expect(parsed.ai.commandSuggestions, false);
      expect(parsed.ai.shareHistory, true);
      expect(parsed.update.autoCheck, false);
      expect(parsed.update.lastCheckTime, '2026-04-13T10:00:00Z');
      expect(parsed.update.skippedVersion, '1.0.0');
    });

    test('copyWith preserves all fields when changing one', () {
      const original = AppConfig(
        general: GeneralConfig(
          shell: '/bin/bash',
          workingDirectory: '~/work',
        ),
        editor: EditorConfig(fontSize: 18.0),
        ai: AiConfig(provider: 'gemini', enabled: true),
        update: UpdateConfig(
          autoCheck: false,
          skippedVersion: '2.0.0',
        ),
        activeTheme: 'dracula',
      );

      // Change only the theme
      final updated = original.copyWith(activeTheme: 'monokai');

      expect(updated.activeTheme, 'monokai');
      // Everything else must survive
      expect(updated.general.shell, '/bin/bash');
      expect(updated.general.workingDirectory, '~/work');
      expect(updated.editor.fontSize, 18.0);
      expect(updated.ai.provider, 'gemini');
      expect(updated.ai.enabled, true);
      expect(updated.update.autoCheck, false);
      expect(updated.update.skippedVersion, '2.0.0');
    });

    test('save → load preserves custom prompt style', () async {
      final original = AppConfig(
        general: GeneralConfig(
          promptStyle: const PromptStyleConfig.powerline().copyWith(
            preset: PromptPreset.custom,
            chipShape: ChipShape.roundedRect,
            cornerRadius: 12,
            chipSpacing: 10,
          ),
        ),
      );

      final writer = ConfigLoader(configPathOverride: configPath);
      await writer.save(original);

      // Debug: print the TOML
      final toml = File(configPath).readAsStringSync();
      // ignore: avoid_print
      print('Written TOML:\n$toml');

      final reader = ConfigLoader(configPathOverride: configPath);
      await reader.load();
      final loaded = reader.config;

      expect(loaded.general.promptStyle.preset, PromptPreset.custom);
      expect(loaded.general.promptStyle.chipShape, ChipShape.roundedRect);
      expect(loaded.general.promptStyle.cornerRadius, 12);
      expect(loaded.general.promptStyle.chipSpacing, 10);
    });

    test('copyWith on UpdateConfig preserves fields', () {
      const original = UpdateConfig(
        autoCheck: false,
        lastCheckTime: '2026-01-01T00:00:00Z',
        skippedVersion: '1.0.0',
      );

      final updated = original.copyWith(lastCheckTime: '2026-04-13T00:00:00Z');

      expect(updated.autoCheck, false);
      expect(updated.lastCheckTime, '2026-04-13T00:00:00Z');
      expect(updated.skippedVersion, '1.0.0');
    });
  });
}

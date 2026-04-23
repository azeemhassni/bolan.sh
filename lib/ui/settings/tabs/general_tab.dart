import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/bolan_theme.dart';
import '../../shared/bolan_button.dart';
import '../../shared/bolan_components.dart';

typedef GeneralUpdater = void Function({
  String? shell,
  String? workingDirectory,
  bool? confirmOnQuit,
  bool? restoreSessions,
  bool? notifyLongRunning,
  bool? inheritWorkingDirectory,
  bool? hidePromptWhileRunning,
});

class GeneralTab extends StatefulWidget {
  final AppConfig config;
  final BolonTheme theme;
  final GeneralUpdater onGeneralChanged;
  final ValueChanged<bool> onAutoCheckUpdateChanged;
  final VoidCallback onRestoreDefaults;

  const GeneralTab({
    super.key,
    required this.config,
    required this.theme,
    required this.onGeneralChanged,
    required this.onAutoCheckUpdateChanged,
    required this.onRestoreDefaults,
  });

  @override
  State<GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<GeneralTab> {
  String? _shellError;
  String? _workingDirError;

  /// Resolves a shell name to a full path and validates it exists.
  /// Returns null if valid, or an error message string.
  String? _validateShell(String value) {
    if (value.isEmpty) return null;
    var path = value;
    if (!path.contains('/')) {
      try {
        final result = Process.runSync('which', [path]);
        if (result.exitCode == 0) {
          path = (result.stdout as String).trim();
        }
      } on ProcessException {
        // ignore
      }
    }
    if (!File(path).existsSync()) {
      return 'Shell not found: $value';
    }
    return null;
  }

  String? _validateWorkingDir(String value) {
    if (value.isEmpty) return null;
    var path = value;
    final home = Platform.environment['HOME'] ?? '';
    if (path.startsWith('~/')) {
      path = '$home${path.substring(1)}';
    } else if (path == '~') {
      path = home;
    }
    if (!Directory(path).existsSync()) {
      return 'Directory not found: $value';
    }
    return null;
  }

  void _confirmRestoreDefaults() {
    final theme = widget.theme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.blockBackground,
        title: Text(
          'Restore defaults?',
          style: TextStyle(
              color: theme.foreground, fontFamily: theme.fontFamily),
        ),
        content: Text(
          'This resets all settings in this workspace to their defaults. '
          'Your command history, tabs, and workspaces are not affected.',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                Text('Cancel', style: TextStyle(color: theme.foreground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onRestoreDefaults();
            },
            child: Text('Restore',
                style: TextStyle(color: theme.exitFailureFg)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final theme = widget.theme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        BolanField(
          label: 'Shell',
          help: 'Leave empty to use \$SHELL',
          error: _shellError,
          child: BolanTextField(
            value: c.general.shell,
            hint: '/bin/zsh',
            onChanged: (v) {
              setState(() => _shellError = _validateShell(v));
              widget.onGeneralChanged(shell: v);
            },
          ),
        ),
        BolanField(
          label: 'Working Directory',
          help: 'Default directory for new tabs',
          error: _workingDirError,
          child: BolanTextField(
            value: c.general.workingDirectory,
            hint: '~ (home)',
            onChanged: (v) {
              setState(() => _workingDirError = _validateWorkingDir(v));
              widget.onGeneralChanged(workingDirectory: v);
            },
          ),
        ),
        BolanToggle(
          label: 'Inherit working directory',
          help: 'New tabs start in the same directory as the active tab',
          value: c.general.inheritWorkingDirectory,
          onChanged: (v) =>
              widget.onGeneralChanged(inheritWorkingDirectory: v),
        ),
        BolanToggle(
          label: 'Hide prompt while running',
          help: 'Hide the prompt bar while a command is executing',
          value: c.general.hidePromptWhileRunning,
          onChanged: (v) =>
              widget.onGeneralChanged(hidePromptWhileRunning: v),
        ),
        BolanToggle(
          label: 'Confirm on Quit',
          help: 'Ask before closing the app',
          value: c.general.confirmOnQuit,
          onChanged: (v) => widget.onGeneralChanged(confirmOnQuit: v),
        ),
        BolanToggle(
          label: 'Restore Sessions',
          help: 'Reopen tabs and panes on startup',
          value: c.general.restoreSessions,
          onChanged: (v) => widget.onGeneralChanged(restoreSessions: v),
        ),
        BolanToggle(
          label: 'Long-Running Notifications',
          help:
              'Notify when commands take longer than ${c.general.longRunningThresholdSeconds}s',
          value: c.general.notifyLongRunning,
          onChanged: (v) => widget.onGeneralChanged(notifyLongRunning: v),
        ),
        BolanToggle(
          label: 'Auto-Check for Updates',
          help: 'Check for new versions on startup',
          value: c.update.autoCheck,
          onChanged: widget.onAutoCheckUpdateChanged,
        ),
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: BolanButton.danger(
            label: 'Restore All Settings to Defaults',
            icon: Icons.restore,
            onTap: _confirmRestoreDefaults,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Config: ~/.config/bolan/config.toml',
            style: TextStyle(
              color: theme.dimForeground,
              fontFamily: theme.fontFamily,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

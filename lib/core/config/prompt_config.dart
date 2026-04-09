import 'package:flutter/material.dart';

import '../theme/bolan_theme.dart';

/// Available chip types for the prompt bar.
enum PromptChipType {
  shell,
  cwd,
  gitBranch,
  gitChanges,
  username,
  hostname,
  time12h,
  time24h,
  date,
  // Live tool chips — appear only when the relevant context is
  // detected in the current working directory or environment.
  nvm,
  kubectl,
  pythonVenv,
  awsProfile,
  gcpProject,
  terraformWorkspace,
  dockerContext,
}

/// Display metadata for each chip type.
extension PromptChipMeta on PromptChipType {
  String get label => switch (this) {
        PromptChipType.shell => 'Shell',
        PromptChipType.cwd => 'Directory',
        PromptChipType.gitBranch => 'Git Branch',
        PromptChipType.gitChanges => 'Git Changes',
        PromptChipType.username => 'Username',
        PromptChipType.hostname => 'Hostname',
        PromptChipType.time12h => 'Time (12h)',
        PromptChipType.time24h => 'Time (24h)',
        PromptChipType.date => 'Date',
        PromptChipType.nvm => 'Node version',
        PromptChipType.kubectl => 'Kubectl context',
        PromptChipType.pythonVenv => 'Python venv',
        PromptChipType.awsProfile => 'AWS profile',
        PromptChipType.gcpProject => 'GCP project',
        PromptChipType.terraformWorkspace => 'Terraform workspace',
        PromptChipType.dockerContext => 'Docker context',
      };

  String get example => switch (this) {
        PromptChipType.shell => 'zsh',
        PromptChipType.cwd => '~/Code/project',
        PromptChipType.gitBranch => 'main',
        PromptChipType.gitChanges => '3 +10 -2',
        PromptChipType.username => 'alice',
        PromptChipType.hostname => 'MacBook',
        PromptChipType.time12h => '03:48 pm',
        PromptChipType.time24h => '15:48',
        PromptChipType.date => 'Apr 3, 2026',
        PromptChipType.nvm => 'v20.11.0',
        PromptChipType.kubectl => 'prod-east · bolan',
        PromptChipType.pythonVenv => 'venv (3.12)',
        PromptChipType.awsProfile => 'production',
        PromptChipType.gcpProject => 'bolan-prod',
        PromptChipType.terraformWorkspace => 'staging',
        PromptChipType.dockerContext => 'colima',
      };

  String get id => name;

  /// SVG icon asset path for this chip type, if available.
  String? get svgIcon => switch (this) {
        PromptChipType.shell => 'assets/icons/ic_terminal.svg',
        PromptChipType.cwd => 'assets/icons/ic_folder_code.svg',
        PromptChipType.gitBranch => 'assets/icons/ic_git.svg',
        PromptChipType.gitChanges => 'assets/icons/ic_diff.svg',
        PromptChipType.nvm => 'assets/icons/ic_nodejs.svg',
        PromptChipType.kubectl => 'assets/icons/ic_kubernetes.svg',
        PromptChipType.pythonVenv => 'assets/icons/ic_python.svg',
        PromptChipType.awsProfile => 'assets/icons/ic_aws.svg',
        PromptChipType.gcpProject => 'assets/icons/ic_gcp.svg',
        PromptChipType.terraformWorkspace => 'assets/icons/ic_terraform.svg',
        PromptChipType.dockerContext => 'assets/icons/ic_docker.svg',
        _ => null,
      };

  /// Returns the themed foreground color for this chip.
  Color fg(BolonTheme theme) => switch (this) {
        PromptChipType.shell => theme.statusShellFg,
        PromptChipType.cwd => theme.statusCwdFg,
        PromptChipType.gitBranch => theme.statusGitFg,
        PromptChipType.gitChanges => theme.foreground,
        PromptChipType.username => theme.ansiYellow,
        PromptChipType.hostname => theme.ansiCyan,
        PromptChipType.time12h => theme.ansiRed,
        PromptChipType.time24h => theme.ansiRed,
        PromptChipType.date => theme.ansiGreen,
        PromptChipType.nvm => theme.ansiGreen,
        PromptChipType.kubectl => theme.ansiBlue,
        PromptChipType.pythonVenv => theme.ansiYellow,
        PromptChipType.awsProfile => theme.ansiYellow,
        PromptChipType.gcpProject => theme.ansiBlue,
        PromptChipType.terraformWorkspace => theme.ansiMagenta,
        PromptChipType.dockerContext => theme.ansiCyan,
      };

  /// Material icon fallback for chip types without SVG.
  IconData? get materialIcon => switch (this) {
        PromptChipType.username => Icons.person_outline,
        PromptChipType.hostname => Icons.computer,
        PromptChipType.time12h => Icons.schedule,
        PromptChipType.time24h => Icons.schedule,
        PromptChipType.date => Icons.calendar_today,
        _ => null,
      };

  static PromptChipType? fromId(String id) {
    for (final type in PromptChipType.values) {
      if (type.name == id) return type;
    }
    return null;
  }
}

/// The default prompt bar chip configuration.
const defaultPromptChips = [
  PromptChipType.shell,
  PromptChipType.cwd,
  PromptChipType.gitBranch,
  PromptChipType.gitChanges,
];

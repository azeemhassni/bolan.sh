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
      };

  String get id => name;

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

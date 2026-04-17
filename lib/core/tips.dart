import 'dart:math';

const _tips = [
  // Keyboard shortcuts
  'You can open a new tab with Cmd+T.',
  'Cmd+D splits your terminal to the right. Cmd+Shift+D splits it downward.',
  'You can navigate between panes with Cmd+Option+Arrow keys.',
  'Cmd+Shift+{ and } let you switch between tabs.',
  'Cmd+K clears everything — the terminal and all blocks.',
  'Cmd+F opens a find bar that searches across all blocks with regex support.',
  'Cmd++ and Cmd+- let you zoom the font size in and out.',
  'Cmd+\\ toggles the workspace sidebar.',

  // AI features
  'You can type # followed by plain English to generate a shell command with AI.',
  'If you run "git commit" without -m, the AI writes the commit message from your staged diff.',
  'When a command fails, an "Explain Error" button appears if AI is enabled.',
  'After each command, the AI can suggest what to type next as faint ghost text. Press right arrow to accept it.',
  'AI suggestions only fire when the model is already loaded — they never start a download behind your back.',
  'You can describe a vibe like "ocean sunset" in Settings > Appearance and the AI generates a complete color theme.',
  'The local AI provider runs entirely on your machine. Nothing leaves your laptop.',
  'The HuggingFace provider gives you access to models like Kimi-K2 and DeepSeek-R1 with a free token.',

  // Workspaces
  'Workspaces give you isolated profiles with their own tabs, history, config, theme, and git identity.',
  'Each workspace can inject its own environment variables into every shell it spawns.',
  'When you switch workspaces, background shells keep running. Switch back and your output is still there.',
  'New workspaces start as a copy of whatever config you are currently using.',
  'Workspace secrets (like API tokens) are stored in the OS keychain, not in plain text files.',
  'You can set a different git name and email for each workspace.',
  'A two-finger swipe inside the sidebar cycles through your workspaces.',

  // History and completion
  'Ctrl+R opens an inline history search.',
  'As you type, ghost text from your command history appears. Press right arrow to accept.',
  'Tab completion works for files, commands, git branches, npm packages, Composer, and Artisan.',

  // Blocks
  'Every command runs in its own block. You can collapse, copy, re-run, or share it as an image.',
  'Collapsed blocks stay collapsed even when new commands run.',
  'The "more" menu on a block lets you save output to a file or share it as a PNG.',

  // Prompt
  'The status chips in your prompt show the shell, cwd, git branch, and file changes.',
  'You can drag and drop to reorder the prompt chips.',
  'Shift+Enter inserts a newline so you can type multi-line commands.',
  'Cmd+Left and Cmd+Right jump to the start and end of the line in the prompt.',
  'Option+Backspace deletes the previous word.',

  // Git
  'Your git branch and dirty state show up automatically in the prompt.',
  'File change counts from git status appear as a status chip.',

  // Themes
  'Bolan ships with 11 built-in themes including Dracula, Nord, Tokyo Night, and Gruvbox.',
  'Custom themes are TOML files. Drop one in ~/.config/bolan/themes/ and it appears in settings.',
  'You can duplicate any built-in theme and customize it from the Appearance tab.',
  'Each workspace can use a different theme.',

  // Configuration
  'All settings live in ~/.config/bolan/config.toml. You can edit it by hand or use the settings UI.',
  'Settings auto-save as you change them.',
  'There is a "Restore All Settings to Defaults" button in General settings if you mess something up.',
  'Each workspace has its own config file, so changing font size in Work does not affect Personal.',

  // Terminal
  'Bolan prefers zsh if available on your system, otherwise it falls back to bash.',
  'The shell starts as a login shell so your PATH, nvm, Homebrew, and other profile setups work.',
  'Scrollback defaults to 15,000 lines. You can increase it in Editor settings.',
  'Font ligatures are enabled by default if you are using JetBrains Mono.',
  'You can switch the cursor style between block, underline, and bar in Editor settings.',

  // Find
  'The find bar searches across all blocks and the live terminal buffer.',
  'You can toggle regex mode and case sensitivity in the find bar.',
  'Enter and Shift+Enter jump forward and backward between search matches.',

  // Links
  'File paths in command output become clickable links when you hold Cmd and hover over them.',
  'Only paths that actually exist on disk light up as links — stale references are ignored.',
  'URLs in command output are also clickable with Cmd+hover.',

  // Panes
  'Split panes let you run multiple shells side by side in the same tab.',
  'You can drag the divider between panes to resize them.',
  'The focused pane has a subtle colored border.',

  // Tabs
  'Right-click a tab to see options like close-others and close-to-the-right.',
  'Double-click a tab to rename it.',
  'If session restore is on, your tab layout is saved and restored on next launch.',

  // Updates
  'Bolan checks for updates from GitHub Releases when it launches.',
  'Updates download in the background and verify code signatures before installing.',
  'If an update fails, it rolls back to your previous version automatically.',

  // Providers
  'The local AI model size is auto-selected based on your system RAM.',
  'Ollama support means you can use any model you have pulled locally.',
  'Claude Code integration works if you have an Anthropic Pro or Max subscription.',
  'You can switch between AI providers at any time in Settings > AI.',

  // Misc
  'Bolan is fully open source. You can read every line at github.com/AzeemHassni/bolan.sh.',
  'Commands that run longer than 10 seconds trigger a system notification when the app is not focused.',
  'You can configure startup commands that run automatically in every new tab.',
  'The confirm-on-quit dialog can be turned off in General settings.',
  'Bolan runs on both macOS and Linux. Windows support is planned.',
  'On Linux, the tab bar integrates with the window title bar for a native look.',
  'The sidebar toggle icon changes appearance when the sidebar is open.',
  'You can export and import custom themes as TOML files.',
  'The Raskoh theme was designed to match the Balochistan mountain range color palette.',
];

final _random = Random();

String randomTip() => _tips[_random.nextInt(_tips.length)];

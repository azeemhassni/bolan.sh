# Bolan

Open-source, AI-powered terminal emulator for macOS and Linux. Built with Flutter — no Electron, no web tech.

## Features

- **Block model** — command outputs captured as styled, copyable blocks with colored ANSI rendering
- **Split panes** — Cmd+D vertical, Cmd+Shift+D horizontal, drag to resize and reorder
- **AI commands** — type `# describe what you want` to generate shell commands with AI
- **AI commit messages** — `git commit` generates a message from your staged diff
- **Error explanation** — failed commands show an "Explain Error" button powered by AI
- **Command suggestions** — AI suggests the next command as ghost text after each execution
- **Smart history search** — Ctrl+R with natural language search ("the deploy command I used")
- **Tab completion** — file paths and commands with inline ghost text
- **Themeable** — 11 built-in themes (Dracula, Nord, Tokyo Night, etc.) + custom TOML themes
- **Customizable prompt bar** — drag-and-drop chip editor for shell, CWD, git, time, etc.
- **Git integration** — branch, dirty status, file changes with diff viewer
- **Find** — Cmd+F search across block output with regex and case sensitivity
- **Settings** — sidebar UI for appearance, prompt, editor, and AI configuration

## Prerequisites

**macOS:**
- Xcode 15+
- CocoaPods
- Flutter 3.28+ (stable)

**Linux:**
- clang, cmake, ninja-build
- libgtk-3-dev, pkg-config
- Flutter 3.28+ (stable)

## Setup

```bash
git clone https://github.com/AzeemHassni/bolan.sh
cd bolan.sh

flutter pub get
flutter run -d macos    # or: flutter run -d linux
```

## Build

```bash
flutter build macos     # → build/macos/Build/Products/Release/bolan.app
flutter build linux     # → build/linux/x64/release/bundle/
```

## Configuration

Config file: `~/.config/bolan/config.toml`

Custom themes: `~/.config/bolan/themes/*.toml`

Command history: `~/.config/bolan/history`

## AI Providers

Bolan supports multiple AI backends:

| Provider | Auth | Use for |
|---|---|---|
| **Claude Code CLI** | Pro/Max subscription | Best quality, no API key needed |
| **Gemini** | Free API key from Google AI Studio | Default, free tier |
| **OpenAI** | API key | GPT-4o |
| **Anthropic API** | API key | Claude via API |
| **Ollama** | Local, no key | Privacy-first, localhost |

Configure in Settings (Cmd+,) → AI.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+T | New tab |
| Cmd+W | Close tab |
| Cmd+Shift+{ / } | Switch tabs |
| Cmd+D | Split pane right |
| Cmd+Shift+D | Split pane down |
| Cmd+Shift+W | Close pane |
| Cmd+Option+Arrows | Navigate panes |
| Cmd+K | Clear screen + scrollback |
| Ctrl+L | Clear screen |
| Cmd+F | Find in output |
| Cmd+, | Settings |
| Cmd++/- | Font size |
| Ctrl+R | History search |
| # + Enter | AI command generation |

## License

MIT

<p align="center">
  <img src="assets/banner.svg" alt="bolan.sh — Terminal that you own!" width="100%" />
</p>

<p align="center">
  An open-source terminal for macOS and Linux with AI built in.
</p>

<p align="center">
  <a href="https://github.com/azeemhassni/bolan.sh/releases/latest"><img src="https://img.shields.io/github/v/release/azeemhassni/bolan.sh?style=flat-square&color=7AA2F7&label=version" alt="Latest Release"></a>
  <a href="https://github.com/azeemhassni/bolan.sh/issues"><img src="https://img.shields.io/github/issues/azeemhassni/bolan.sh?style=flat-square&color=F7768E" alt="Issues"></a>
  <a href="https://github.com/azeemhassni/bolan.sh/stargazers"><img src="https://img.shields.io/github/stars/azeemhassni/bolan.sh?style=flat-square&color=E0AF68" alt="Stars"></a>
  <a href="https://github.com/azeemhassni/bolan.sh/blob/main/LICENSE"><img src="https://img.shields.io/github/license/azeemhassni/bolan.sh?style=flat-square&color=9ECE6A" alt="License"></a>
  <a href="https://github.com/azeemhassni/bolan.sh/releases/latest"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue?style=flat-square" alt="Platform"></a>
</p>

<p align="center">
  <a href="https://github.com/azeemhassni/bolan.sh/releases/latest">
    <img src="https://img.shields.io/badge/macOS-Download-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS">
  </a>
  &nbsp;
  <a href="https://github.com/azeemhassni/bolan.sh/releases/latest">
    <img src="https://img.shields.io/badge/Linux%20x64-Download-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Download for Linux x64">
  </a>
  &nbsp;
  <a href="https://github.com/azeemhassni/bolan.sh/releases/latest">
    <img src="https://img.shields.io/badge/Linux%20ARM64-Download-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Download for Linux ARM64">
  </a>
</p>

---

I started this because I used Warp and liked it, but I didn't like the deal: turn off telemetry and you lose every AI feature. There's no way to use the nice stuff without sending your data through their servers. Warp is closed source, so you either trust it or you don't.

Bolan is what I wanted instead. Same block-based output. AI features that can run fully local. Open source, so you can read what it does with your data (nothing, unless you point it at a cloud provider yourself).

Early and a bit rough. I use it every day.

## Features

- Block-based output with ANSI colors, collapsible, copy button
- `# natural language` generates shell commands
- `git commit` without `-m` generates the commit message
- AI command suggestions as ghost text after each command
- AI theme generator from a text description
- Error explanation on failed commands
- Workspaces with isolated env vars, git identity, history, config, and theme
- Split panes, tabs, drag to reorder
- Ctrl+R history search, ghost text from history while typing
- Tab completion for files, commands, git, npm, composer, artisan
- Git branch and dirty state in the prompt
- Cmd/Ctrl+hover file paths to open them
- Cmd+F find with regex across blocks
- 11 built-in themes, custom TOML themes, AI-generated themes
- Auto-updates with signature verification and rollback

## Getting started

macOS needs Xcode 15+ and CocoaPods. Linux needs clang, cmake, ninja-build, libgtk-3-dev, pkg-config.

Both need [Flutter](https://flutter.dev) 3.28+ (stable channel).

```bash
git clone https://github.com/AzeemHassni/bolan.sh
cd bolan.sh
flutter pub get
flutter run -d macos    # or: flutter run -d linux
```

Release builds:

```bash
flutter build macos     # -> build/macos/Build/Products/Release/Bolan.app
flutter build linux     # -> build/linux/x64/release/bundle/
```

Or grab a DMG/tar.gz from the [releases page](https://github.com/AzeemHassni/bolan.sh/releases).

## AI providers

All optional. The terminal works fine without any of this.

| Provider | What you need |
|---|---|
| Local | Nothing. Pick a model size in settings, it downloads. No keys, no account, stays on your machine. |
| HuggingFace | Free HuggingFace token. Kimi-K2 by default, also has DeepSeek-R1, Llama 3.3, etc. |
| Claude Code | Anthropic Pro/Max subscription |
| Google | API key from Google AI Studio |
| OpenAI | API key |
| Anthropic | API key |
| Ollama | Your own Ollama server, any model you've pulled |

## Config

`~/.config/bolan/` has everything:

```
config.toml                       # settings
themes/*.toml                     # custom themes
workspaces.toml                   # workspace list
workspaces/<id>/config.toml       # per-workspace settings
workspaces/<id>/history           # per-workspace history
workspaces/<id>/session_state.json # saved tab layout
```

Settings UI: Cmd+, (macOS) or Ctrl+, (Linux). There's a "Restore All Settings to Defaults" button if you break something.

## Shortcuts

| | |
|---|---|
| Cmd/Ctrl+T | New tab |
| Cmd/Ctrl+W | Close tab |
| Cmd/Ctrl+Shift+{ / } | Switch tabs |
| Cmd/Ctrl+D | Split right |
| Cmd/Ctrl+Shift+D | Split down |
| Cmd/Ctrl+Shift+W | Close pane |
| Cmd/Ctrl+Option+Arrows | Navigate panes |
| Cmd/Ctrl+\ | Workspace sidebar |
| Cmd/Ctrl+K | Clear |
| Cmd/Ctrl+F | Find |
| Cmd/Ctrl++/- | Font size |
| Ctrl+R | History search |
| `# ` + Enter | AI command |

## Contributing

PRs and bug reports welcome. If there's something you want, open an issue.

## License

MIT

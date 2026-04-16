<p align="center">
  <img src="assets/banner.svg" alt="bolan.sh — Terminal that you own!" width="100%" />
</p>

<p align="center">
  An open-source terminal for macOS and Linux with AI built in.
</p>

---

I started this because I used Warp and liked it, but I didn't like the deal: turn off telemetry and you lose every AI feature. There's no way to use the nice stuff without sending your data through their servers. Warp is closed source, so you either trust it or you don't.

Bolan is what I wanted instead. Same block-based output. AI features that can run fully local. Open source, so you can read what it does with your data (nothing, unless you point it at a cloud provider yourself).

Early and a bit rough. I use it every day.

## Features

Command output shows up in blocks. Each block is collapsible, has ANSI color support, and a copy button. Type `# find large files over 1GB` and press enter — the AI writes the actual shell command. Run `git commit` without `-m` and it generates the message from the diff. If a command fails, there's an "Explain Error" button.

After a command finishes, the AI can suggest what to type next (ghost text, right arrow to accept). It only does this if you've already loaded a model — it won't start downloading one just because you ran `ls`.

There's also an AI theme generator. Go to Settings > Appearance, type something like "ocean sunset", and it spits out a complete color scheme you can preview and save.

Workspaces are the big recent addition. You can have a Work profile with its own AWS_PROFILE, git email, theme, and history, completely separate from Personal. Cmd+\ toggles the sidebar, click to switch. Background shells keep running, so switching back doesn't lose anything. New workspaces copy your current config as a starting point.

The rest: split panes (horizontal/vertical), tabs with drag reorder, Ctrl+R history search with ghost text, tab completion for files/commands/git/npm/composer, git branch and dirty state in the prompt, Cmd+F find with regex, 11 built-in themes plus custom TOML themes, auto-updates from GitHub Releases with signature verification and rollback.

File paths in command output are clickable — hold Cmd (or Ctrl on Linux) and hover, if the file actually exists it becomes a link.

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

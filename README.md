<p align="center">
  <img src="assets/banner.svg" alt="bolan.sh — Terminal that you own!" width="100%" />
</p>

<p align="center">
  An open-source terminal for macOS and Linux with AI baked in.
</p>

---

Bolan groups your command output into clean, copyable blocks instead of dumping everything into an endless scroll. It can also talk to AI — describe what you want in plain English and it turns that into a shell command for you.

## What it does

- **Output blocks** — each command's output is its own block with colored ANSI rendering, selectable text, and copy support
- **AI commands** — type `# find large files over 1GB` and it gives you the right command
- **AI commit messages** — run `git commit` and it writes the message from your staged diff
- **Error explanation** — failed commands get an "Explain Error" button
- **Split panes** — split horizontally, vertically, drag to resize, reorder with drag and drop
- **Tabs** — multiple sessions, instant switching
- **Themes** — 11 built-in (Dracula, Nord, Tokyo Night, Gruvbox, etc.) plus custom themes via TOML files
- **Smart history** — Ctrl+R with natural language search, ghost text suggestions
- **Tab completion** — files and commands with inline preview
- **Git in the prompt** — branch, dirty status, file changes with a diff viewer
- **Find** — search across output with regex support
- **Customizable prompt bar** — drag-and-drop editor for status chips (shell, CWD, git, time)

## Get started

**macOS** requires Xcode 15+ and CocoaPods. **Linux** needs clang, cmake, ninja-build, libgtk-3-dev, and pkg-config.

Both need [Flutter](https://flutter.dev) 3.28+ (stable).

```bash
git clone https://github.com/AzeemHassni/bolan.sh
cd bolan.sh
flutter pub get
flutter run -d macos    # or: flutter run -d linux
```

To build a release:

```bash
flutter build macos     # → build/macos/Build/Products/Release/bolan.app
flutter build linux     # → build/linux/x64/release/bundle/
```

## AI providers

Bolan works with several AI backends. Pick one (or more) in Settings:

| Provider | How to set up |
|---|---|
| **Claude Code** | Needs a Pro/Max subscription, no API key |
| **Gemini** | Free API key from Google AI Studio |
| **OpenAI** | API key |
| **Anthropic** | API key |
| **Ollama** | Runs locally, no key needed |

## Configuration

Everything lives in `~/.config/bolan/`:

- `config.toml` — settings
- `themes/*.toml` — custom themes
- `history` — command history

Or just use the settings UI (Cmd+, on macOS, Ctrl+, on Linux).

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| Cmd/Ctrl+T | New tab |
| Cmd/Ctrl+W | Close tab |
| Cmd/Ctrl+Shift+{ / } | Switch tabs |
| Cmd/Ctrl+D | Split right |
| Cmd/Ctrl+Shift+D | Split down |
| Cmd/Ctrl+Shift+W | Close pane |
| Cmd/Ctrl+Option+Arrows | Navigate panes |
| Cmd/Ctrl+K | Clear everything |
| Ctrl+L | Clear screen |
| Cmd/Ctrl+F | Find |
| Cmd/Ctrl++/- | Font size |
| Ctrl+R | History search |
| `# ` + Enter | AI command |

## License

MIT

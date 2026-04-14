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

## What it does

- **Output blocks** — each command's output is its own block with ANSI colors, selectable text, and copy support
- **AI commands** — type `# find large files over 1GB` and press enter, it generates the command
- **AI commit messages** — `git commit` with no message, it writes one from the staged diff
- **Error explanation** — failed commands get an "Explain Error" button
- **Split panes** — horizontal, vertical, drag to resize, drag to reorder
- **Tabs** — multiple sessions, drag to reorder
- **Themes** — 11 built-in (Dracula, Nord, Tokyo Night, Gruvbox, etc.) plus custom TOML themes
- **History search** — Ctrl+R with natural language, ghost text suggestions
- **Tab completion** — files, commands, and a bunch of tools (git, npm, composer, artisan, more on the way)
- **Git in the prompt** — branch, dirty status, file changes, inline diff viewer
- **Clickable paths** — Cmd/Ctrl+click a file path in any block output to open it
- **Find** — search across blocks and the live buffer, regex supported
- **Customizable prompt** — drag and drop status chips (shell, cwd, git, etc.)

## Get started

macOS needs Xcode 15+ and CocoaPods. Linux needs clang, cmake, ninja-build, libgtk-3-dev, and pkg-config.

Both need [Flutter](https://flutter.dev) 3.28+ (stable channel).

```bash
git clone https://github.com/AzeemHassni/bolan.sh
cd bolan.sh
flutter pub get
flutter run -d macos    # or: flutter run -d linux
```

Building a release:

```bash
flutter build macos     # → build/macos/Build/Products/Release/Bolan.app
flutter build linux     # → build/linux/x64/release/bundle/
```

Or grab a DMG/tar.gz from the [releases page](https://github.com/AzeemHassni/bolan.sh/releases).

## AI providers

Pick one (or more) in Settings:

| Provider | Setup |
|---|---|
| Local | Built in. Pick a model size (Small / Medium / Large / XL) and it downloads in the background. No keys, no external service. |
| Claude Code | Needs a Pro/Max subscription, no API key |
| Gemini | Free API key from Google AI Studio |
| OpenAI | API key |
| Anthropic | API key |
| Ollama | Point at your local Ollama server |

If you want everything to stay on your machine, use the Local provider or Ollama. All AI features are optional; the terminal works with them off.

## Configuration

Everything lives in `~/.config/bolan/`:

- `config.toml` — settings
- `themes/*.toml` — custom themes
- `history` — command history

Or use the settings UI (Cmd+, on macOS, Ctrl+, on Linux). Changes save automatically.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| Cmd/Ctrl+T | New tab |
| Cmd/Ctrl+W | Close tab |
| Cmd/Ctrl+Shift+{ / } | Switch tabs |
| Cmd/Ctrl+Shift+←/→ | Move tab |
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

## Contributing

PRs and bug reports welcome. No roadmap yet — if there's something you want, open an issue.

## License

MIT
</content>
</invoke>
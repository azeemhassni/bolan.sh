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

- **Output blocks** — each command's output is its own collapsible block with ANSI colors, copy button, selectable text
- **AI commands** — type `# find large files over 1GB` and press enter. It figures out the actual command.
- **AI commit messages** — run `git commit` with no `-m`, it writes a message from the staged diff
- **AI suggestions** — after a command finishes, the AI predicts what you'll type next as ghost text. Right arrow to accept. Only fires when the model is already loaded; never starts one behind your back.
- **AI theme generator** — describe a vibe ("ocean sunset", "cyberpunk neon") and it builds a full color theme. Preview it live, save if you like it.
- **Error explanation** — failed commands get an "Explain Error" button
- **Workspaces** — isolated profiles (Work, Personal, whatever). Each gets its own tabs, history, config, theme, env vars, and git identity. Background shells keep running when you switch. More on this below.
- **Split panes** — horizontal and vertical, drag to resize
- **Tabs** — drag to reorder, right-click for close-others and close-to-the-right
- **Themes** — 11 built-in plus custom TOML themes and AI-generated ones
- **History** — Ctrl+R search, ghost text from history while you type
- **Tab completion** — files, commands, git, npm, composer, artisan, more coming
- **Git in the prompt** — branch, dirty state, file counts
- **Clickable paths** — hold Cmd/Ctrl and hover a file path in output. If the file exists, it lights up as a link.
- **Find** — Cmd+F across blocks and the live terminal, regex supported
- **Prompt chips** — drag and drop the status chips (shell, cwd, git branch, etc.)
- **Auto-updates** — checks GitHub Releases on launch, downloads quietly, verifies signatures (macOS) or checksums (Linux), installs with rollback if something goes wrong

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
flutter build macos     # -> build/macos/Build/Products/Release/Bolan.app
flutter build linux     # -> build/linux/x64/release/bundle/
```

Or grab a DMG/tar.gz from the [releases page](https://github.com/AzeemHassni/bolan.sh/releases).

## AI providers

Pick one (or more) in Settings > AI:

| Provider | Setup |
|---|---|
| Local | Built in. Pick a model size, it downloads in the background. No keys, no external service. Size auto-selected based on your RAM. |
| HuggingFace | Free tier with a HuggingFace token. Routes through their inference providers. Kimi-K2, DeepSeek-R1, Llama 3.3 70B, and others available. |
| Claude Code | Needs a Pro/Max subscription, no API key |
| Google | API key from Google AI Studio. Models: Gemini 2.5 Flash/Pro. |
| OpenAI | API key. GPT-4o, GPT-4.1, o3-mini. |
| Anthropic | API key. Claude Sonnet, Opus, Haiku. |
| Ollama | Point at your local Ollama server, any model |

If you want everything to stay on your machine, use the Local provider or Ollama. All AI features are optional; the terminal works fine with them off.

## Workspaces

Different jobs, different contexts. A "Work" workspace can have its own AWS_PROFILE, its own git email, its own theme and command history. "Personal" sees none of that.

Cmd+\ opens the sidebar. Click to switch, or two-finger swipe. Each workspace's shells keep running in the background, so you can switch to Work, check something, and come back to Personal without losing your place.

New workspaces start as a copy of whatever you're currently using. After that they're independent.

## Configuration

Everything lives in `~/.config/bolan/`:

- `config.toml` — settings (per-workspace under `workspaces/<id>/`)
- `themes/*.toml` — custom themes
- `workspaces.toml` — workspace registry
- `workspaces/<id>/history` — per-workspace command history
- `workspaces/<id>/session_state.json` — tab layout

Or use the settings UI (Cmd+, on macOS, Ctrl+, on Linux). Changes save automatically. There's a "Restore All Settings to Defaults" button in the General tab if you mess something up.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| Cmd/Ctrl+T | New tab |
| Cmd/Ctrl+W | Close tab |
| Cmd/Ctrl+Shift+{ / } | Switch tabs |
| Cmd/Ctrl+Shift+left/right | Move tab |
| Cmd/Ctrl+D | Split right |
| Cmd/Ctrl+Shift+D | Split down |
| Cmd/Ctrl+Shift+W | Close pane |
| Cmd/Ctrl+Option+Arrows | Navigate panes |
| Cmd/Ctrl+\ | Toggle workspace sidebar |
| Cmd/Ctrl+K | Clear everything |
| Ctrl+L | Clear screen |
| Cmd/Ctrl+F | Find |
| Cmd/Ctrl++/- | Font size |
| Ctrl+R | History search |
| `# ` + Enter | AI command |

## Contributing

PRs and bug reports welcome. If there's something you want, open an issue.

## License

MIT

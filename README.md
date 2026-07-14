# Zed Bootstrap Configuration

Automated bootstrap for Zed Editor on Windows and Linux/WSL. Install and configure Zed with personal settings, keybindings, theme, and extensions with a single command per platform.

## Quick Start

### Windows
```powershell
irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.ps1 | iex
```

### Linux / WSL
```bash
curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.sh | bash
```

## What Gets Installed

- **Zed Editor** (via winget on Windows, official installer on Linux)
- **Git** (via winget on Windows, apt/yum on Linux)
- **Personal Settings** — synced from `config/settings.json`
- **Keybindings** — synced from `config/keymap.json` (VSCode base + browser-style pane tab navigation)
- **Agent Instructions** — synced from `config/AGENTS.md`
- **Theme Extension** — custom Ayu theme from separate repository
- **Marketplace Extensions** — automatically installed via Zed (14 extensions)

## Architecture

| Component | Purpose |
|-----------|---------|
| `bootstrap.{ps1,sh}` | Pull entry points — ensure git, clone/update repo, run installer |
| `push.{ps1,sh}` | Push entry points — copy live Zed config back into the repo, commit, push |
| `src/<os>/install.*` | Main orchestrator — calls prerequisites, syncs config, installs theme |
| `src/<os>/push.*` | Push logic — copies live config files, strips platform-only fields, commits, pushes |
| `src/<os>/prerequisites.*` | Package manager integration — installs Zed, Git, and extras |
| `src/<os>/paths.*` | Platform-specific paths — Zed config directories by OS |
| `config/` | User settings — settings.json, keymap.json, AGENTS.md, removed-extensions.json (synced to Zed) |
| `theme/manifest.json` | Theme pointer — URL and extension ID of custom theme |
| `docs/adding-config.md` | Extension guide — how to add new extensions, settings, themes, prerequisites |

## Key Design Decisions

1. **Extensible by Git commits** — all logic lives in versioned files, not remote one-liners
2. **Idempotent** — re-running bootstrap is safe and serves as update mechanism
3. **Platform-specific where needed** — Windows PowerShell, Linux Bash, WSL detection built in
4. **Personal theme as extension** — custom theme lives in separate repo, synced by bootstrap
5. **Marketplace extensions via Zed's native mechanism** — `auto_install_extensions` in settings.json
6. **Backups before first overwrite** — `.bak-TIMESTAMP` files preserve manual edits not yet ported
7. **Explicit extension removal** — `config/removed-extensions.json` actively uninstalls extensions (Zed's `auto_install_extensions` only controls what gets installed, not what gets removed)
8. **Explicit push, not a background daemon** — changing settings in the Zed UI is common; `push` is a deliberate, one-shot command you run when you want those changes saved, not an always-on file watcher

## Platform Details

### Windows
- Zed and Git installed via `winget`
- Settings/keybindings synced to `%APPDATA%\Zed\`
- Terminal configured to use WSL as shell (`terminal.shell.program: wsl.exe`)
- Extensions installed to `%LOCALAPPDATA%\Zed\extensions\installed\`

### Linux (native)
- Zed installed via official installer (covers Ubuntu, Debian, Arch, Fedora)
- Git installed via system package manager (apt, yum, pacman)
- Settings/keybindings synced to `~/.config/zed/`
- Extensions installed to `~/.local/share/zed/extensions/installed/`

### WSL (Windows with WSL)
- Runs in "dev-only" mode — installs Git and build tools only
- Zed configuration is managed from Windows side
- Detects WSL via `/proc/version` check

## Extending the Configuration

See [docs/adding-config.md](docs/adding-config.md) for:
- Adding new marketplace extensions
- Customizing keybindings and settings
- Managing personal themes
- Installing additional prerequisites
- Adding macOS support in the future

## Manual Backups

Before the first overwrite of an existing configuration file, a timestamped backup is created:

```
settings.json          → settings.json.bak-20260711-143022
keymap.json           → keymap.json.bak-20260711-143022
AGENTS.md             → AGENTS.md.bak-20260711-143022
```

This ensures you can recover manual edits if they haven't been ported to the repository yet.

## Rerunning Bootstrap (Pull)

Bootstrap is idempotent and serves as your **update mechanism** — repo changes flow into Zed:

```powershell
# Windows
irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.ps1 | iex

# Linux/WSL
curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.sh | bash
```

Each run:
1. Clones or updates the repository locally
2. Installs/verifies Zed and Git
3. Reapplies all configuration files
4. Uninstalls any extensions listed in `config/removed-extensions.json`
5. Syncs theme extension
6. Delegates extension marketplace updates to Zed itself

## Pushing Local Changes (Push)

Made changes in Zed's UI (settings, keybindings) that you want saved? `push` is the reverse of bootstrap — Zed changes flow into the repo:

```powershell
# Windows
irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/push.ps1 | iex

# Linux/WSL
curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/push.sh | bash
```

Each run:
1. Updates the local repo clone (`git pull --ff-only`) before making changes
2. Copies `settings.json`, `keymap.json`, and `AGENTS.md` from Zed's live config directory into `config/`
3. Strips platform-only fields that shouldn't be committed (e.g. Windows' `terminal.shell.program`)
4. Shows the diff, then commits and pushes — if there's nothing to sync, it exits without committing

`push` requires the repo to already be cloned locally (i.e. you've run `bootstrap` at least once), and a working git remote (SSH key or credential helper configured for push access).

## Installed Extensions

**Marketplace extensions** (auto-installed via Zed):
- `ayu-darker`, `ayu-themes-glass` — Color themes
- `catppuccin-icons` — Icon theme
- `csv`, `dockerfile`, `git-firefly`, `html`, `material-icon-theme`, `php`, `powershell`, `scss`, `sql`, `toml`, `xml` — Language support and utilities

MCP servers (Playwright, Context7, Serena, chrome-devtools) are intentionally
not configured in Zed — used only in Claude Code.

**Personal theme** (separate repository):
- `cansee-ayu-theme` — Custom Ayu variant (synced from separate repo)

## Troubleshooting

**Git not installed?** Install from https://git-scm.com/download/win (Windows) or your package manager (Linux).

**Theme not showing?** Verify `theme/manifest.json` has correct repository URL, then restart Zed.

**Settings not applied?** Restart Zed after running bootstrap — it only reads config on startup.

**WSL not detected?** On Windows with WSL, verify `/proc/version` contains "microsoft" and run from WSL terminal.

## License

This is personal configuration. Feel free to fork and adapt for your own use.

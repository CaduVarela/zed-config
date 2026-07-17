# Adding Configuration to Zed Bootstrap

This document explains how to extend the bootstrap configuration for new extensions, settings, themes, or prerequisites.

## Directory Structure Overview

```
zed-config/
├── config/              # User settings and keybindings (synced to Zed)
│   ├── settings.json    # Zed settings, including auto_install_extensions
│   ├── keymap.json      # Custom keybindings (VSCode base + pane tab navigation)
│   ├── AGENTS.md        # Agent instructions for Zed's Claude integration
│   ├── mcp/              # One file per MCP server (context_servers), source of truth
│   └── removed-extensions.json  # Extensions to actively uninstall
├── theme/               # Personal theme configuration
│   └── manifest.json    # Pointer to custom theme repository
├── src/                 # Platform-specific installation logic
│   ├── windows/         # Windows installer scripts (PowerShell), incl. push.ps1
│   └── linux/           # Linux/WSL installer scripts (Bash), incl. push.sh
├── bootstrap.{ps1,sh}   # Pull entry points for remote execution
└── push.{ps1,sh}        # Push entry points for remote execution
```

## Adding a New Marketplace Extension

1. Open `config/settings.json`
2. Find the `auto_install_extensions` section
3. Add a new entry: `"extension-name": true`
4. Commit and push

**Example:**
```json
"auto_install_extensions": {
  "existing-extension": true,
  "new-extension": true
}
```

When the bootstrap runs next, Zed will automatically install the new extension.

## Adding Custom Keybindings

1. Open `config/keymap.json`
2. Add binding entries following Zed's keybinding format
3. Commit and push

**Example:**
```json
[
  {
    "bindings": {
      "ctrl-k ctrl-f": "editor::Format"
    }
  }
]
```

## Changing Global Settings

1. Open `config/settings.json`
2. Edit the desired setting
3. Commit and push

**Common settings to customize:**
- `ui_font_family`, `ui_font_size` — UI appearance
- `buffer_font_family`, `buffer_font_size` — Editor font
- `theme` — Color theme name
- `soft_wrap`, `preferred_line_length` — Line wrapping

**Note:** The `terminal.shell.program` is Windows-specific (set to `wsl.exe` for WSL integration). Linux installations will use the system default shell.

## Removing an Extension

If an extension is installed (manually or via a previous `auto_install_extensions`
entry) and you want the bootstrap to actively uninstall it - not just stop
reinstalling it - add its id to `config/removed-extensions.json`:

```json
[
  "extension-to-remove"
]
```

On the next run, the installer deletes `extensions/installed/<id>` (and
`extensions/work/<id>` if present) before syncing anything else. It's
idempotent: if the extension is already gone, nothing happens. Removing an id
from `auto_install_extensions` alone is *not* enough to uninstall an
already-installed extension - Zed only uses that list to decide what to
install, not to clean up what's already there - so both steps go together
when you want an extension gone for good:

1. Remove the id from `auto_install_extensions` in `config/settings.json`
   (so Zed doesn't reinstall it).
2. Add the id to `config/removed-extensions.json` (so the bootstrap actively
   uninstalls it).

**Note:** don't add your personal theme's `extension_id` (from
`theme/manifest.json`) here - the theme sync step manages that extension on
its own.

## Adding or Removing an MCP Server

Zed's MCP server configs (the `context_servers` setting) are tracked as one
file per server under `config/mcp/`, named `<server-key>.json`, holding just
that server's value (`{enabled, remote, settings}` — whatever Zed itself
writes for that key).

**To add a server:** configure it in Zed's UI as usual, then run `push` — it
extracts every key under `context_servers` into `config/mcp/<key>.json`
automatically. You don't need to hand-write these files.

**To remove a server:** either delete it in Zed's UI and run `push` (which
deletes the corresponding file, since `config/mcp/` always mirrors what's
live), or delete `config/mcp/<key>.json` directly and commit — the next
`install` will no longer include that server.

**On install:** every file in `config/mcp/` is merged into `context_servers`
before `settings.json` is written to Zed's live config directory. An empty or
missing `config/mcp/` means no `context_servers` key at all, same as Zed's
default.

## Pushing Local Changes Back to the Repo

If you tweak settings or keybindings directly in Zed's UI and want to keep
them, run `push` instead of editing `config/` by hand:

```powershell
# Windows
irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/push.ps1 | iex

# Linux/WSL
curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/push.sh | bash
```

It copies `settings.json`, `keymap.json`, and `AGENTS.md` from Zed's live
config directory into `config/`, strips platform-only fields (like Windows'
`terminal.shell.program`, which `install.ps1` injects at apply-time and
should never be committed), extracts MCP server configs into `config/mcp/`
(see [Adding or Removing an MCP Server](#adding-or-removing-an-mcp-server)),
shows the diff, then commits and pushes. If nothing changed, it's a no-op -
safe to run anytime, e.g. right after you notice you changed a setting.

`push` assumes the repo is already cloned locally (bootstrap has run at
least once) and that your git remote has push access configured (SSH key or
credential helper) - it does not set up authentication for you.

## Adding a New Personal Theme

If you have a custom theme in a separate repository:

1. Open `theme/manifest.json`
2. Update the `repo` field with your theme repository URL
3. Update the `extension_id` field with your theme's extension ID
4. Commit and push

**Example:**
```json
{
  "repo": "https://github.com/yourusername/your-custom-theme.git",
  "extension_id": "your-theme-id"
}
```

The bootstrap will automatically clone the theme and install it to Zed's extensions directory.

## Adding a New Prerequisite

If you need to install additional system packages:

### Windows (PowerShell)

Edit `src/windows/prerequisites.ps1`:

```powershell
# Install your-package if not present
Write-Host "Checking your-package..."
$packagePath = Get-Command your-package -ErrorAction SilentlyContinue
if (-not $packagePath) {
    Write-Host "Installing your-package..." -ForegroundColor Cyan
    winget install -e --id Package.Id -h --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: your-package installation had issues" -ForegroundColor Yellow
    }
} else {
    Write-Host "your-package already installed" -ForegroundColor Green
}
```

### Linux (Bash)

Edit `src/linux/prerequisites.sh`:

```bash
# Install your-package if not present
if ! command -v your-package &> /dev/null; then
    echo "Installing your-package..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y your-package
    elif command -v yum &> /dev/null; then
        sudo yum install -y your-package
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm your-package
    fi
else
    echo "your-package already installed"
fi
```

## Adding Support for macOS

When ready to add macOS support:

1. Create directory structure:
   ```
   src/macos/
   ├── install.sh
   ├── prerequisites.sh
   └── paths.sh
   ```

2. Follow the same patterns as Windows/Linux:
   - `paths.sh` → define macOS paths (typically `~/.config/zed`)
   - `prerequisites.sh` → install via Homebrew
   - `install.sh` → orchestrate the full installation

3. Update `bootstrap.sh` to detect macOS and call the appropriate installer

## Running the Bootstrap

### Windows
```powershell
irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.ps1 | iex
```

### Linux/WSL
```bash
curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.sh | bash
```

Re-running the bootstrap is also how you **update** your configuration. It will:
- Pull latest changes from the repository
- Apply all settings, keybindings, and agent instructions
- Sync your theme extension
- Install any new marketplace extensions (via Zed's native mechanism)

## Idempotency

All bootstrap operations are idempotent:
- Already-installed packages are skipped
- Configuration files are overwritten deterministically
- Theme sync uses mirroring (always matches the repository)
- Extensions are managed by Zed itself

Before the first overwrite of a managed file, a backup is created with a timestamp:
```
settings.json.bak-20260711-143022
```

This ensures you can recover any manual changes not yet ported to the repository.

## Troubleshooting

### Git not found on first run
The bootstrap requires Git. On Windows, install Git from https://git-scm.com/download/win. On Linux, run:
```bash
sudo apt-get install -y git  # Debian/Ubuntu
sudo yum install -y git      # RHEL/CentOS
sudo pacman -S git           # Arch
```

### Theme fails to sync
Check that the theme repository URL in `theme/manifest.json` is correct and accessible:
```bash
git clone <repo-url>
```

### Settings not applying
Restart Zed after running the bootstrap. Configuration files are synced to Zed's real directories, but Zed only reads them on startup.

### WSL setup
On Windows with WSL installed, the bootstrap runs differently:
- Windows side: full Zed setup + configuration
- WSL side: only development prerequisites (Git, build tools)

The Zed editor runs on Windows; the WSL terminal is used as the integrated shell (`terminal.shell.program: wsl.exe`).

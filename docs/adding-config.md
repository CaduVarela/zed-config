# Adding Configuration to Zed Bootstrap

This document explains how to extend the bootstrap configuration for new extensions, settings, themes, or prerequisites.

## Directory Structure Overview

```
zed-config/
├── config/              # User settings and keybindings (synced to Zed)
│   ├── settings.json    # Zed settings, including auto_install_extensions
│   ├── keymap.json      # Custom keybindings (empty/VSCode base for now)
│   └── AGENTS.md        # Agent instructions for Zed's Claude integration
├── theme/               # Personal theme configuration
│   └── manifest.json    # Pointer to custom theme repository
├── src/                 # Platform-specific installation logic
│   ├── windows/         # Windows installer scripts (PowerShell)
│   └── linux/           # Linux/WSL installer scripts (Bash)
└── bootstrap.{ps1,sh}   # Entry points for remote execution
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

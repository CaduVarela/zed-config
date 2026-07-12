#!/bin/bash
# Main installation orchestrator for Linux/WSL

set -euo pipefail

REPO_ROOT="${1:-.}"

echo "Starting Zed bootstrap on Linux..."
echo "Repository root: $REPO_ROOT"

# Source paths
source "$REPO_ROOT/src/linux/paths.sh"

# Function to detect if running on WSL
is_wsl() {
    grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

# Function to backup existing files
backup_if_exists() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d-%H%M%S)
        local backup_path="${file_path}.bak-${timestamp}"
        echo "Backing up existing file to: $backup_path"
        cp "$file_path" "$backup_path"
    fi
}

# Determine if running on WSL
if is_wsl; then
    echo ""
    echo "Detected WSL environment"
    echo "Installing only development prerequisites (Git, build tools)"
    echo "Zed configuration is managed from Windows side"

    echo ""
    echo "Step 1: Installing prerequisites..."
    bash "$REPO_ROOT/src/linux/prerequisites.sh" --dev-only

    echo ""
    echo "✓ WSL bootstrap completed successfully!"
    echo "Configure Zed from your Windows installation."
    exit 0
fi

# Linux native installation
echo ""
echo "Detected native Linux environment"
echo "Running full Zed bootstrap"

# Create Zed config directory if it doesn't exist
if [[ ! -d "$ZED_CONFIG_DIR" ]]; then
    echo "Creating Zed config directory: $ZED_CONFIG_DIR"
    mkdir -p "$ZED_CONFIG_DIR"
fi

# Create extensions directory if it doesn't exist
if [[ ! -d "$ZED_EXTENSIONS_DIR" ]]; then
    echo "Creating Zed extensions directory: $ZED_EXTENSIONS_DIR"
    mkdir -p "$ZED_EXTENSIONS_DIR"
fi

# Install prerequisites
echo ""
echo "Step 1: Installing prerequisites..."
bash "$REPO_ROOT/src/linux/prerequisites.sh"

# Copy configuration files
echo ""
echo "Step 2: Copying configuration files..."

declare -A CONFIG_FILES=(
    ["settings.json"]="$ZED_SETTINGS_FILE"
    ["keymap.json"]="$ZED_KEYMAP_FILE"
    ["AGENTS.md"]="$ZED_AGENTS_FILE"
)

for name in "${!CONFIG_FILES[@]}"; do
    dest="${CONFIG_FILES[$name]}"
    backup_if_exists "$dest"
    cp "$REPO_ROOT/config/$name" "$dest"
    echo "Copied $name"
done

# No Linux-specific settings patch is needed: config/settings.json carries no
# platform-specific fields (the one that exists - terminal.shell.program - is
# applied only by the Windows installer). Native Linux gets Zed's default shell.

# Sync theme extension
echo ""
echo "Step 3: Syncing theme extension..."

MANIFEST_PATH="$REPO_ROOT/theme/manifest.json"
if [[ -f "$MANIFEST_PATH" ]]; then
    THEME_REPO=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['repo'])" "$MANIFEST_PATH")
    EXTENSION_ID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['extension_id'])" "$MANIFEST_PATH")

    THEME_CACHE_DIR="/tmp/zed-theme-sync"
    THEME_INSTALL_DIR="$ZED_EXTENSIONS_DIR/$EXTENSION_ID"

    # If the cache points at a different repo than configured, drop it so we
    # don't silently pull/mirror the wrong theme.
    if [[ -d "$THEME_CACHE_DIR" ]]; then
        EXISTING_REMOTE=$(git -C "$THEME_CACHE_DIR" remote get-url origin 2>/dev/null || true)
        if [[ "$EXISTING_REMOTE" != "$THEME_REPO" ]]; then
            echo "Theme repo changed, dropping stale cache..."
            rm -rf "$THEME_CACHE_DIR"
        fi
    fi

    # Clone or update theme repository
    if [[ -d "$THEME_CACHE_DIR" ]]; then
        echo "Updating theme repository..."
        if ! git -C "$THEME_CACHE_DIR" pull --ff-only 2>/dev/null; then
            echo "Failed to update theme, re-cloning..."
            rm -rf "$THEME_CACHE_DIR"
            git clone "$THEME_REPO" "$THEME_CACHE_DIR"
        fi
    else
        echo "Cloning theme repository..."
        git clone "$THEME_REPO" "$THEME_CACHE_DIR"
    fi

    # Mirror theme to extensions directory. --delete already removes stale
    # files on the destination, so no manual pre-delete is needed - and
    # skipping it lets rsync make this an incremental (near-instant) sync on
    # reruns.
    echo "Mirroring theme to extensions directory..."
    rsync -a --delete --exclude=.git "$THEME_CACHE_DIR/" "$THEME_INSTALL_DIR/"

    echo "Theme synced successfully"
else
    echo "Warning: manifest.json not found"
fi

echo ""
echo "✓ Zed bootstrap completed successfully!"
echo "Please restart Zed to apply all changes."

#!/bin/bash
# Main installation orchestrator for Linux/WSL

set -e

REPO_ROOT="${1:-.}"

echo "Starting Zed bootstrap on Linux..."
echo "Repository root: $REPO_ROOT"

# Source paths
source "$REPO_ROOT/src/linux/paths.sh"

# Function to detect if running on WSL
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null
    return $?
}

# Function to backup existing files
backup_if_exists() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local timestamp=$(date +%Y%m%d-%H%M%S)
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
    bash "$REPO_ROOT/src/linux/prerequisites.sh" "$REPO_ROOT"

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
bash "$REPO_ROOT/src/linux/prerequisites.sh" "$REPO_ROOT"

# Copy configuration files
echo ""
echo "Step 2: Copying configuration files..."

backup_if_exists "$ZED_SETTINGS_FILE"
cp "$REPO_ROOT/config/settings.json" "$ZED_SETTINGS_FILE"
echo "Copied settings.json"

backup_if_exists "$ZED_KEYMAP_FILE"
cp "$REPO_ROOT/config/keymap.json" "$ZED_KEYMAP_FILE"
echo "Copied keymap.json"

backup_if_exists "$ZED_AGENTS_FILE"
cp "$REPO_ROOT/config/AGENTS.md" "$ZED_AGENTS_FILE"
echo "Copied AGENTS.md"

# Sync theme extension
echo ""
echo "Step 3: Syncing theme extension..."

MANIFEST_PATH="$REPO_ROOT/theme/manifest.json"
if [[ -f "$MANIFEST_PATH" ]]; then
    THEME_REPO=$(grep -o '"repo"[^,]*' "$MANIFEST_PATH" | cut -d'"' -f4)
    EXTENSION_ID=$(grep -o '"extension_id"[^,]*' "$MANIFEST_PATH" | cut -d'"' -f4)

    THEME_CACHE_DIR="/tmp/zed-theme-sync"
    THEME_INSTALL_DIR="$ZED_EXTENSIONS_DIR/$EXTENSION_ID"

    # Clone or update theme repository
    if [[ -d "$THEME_CACHE_DIR" ]]; then
        echo "Updating theme repository..."
        if ! git -C "$THEME_CACHE_DIR" pull --ff-only origin master 2>/dev/null; then
            echo "Failed to update theme, re-cloning..."
            rm -rf "$THEME_CACHE_DIR"
            git clone "$THEME_REPO" "$THEME_CACHE_DIR"
        fi
    else
        echo "Cloning theme repository..."
        git clone "$THEME_REPO" "$THEME_CACHE_DIR"
    fi

    # Mirror theme to extensions directory
    echo "Mirroring theme to extensions directory..."
    if [[ -d "$THEME_INSTALL_DIR" ]]; then
        rm -rf "$THEME_INSTALL_DIR"
    fi
    rsync -a --delete "$THEME_CACHE_DIR/" "$THEME_INSTALL_DIR/"

    echo "Theme synced successfully"
else
    echo "Warning: manifest.json not found"
fi

# Remove terminal.shell.program on Linux (it's Windows-specific)
if [[ -f "$ZED_SETTINGS_FILE" ]]; then
    echo ""
    echo "Step 4: Applying Linux-specific settings..."
    # Settings are already correct for Linux (no WSL terminal override)
    echo "Linux settings applied"
fi

echo ""
echo "✓ Zed bootstrap completed successfully!"
echo "Please restart Zed to apply all changes."

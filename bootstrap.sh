#!/bin/bash
# Bootstrap entrypoint for Linux/WSL
# This script ensures git is available, clones/updates the repo, and runs the installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.sh | bash

set -e

REPO_URL="https://github.com/CaduVarela/zed-config.git"
REPO_DIR="$HOME/.config/zed-bootstrap"

echo "Zed Bootstrap (Linux/WSL)"
echo "========================="
echo ""

# Check if git is available. Installing git for arbitrary distros is
# src/linux/prerequisites.sh's job (it runs once this repo is actually
# cloned) - this entrypoint only needs enough git to get that far.
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Install it with your package manager, e.g.:"
    echo "  sudo apt-get install -y git   # Debian/Ubuntu"
    echo "  sudo yum install -y git       # RHEL/CentOS"
    echo "  sudo pacman -S git            # Arch"
    exit 1
fi

echo "Ensuring repository is cloned/updated..."
if [[ -d "$REPO_DIR" ]]; then
    echo "Updating existing repository..."
    git -C "$REPO_DIR" pull --ff-only
else
    echo "Cloning repository..."
    git clone "$REPO_URL" "$REPO_DIR"
fi

echo ""
echo "Running installer..."
bash "$REPO_DIR/src/linux/install.sh" "$REPO_DIR"

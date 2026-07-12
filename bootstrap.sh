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

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Installing git..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y git
    elif command -v yum &> /dev/null; then
        sudo yum install -y git
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm git
    else
        echo "Error: git not found and could not install it"
        exit 1
    fi
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

#!/bin/bash
# Install prerequisites on Linux: Git (+ build tools), and Zed.
#
# Usage:
#   prerequisites.sh              # full install (native Linux): git, build tools, Zed
#   prerequisites.sh --dev-only   # WSL mode: git and build tools only, no Zed
#     (Zed itself runs on the Windows host in a WSL setup - see install.sh)

set -euo pipefail

DEV_ONLY=false
if [[ "${1:-}" == "--dev-only" ]]; then
    DEV_ONLY=true
fi

echo "Installing prerequisites on Linux..."

if [[ $EUID -ne 0 ]]; then
   echo "Not running as root. Some package installations may require sudo." >&2
fi

install_packages() {
    # $@: package names to install via whichever package manager is present
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y "$@"
    elif command -v yum &> /dev/null; then
        sudo yum install -y "$@"
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm "$@"
    else
        echo "Error: Unsupported package manager" >&2
        exit 1
    fi
}

if ! command -v git &> /dev/null; then
    echo "Installing Git and build tools..."
    install_packages git build-essential
else
    echo "Git already installed"
fi

if [[ "$DEV_ONLY" == true ]]; then
    echo "Dev-only mode: skipping Zed install (managed on the Windows host)"
    echo "Prerequisites installed successfully"
    exit 0
fi

# Install Zed if not present
if ! command -v zed &> /dev/null; then
    echo "Installing Zed..."
    if curl -fsSL https://zed.dev/install.sh | bash; then
        echo "Zed installed successfully"
    else
        echo "Error: Failed to install Zed" >&2
        exit 1
    fi
else
    echo "Zed already installed"
fi

echo "Prerequisites installed successfully"

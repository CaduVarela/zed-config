#!/bin/bash
# Install prerequisites on Linux: Git and Zed

set -e

REPO_ROOT="${1:-.}"

echo "Installing prerequisites on Linux..."

# Check if running as root (if not, some operations may fail)
if [[ $EUID -ne 0 ]]; then
   echo "Not running as root. Some package installations may require sudo." >&2
fi

# Install Git if not present
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y git
    elif command -v yum &> /dev/null; then
        sudo yum install -y git
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm git
    else
        echo "Error: Unsupported package manager"
        exit 1
    fi
else
    echo "Git already installed"
fi

# Install Zed if not present
if ! command -v zed &> /dev/null; then
    echo "Installing Zed..."
    if curl -fsSL https://zed.dev/install.sh | bash; then
        echo "Zed installed successfully"
    else
        echo "Error: Failed to install Zed"
        exit 1
    fi
else
    echo "Zed already installed"
fi

echo "Prerequisites installed successfully"

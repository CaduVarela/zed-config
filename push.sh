#!/bin/bash
# Push entrypoint for Linux/WSL
# Updates the local repo, then copies live Zed config back into it and pushes.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/push.sh | bash

set -e

REPO_DIR="$HOME/.config/zed-bootstrap"

echo "Zed Config Push (Linux/WSL)"
echo "============================"
echo ""

if [[ ! -d "$REPO_DIR" ]]; then
    echo "No local repo found at $REPO_DIR - run bootstrap.sh first."
    exit 1
fi

echo "Updating local repo before push..."
if ! git -C "$REPO_DIR" pull --ff-only; then
    echo "Error: Failed to update repository (resolve manually before pushing)"
    exit 1
fi

echo ""
bash "$REPO_DIR/src/linux/push.sh" "$REPO_DIR"

#!/bin/bash
# Pushes local Zed config changes back into the repo, commits, and pushes.
#
# Usage: bash src/linux/push.sh [repo-root]

set -euo pipefail

REPO_ROOT="${1:-.}"

echo "Pushing local Zed config to repo..."

source "$REPO_ROOT/src/linux/paths.sh"

CONFIG_FILES=(
    "settings.json:$ZED_SETTINGS_FILE"
    "keymap.json:$ZED_KEYMAP_FILE"
    "AGENTS.md:$ZED_AGENTS_FILE"
)

for entry in "${CONFIG_FILES[@]}"; do
    name="${entry%%:*}"
    src="${entry#*:}"
    dest="$REPO_ROOT/config/$name"
    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        echo "Copied $name from live config"
    else
        echo "Skipping $name (not found at $src)"
    fi
done

# No platform-specific fields are injected into settings.json on native
# Linux today (unlike Windows' terminal.shell.program patch in install.ps1),
# so nothing needs to be stripped before committing back.

cd "$REPO_ROOT"

CHANGED=$(git status --porcelain -- config/settings.json config/keymap.json config/AGENTS.md)
if [[ -z "$CHANGED" ]]; then
    echo "Already in sync - nothing to push."
    exit 0
fi

echo ""
echo "Changes to sync:"
git --no-pager diff -- config/settings.json config/keymap.json config/AGENTS.md
git --no-pager diff --cached -- config/settings.json config/keymap.json config/AGENTS.md

git add config/settings.json config/keymap.json config/AGENTS.md
git commit -m "chore: sync personal config from $(hostname)"

echo ""
echo "Pushing to remote..."
if git push; then
    echo "Push complete."
else
    echo "Warning: commit created locally but push failed (check your git remote auth)." >&2
    exit 1
fi

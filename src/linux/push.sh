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

# Extract Zed's MCP server configs (context_servers) into config/mcp/<name>.json
# as the source of truth, and strip context_servers from settings.json so it
# isn't duplicated. Deletes files for servers no longer present live, mirroring
# the theme sync's "repo always matches what's live" behavior.
MCP_DIR="$REPO_ROOT/config/mcp"
mkdir -p "$MCP_DIR"
python3 - "$REPO_ROOT/config/settings.json" "$MCP_DIR" <<'PYEOF'
import json
import os
import sys

settings_path, mcp_dir = sys.argv[1], sys.argv[2]
with open(settings_path, encoding="utf-8") as f:
    settings = json.load(f)

servers = settings.pop("context_servers", {})

live_keys = set(servers.keys())
for existing in os.listdir(mcp_dir):
    if existing.endswith(".json") and existing[:-5] not in live_keys:
        os.remove(os.path.join(mcp_dir, existing))
        print(f"Removed stale MCP config: {existing}")

for key, value in servers.items():
    dest = os.path.join(mcp_dir, f"{key}.json")
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"Synced MCP config: {key}.json")

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

cd "$REPO_ROOT"

CHANGED=$(git status --porcelain -- config/settings.json config/keymap.json config/AGENTS.md config/mcp)
if [[ -z "$CHANGED" ]]; then
    echo "Already in sync - nothing to push."
    exit 0
fi

echo ""
echo "Changes to sync:"
git --no-pager diff -- config/settings.json config/keymap.json config/AGENTS.md config/mcp
git --no-pager diff --cached -- config/settings.json config/keymap.json config/AGENTS.md config/mcp

git add config/settings.json config/keymap.json config/AGENTS.md config/mcp
git commit -m "chore: sync personal config from $(hostname)"

echo ""
echo "Pushing to remote..."
if git push; then
    echo "Push complete."
else
    echo "Warning: commit created locally but push failed (check your git remote auth)." >&2
    exit 1
fi

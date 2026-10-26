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

# Strip machine-specific state (recent WSL/SSH projects) from settings.json,
# extract Zed's MCP server configs (context_servers) into
# config/mcp/<name>.json as the source of truth, and add extensions installed
# through the Zed UI to auto_install_extensions.
#
# MCP: disabled servers are left out, and files for servers no longer present
# (or enabled) live are deleted, mirroring the theme sync's "repo always
# matches what's live" behavior.
#
# Extensions: skips the personal theme (synced separately) and anything in
# removed-extensions.json. Never removes entries: an extension missing here
# may still be wanted elsewhere - uninstall via removed-extensions.json instead.
MCP_DIR="$REPO_ROOT/config/mcp"
mkdir -p "$MCP_DIR"
python3 - "$REPO_ROOT" "$ZED_EXTENSIONS_DIR" <<'PYEOF'
import json
import os
import sys

repo_root, extensions_dir = sys.argv[1], sys.argv[2]
settings_path = os.path.join(repo_root, "config", "settings.json")
mcp_dir = os.path.join(repo_root, "config", "mcp")


def load(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dump(path, value):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, ensure_ascii=False)
        f.write("\n")


settings = load(settings_path, {})

for key in ("wsl_connections", "ssh_connections"):
    if settings.pop(key, None) is not None:
        print(f"Stripped machine-specific {key} before committing")

servers = settings.pop("context_servers", {})
live_keys = set()
for key, value in servers.items():
    if isinstance(value, dict) and value.get("enabled") is False:
        print(f"Skipping disabled MCP config: {key}")
        continue
    live_keys.add(key)
    dump(os.path.join(mcp_dir, f"{key}.json"), value)
    print(f"Synced MCP config: {key}.json")

for existing in os.listdir(mcp_dir):
    if existing.endswith(".json") and existing[:-5] not in live_keys:
        os.remove(os.path.join(mcp_dir, existing))
        print(f"Removed stale MCP config: {existing}")

if os.path.isdir(extensions_dir):
    removed = set(load(os.path.join(repo_root, "config", "removed-extensions.json"), []))
    theme_id = load(os.path.join(repo_root, "theme", "manifest.json"), {}).get("extension_id")
    auto_install = dict(settings.get("auto_install_extensions", {}))
    for ext_id in sorted(os.listdir(extensions_dir)):
        if not os.path.isdir(os.path.join(extensions_dir, ext_id)):
            continue
        if ext_id == theme_id or ext_id in removed or ext_id in auto_install:
            continue
        auto_install[ext_id] = True
        print(f"Added installed extension to auto_install_extensions: {ext_id}")
    settings["auto_install_extensions"] = dict(sorted(auto_install.items()))

dump(settings_path, settings)
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

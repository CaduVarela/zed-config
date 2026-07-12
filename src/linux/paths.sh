#!/bin/bash
# Linux paths for Zed configuration

ZED_CONFIG_DIR="${HOME}/.config/zed"
ZED_EXTENSIONS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/zed/extensions/installed"
ZED_SETTINGS_FILE="${ZED_CONFIG_DIR}/settings.json"
ZED_KEYMAP_FILE="${ZED_CONFIG_DIR}/keymap.json"
ZED_AGENTS_FILE="${ZED_CONFIG_DIR}/AGENTS.md"

export ZED_CONFIG_DIR ZED_EXTENSIONS_DIR ZED_SETTINGS_FILE ZED_KEYMAP_FILE ZED_AGENTS_FILE

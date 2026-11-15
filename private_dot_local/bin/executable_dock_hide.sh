#!/bin/bash

# Hide the macOS Dock for good, or undo it.
#
# macOS has no switch that turns the Dock off, and killing the Dock process
# breaks Mission Control, Spaces and Cmd+Tab. This script turns on auto-hide
# with a 1000-second delay instead, so the Dock never appears in practice.
#
# Usage:
#   dock_hide.sh           # apply (default)
#   dock_hide.sh --apply   # apply
#   dock_hide.sh --undo    # delete every key this script sets (macOS defaults)
#   dock_hide.sh --help

set -euo pipefail

RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

DOMAIN="com.apple.dock"

# One entry per line: key type value. Bash 3.2 on macOS has no associative arrays.
SETTINGS="autohide bool true
autohide-delay float 1000
autohide-time-modifier float 0
tilesize int 16
magnification bool false
show-recents bool false
static-only bool true
launchanim bool false
no-bouncing bool true"

usage() {
    sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
}

apply() {
    echo -e "${CYAN}⏳ Writing Dock settings...${RESET}"
    while read -r key type value; do
        defaults write "$DOMAIN" "$key" "-$type" "$value"
        echo "   $key = $value"
    done <<< "$SETTINGS"
}

undo() {
    echo -e "${CYAN}⏳ Removing Dock settings (back to macOS defaults)...${RESET}"
    while read -r key _ _; do
        # A key that was never set makes `defaults delete` fail; that is fine.
        if defaults delete "$DOMAIN" "$key" 2>/dev/null; then
            echo "   removed $key"
        else
            echo "   $key was not set"
        fi
    done <<< "$SETTINGS"
}

mode="apply"
if [ $# -gt 1 ]; then
    usage
    exit 1
fi
case "${1:-}" in
    ""|--apply) mode="apply" ;;
    --undo) mode="undo" ;;
    -h|--help) usage; exit 0 ;;
    *)
        echo -e "${RED}❌ Error: unknown option '$1'${RESET}"
        usage
        exit 1
        ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
    echo -e "${RED}❌ Error: this script only runs on macOS.${RESET}"
    exit 1
fi

"$mode"

killall Dock
echo -e "${GREEN}✅ Done. The Dock restarted with the new settings.${RESET}"
if [ "$mode" = "apply" ]; then
    echo -e "${YELLOW}ℹ️  Cmd+Option+D toggles auto-hide and brings the Dock back. Run this script again to fix it.${RESET}"
fi

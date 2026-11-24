#!/bin/bash

# Copy Rex's tracked app settings out of its macOS defaults and into the
# chezmoi source, at .chezmoitemplates/rex-defaults.plist.
#
# Why this exists: Rex keeps its look (theme, font, tabs, sidebar, padding,
# selection) in the com.superlogical.rex defaults domain, not in
# ~/.config/rex/init.lua. The same domain holds window frames, the last
# focused session, Sparkle update state and the local server's route, which
# mean nothing on another Mac. So the domain can never be tracked whole.
#
# Policy: allowlist the `Workspace.` prefix, where Rex stores its settings,
# then deny the keys under it that are session state. A prefix allowlist picks
# up settings that future Rex releases add without an edit here.
#
# .chezmoiscripts/run_onchange_after_rex-settings.sh.tmpl applies the result.
# Nothing here applies or commits anything. Review the result with
# `git diff` in the chezmoi source and commit yourself.
#
# Usage:
#   rex_settings_export.sh                 Write .chezmoitemplates/rex-defaults.plist.
#   rex_settings_export.sh -n|--dry-run    Print the tracked keys, write nothing.

set -euo pipefail

DOMAIN="com.superlogical.rex"
SOURCE="$(chezmoi source-path)"
OUT="$SOURCE/.chezmoitemplates/rex-defaults.plist"

dry_run=false
case "${1:-}" in
  -n|--dry-run) dry_run=true ;;
  "") ;;
  *) echo "usage: $(basename "$0") [-n|--dry-run]" >&2; exit 2 ;;
esac

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

defaults export "$DOMAIN" - | /usr/bin/python3 -I -c '
import plistlib, sys

PREFIX = "Workspace."
DENY = {
    "Workspace.lastFocusedSession",                 # an ID on this machine
    "Workspace.activityGroupingResetToPriority",    # a one-time migration flag
}

domain = plistlib.loads(sys.stdin.buffer.read())  # load() needs a seekable file
kept = {k: v for k, v in sorted(domain.items())
        if k.startswith(PREFIX) and k not in DENY}
plistlib.dump(kept, sys.stdout.buffer, sort_keys=True)
' > "$tmp"

if $dry_run; then
  plutil -p "$tmp"
  exit 0
fi

mkdir -p "$(dirname "$OUT")"
mv "$tmp" "$OUT"
trap - EXIT
echo "wrote $OUT ($(plutil -p "$OUT" | grep -c '=>') keys)"

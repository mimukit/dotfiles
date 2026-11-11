#!/bin/bash

# Extract our slice of Claude Code's settings file into the chezmoi source, at
# .chezmoitemplates/claude-settings.json.
#
# Why this exists: two programs write ~/.claude/settings.json. We own the
# top-level keys. Orca installs twelve hook entries calling its own
# ~/.orca/agent-hooks/claude-hook.sh. Orca reinstalls them on launch and
# rewrites their command string on upgrade, so tracking the file whole produced
# a diff in the source every time it shipped a build.
#
# The file is therefore managed by a chezmoi modify_ script
# (private_dot_claude/modify_settings.json.tmpl), which merges the payload this
# script writes into whatever is on disk and passes vendor hook entries through. That
# makes `chezmoi re-add` useless on it — chezmoi silently skips modify_ entries —
# so this script is how target -> source drift gets captured instead.
#
# Never run `chezmoi add` on ~/.claude/settings.json. Unlike re-add it does not
# skip: it DELETES modify_settings.json.tmpl and replaces it with a plain file.
#
# Policy: export only the preferences named in JQ_PROGRAM. Credentials and new
# settings stay local until this list explicitly permits them. Hook ownership is
# decided by the command an entry runs — ours all invoke
# $HOME/.local/bin/agent-hook. Match the full `.local/bin/agent-hook` path and
# not a bare `agent-hook`, which would also match Orca's `.orca/agent-hooks/`
# directory and claim its entries as ours.
#
# Key order is preserved rather than sorted: the modify_ script
# merges into the live file and jq keeps input order, so re-sorting here would
# fight whatever Claude Code writes next and never settle.
#
# Nothing here applies source -> target or commits anything. Review the result
# with `git diff` in the chezmoi source and commit yourself.
#
# Usage:
#   claude_settings_export.sh                 Write .chezmoitemplates/claude-settings.json.
#   claude_settings_export.sh -n|--dry-run    Show what would change, write nothing.

set -euo pipefail

# Color definitions
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Marker identifying a hook entry as ours rather than a vendor's. Keep this in
# step with the same constant in private_dot_claude/modify_settings.json.tmpl.
MARKER=".local/bin/agent-hook"

DRY_RUN=0
case "${1:-}" in
-n | --dry-run) DRY_RUN=1 ;;
"") ;;
*)
  echo -e "${RED}Unknown argument: $1${RESET}" >&2
  echo "Usage: claude_settings_export.sh [-n|--dry-run]" >&2
  exit 1
  ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
  echo -e "${RED}❌ chezmoi not found on PATH; cannot locate the source dir.${RESET}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}❌ jq not found on PATH; cannot filter the settings file.${RESET}" >&2
  exit 1
fi

if [ ! -f "$CLAUDE_SETTINGS" ]; then
  echo -e "${YELLOW}⏭️  Skipping Claude: no settings file at $CLAUDE_SETTINGS${RESET}"
  exit 0
fi

SOURCE_DIR="$(chezmoi source-path)"
OUT="$SOURCE_DIR/.chezmoitemplates/claude-settings.json"

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${YELLOW}ℹ️ Dry run: showing changes only, writing nothing.${RESET}"
fi

# Drop vendor hook entries, then drop any event left with nothing in it, then
# replace this machine's home directory with a portable __HOME__ token.
#
# The token is the same idea as the one in orca_settings_export.sh, but wider.
# Orca stores whole-path values, so its expansion tests `startswith("__HOME__")`.
# Claude Code writes the path inside a larger string, as in
# `Bash(bash /Users/mukit/.claude/statusline.sh)`, so a prefix test never fires
# and the swap has to work anywhere in the string. Keep this in step with the
# matching `expand` in private_dot_claude/modify_settings.json.tmpl.
#
# split/join, not gsub: the 1-argument form of split is literal, so a home
# directory containing a regex metacharacter cannot corrupt the payload.
# shellcheck disable=SC2016  # $marker and $home are jq variables, bound with --arg below.
JQ_PROGRAM='
  def only($keys): with_entries(select(.key as $key | $keys | index($key) != null));
  def is_ours: ((.hooks // []) | any((.command // "") | index($marker) != null));
  def tokenize: walk(if type == "string" and (index($home) != null)
                     then (split($home) | join("__HOME__")) else . end);
  only(["env", "attribution", "permissions", "model", "hooks", "statusLine",
        "effortLevel", "modelSettings", "awaySummaryEnabled", "tui", "theme",
        "fileCheckpointingEnabled", "terminalProgressBarEnabled"])
  | (if has("env") then .env |= only(["DISABLE_TELEMETRY", "IS_DEMO"]) else . end)
  | (if has("attribution") then .attribution |= only(["commit", "pr"]) else . end)
  | (if has("permissions") then .permissions |= only(["allow", "deny", "defaultMode"]) else . end)
  | (if has("statusLine") then .statusLine |= only(["type", "command", "padding"]) else . end)
  | (if has("modelSettings") then .modelSettings |= with_entries(.value |= only(["effortLevel"])) else . end)
  | (.hooks |= ((. // {}) | with_entries(.value |= map(select(is_ours)
       | only(["matcher", "hooks"])
       | .hooks |= map(only(["type", "command", "timeout", "statusMessage", "async"]))))
       | with_entries(select(.value | length > 0))))
  | tokenize
'

if ! rendered=$(jq --indent 2 --arg marker "$MARKER" --arg home "$HOME" "$JQ_PROGRAM" "$CLAUDE_SETTINGS" 2>/dev/null); then
  echo -e "${RED}❌ Could not parse $CLAUDE_SETTINGS as JSON.${RESET}" >&2
  exit 1
fi
rendered="$rendered"$'\n'

kept=$(printf '%s' "$rendered" | jq '[.hooks // {} | to_entries[] | .value[]] | length')
total=$(jq --arg marker "$MARKER" '[.hooks // {} | to_entries[] | .value[]] | length' "$CLAUDE_SETTINGS")
echo -e "${CYAN}   hooks: $kept ours, $((total - kept)) vendor entries withheld${RESET}"

# Refuse to record an empty hook set. Our three entries going missing from the
# target means something wiped them, not that we stopped wanting them — writing
# that through would bake the loss into the source and the next apply would stop
# reinstalling them. Leave the payload alone and let a human look.
if [ "$kept" -eq 0 ]; then
  echo -e "${RED}❌ No agent-hook entries found in $CLAUDE_SETTINGS.${RESET}" >&2
  echo -e "${YELLOW}   Refusing to overwrite the payload with an empty hook set.${RESET}" >&2
  echo -e "${YELLOW}   Run 'chezmoi apply ~/.claude/settings.json' to reinstall them.${RESET}" >&2
  exit 0
fi

if [ -f "$OUT" ] && printf '%s' "$rendered" | cmp -s - "$OUT"; then
  echo -e "${GREEN}✅ Claude settings already up to date.${RESET}"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${YELLOW}   would rewrite $OUT${RESET}"
  exit 0
fi

mkdir -p "$(dirname "$OUT")"
printf '%s' "$rendered" >"$OUT"
echo -e "${GREEN}✅ Wrote $OUT${RESET}"

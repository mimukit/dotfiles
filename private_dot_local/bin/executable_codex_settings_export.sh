#!/bin/bash

# Extract our slice of Codex's config file into the chezmoi source, at
# .chezmoitemplates/codex-config.toml.
#
# Why this exists: ~/.codex/config.toml mixes the preferences you actually tune
# with state that belongs to one machine and to one build of ChatGPT.app.
# Tracking it whole carried all of the following across:
#
#   notify                    absolute path into the ChatGPT.app bundle
#   marketplaces              last_updated stamps and ~/.cache paths
#   projects                  per-directory trust decisions, absolute, and a
#                             readable list of every project you have opened
#   mcp_servers               vendor-installed, pins an app version string
#   shell_environment_policy  vendor build hashes
#   hooks.state               a trusted_hash per hook entry, rewritten whenever
#                             hooks.json changes
#   tui.model_availability_nux  first-run counters
#
# The file is therefore managed by a chezmoi modify_ script
# (dot_codex/private_modify_config.toml.tmpl), which merges the payload this
# script writes into whatever is on disk and passes the sections above through.
# That makes `chezmoi re-add` useless on it — chezmoi silently skips modify_
# entries — so this script is how target -> source drift gets captured instead.
#
# Never run `chezmoi add` on ~/.codex/config.toml. Unlike re-add it does not
# skip: it DELETES the modify_ script and replaces it with a plain file.
#
# Policy: keep everything except the sections named in DROP below. A deny list,
# not an allow list, so a preference Codex adds in a future build is captured on
# the next sync instead of being silently dropped.
#
# Formatting: tomlkit parses TOML into a style-preserving tree, so key order,
# quote style and blank lines survive. That matters for the same reason it does
# in the Orca script: the modify_ script merges into the live file, and a
# re-sorted payload would fight whatever Codex writes next and never settle.
# `dasel` was tried first and rejected — it round-trips without data loss but
# alphabetises every table and rewrites double quotes as single.
#
# Nothing here applies source -> target or commits anything. Review the result
# with `git diff` in the chezmoi source and commit yourself.
#
# Usage:
#   codex_settings_export.sh                 Write .chezmoitemplates/codex-config.toml.
#   codex_settings_export.sh -n|--dry-run    Show what would change, write nothing.

set -euo pipefail

# Color definitions
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

CODEX_CONFIG="$HOME/.codex/config.toml"

DRY_RUN=0
case "${1:-}" in
-n | --dry-run) DRY_RUN=1 ;;
"") ;;
*)
  echo -e "${RED}Unknown argument: $1${RESET}" >&2
  echo "Usage: codex_settings_export.sh [-n|--dry-run]" >&2
  exit 1
  ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
  echo -e "${RED}❌ chezmoi not found on PATH; cannot locate the source dir.${RESET}" >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo -e "${RED}❌ uv not found on PATH; cannot run the tomlkit filter.${RESET}" >&2
  exit 1
fi

if [ ! -f "$CODEX_CONFIG" ]; then
  echo -e "${YELLOW}⏭️  Skipping Codex: no config file at $CODEX_CONFIG${RESET}"
  exit 0
fi

SOURCE_DIR="$(chezmoi source-path)"
OUT="$SOURCE_DIR/.chezmoitemplates/codex-config.toml"

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${YELLOW}ℹ️ Dry run: showing changes only, writing nothing.${RESET}"
fi

# Keep this deny list in step with the same constant in
# dot_codex/private_modify_config.toml.tmpl.
FILTER=$(
  cat <<'PY'
import sys, tomlkit

# Top-level keys withheld from the source, and nested (table, key) pairs where
# only part of the table is machine state.
DROP_TOP = ["notify", "marketplaces", "projects", "mcp_servers",
            "shell_environment_policy"]
DROP_NESTED = [("hooks", "state"), ("tui", "model_availability_nux")]

doc = tomlkit.parse(sys.stdin.read())

withheld = []
for key in DROP_TOP:
    if key in doc:
        del doc[key]
        withheld.append(key)
for parent, child in DROP_NESTED:
    table = doc.get(parent)
    if table is not None and child in table:
        del table[child]
        withheld.append(f"{parent}.{child}")
        # Drop a table that held nothing but machine state.
        if not len(table):
            del doc[parent]

sys.stderr.write(",".join(withheld))
sys.stdout.write(tomlkit.dumps(doc))
PY
)

if ! rendered=$(uv run --quiet --with tomlkit python -c "$FILTER" \
  <"$CODEX_CONFIG" 2>/tmp/codex_export_withheld.$$); then
  rm -f "/tmp/codex_export_withheld.$$"
  echo -e "${RED}❌ Could not parse $CODEX_CONFIG as TOML.${RESET}" >&2
  exit 1
fi
withheld=$(cat "/tmp/codex_export_withheld.$$")
rm -f "/tmp/codex_export_withheld.$$"

if [ -n "$withheld" ]; then
  echo -e "${CYAN}   withheld: ${withheld//,/, }${RESET}"
else
  echo -e "${CYAN}   withheld: nothing (no machine state present)${RESET}"
fi

# Refuse to record an empty payload. Codex rewriting its config down to nothing
# but machine state means something went wrong, not that we stopped wanting our
# preferences. Writing that through would bake the loss into the source.
if [ -z "${rendered//[[:space:]]/}" ]; then
  echo -e "${RED}❌ Filtering $CODEX_CONFIG left no tracked keys.${RESET}" >&2
  echo -e "${YELLOW}   Refusing to overwrite the payload with an empty document.${RESET}" >&2
  exit 0
fi

if [ -f "$OUT" ] && printf '%s' "$rendered" | cmp -s - "$OUT"; then
  echo -e "${GREEN}✅ Codex config already up to date.${RESET}"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${YELLOW}   would rewrite $OUT${RESET}"
  exit 0
fi

mkdir -p "$(dirname "$OUT")"
printf '%s' "$rendered" >"$OUT"
echo -e "${GREEN}✅ Wrote $OUT${RESET}"

#!/bin/bash

# Backfill the zoxide database from atuin's recorded shell history.
#
# WHY THIS EXISTS
#   zoxide already learns every directory you visit going forward: `zoxide init`
#   installs `__zoxide_hook` into zsh's `chpwd_functions`, so any directory
#   change (builtin `cd`, `z`, `pushd`, yazi, `..`) runs `zoxide add "$PWD"`
#   automatically. Separating `cd` from the `z` binding did NOT break that.
#
#   What that hook can't do is backfill the places you visited *before* zoxide
#   started tracking them. This script does that one-time/periodic backfill.
#
# WHY ATUIN AND NOT ~/.zsh_history
#   ~/.zsh_history here is plain format (no timestamps) and most `cd` targets in
#   shell history are relative (`cd foo`) — unresolvable to an absolute path
#   without knowing the cwd at the time. atuin records the absolute cwd of every
#   command, so it's a far richer, already-deduped source of real directories.
#
# WHAT IT IMPORTS
#   Distinct directories from atuin that (a) live under $HOME, (b) still exist,
#   and (c) aren't obvious cache/build/runtime noise (see EXCLUDE_RE). Each is
#   handed to `zoxide add`, which seeds its frecency. zoxide's own aging decays
#   one-off visits over time, so a slightly generous import is self-correcting.
#
# NOTE
#   The zoxide DB is machine-local runtime state and is deliberately NOT managed
#   by chezmoi — importing into it is a maintenance action, not a config sync.
#
# Usage:
#   zoxide_sync.sh             Import eligible dirs into zoxide.
#   zoxide_sync.sh -n|--dry-run   List what would be imported, add nothing.

set -euo pipefail

# Color definitions
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

# Directories to skip: cache/build/runtime junk that atuin also captured but
# you'd never want as a `z` jump target. Matched as whole path segments.
EXCLUDE_RE='/(\.cache|Library|Caches|node_modules|\.git|\.Trash|\.venv|venv|site-packages|__pycache__|\.terraform|\.next|dist|build|\.turbo|target|\.cargo|\.rustup|\.bun|\.pnpm-store|\.local/state)(/|$)'

DRY_RUN=0
case "${1:-}" in
-n | --dry-run) DRY_RUN=1 ;;
"") ;;
*)
  echo -e "${RED}Unknown argument: $1${RESET}" >&2
  echo "Usage: zoxide_sync.sh [-n|--dry-run]" >&2
  exit 1
  ;;
esac

if ! command -v zoxide >/dev/null 2>&1; then
  echo -e "${RED}❌ zoxide not found on PATH; nothing to sync.${RESET}" >&2
  exit 1
fi
if ! command -v atuin >/dev/null 2>&1; then
  echo -e "${RED}❌ atuin not found on PATH; it is the import source.${RESET}" >&2
  exit 1
fi

[ "$DRY_RUN" -eq 1 ] && \
  echo -e "${YELLOW}ℹ️ Dry run: listing candidates only, importing nothing.${RESET}"

# Collect distinct atuin directories under $HOME. `grep`/`sort` may exit non-zero
# on no match; guard with `|| true` so `set -e` doesn't abort on an empty source.
candidates=()
while IFS= read -r d; do
  [ -n "$d" ] && candidates+=("$d")
done < <(atuin history list --format "{directory}" 2>/dev/null \
  | grep "^$HOME/" \
  | sort -u || true)

keep=()
skipped_excluded=0
skipped_missing=0
for d in ${candidates[@]+"${candidates[@]}"}; do
  # Skip $HOME itself ($HOME or $HOME/) — not a useful `z` jump target.
  if [ "$d" = "$HOME" ] || [ "$d" = "$HOME/" ]; then
    continue
  fi
  if [[ "$d" =~ $EXCLUDE_RE ]]; then
    skipped_excluded=$((skipped_excluded + 1))
    continue
  fi
  if [ ! -d "$d" ]; then
    skipped_missing=$((skipped_missing + 1))
    continue
  fi
  keep+=("$d")
done

n="${#keep[@]}"
echo -e "${CYAN}📂 ${#candidates[@]} distinct \$HOME dirs from atuin → ${n} eligible" \
  "(${skipped_excluded} noise, ${skipped_missing} gone).${RESET}"

if [ "$n" -eq 0 ]; then
  echo -e "${YELLOW}ℹ️ Nothing to import.${RESET}"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  for d in "${keep[@]}"; do
    echo -e "   ${GREEN}+ ${d/#$HOME/~}${RESET}"
  done
  echo -e "${GREEN}✅ Dry run complete. Re-run without --dry-run to import.${RESET}"
  exit 0
fi

# `zoxide add` accepts many paths at once and is idempotent (re-adding an
# existing entry just bumps its score), so a single batched call is safe.
zoxide add -- "${keep[@]}"
echo -e "${GREEN}✅ Imported ${n} dirs into zoxide.${RESET}"

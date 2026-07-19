#!/bin/bash

# Script to sync external updates back into the chezmoi source.
#
# Some tools (Topgrade, AI-skill installers, Neovim plugin managers, app
# auto-updaters) change files in $HOME directly, never going through
# `chezmoi edit`. Those changes live only in the target and never reach the
# chezmoi source until they are re-added. This script captures them.
#
# Maintain the two lists below:
#
#   RE_ADD_PATHS  Files/dirs whose MODIFICATIONS should be captured. Uses
#                 `chezmoi re-add`, which only ever touches files chezmoi
#                 already manages. It never pulls in new/untracked files, so
#                 it can never drag runtime junk (logs, sockets, caches) into
#                 the source. This is the safe default; prefer it.
#
#   ADD_PATHS     Dirs where NEW files should also be captured. Uses
#                 `chezmoi add`, which adds new + modified files recursively.
#                 WARNING: `chezmoi add` does NOT honour .chezmoiignore, so any
#                 runtime junk inside these dirs gets pulled in too. Only list
#                 dirs you know stay clean (e.g. skill folders), and review the
#                 diff before committing.
#
# After syncing, the script also PRUNES: entries that still exist in the source
# but were deleted from the live target (under the listed paths) are listed and,
# once you confirm, forgotten so the source matches reality.
#
# Nothing here applies source -> target or commits anything. After syncing,
# review the result with `chezmoi status` / lazygit and commit yourself.
#
# Usage:
#   chezmoi_sync.sh            Sync every listed path into the source.
#   chezmoi_sync.sh -n|--dry-run   Show what would change, write nothing.

set -euo pipefail

# Color definitions
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

# --- Paths to sync ----------------------------------------------------------
# Edit these lists to match what your update flows touch.

# Modifications only (safe; managed files only).
RE_ADD_PATHS=(
  "$HOME/.zshrc"
  "$HOME/.ssh/config"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/statusline.sh"
  "$HOME/.config/nvim"
  "$HOME/.config/brew/Brewfile"
  "$HOME/.config/icons"
  # Codex (~/.codex): stable config files only. Secrets (auth.json), history,
  # logs, caches, sqlite DBs, sessions and other runtime state are excluded.
  "$HOME/.codex/config.toml"
  "$HOME/.codex/hooks.json"
  "$HOME/.codex/rules/default.rules"
  "$HOME/.codex/AGENTS.md"
  "$HOME/.config/yazi/package.toml"

)

# New + modified files (recursive; keep these dirs free of runtime junk).
ADD_PATHS=(
  "$HOME/.agents/"
  "$HOME/.claude/skills/"
  "$HOME/.codex/automations/"
)
# ---------------------------------------------------------------------------

DRY_RUN=0
case "${1:-}" in
-n | --dry-run) DRY_RUN=1 ;;
"") ;;
*)
  echo -e "${RED}Unknown argument: $1${RESET}" >&2
  echo "Usage: chezmoi_sync.sh [-n|--dry-run]" >&2
  exit 1
  ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
  echo -e "${RED}❌ chezmoi not found on PATH; cannot sync.${RESET}" >&2
  exit 1
fi

# chezmoi flags: always verbose so the diff is visible; add --dry-run on demand.
FLAGS=(--verbose)
if [ "$DRY_RUN" -eq 1 ]; then
  FLAGS+=(--dry-run)
  echo -e "${YELLOW}ℹ️ Dry run: showing changes only, writing nothing.${RESET}"
fi

synced_any=0

# Re-add: capture modifications to already-managed files.
for path in "${RE_ADD_PATHS[@]}"; do
  if [ ! -e "$path" ]; then
    echo -e "${YELLOW}⏭️  Skipping (not found): $path${RESET}"
    continue
  fi
  echo -e "${CYAN}⏳ re-add  $path${RESET}"
  chezmoi re-add "${FLAGS[@]}" "$path"
  synced_any=1
done

# Add: capture new + modified files in clean dirs.
for path in "${ADD_PATHS[@]}"; do
  if [ ! -e "$path" ]; then
    echo -e "${YELLOW}⏭️  Skipping (not found): $path${RESET}"
    continue
  fi
  echo -e "${CYAN}⏳ add     $path${RESET}"
  chezmoi add "${FLAGS[@]}" "$path"
  synced_any=1
done

if [ "$synced_any" -eq 0 ]; then
  echo -e "${YELLOW}ℹ️ No listed paths exist; nothing synced.${RESET}"
  exit 0
fi

# --- Prune: source entries whose target was deleted -------------------------
# `chezmoi status` marks these with 'D' in the first column (still in the
# source, gone from the live target). We forget them so the source matches.
ALL_PATHS=("${RE_ADD_PATHS[@]}" "${ADD_PATHS[@]}")

deleted=()
for path in "${ALL_PATHS[@]}"; do
  [ -e "$path" ] || continue
  while IFS= read -r line; do
    # Status line is "XY relpath"; X is the target-vs-last-written status.
    [ "${line:0:1}" = "D" ] || continue
    deleted+=("${line:3}")
  done < <(chezmoi status "$path" 2>/dev/null)
done

# Reduce to top-level entries: forgetting a directory removes its children too,
# so listing both the dir and its files would double-forget (and confuse the
# confirmation list). Sorting puts a parent right before its descendants.
prune_roots=()
if [ "${#deleted[@]}" -gt 0 ]; then
  while IFS= read -r rel; do
    is_child=0
    for root in ${prune_roots[@]+"${prune_roots[@]}"}; do
      case "$rel" in "$root"/*)
        is_child=1
        break
        ;;
      esac
    done
    [ "$is_child" -eq 0 ] && prune_roots+=("$rel")
  done < <(printf '%s\n' "${deleted[@]}" | sort -u)
fi

if [ "${#prune_roots[@]}" -gt 0 ]; then
  n="${#prune_roots[@]}"
  [ "$n" -eq 1 ] && noun="entry" || noun="entries"
  echo
  echo -e "${YELLOW}🗑️  $n $noun in the source no longer exist in the target:${RESET}"
  for rel in "${prune_roots[@]}"; do
    echo -e "   ${RED}- $rel${RESET}"
  done
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${YELLOW}ℹ️ Dry run: would forget the above from the source.${RESET}"
  else
    targets=()
    for rel in "${prune_roots[@]}"; do
      targets+=("$HOME/$rel")
    done
    read -r -p "$(echo -e "${YELLOW}Prune these $n $noun from the source? [y/N] ${RESET}")" reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      chezmoi forget --force "${targets[@]}"
      echo -e "${GREEN}✅ Pruned $n $noun from the source.${RESET}"
    else
      echo -e "${YELLOW}⏭️  Skipped pruning; source entries kept.${RESET}"
    fi
  fi
fi

# --- Side step: refresh the Homebrew Brewfile --------------------------------
# Same "sync my environment" ritual as `bbk`: regenerate ~/.config/brew/Brewfile
# with `brew bundle dump` so newly installed packages are captured, then re-add
# it into the source. The brew script self-syncs into chezmoi, so this only runs
# the shared backup script. It has no --dry-run mode, so we skip it on dry runs.
# Non-fatal: a brew failure must never abort the chezmoi sync.
BREW_BACKUP="$HOME/setup_scripts/brew_apps_backup.sh"
if [ -x "$BREW_BACKUP" ] && command -v brew >/dev/null 2>&1; then
  echo
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${YELLOW}ℹ️ Dry run: would regenerate and sync the Brewfile via ${BREW_BACKUP}.${RESET}"
  else
    echo -e "${CYAN}⏳ brew    regenerate Brewfile backup${RESET}"
    "$BREW_BACKUP" || echo -e "${YELLOW}⏭️  Brewfile backup skipped (non-fatal).${RESET}"
  fi
fi

# --- Side step: backfill zoxide from atuin -----------------------------------
# Not a chezmoi operation — the zoxide DB is machine-local runtime state and is
# intentionally unmanaged. Run here only because it shares the same "sync my
# environment" ritual. Non-fatal: a failure must never abort the chezmoi sync.
ZOXIDE_SYNC="$HOME/setup_scripts/zoxide_sync.sh"
if [ -x "$ZOXIDE_SYNC" ]; then
  echo
  echo -e "${CYAN}⏳ zoxide  backfill from atuin${RESET}"
  if [ "$DRY_RUN" -eq 1 ]; then
    "$ZOXIDE_SYNC" --dry-run || echo -e "${YELLOW}⏭️  zoxide sync skipped (non-fatal).${RESET}"
  else
    "$ZOXIDE_SYNC" || echo -e "${YELLOW}⏭️  zoxide sync skipped (non-fatal).${RESET}"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${GREEN}✅ Dry run complete. Re-run without --dry-run to apply.${RESET}"
  exit 0
fi

echo -e "${GREEN}✅ Sync complete.${RESET}"
echo -e "${YELLOW}ℹ️ Review and commit the source changes:${RESET}"
echo -e "   chezmoi status      # see remaining drift"
echo -e "   czg                 # lazygit in the chezmoi source to commit"

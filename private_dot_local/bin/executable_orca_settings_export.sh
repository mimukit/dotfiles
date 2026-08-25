#!/bin/bash

# Extract Orca's tracked settings out of its live state blob and into the
# chezmoi source, at .chezmoitemplates/orca-settings.json.
#
# Why this exists: Orca keeps preferences and machine-local state in one file,
#
#   ~/Library/Application Support/orca/profiles/local-default/orca-data.json
#
# which it rewrites every few seconds. That file mixes the ~180 `settings` keys
# you actually tune with `repos`, `projects`, `worktreeMeta`, `workspaceSession`,
# `sshTargets` and `telemetry.installId` — all of which are specific to this
# machine. It can never be chezmoi-managed as a whole file, so this script pulls
# out a curated slice and chezmoi's modify_ script (see the source entry under
# private_Library/) merges that slice back in on apply.
#
# THIS FILE IS THE ONLY PLACE THE KEY POLICY LIVES. The modify_ script just
# applies whatever ends up in .chezmoitemplates/orca-settings.json.
#
# It has to be .chezmoitemplates and not .chezmoidata: chezmoi parses data files
# into Go maps, which are unordered, so `toJson` would hand the modify_ script
# every nested object with its keys alphabetised. Orca writes them in its own
# order, so each apply would reshuffle nested values like terminalQuickCommands
# and `chezmoi status` would report a change forever even though nothing moved.
# A template is included as raw text, so byte order survives.
#
# Policy:
#   settings  denylist — track everything except machine identity, credentials
#             and host-bound paths. A denylist means settings added by future
#             Orca releases get picked up automatically instead of silently
#             going untracked.
#   ui        allowlist — only genuine preferences. The rest of `ui` is window
#             geometry, last-active worktree ids, dismissed nags and state keyed
#             by repo UUIDs, none of which mean anything on another machine.
#   Every other top-level key is ignored entirely and left to the target machine.
#
# Absolute paths under $HOME are stored as a __HOME__ token and expanded again
# by the modify_ script, so they survive a different username.
#
# Nothing here applies source -> target or commits anything. Review the result
# with `git diff` in the chezmoi source and commit yourself.
#
# `chezmoi diff` is not useful on the target itself — Orca writes the whole blob
# on one line, so any change reads as a 109 KB rewrite. To see what an apply
# would really do:
#
#   ORCA=~/"Library/Application Support/orca/profiles/local-default/orca-data.json"
#   diff <(jq -S . "$ORCA") <(chezmoi cat "$ORCA" | jq -S .)
#
# Usage:
#   orca_settings_export.sh                 Write .chezmoitemplates/orca-settings.json.
#   orca_settings_export.sh -n|--dry-run    Show what would change, write nothing.

set -euo pipefail

# Color definitions
RESET='\033[0m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

ORCA_DATA="$HOME/Library/Application Support/orca/profiles/local-default/orca-data.json"

DRY_RUN=0
case "${1:-}" in
-n | --dry-run) DRY_RUN=1 ;;
"") ;;
*)
  echo -e "${RED}Unknown argument: $1${RESET}" >&2
  echo "Usage: orca_settings_export.sh [-n|--dry-run]" >&2
  exit 1
  ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
  echo -e "${RED}❌ chezmoi not found on PATH; cannot locate the source dir.${RESET}" >&2
  exit 1
fi

if [ ! -f "$ORCA_DATA" ]; then
  echo -e "${YELLOW}⏭️  Skipping Orca: no settings blob at $ORCA_DATA${RESET}"
  exit 0
fi

SOURCE_DIR="$(chezmoi source-path)"
OUT="$SOURCE_DIR/.chezmoitemplates/orca-settings.json"

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${YELLOW}ℹ️ Dry run: showing changes only, writing nothing.${RESET}"
fi

ORCA_DATA="$ORCA_DATA" OUT="$OUT" HOME_DIR="$HOME" DRY_RUN="$DRY_RUN" python3 - <<'PY'
import json, os, re, sys

src = os.environ["ORCA_DATA"]
out = os.environ["OUT"]
home = os.environ["HOME_DIR"]
dry = os.environ["DRY_RUN"] == "1"

# --- Key policy ------------------------------------------------------------

# settings: drop machine identity, credentials, and host-bound paths.
SETTINGS_DENY = re.compile(r'''^(
   telemetry
  |claudeManagedAccounts|codexManagedAccounts
  |activeClaudeManagedAccountId|activeCodexManagedAccountId
  |activeCodexManagedAccountIdsByRuntime
  |activeRuntimeEnvironmentId
  |defaultRepoSelection|defaultLinearTeamSelection
  |opencodeSessionCookie|opencodeWorkspaceId|minimaxGroupId
  |androidSdkPath
  |localAccountRuntime.*|localAccountWslDistro|localWindowsRuntimeDefault
  |terminalWindows.*
  |mobile.*
  |devPluginPaths|pluginConsents
  |httpProxyUrl|httpProxyBypassRules
  |floatingTerminalTrustedCwds
  |workspaceDirHistory
  |codexResetCreditAttemptLedger
)$''', re.X)

# ui: keep only real preferences.
UI_ALLOW = [
    "agentActivityDisplayMode",
    "alwaysShowDefaultBranchWorkspace",
    "browserDefaultZoomLevel",
    "combinedDiffFileTreeWidth",
    "editorFontZoomLevel",
    "groupBy",
    "hideAutomationGeneratedWorkspaces",
    "hideCliCreatedWorkspaces",
    "hideDefaultBranchWorkspace",
    "hideDetachedHeadWorkspaces",
    "hideSleepingWorkspaces",
    "markdownTocPanelWidth",
    "projectOrderBy",
    "rightSidebarExplorerView",
    "rightSidebarOpen",
    "rightSidebarTab",
    "rightSidebarWidth",
    "showActiveOnly",
    "showSleepingWorkspaces",
    "sidebarWidth",
    "sortBy",
    "statusBarItems",
    "statusBarUsageMode",
    "statusBarVisible",
    "syncTaskStatusFromWorkspaceBoard",
    "uiZoomLevel",
    "usagePercentageDisplay",
    "workspaceBoardColumnWidth",
    "workspaceBoardOpacity",
    "workspaceStatuses",
    "worktreeCardProperties",
]

# ---------------------------------------------------------------------------

def tokenize(value):
    """Replace this machine's $HOME prefix with a portable __HOME__ token."""
    if isinstance(value, str):
        if value == home:
            return "__HOME__"
        if value.startswith(home + "/"):
            return "__HOME__" + value[len(home):]
        return value
    if isinstance(value, dict):
        return {k: tokenize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [tokenize(v) for v in value]
    return value

try:
    with open(src, encoding="utf-8") as fh:
        data = json.load(fh)
except (OSError, ValueError) as err:
    print(f"\033[0;31m❌ Could not read Orca settings: {err}\033[0m", file=sys.stderr)
    sys.exit(1)

settings = data.get("settings", {})
ui = data.get("ui", {})

# Top-level names are sorted so `git diff` stays readable, but nested values keep
# the order Orca wrote them in. Recursive sorting would make every apply reshuffle
# nested objects and arrays against whatever Orca writes next — permanent churn.
payload = {
    "settings": {
        k: tokenize(settings[k]) for k in sorted(settings) if not SETTINGS_DENY.match(k)
    },
    "ui": {k: tokenize(ui[k]) for k in sorted(UI_ALLOW) if k in ui},
}

rendered = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"

dropped = sorted(k for k in settings if SETTINGS_DENY.match(k))
print(f"\033[0;36m   settings: {len(payload['settings'])} tracked, {len(dropped)} withheld\033[0m")
print(f"\033[0;36m   ui:       {len(payload['ui'])} tracked, {len(ui) - len(payload['ui'])} withheld\033[0m")

previous = ""
if os.path.exists(out):
    with open(out, encoding="utf-8") as fh:
        previous = fh.read()

if previous == rendered:
    print("\033[0;32m✅ Orca settings already up to date.\033[0m")
    sys.exit(0)

if dry:
    print(f"\033[0;33m   would rewrite {out}\033[0m")
    sys.exit(0)

os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as fh:
    fh.write(rendered)
print(f"\033[0;32m✅ Wrote {out}\033[0m")
PY

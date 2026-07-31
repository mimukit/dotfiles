#!/bin/sh
# Stop hook: kill lingering listeners (dev/test servers) left running in an
# ephemeral Orca agent worktree after an agent finishes a turn. Scoped to
# ~/orca/workspaces/* so it never touches a manually-run dev server in a
# regular checkout — only ephemeral per-task worktrees are cleaned up.
#
# Invoked via ~/.local/bin/agent-hook, which resolves the project dir from the
# hook payload and exports it as AGENT_PROJECT_DIR. CLAUDE_PROJECT_DIR is still
# honoured so the script keeps working if called directly by Claude.
cat >/dev/null 2>&1 || :

PROJECT_DIR="${AGENT_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-}}}"

case "$PROJECT_DIR" in
  "$HOME"/orca/workspaces/*) ;;
  *) exit 0 ;;
esac

lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR>1{print $2}' | sort -u | while read -r pid; do
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | awk '/^n/{print substr($0,2)}')
  case "$cwd" in
    "$PROJECT_DIR"*) kill "$pid" 2>/dev/null ;;
  esac
done

exit 0

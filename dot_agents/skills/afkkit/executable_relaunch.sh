#!/usr/bin/env bash
# relaunch.sh starts an unattended afkkit run for one issue as a headless agent
# session, and starts it again when the session dies while the issue still needs
# the run. afkkit's resume table picks the resume point on every start, so this
# script holds no pipeline knowledge: it only decides whether to start again.
#
# It starts again only when all four hold after a session ends:
#   - the issue still carries the `in-progress` label;
#   - no pull request, open or closed, has an `issue-<n>-*` head branch;
#   - the last line of the worktree's .afkkit/progress.md is not `escalated ...`
#     (afkkit writes that line when it stops on purpose);
#   - fewer than 3 restarts have run in this invocation.
# Waits before restarts 1, 2 and 3: 60 s, 300 s, 900 s. At the limit it comments
# the log tail on the issue once and exits, leaving the label as it is.
#
# Requires: git, gh (authenticated), and the agent CLI. Bash 3.2 compatible.
#
# Usage:
#   relaunch.sh [--agent '<cmd>'] <n>
#     --agent  headless command that takes a prompt as its last argument
#              (default: claude -p; for Codex: --agent 'codex exec')
#
# Run it from inside the repository. It detaches itself, prints its PID and log
# path, and refuses a second start for the same issue while the first one lives.
# State: ${XDG_STATE_HOME:-$HOME/.local/state}/afkkit/<owner>-<repo>-<n>.pid|.log

set -u

agent='claude -p'
n=''
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) [ $# -ge 2 ] || { echo "relaunch.sh: --agent needs a command" >&2; exit 2; }
             agent="$2"; shift 2 ;;
    --agent=*) agent="${1#--agent=}"; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "relaunch.sh: unknown option $1" >&2; exit 2 ;;
    *) [ -z "$n" ] || { echo "relaunch.sh: one issue number only" >&2; exit 2; }
       n="$1"; shift ;;
  esac
done

case "$n" in
  ''|*[!0-9]*) echo "usage: relaunch.sh [--agent '<cmd>'] <issue-number>" >&2; exit 2 ;;
esac

read -r -a agent_words <<<"$agent"
[ "${#agent_words[@]}" -gt 0 ] || { echo "relaunch.sh: --agent is empty" >&2; exit 2; }

for dep in git gh "${agent_words[0]}"; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "relaunch.sh: '$dep' not found. Run the headless command once instead: ${agent} \"afkkit ${n}\"" >&2
    exit 127
  }
done

# The main checkout is the first entry git lists, from any worktree of the repo.
main=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
[ -n "$main" ] || { echo "relaunch.sh: run it inside a git repository" >&2; exit 2; }

slug=$(cd "$main" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || slug=''
[ -n "$slug" ] || { echo "relaunch.sh: gh cannot resolve this repository on GitHub" >&2; exit 2; }

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/afkkit"
base="${state_dir}/$(printf '%s' "$slug" | tr '/' '-')-${n}"
pid_file="${base}.pid"
log_file="${base}.log"
mkdir -p "$state_dir"

# --- launcher: refuse a second instance, then detach ------------------------
if [ -z "${AFKKIT_RELAUNCH_DETACHED:-}" ]; then
  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null; then
    echo "relaunch.sh: issue #${n} already has a relaunch loop, PID $(cat "$pid_file"); log: ${log_file}" >&2
    exit 1
  fi
  detach=''
  command -v setsid >/dev/null 2>&1 && detach='setsid'
  AFKKIT_RELAUNCH_DETACHED=1 $detach nohup "$0" --agent "$agent" "$n" </dev/null >>"$log_file" 2>&1 &
  loop_pid=$!
  echo "$loop_pid" >"$pid_file"
  echo "relaunch.sh: issue #${n} started, PID ${loop_pid}"
  echo "log: ${log_file}"
  exit 0
fi

# --- the loop (detached) ----------------------------------------------------
echo $$ >"$pid_file"
trap 'rm -f "$pid_file"' EXIT

note() { echo "[relaunch $(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }

# Prints the last progress.md line of the issue's worktree, or nothing.
last_progress() {
  local wt
  wt=$(git -C "$main" worktree list --porcelain | awk -v pre="branch refs/heads/issue-${n}-" '
    /^worktree / { path = substr($0, 10) }
    index($0, pre) == 1 { print path; exit }')
  [ -n "$wt" ] && [ -f "$wt/.afkkit/progress.md" ] && tail -n 1 "$wt/.afkkit/progress.md"
}

# Exit 0 when the run needs another start; print the reason to stop otherwise.
needs_restart() {
  local labels branch prs last
  labels=$(gh issue view "$n" --json labels -q '.labels[].name' 2>/dev/null) \
    || { echo "gh cannot read issue #${n}"; return 1; }
  printf '%s\n' "$labels" | grep -qx 'in-progress' \
    || { echo "issue #${n} no longer reads in-progress"; return 1; }
  branch=$(git -C "$main" for-each-ref --format='%(refname:short)' "refs/heads/issue-${n}-*" | head -n 1)
  if [ -n "$branch" ]; then
    prs=$(gh pr list --head "$branch" --state all --json url -q '.[].url' 2>/dev/null) \
      || { echo "gh cannot list pull requests for ${branch}"; return 1; }
    [ -z "$prs" ] || { echo "a pull request exists: ${prs}"; return 1; }
  fi
  last=$(last_progress)
  case "$last" in
    escalated*) echo "the run escalated: ${last}"; return 1 ;;
  esac
  return 0
}

waits='60 300 900'
limit=3
attempt=0
while :; do
  note "start attempt $((attempt + 1)): ${agent} \"afkkit ${n}\" in ${main}"
  (cd "$main" && "${agent_words[@]}" "afkkit ${n}") </dev/null
  rc=$?
  note "session ended, exit ${rc}"

  if ! reason=$(needs_restart); then
    note "no restart: ${reason}"
    exit 0
  fi
  if [ "$attempt" -ge "$limit" ]; then
    note "restart limit ${limit} reached; issue #${n} keeps in-progress"
    body=$(printf 'relaunch.sh stopped after %s restarts. The run still reads `in-progress` with no PR.\n\nLog tail (`%s`):\n\n```\n%s\n```\n' \
      "$limit" "$log_file" "$(tail -n 30 "$log_file")")
    gh issue comment "$n" --body "$body" >/dev/null 2>&1 || note "could not comment on issue #${n}"
    exit 1
  fi

  set -- $waits
  shift "$attempt"
  wait_s=$1
  attempt=$((attempt + 1))
  note "restart ${attempt} of ${limit} in ${wait_s}s; previous exit ${rc}; last progress line: $(last_progress || true)"
  sleep "$wait_s"
done

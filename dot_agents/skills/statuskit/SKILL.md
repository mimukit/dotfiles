---
name: statuskit
description: >-
  Survey a project's status and recommend the single best next move — a read-only sweep of the git working tree, GitHub issues, open PRs, and unfiled plans, rendered as a one-screen dashboard with one finish-first action crowned and routed to the kit that does it. Use when you sit down at a project and ask "what should I do next", "check project status", "where's this at", "what's next", "project status", "orient me", or run "/statuskit".
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# statuskit

The front door you open when you sit back down at a project and ask *"where is this thing, and what's my single best next move?"* statuskit surveys the whole project **read-only** — git working tree, GitHub issues, open PRs, unfiled plans — prints a one-screen **status dashboard**, then does the opinionated part: it ranks the possible next actions by a **finish-first** rule and crowns exactly **one** as the move to make, routing you to the kit (or plain command) that does it.

It is a **read + advise** tool. It never commits, pushes, closes an issue, edits a PR, merges, relabels, or writes code — every mutation happens inside the kit it hands you off to, under that kit's own guard. That zero-mutation stance is the point: statuskit is safe to run anytime, as often as you like, to re-orient.

## When this fires

You want to orient before acting: "what should I do next", "check project status", "where's this project at", "what's next", "project status", "orient me", "/statuskit", or a bare "what's the state of this" after stepping away.

One boundary matters:

- **Not the tracker authority** — that's issuekit. statuskit reads issue *counts and state* to inform its recommendation and computes one cheap staleness signal. Detailed tracker health belongs to issuekit: issuekit answers "is my tracker honest?"; statuskit answers "where's this project and what do I do next?"

## The ranking principle: finish-first

Everything statuskit crowns derives from one rule — **"stop starting, start finishing"** (minimize work-in-progress). The crowned move is always whatever retires the most in-flight work for the least effort, *before* anything new is started. When several candidates tie within a rung, crown the **most-recently-active** one (issue/PR `updatedAt`, or a branch's last-commit time) — lowest context-switch cost — and list the rest as runners-up.

Two states are **surfaced but never crowned**, because acting on them is a human gate, not a finish-first win statuskit should push:

- an approved + CI-green PR ("ready to merge") — merging is your call;
- a PR awaiting *someone else's* review — out of your hands.

Both appear in the dashboard as facts; neither becomes the #1 move.

## Procedure

### 1. Preflight — degrade per source, never fail wholesale

statuskit is **git-first**: git signals always drive it, and GitHub signals enrich it when available. Detect what's present and adapt, rather than bailing:

- **Not a git repo** → say so; skip everything git-derived. If there's no repo yet, the move is "start with `plankit`."
- **`gh` missing / unauthenticated / no remote** → drop to the **git-only ladder** below. This is a first-class mode, not an error — name the actual gap once (`gh` is not installed, run `gh auth login`, or add a GitHub remote) and carry on.
- **No `docs/plans/`** → skip the plans panel.
- **No shell at all** (e.g. a browser-based agent) → you can't run the survey; print the commands below for the user to run and reason from what they paste back.

### 2. Survey — collect signals read-only

Gather git always; gather GitHub only when `gh` is usable. All commands are read-only.

**git (always):**
- working tree — `git status --porcelain`, current branch, upstream ahead/behind, `git log @{u}.. --oneline` (unpushed — skip if the branch has no upstream set, which is itself the "push/publish" signal), `git stash list`, and any local branches carrying unmerged commits.
- **branch → issue mapping** — resolve the current branch to a tracked issue by reading an open PR's `Closes #N` (the reliable signal); fall back to a branch-name heuristic (`#N` / `issue-N` / a slug matching an issue title). When it stays unmappable, treat a dirty non-`main` branch as *continue*, not *commit*.

**GitHub (only when `gh` is usable):**
- issues — `gh issue list --state open --json number,title,labels,updatedAt`, bucketed by lifecycle label (`in-progress` / `ready` / `blocked` / `in-review`) plus an **unlabeled/other-status** bucket for repos without that vocabulary. Counts and the actionable set only — no drift detection. Treat recent unlabeled issues as candidates for classification or planning, not as invisible work.
- open PRs — `gh pr list --json number,title,statusCheckRollup,reviewDecision,isDraft,updatedAt`, classified into: *your red / change-requested PR* (actionable), *approved + green* (surface-only), *awaiting others* (surface-only). Cap the list on large repos to stay fast; if a JSON field is rejected, check `gh pr list --help`.
- **stale-tracker signal** — one cheap cross-check: how many merged PRs have a linked issue still open. A single count, used only to decide whether "reconcile" ranks. **Never itemize which or why** — that's issuekit's job.

**plans (filesystem, available even without `gh`):**
- list canonical `docs/plans/plan-<slug>-YYYY-MM-DD.md` files (or wherever the repo keeps plans — an `rfcs/`, `specs/`, or documented location takes precedence); when `gh` is present, cross-check titles against the issue list to flag plans never turned into issues.

### 3. Rank — crown one finish-first move

Map the signals onto candidate actions, each tagged with its owning kit/command, then crown the highest applicable rung (most-recently-active breaks ties; the rest become runners-up). Pick the ladder by whether GitHub signals are available.

**Git-only ladder** (no `gh`):

| # | State | Move → |
|---|-------|--------|
| 1 | uncommitted work on a feature branch | continue / `commitkit` |
| 2 | unpushed commits | `git push` |
| 3 | a stash | restore or drop it |
| 4 | an unmerged local feature branch | finish or clean it up |
| 5 | an unfiled plan doc | `implementkit` / `plankit` |
| 6 | clean on `main`, nothing pending | start something (newest plan) / `plankit` |

**Full ladder** (`gh` available) — every git-only state has an explicit home below. *(Surfaced, never crowned: an approved+green PR; a PR awaiting others.)*

| # | State | Move → |
|---|-------|--------|
| 1 | your PR is red or change-requested | fix CI / address review — `implementkit` / `prkit` |
| 2 | in-progress issue whose branch you're on *(uncommitted work folds in here as "continue")* | resume / `implementkit` |
| 3 | orphaned work — uncommitted on `main`/untracked branch, or unpushed commits | `commitkit` / push |
| 4 | a stash | restore it to finish the work, or drop it if obsolete |
| 5 | an unmerged local feature branch | finish it or clean it up |
| 6 | stale-tracker signal fired | reconcile — `issuekit sync` |
| 7 | a `ready` issue to start (most-recently-updated) | `implementkit` / `orcakit` |
| 8 | an unlabeled/other-status issue needing classification | classify it — `issuekit triage` |
| 9 | an unfiled plan, or none at all | `issuekit create` / `plankit` |

When the owning kit isn't installed, name the **plain action** instead ("commit your changes" rather than "run commitkit") — statuskit routes, it doesn't require the ecosystem.

### 4. Output — dashboard, then one crowned move

Print a compact panel (one line per signal source, **empty panels suppressed**), then the ranked next-actions list with the **#1 move bolded** and its exact kit/command. Keep it to one screen:

```
# Project status — <repo> (<branch>)

## Working tree
<clean | N uncommitted, M unpushed, stash: K>

## Issues        in-progress N · ready N · blocked N · in-review N     (omit without gh)
## Pull requests <open N — X awaiting review, Y CI-red, Z ready to merge>   (omit without gh)
## Plans         <N filed · M unfiled>

## Next move
**→ <the #1 action>** — run `<kit / command>`.

Then: <2–4 ranked runner-up actions, each with its kit>
```

Drop any panel with nothing to show (no PRs → no PR line; no `gh` → omit Issues + PRs and say so once).

## Notes

- **Zero mutation, always.** statuskit surveys and advises; it never changes git or GitHub state. If a recommendation needs a mutation, it routes to the kit that owns it — that kit previews and gets approval on its own.
- **Route, don't launch.** Routing means *naming* the kit and its one-line command — statuskit never invokes the kit for you; the user launches it. Naming "run `issuekit sync`" and then calling the kit yourself would restart mutation in the same breath as "orient me," breaking the read-only stance.
- **Route, don't require.** Every recommendation degrades to a plain command when its kit isn't installed. statuskit is useful in a bare repo with only git.
- **Hold the issuekit line.** Display issue counts and the ready/in-progress set; compute the one staleness boolean to rank "reconcile." Never render an itemized health verdict — the moment you're explaining *which* issues are stale and *why*, that's issuekit `triage`/`sync`, and statuskit should be pointing at it, not doing it.
- **On-demand, no state.** statuskit doesn't persist a `STATUS.md` or a last-run cache; each run is a fresh read.

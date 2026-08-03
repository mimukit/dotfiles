---
name: orcakit
description: >-
  DEPRECATED — do not use. Every capability moved to issuekit (`start`/`close`) and gitkit (worktrees). Use when the user explicitly names "orcakit", "orcakit start", or "orcakit finish"; warn them and route to the replacement. Never select this skill for an unnamed request — issuekit owns "start issue #N", "close #N", and "spin up a worktree for #N".
license: MIT
allowed-tools: Skill
metadata:
  internal: false
---

# orcakit — deprecated

**This skill does nothing.** It has no behavior of its own left; it exists only to catch invocations from muscle memory and point them somewhere real.

orcakit sequenced two systems at the moments they met: a GitHub issue tracker and Orca-managed worktrees. Worktrees are now native `git worktree` on every machine, so there is no Orca half to sequence — and the tracker half it had left was always issuekit's job, reached through a wrapper. Both moments are now owned end to end elsewhere.

## When this fires

**Only when the user names orcakit explicitly** — "orcakit", "orcakit start 12", "orcakit finish 12", "run orcakit".

Do **not** select this skill for a request that merely mentions an issue and a worktree. "Start issue #12", "spin up a worktree for #12", "close #12", "tear down #12's worktree" all belong to **issuekit**, which owns those triggers now. Routing them here would put a deprecation warning in front of a working command for no reason.

## What to do

Print the warning below, then do the replacement work by invoking the skill it names. Do not ask whether to proceed — the user asked for the action, and the mode they wanted maps one-to-one onto its replacement. The warning is a notice, not a gate.

> ⚠️ **orcakit is deprecated and will be removed.** Its worktree half is now **gitkit** and its tracker half is **issuekit**. Running `<replacement>` instead.
>
> | You ran | Use instead |
> |---|---|
> | `orcakit start <n>` | **issuekit `start <n>`** — same `ready` guard, same label flip, worktree via gitkit |
> | `orcakit finish <n>` | **issuekit `close <n>`** — same merged-PR precondition and preview, teardown via gitkit |
>
> Nothing is lost in the move: issuekit's modes are where orcakit's steps went, not a reimplementation of them.

Then:

- **`orcakit start <n>`** → invoke **issuekit `start <n>`**.
- **`orcakit finish <n>`** → invoke **issuekit `close <n>`**. (issuekit names the mode `close`; `finish` was orcakit's word for the same moment.)
- **Neither named** → print the warning and the table, and stop. Don't guess which moment they meant, because one creates a workspace and the other deletes one.

**If issuekit isn't installed**, say so and stop. Do not fall back to running the steps inline: a deprecated skill quietly reimplementing its replacement is exactly the divergence this deprecation exists to end. Point the user at `npx skills add mimukit/skills -s issuekit` (and `-s gitkit`), which is a smaller ask than a wrong workspace.

## What changed, if you're wondering

| orcakit did | Now owned by |
|---|---|
| Guard that the issue is `ready`; refuse otherwise | **issuekit `start`** |
| Flip `ready → in-progress` | **issuekit `start`** |
| Confirm a merged PR before touching anything | **issuekit `close`** |
| Close the issue, tick the parent checklist, unblock dependents | **issuekit `close`** (reusing `sync`) |
| Derive the branch name, create or adopt the worktree | **gitkit** |
| Resolve the base ref | **gitkit** |
| Remove the worktree | **gitkit** |
| Orca↔GitHub issue link (`--issue`), `--no-parent` lineage, the `orca` CLI | **dropped** — Orca-specific, with no equivalent on a headless machine |

The safety property survived the move intact: **no worktree is created for an issue that isn't labeled `ready`.** That guard now lives in issuekit `start`. It matters because an issue only reaches `ready` after a human has grilled it, or via issuekit `sync` when a prerequisite lands — so the gate enforces both the dependency graph and human judgment, and nothing automated can get ahead of either.

## Notes

- **Existing installs are the reason this file still exists.** orcakit was published, so deleting the directory outright would leave anyone who installed it running `orca worktree create` forever, silently diverging from the convention. This notice is the signal; the directory is removed a release or two after it.
- **No shell needed.** This skill runs no commands. If you can't invoke issuekit, print the table above and let the user route themselves.

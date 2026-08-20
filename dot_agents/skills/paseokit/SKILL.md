---
name: paseokit
description: >-
  Push the git worktrees your workflow actually creates into Paseo's workspace registry, and reap the rows whose directories are gone, because Paseo discovers nothing on its own and prunes nothing on its own. Use when the user says "paseokit", "sync my worktrees to paseo", "my paseo sidebar is missing worktrees", "paseo doesn't show my worktree", "clean up my paseo workspaces", "my paseo sidebar is full of dead entries", or "where should paseo put new worktrees".
license: MIT
allowed-tools: Bash, Read, Skill
metadata:
  internal: false
---

# paseokit

[Paseo](https://paseo.sh) shows one **workspace** per checkout, either a main repo or a git worktree under it, and hangs agents off each one. Worktrees themselves come from plain `git worktree`: gitkit's convention, issuekit's `start`, or your own hands.

**Paseo's registry is explicit-only in both directions.** A worktree that `git worktree add` created is invisible to Paseo until something registers it, and a workspace whose directory was deleted stays in the sidebar forever. There is no discovery setting to turn on and no prune command to run. So the sidebar drifts from the disk in both directions at once: real work that never appears, and finished work that never leaves.

paseokit owns exactly that reconciliation: **Paseo's registry, made to match the worktrees that actually exist.** One command, machine-wide, and running it twice changes nothing the second time.

It is on-demand by design. Worktrees appear in Paseo when you run [`sync`](#mode-sync), not when they are created. That is a deliberate trade: no git hooks, no scheduler, no background process, nothing written into any repo.

## The line paseokit does not cross

**Git owns the worktree; Paseo owns the row.** paseokit never runs `paseo workspace create --isolation worktree` to do real work, never invents a path, and never lets Paseo create a branch. Creating and removing a worktree is native `git worktree` under gitkit's convention, so a machine with no Paseo on it runs identical commands.

paseokit works one layer up, on the only thing Paseo alone knows: **the registry row**, meaning that a workspace exists for this path, under this project, with this title.

Two consequences worth stating plainly:

- **`paseo workspace archive` is registry-only.** It removes the row and leaves the directory, the branch, and git's own worktree registration completely intact. That is what lets [`sync`](#mode-sync) reap without a destructive-confirm gate, because nothing it does can lose work.
- **Removing a worktree is still gitkit's job.** Paseo does not notice a deleted directory, so the row has to be archived afterward, which is precisely what `sync` is for.

**paseokit never touches the tracker.** It reads issues and pull requests to build a title and judge a verdict; it never closes an issue, moves a label, or edits a pull request. A merged pull request whose issue is still open is tracker drift, and it says so, routing to **issuekit** `close`.

## When this fires

- **`list`.** "What does paseo think my worktrees are", "why isn't my worktree in the sidebar", "show me the drift". Read-only.
- **`sync`.** "Sync my worktrees to paseo", "register my worktrees", "clean the dead rows out of my sidebar".
- **`align`.** "Where should paseo put new worktrees", "make paseo use my worktree root".

**If no mode is clear, start with [`list`](#mode-list).** It is read-only and it names which rows [`sync`](#mode-sync) would touch, so it is never the wrong first move.

**Not this skill:** creating or removing a worktree (gitkit), closing an issue and tearing down after a merge (issuekit `close`), or driving agents, since `paseo run`, `attach`, `send`, `logs`, and the schedule surface all belong to the `paseo` CLI directly. paseokit is registry *hygiene*, not agent *operation*.

## Preflight (every mode)

```sh
paseo status        # CLI installed? daemon running and reachable?
```

- **`paseo` not installed** → this machine has no Paseo, so there is nothing to reconcile. Say exactly that and stop. Do not fall back to anything: the worktrees are already fine without Paseo, and nothing else in the workflow depends on this skill.
- **Daemon not running or unreachable** → name `paseo start` and stop. Do not start a daemon on someone's machine unasked.
- **`gh` missing or unauthenticated** → titles degrade to the branch name and the tracker column reads "unknown". Nothing else degrades. Unlike a worktree-deleting sweep, no operation here is gated on proving a merge, so a missing `gh` never blocks a mode.
- **A rejected `paseo` flag or subcommand** → the CLI moves fast. Check `paseo <command> --help` before concluding an operation is unsupported. The goal is the contract, meaning the row registered, the row archived, the title set; the exact flag spelling is not.

Verified against Paseo **0.4.0**, CLI and daemon. Re-check the seam below against a newer version before trusting a write.

## What Paseo knows about a workspace

Two surfaces, and the difference between them is load-bearing.

**The CLI listing is a thin projection.** `paseo workspace ls --json` returns only `workspaceId`, `project` (the display name, not the id), `name`, `isolation`, and `cwd`. It lists **active workspaces only**. That is enough to answer one question, which is whether any live row points at this path, and nothing else.

**The state files carry the rest.** Everything the modes below actually decide on lives in two JSON files under `~/.paseo/projects/`:

| file | what it uniquely provides | needed for |
|---|---|---|
| `projects.json` | `projectId` per `rootPath`, plus `projectKey` and `archivedAt` | every registration, since `--project` is mandatory |
| `workspaces.json` | `branch`, `title`, `projectId`, `createdAt`, `archivedAt` | tombstones, duplicate ordering, retitle safety |

**This is a documented seam, not a stable API.** Paseo 0.4.0 ships no `project ls`, `--project` rejects both a name and a path, and the `prj_…` id is not derivable from `projectKey` by any hash, so reading the files is unavoidable rather than a shortcut. Treat them as **read-only**: paseokit parses them and writes through the CLI, never into them.

If either file is missing, unreadable, or shaped unexpectedly, **degrade every writing mode to read-only** and say which file and why. Never guess at an id.

A workspace carries a **title and a pin, and nothing else**, with no issue link and no status field. So `link`-style enrichment has no equivalent here; the title is the entire surface.

### Two things the registry gets wrong

- **`isPaseoOwnedWorktree` is a known lie.** Paseo sets it `true` for a worktree that git created and Paseo merely adopted. No CLI corrects it, so the desktop app may offer to delete a worktree that git owns. paseokit documents this and works around nothing; it never reads the flag to make a decision.
- **`workspace create` is not idempotent.** Two identical calls on one path silently produce two rows with the same `cwd`. Every existence check before a registration is therefore load-bearing rather than an optimization, and it must consider **archived** rows too, or the tombstone rule below fails silently.

## Mode: `list`

Read-only. Changes nothing, asks nothing, and is the right first move whenever the state is unclear.

Join three sources and match on **absolute path**, the only key both git and Paseo record:

```sh
git -C "$REPO" worktree list --porcelain    # per live project in projects.json
paseo workspace ls --json                   # active rows
paseo ls --json                             # agents, each with a cwd and a status
```

Two filters before anything gets a verdict:

- **No symbolic HEAD, no row.** A porcelain record carries either `branch refs/heads/<name>` or `detached`; the detached ones never register. This is the same answer `git symbolic-ref -q HEAD` gives inside the worktree, and it is what keeps debugkit's bisect scratch out of the sidebar.
- **Agent `cwd` values come back tilde-abbreviated** (`~/projects/skills`). Expand before comparing, or every `busy` check quietly returns false.

Then give every row a verdict:

| verdict | means | fix |
|---|---|---|
| `busy` | a non-idle agent's `cwd` is inside this workspace | leave it |
| `registered` | worktree exists, exactly one active row points at it | nothing |
| `unregistered` | worktree exists, no row points at it | [`sync`](#mode-sync) |
| `orphaned` | an active row points at a path that no longer exists | [`sync`](#mode-sync) |
| `duplicate` | two or more active rows share one `cwd` | [`sync`](#mode-sync) |
| `tombstoned` | worktree exists, and its only row is archived | [`sync`](#mode-sync), on confirmation |
| `unknown repo` | worktree under `$WORKTREE_ROOT` whose repo Paseo has never seen | [`sync`](#mode-sync), on confirmation |
| `stray project` | a project whose `rootPath` is a worktree rather than a main checkout | reported only; no CLI deletes a project |
| `reapable` | pull request merged, issue closed, tree clean | **gitkit** teardown, then [`sync`](#mode-sync) |

**Put `busy` rows first when any exist.** Those are the rows where an action would interrupt live work.

**A stray project has a clear signature**: its `projectKey` matches a real project's while its `rootPath` sits under `$WORKTREE_ROOT`. That is what a registration without `--project` produces, and it is invisible in `workspace ls` because the row beneath it may since have been archived.

### Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Nothing. Say so.

**Where it landed.** Give one table, with the counts per verdict.

**Next.** Crown [`sync`](#mode-sync) when any row is `unregistered`, `orphaned`, `duplicate`, or `tombstoned`. Crown **gitkit** teardown instead when the only findings are `reapable`. Say plainly that the sidebar already matches the disk when every row reads `registered`.

## Mode: `sync`

The writing mode, and safe to run repeatedly by construction.

Run [`list`](#mode-list)'s join first, because `sync` acts on exactly those verdicts.

### Straight through, no confirmation

Every operation below is non-destructive and proven so, so none of them asks.

**Register** each `unregistered` worktree:

```sh
paseo workspace create --isolation local --path "$WT" \
  --project "$PROJECT_ID" --title "$TITLE" --json
```

`--isolation local` is correct even though the target is a worktree: it tells Paseo to adopt the checkout at `$WT` rather than create one. Paseo introspects git and records `kind: "worktree"`, the branch, and `mainRepoRoot` on its own.

**`--project` is mandatory.** Without it Paseo creates a duplicate *project* rooted at the worktree path, the `stray project` above, which no CLI can delete. Resolve `$PROJECT_ID` from `projects.json` by matching `rootPath` to the main checkout with `archivedAt` null. **If the id cannot be resolved, skip the registration and report it.** A missing row is recoverable; a stray project is not.

**Archive** each `orphaned` row:

```sh
paseo workspace archive "$WORKSPACE_ID" --json
```

**Collapse** each `duplicate` set to one row: keep the row a live agent is attached to, otherwise the oldest by `createdAt`, and archive the rest.

**Retitle** rows whose title Paseo generated rather than a human:

```sh
paseo workspace rename "$WORKSPACE_ID" "$TITLE"
```

The title is `#<n> · <issue title>`, with `<n>` parsed from an `issue-<n>-<slug>` branch and the title read with `gh issue view "$N" --json title`. It degrades to the branch name when `gh` is unusable or the branch names no issue.

**Only ever retitle a row whose `title` is null or exactly the branch name.** Anything else was set by a human and is left alone, reported as a disagreement rather than overwritten.

**Skip** anything `busy`, naming the agent's short id in the report. Never archive a workspace with a live agent in it.

### Gated on one confirmation each

Both of these widen the scope past what the user asked for, so both stop and ask.

**Unknown repos.** Walk `$WORKTREE_ROOT/*`, resolve each candidate to its main checkout with `git -C "$CANDIDATE" rev-parse --git-common-dir`, and collect the repos Paseo has never seen. List them, then on one OK register the main checkout first:

```sh
paseo workspace create --isolation local --path "$REPO" --json
```

That call is what brings the **project** into being. Re-read `projects.json` afterward for the new `prj_…` id, then register the repo's worktrees with it.

Paseo's own worktrees need no special case. They already carry a row, and their `--git-common-dir` resolves to a repo Paseo knows, so they never reach the unknown-repo bucket, and no hash-directory pattern has to be guessed at.

**Tombstones.** An archived row **suppresses re-registration**: someone archived that workspace deliberately, and re-adding it on the next run would undo the decluttering they just did. Name the tombstoned worktrees, restore them on one OK, and leave them alone otherwise.

**There is no `paseo workspace unarchive` in 0.4.0.** "Restoring" a tombstone means creating a fresh row for the same path, so the archived row stays in `workspaces.json` and the restored workspace is a new `wks_…` id. Say that when you do it; do not report a resurrection.

### Hand off

**What changed.** Report registrations, archives, collapses, and retitles, each with a count. Name every skip with its reason. Put `busy` skips first, because those are live work.

**Where it landed.** Paseo's registry only. Say plainly that no directory, branch, or git registration changed, and that the sidebar reflects the new rows within a few seconds.

**Next.** Crown one:

- **anything `busy`** → name the path and the agent. Tell the user to run `sync` again after that agent finishes.
- **any `stray project`** → name it. Say that the fix is manual: edit `~/.paseo/projects/projects.json`, then run `paseo restart`. Do not perform it, because a daemon restart kills every running agent, including the one reading this.
- **any `reapable`** → route to **gitkit** teardown, otherwise `git -C "$REPO" worktree remove "$WT"` followed by `sync` again to archive the row.
- **tracker drift** → route to **issuekit** `close <n>`, otherwise `gh issue close <n>`.
- **nothing left** → say the registry matches the disk and stop. This is not a loop worth repeating.

## Mode: `align`

One-time configuration, per machine. It does not touch a single workspace.

**Check the worktree root.** Compare `worktrees.root` in `~/.paseo/config.json` against `$WORKTREE_ROOT`, which is gitkit's convention, defaulting to `~/worktrees` unless the environment says otherwise. Two roots in play means every sweep classifies by path forever.

Aligning it **only affects worktrees Paseo creates itself**. Existing worktrees are untouched, and git stores absolute paths, so nothing moves. Say that out loud, because "aligned" reads like "migrated" and it is not.

**Surface `daemon.autoArchiveAfterMerge`.** Setting it `true` lets Paseo archive a workspace by itself when its change request merges, which would cover part of `sync`'s reaping natively. Recommend it as an experiment to observe, and flag both limits honestly: it is undocumented, and it only reaches workspaces where Paseo detected a pull request. `sync` still owns the general case either way.

### Hand off

**What changed.** Report which config keys you compared, and which the user chose to change.

**Where it landed.** Report `~/.paseo/config.json`. Repeat that existing worktrees stayed where they were.

**Next.** Run [`list`](#mode-list) to see the whole set in one table. Then stop. This is a one-time setting per machine, not a routine.

## Notes

- **paseokit is machine-local and always optional.** No Paseo on the box means no-op, and nothing else in the workflow may depend on it. gitkit, issuekit, and the rest never call it, because they would break on every machine without the tool. It is a pump you run, not a link in a chain.
- **`orcakit` is the sibling, not the predecessor.** It reconciles the same worktrees into Orca, whose model is the exact inverse: Orca discovers worktrees on its own and knows nothing about them, so orcakit enriches and cleans up, while paseokit registers and reaps. Both are machine-local and optional, and **neither ever calls the other**.
- **Worktree facts belong to gitkit.** The path convention `$WORKTREE_ROOT/<repo>/<branch>` and the `issue-<n>-<slug>` branch grammar appear here only as declared portability fallbacks for machines without gitkit. Branch naming, base-ref resolution, and the teardown rules live there, and any *other* copy of a gitkit fact in this file is a bug.
- **Tracker facts belong to issuekit.** paseokit reads issue and pull request state to build a title and a verdict; it writes none of it.
- **Read-only modes run straight through; scope-widening ones ask.** `list` never asks. `sync` runs its non-destructive work without a prompt precisely because archiving cannot lose anything, and stops only for the two operations that register something the user did not name.
- **Never write into `~/.paseo/projects/*.json`.** paseokit reads those files because 0.4.0 exposes no CLI equivalent, and writes exclusively through `paseo`. A hand-edited state file needs a daemon restart to take effect, and a restart kills every running agent.
- **No shell available?** Then you cannot reach the `paseo` CLI, `git`, or `gh`. Reason from what the user gives you and **print the exact commands** as a codeblock for them to run, and never report a workspace registered or archived that you could not perform.

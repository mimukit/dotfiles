---
name: paseokit
description: >-
  Push the git worktrees your workflow actually creates into Paseo's workspace registry, because Paseo discovers nothing on its own. Use when the user says "paseokit", "sync my worktrees to paseo", "sync all my projects to paseo", "my paseo sidebar is missing worktrees", "paseo doesn't show my worktree", or "where should paseo put new worktrees". It also reaps the finished work and the dead rows: "clean up the worktrees whose PRs merged", "clean up my paseo workspaces", "my paseo sidebar is full of dead entries".
license: MIT
disable-model-invocation: true
allowed-tools: Bash, Read, Skill
metadata:
  internal: false
---

# paseokit

[Paseo](https://paseo.sh) shows one **workspace** per checkout, either a main repo or a git worktree under it, and hangs agents off each one. Worktrees themselves come from plain `git worktree`: gitkit's convention, issuekit's `start`, or your own hands.

**Paseo registers nothing on its own.** A worktree that `git worktree add` created is invisible to Paseo until something registers it. There is no discovery setting to turn on, so real work never appears in the sidebar by itself.

**Paseo does prune one thing on its own**, per [directory pruning](#the-version-seam) in the version seam: it archives every active row whose directory has gone. It archives nothing else: it never collapses duplicate rows, never judges whether work landed, and never touches a row whose directory still exists. So the drift that remains is the work that never appears, the duplicates, and the finished worktrees still sitting on disk.

paseokit owns exactly that reconciliation, split by direction: [`sync`](#mode-sync) adds what is missing, and [`clean`](modes/clean.md) removes what is finished — the duplicate rows, and the worktrees whose work already landed. Each is scoped to the project you run it from — or the whole machine on request — and running either twice changes nothing the second time.

It is on-demand by design. Worktrees appear in Paseo when you run [`sync`](#mode-sync), not when they are created. That is a deliberate trade: no git hooks, no scheduler, no background process, nothing written into any repo.

## The line paseokit does not cross

**Git owns the worktree; Paseo owns the row.** paseokit never runs `paseo workspace create --isolation worktree` to do real work, never invents a path, and never lets Paseo create a branch. Creating and removing a worktree is native `git worktree` under gitkit's convention, so a machine with no Paseo on it runs identical commands.

paseokit works one layer up, on the only thing Paseo alone knows: **the registry row**, meaning that a workspace exists for this path, under this project, with this title.

Two consequences worth stating plainly:

- **`paseo workspace archive` is not registry-only.** It archives every agent in the workspace, kills every terminal in it, and **deletes the backing worktree directory** when Paseo counts that directory as its own and no other active row points at it. Only the row is reversible; the directory is not. Read [The archive call deletes directories](#the-archive-call-deletes-directories) before you queue a single archive.
- **Removing a worktree is still gitkit's job.** paseokit drives the teardown through gitkit and never lets an archive stand in for it, because an archive that deletes is a delete nobody previewed.
- **[`clean`](modes/clean.md) is the one mode that reaches the disk.** It decides *which* worktrees are finished and it drives the teardown, but it runs no `git worktree remove` of its own when gitkit is installed, and it never invents a path or a branch rule. The decision is paseokit's; the removal is still gitkit's.

**paseokit never touches the tracker.** It reads issues and pull requests to build a title and judge a verdict; it never closes an issue, moves a label, or edits a pull request. A merged pull request whose issue is still open is tracker drift, and it says so, routing to **issuekit** `close`.

## When this fires

- **`list`.** "What does paseo think my worktrees are", "why isn't my worktree in the sidebar", "show me the drift". Read-only.
- **`sync`.** "Sync my worktrees to paseo", "register my worktrees". Scoped to the current project by default; "sync all", "sync everything", or "all my projects" widens it to the whole machine — see [Scope](#scope).
- **`clean`.** "Clean up the worktrees whose PRs merged", "delete the merged worktrees and their sessions", "clean the dead rows out of my sidebar", "my machine is full of landed work". The only mode that archives a row or deletes from disk; it lists every planned archive and delete first, then confirms the archives as one set and each delete on its own.
- **`align`.** "Where should paseo put new worktrees", "make paseo use my worktree root".

**If no mode is clear, start with [`list`](#mode-list).** It is read-only and it names which rows [`sync`](#mode-sync) would touch, so it is never the wrong first move.

**`sync` versus `clean`.** `sync` only ever adds: it registers, retitles, and restores, and it never archives a row, never collapses a duplicate, and never touches the disk. Every removal, from the archive of a dead row up to the deletion of a merged worktree, belongs to `clean`. `clean` previews both halves in one list and asks before it touches either; its disk half additionally proves the pull request merged before a worktree can appear in that list, and follows gitkit's removal rule of one confirmation per worktree.

**Not this skill:** creating a worktree (gitkit), closing an issue and tearing down after a merge (issuekit `close`), or driving agents, since `paseo run`, `attach`, `send`, `logs`, and the schedule surface all belong to the `paseo` CLI directly. paseokit is registry *hygiene*, not agent *operation*.

## Preflight (every mode)

```sh
paseo status        # CLI installed? daemon running and reachable?
```

- **`paseo` not installed** → this machine has no Paseo, so there is nothing to reconcile. Say exactly that and stop. Do not fall back to anything: the worktrees are already fine without Paseo, and nothing else in the workflow depends on this skill.
- **Daemon not running or unreachable** → name `paseo start` and stop. Do not start a daemon on someone's machine unasked.
- **`gh` missing or unauthenticated** → titles degrade to the branch name and the tracker column reads "unknown". Nothing else degrades in `list`, `sync`, and `align`. **[`clean`](modes/clean.md)'s disk half is the exception and it stops**, because its whole precondition is a proven merge and only the tracker can prove one; its registry reap still runs, behind its own preview and confirmation.
- **A rejected `paseo` flag or subcommand** → the CLI moves fast. Check `paseo <command> --help` before concluding an operation is unsupported, and compare the two version numbers below before concluding the CLI is at fault. The goal is the contract, meaning the row registered, the row archived, the title set; the exact flag spelling is not.

Every version-dependent fact sits in [The version seam](#the-version-seam). Re-check that list against a newer version before trusting a write.

**Read the two version numbers separately.** `paseo status` prints `CLI` and `Daemon Version` as separate rows, and they drift apart: the CLI upgrades on the next install, and the daemon keeps running the code it started with until `paseo restart`. The CLI advertises every flag its own version knows, so a flag can parse locally and still fail at the daemon. When the two numbers differ, treat a rejected write as a version skew first and say so. **Do not run `paseo restart` to close the gap.** A restart kills every running agent, including the one reading this.

## The version seam

Verified against Paseo CLI **0.8.0** and daemon **0.8.0**. Every fact in this skill that depends on the Paseo version is in this list, and the rest of the skill cites these entries by name and states no version of its own. When the daemon reports a newer version, re-check each entry before trusting a write, and update this list in one place.

- **Directory pruning.** A reconciliation pass runs at daemon start and every five minutes after. It archives every active row whose directory has gone, with the reason `directory_missing`, and nothing else. It arrived in 0.7.
- **The ownership flag.** `isPaseoOwnedWorktree` runs the same `<hash>/<slug>` path test as the archive delete, and every reconciliation pass refreshes it. Before 0.7 a looser check set it, and it disagreed with the delete.
- **The `project` group.** `create`, `ls`, `rename`, and `delete` are all implemented. A safe probe for any other verb is one the daemon accepts and acts on without matching anything, such as a well-formed id that exists nowhere.
- **No unarchive.** The `workspace` subcommands are `create`, `ls`, `rename`, and `archive`, and nothing else.
- **`daemon.autoArchiveAfterMerge` gates.** It acts only on a merged pull request, only on a clean tree, only when nothing is ahead of origin, and only on a Paseo-created worktree. These gates arrived in 0.7.

## What Paseo knows about a workspace

Two surfaces, and the difference between them is load-bearing.

**The CLI listing is a thin projection.** `paseo workspace ls --json` returns only `workspaceId`, `project` (the display name, not the id), `name`, `isolation`, and `cwd`. It lists **active workspaces only**. That is enough to answer one question, which is whether any live row points at this path, and nothing else.

**`paseo project ls --json` resolves the project id.** It returns `projectId`, `name`, `kind`, and `path` for every live project, so the `prj_…` id that `--project` demands now comes from the CLI. Match on `path`. Use it in preference to the state file, and fall back to the file only when the command is missing or the daemon rejects it.

**The state files carry what neither listing exposes.** These live under `~/.paseo/projects/`:

| file | what it uniquely provides | needed for |
|---|---|---|
| `workspaces.json` | `branch`, `title`, `kind`, `projectId`, `createdAt`, `archivedAt`, `isPaseoOwnedWorktree`, `worktreeRoot`, `mainRepoRoot` | tombstones, duplicate ordering, retitle safety, the delete forecast |
| `projects.json` | `projectKey` and `archivedAt` per project | stray-project detection, and the `project ls` fallback |

`kind` reads `local_checkout` for a main checkout and `worktree` for a worktree.

**This is a documented seam, not a stable API.** `workspace ls` still omits `branch`, `title`, `createdAt`, and every archived row, so reading `workspaces.json` remains unavoidable rather than a shortcut. Treat both files as **read-only**: paseokit parses them and writes through the CLI, never into them.

If either file is missing, unreadable, or shaped unexpectedly, **degrade every writing mode to read-only** and say which file and why. Never guess at an id.

A workspace carries a **title and a pin, and nothing else**, with no issue link and no status field. So `link`-style enrichment has no equivalent here; the title is the entire surface.

### The archive call deletes directories

`paseo workspace archive <workspace-id>` runs three steps, and only the first is a registry edit:

1. It archives every agent the workspace owns, live and stored alike, and kills every terminal in it. It does not ask, and it does not refuse because an agent is running.
2. It archives the workspace record. This part is reversible.
3. It then tries to **delete the backing directory**, when no *other* active row points at it and the directory passes the ownership test below. The delete runs `git worktree remove --force` and then removes the directory. Git gives none of it back.

**The delete has a path test, and the path shape is the whole test.** The daemon accepts a directory only at `<worktrees.root>/<hash>/<slug>`, where `<hash>` is a short base-36 digest of the main checkout's absolute path. gitkit's convention is `$WORKTREE_ROOT/<repo>/<branch>`, which carries the repo *name* where the daemon wants the *hash*, so a gitkit worktree fails the test and the delete throws `Refusing to delete non-Paseo worktree`. **Only a worktree Paseo created itself passes.** The daemon catches that throw, logs it as a warning, and reports the archive as successful, so a refused delete is silent from the CLI.

**`isPaseoOwnedWorktree` forecasts the delete**, per [the ownership flag](#the-version-seam) in the version seam: `true` in `workspaces.json` forecasts a disk delete and `false` forecasts a registry-only archive. **Confirm it against the path shape anyway** before you queue an archive, because the stored value is only as fresh as the last pass: a directory whose parent name is the repo name is a git worktree, and a directory whose parent name is an opaque hash is Paseo's.

Three rules follow, and none of them is optional:

- **Treat an archive as a disk delete whenever the worktree sits under a hash directory.** That is the only shape the daemon will remove. Preview it as a delete, never as a registry edit.
- **A dirty tree is no protection.** The daemon passes `--force` to `git worktree remove`, so uncommitted work in a Paseo-created worktree dies with the directory. This is why [`clean`](modes/clean.md) proves the tree clean itself rather than trusting the call to refuse.
- **A live agent does not block the call.** The archive stops and archives the agent instead, and it kills every terminal in the workspace. The `busy` check is therefore paseokit's own guard, not a safety net the CLI provides.

**Workspace teardown commands run before the delete**, on the backing path. A workspace with a configured teardown script runs it on every archive of a Paseo-owned worktree. A teardown command that fails cancels the directory delete and leaves the row archived, so the workspace and its directory then disagree.

### One more thing the registry gets wrong

**`workspace create` is not idempotent.** Two identical calls on one path silently produce two rows with the same `cwd`. Every existence check before a registration is therefore load-bearing rather than an optimization, and it must consider **archived** rows too, or the tombstone rule below fails silently.

## Mode: `list`

Read-only. Changes nothing, asks nothing, and is the right first move whenever the state is unclear.

Join three sources and match on **absolute path**, the only key both git and Paseo record:

```sh
paseo project ls --json                     # live projects, each with a projectId and a path
git -C "$REPO" worktree list --porcelain    # per live project
paseo workspace ls --json                   # active rows
paseo ls -g --json                          # agents across every directory, each with a cwd and a status
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
| `orphaned` | an active row points at a path that no longer exists | wait; the daemon archives it within five minutes |
| `duplicate` | two or more active rows share one `cwd` | [`clean`](modes/clean.md) |
| `tombstoned` | worktree exists, and its only row is archived | [`sync`](#mode-sync), on confirmation |
| `unknown repo` | worktree under `$WORKTREE_ROOT` whose repo Paseo has never seen | [`sync`](#mode-sync), on confirmation |
| `stray project` | a project whose `rootPath` is a worktree rather than a main checkout | reported; `paseo project delete` removes it, on confirmation |
| `reapable` | pull request merged, issue closed, tree clean | [`clean`](modes/clean.md) |

**Put `busy` rows first when any exist.** Those are the rows where an action would interrupt live work.

**An `orphaned` row is a timing artifact**, per [directory pruning](#the-version-seam). The daemon's own pass archives it, so report it and say when it will go. Queue one for archive only when the user asks to clear it now.

**A stray project has a clear signature**: its `projectKey` matches a real project's while its `rootPath` sits under `$WORKTREE_ROOT`. That is what a registration without `--project` produces, and it is invisible in `workspace ls` because the row beneath it may since have been archived.

### Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Nothing. Say so.

**Where it landed.** Give one table, with the counts per verdict.

**Next.** Crown [`sync`](#mode-sync) when any row is `unregistered` or `tombstoned`. Crown [`clean`](modes/clean.md) when any row is `duplicate` or `reapable`. When both apply, crown `clean` first, so `sync` registers into a registry that is already free of dead rows. Say plainly that the sidebar already matches the disk when every row reads `registered`.

## Mode: `sync`

The adding mode, and safe to run repeatedly by construction. It registers, retitles, and restores; **it never archives a row and never touches a directory or a branch**. Removal of any kind, including the archive of a dead row, belongs to [`clean`](modes/clean.md).

### Scope

`sync` has two scopes, and the words in the request pick one:

- **Project scope is the default.** Resolve the main checkout from the current directory with `git rev-parse --path-format=absolute --git-common-dir`, then act only on that project: its worktrees on disk, and the registry rows whose `projectId` matches it in `workspaces.json`. Every other project's rows and worktrees stay untouched and unreported.
- **`sync all` is machine-wide.** The user asks for it with "sync all", "sync everything", or "all my projects". It covers every project `paseo project ls --json` returns, and it is the only scope that runs the unknown-repo walk below, because that walk is a machine-wide sweep by nature.

**Outside a git repository, project scope has no referent.** Say so, and name `sync all` as the way to sweep the machine. Do not silently widen the scope the user did not ask for.

Run [`list`](#mode-list)'s join first, filtered to the chosen scope, because `sync` acts on exactly those verdicts.

### Straight through, no confirmation

Every operation below is non-destructive and proven so, so none of them asks.

**Register** each `unregistered` worktree:

```sh
paseo workspace create --isolation local --path "$WT" \
  --project "$PROJECT_ID" --title "$TITLE" --json
```

`--isolation local` is correct even though the target is a worktree: it tells Paseo to adopt the checkout at `$WT` rather than create one. Paseo introspects git and records `kind: "worktree"`, the branch, and `mainRepoRoot` on its own.

**`--project` is mandatory.** Without it Paseo creates a duplicate *project* rooted at the worktree path, the `stray project` above. Resolve `$PROJECT_ID` with `paseo project ls --json`, matching `path` to the main checkout, and fall back to `projects.json` by `rootPath` with `archivedAt` null. **If the id cannot be resolved, skip the registration and report it.** Never register without `--project` to get past a missing id.

**Report** each `duplicate` set, and route it to [`clean`](modes/clean.md). Report each `orphaned` row as self-healing. `sync` names both so the drift is visible, and it archives nothing.

**Retitle** rows whose title Paseo generated rather than a human:

```sh
paseo workspace rename "$WORKSPACE_ID" "$TITLE"
```

The title is `#<n> · <issue title>`, with `<n>` parsed from an `issue-<n>-<slug>` branch and the title read with `gh issue view "$N" --json title`. It degrades to the branch name when `gh` is unusable or the branch names no issue.

**Only ever retitle a row whose `title` is null or exactly the branch name.** Anything else was set by a human and is left alone, reported as a disagreement rather than overwritten.

**Skip** anything `busy`, naming the agent's short id in the report. Never retitle a workspace with a live agent in it.

### Gated on one confirmation each

Both of these widen the scope past what the user asked for, so both stop and ask.

**Unknown repos** (`sync all` only, per [Scope](#scope)). Walk `$WORKTREE_ROOT/*`, resolve each candidate to its main checkout with `git -C "$CANDIDATE" rev-parse --git-common-dir`, and collect the repos Paseo has never seen. List them, then on one OK create the project first:

```sh
paseo project create "$REPO" --json
```

That call returns the new `prj_…` id directly. Register the repo's main checkout and then its worktrees with that id, each through `workspace create --isolation local --project "$PROJECT_ID"`.

Paseo's own worktrees need no special case. They already carry a row, and their `--git-common-dir` resolves to a repo Paseo knows, so they never reach the unknown-repo bucket, and no hash-directory pattern has to be guessed at.

**Tombstones.** An archived row **suppresses re-registration**: someone archived that workspace deliberately, and re-adding it on the next run would undo the decluttering they just did. Name the tombstoned worktrees, restore them on one OK, and leave them alone otherwise.

**There is no `paseo workspace unarchive`**, per the [version seam](#the-version-seam). "Restoring" a tombstone means creating a fresh row for the same path, so the archived row stays in `workspaces.json` and the restored workspace is a new `wks_…` id. Say that when you do it; do not report a resurrection.

### Hand off

**What changed.** Name the scope you ran, the current project or the whole machine. Report registrations, restores, and retitles, each with a count. Name every skip with its reason. Put `busy` skips first, because those are live work.

**Where it landed.** Paseo's registry only, and only new or renamed rows. Say plainly that no row was archived and that no directory, branch, or git registration changed, and that the sidebar reflects the new rows within a few seconds.

**Next.** Crown one:

- **anything `busy`** → name the path and the agent. Tell the user to run `sync` again after that agent finishes.
- **any `stray project`** → name it, and name `paseo project delete "$PROJECT_ID"` as the fix. **Do not run it here.** That command deletes the project *and every workspace under it*, so it belongs behind [`clean`](modes/clean.md)'s preview and confirmation, not in `sync`'s straight-through half.
- **any `duplicate` or `reapable`** → route to [`clean`](modes/clean.md), which collapses the duplicate rows and tears the merged worktrees down through gitkit in one pass.
- **tracker drift** → route to **issuekit** `close <n>`, otherwise `gh issue close <n>`.
- **nothing left** → say the registry matches the disk and stop. This is not a loop worth repeating.

## The modes

The mode bodies of `clean` and `align` live in one file each under `modes/`. Route with [When this fires](#when-this-fires), read that one file, and follow it. Everything in this file applies to every mode and is not restated in the mode files. `list` and `sync` stay here, because `list`'s join and verdicts are the vocabulary both `sync` and `clean` act on.

- Mode `clean` → read [modes/clean.md](modes/clean.md), then follow it.
- Mode `align` → read [modes/align.md](modes/align.md), then follow it.

## Notes

- **paseokit is machine-local and always optional.** No Paseo on the box means no-op, and nothing else in the workflow may depend on it. gitkit, issuekit, and the rest never call it, because they would break on every machine without the tool. It is a pump you run, not a link in a chain.
- **`orcakit` is the sibling, not the predecessor.** It reconciles the same worktrees into Orca, whose model is the exact inverse: Orca discovers worktrees on its own and knows nothing about them, so orcakit enriches and cleans up, while paseokit registers and reaps. Both are machine-local and optional, and **neither ever calls the other**.
- **Worktree facts belong to gitkit.** The path convention `$WORKTREE_ROOT/<repo>/<branch>` and the `issue-<n>-<slug>` branch grammar appear here only as declared portability fallbacks for machines without gitkit. Branch naming, base-ref resolution, and the teardown rules live there, and any *other* copy of a gitkit fact in this file is a bug.
- **Tracker facts belong to issuekit.** paseokit reads issue and pull request state to build a title and a verdict; it writes none of it.
- **Safe work runs straight through; scope-widening and destructive work asks.** `list` never asks. `sync` runs its additions without a prompt, and stops only for the two operations that register something the user did not name. `clean` lists every planned archive and delete before doing any of it. It asks once for the archives, because the user should see what leaves the sidebar, and once per delete, because gitkit's removal rule treats each worktree as its own decision, and a removed worktree is the one thing here that git cannot give back.
- **No `paseo` command is safe because its name sounds safe.** `archive` deletes directories and `project delete` takes every workspace under it with it. Check `paseo <command> --help` for what a verb reaches, and treat a one-line description as a summary rather than a contract.
- **Never write into `~/.paseo/projects/*.json`.** paseokit reads those files for the fields no listing exposes, and writes exclusively through `paseo`. A hand-edited state file needs a daemon restart to take effect, and a restart kills every running agent.
- **No shell available?** Then you cannot reach the `paseo` CLI, `git`, or `gh`. Reason from what the user gives you and **print the exact commands** as a codeblock for them to run, and never report a workspace registered or archived that you could not perform.

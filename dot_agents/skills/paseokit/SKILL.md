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

**Paseo does prune one thing on its own, since 0.7.** A reconciliation pass runs at daemon start and every five minutes after, and it archives every active row whose directory has gone, with the reason `directory_missing`. It archives nothing else: it never collapses duplicate rows, never judges whether work landed, and never touches a row whose directory still exists. So the drift that remains is the work that never appears, the duplicates, and the finished worktrees still sitting on disk.

paseokit owns exactly that reconciliation, split by direction: [`sync`](#mode-sync) adds what is missing, and [`clean`](#mode-clean) removes what is finished — the duplicate rows, and the worktrees whose work already landed. Each is scoped to the project you run it from — or the whole machine on request — and running either twice changes nothing the second time.

It is on-demand by design. Worktrees appear in Paseo when you run [`sync`](#mode-sync), not when they are created. That is a deliberate trade: no git hooks, no scheduler, no background process, nothing written into any repo.

## The line paseokit does not cross

**Git owns the worktree; Paseo owns the row.** paseokit never runs `paseo workspace create --isolation worktree` to do real work, never invents a path, and never lets Paseo create a branch. Creating and removing a worktree is native `git worktree` under gitkit's convention, so a machine with no Paseo on it runs identical commands.

paseokit works one layer up, on the only thing Paseo alone knows: **the registry row**, meaning that a workspace exists for this path, under this project, with this title.

Two consequences worth stating plainly:

- **`paseo workspace archive` is not registry-only.** It archives every agent in the workspace, kills every terminal in it, and **deletes the backing worktree directory** when Paseo counts that directory as its own and no other active row points at it. Only the row is reversible; the directory is not. Read [The archive call deletes directories](#the-archive-call-deletes-directories) before you queue a single archive.
- **Removing a worktree is still gitkit's job.** paseokit drives the teardown through gitkit and never lets an archive stand in for it, because an archive that deletes is a delete nobody previewed.
- **[`clean`](#mode-clean) is the one mode that reaches the disk.** It decides *which* worktrees are finished and it drives the teardown, but it runs no `git worktree remove` of its own when gitkit is installed, and it never invents a path or a branch rule. The decision is paseokit's; the removal is still gitkit's.

**paseokit never touches the tracker.** It reads issues and pull requests to build a title and judge a verdict; it never closes an issue, moves a label, or edits a pull request. A merged pull request whose issue is still open is tracker drift, and it says so, routing to **issuekit** `close`.

## When this fires

- **`list`.** "What does paseo think my worktrees are", "why isn't my worktree in the sidebar", "show me the drift". Read-only.
- **`sync`.** "Sync my worktrees to paseo", "register my worktrees". Scoped to the current project by default; "sync all", "sync everything", or "all my projects" widens it to the whole machine — see [Scope](#scope).
- **`clean`.** "Clean up the worktrees whose PRs merged", "delete the merged worktrees and their sessions", "clean the dead rows out of my sidebar", "my machine is full of landed work". The only mode that archives a row or deletes from disk; it lists every planned archive and delete first, and one confirmation gates the whole set.
- **`align`.** "Where should paseo put new worktrees", "make paseo use my worktree root".

**If no mode is clear, start with [`list`](#mode-list).** It is read-only and it names which rows [`sync`](#mode-sync) would touch, so it is never the wrong first move.

**`sync` versus `clean`.** `sync` only ever adds: it registers, retitles, and restores, and it never archives a row, never collapses a duplicate, and never touches the disk. Every removal, from the archive of a dead row up to the deletion of a merged worktree, belongs to `clean`. `clean` previews both halves in one list and asks before it touches either; its disk half additionally proves the pull request merged before a worktree can appear in that list.

**Not this skill:** creating a worktree (gitkit), closing an issue and tearing down after a merge (issuekit `close`), or driving agents, since `paseo run`, `attach`, `send`, `logs`, and the schedule surface all belong to the `paseo` CLI directly. paseokit is registry *hygiene*, not agent *operation*.

## Preflight (every mode)

```sh
paseo status        # CLI installed? daemon running and reachable?
```

- **`paseo` not installed** → this machine has no Paseo, so there is nothing to reconcile. Say exactly that and stop. Do not fall back to anything: the worktrees are already fine without Paseo, and nothing else in the workflow depends on this skill.
- **Daemon not running or unreachable** → name `paseo start` and stop. Do not start a daemon on someone's machine unasked.
- **`gh` missing or unauthenticated** → titles degrade to the branch name and the tracker column reads "unknown". Nothing else degrades in `list`, `sync`, and `align`. **[`clean`](#mode-clean)'s disk half is the exception and it stops**, because its whole precondition is a proven merge and only the tracker can prove one; its registry reap still runs, behind its own preview and confirmation.
- **A rejected `paseo` flag or subcommand** → the CLI moves fast. Check `paseo <command> --help` before concluding an operation is unsupported, and compare the two version numbers below before concluding the CLI is at fault. The goal is the contract, meaning the row registered, the row archived, the title set; the exact flag spelling is not.

Verified against Paseo CLI **0.7.0** and daemon **0.7.0**. Re-check the seam below against a newer version before trusting a write.

**Read the two version numbers separately.** `paseo status` prints `CLI` and `Daemon Version` as separate rows, and they drift apart: the CLI upgrades on the next install, and the daemon keeps running the code it started with until `paseo restart`. The CLI advertises every flag its own version knows, so a flag can parse locally and still fail at the daemon. When the two numbers differ, treat a rejected write as a version skew first and say so. **Do not run `paseo restart` to close the gap.** A restart kills every running agent, including the one reading this.

Against daemon 0.7.0 the whole `project` group is implemented, `create`, `ls`, `rename`, and `delete` alike. A safe probe for any other verb is one the daemon accepts and acts on without matching anything, such as a well-formed id that exists nowhere.

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

**`isPaseoOwnedWorktree` now runs that same test, so 0.7 makes it readable.** Paseo computes the flag from the `<hash>/<slug>` check and refreshes it on every reconciliation pass, so `true` in `workspaces.json` forecasts a disk delete and `false` forecasts a registry-only archive. Earlier versions set it from a looser check and it lied; on 0.7 it agrees with the delete. **Confirm it against the path shape anyway** before you queue an archive, because the stored value is only as fresh as the last pass: a directory whose parent name is the repo name is a git worktree, and a directory whose parent name is an opaque hash is Paseo's.

Three rules follow, and none of them is optional:

- **Treat an archive as a disk delete whenever the worktree sits under a hash directory.** That is the only shape the daemon will remove. Preview it as a delete, never as a registry edit.
- **A dirty tree is no protection.** The daemon passes `--force` to `git worktree remove`, so uncommitted work in a Paseo-created worktree dies with the directory. This is why [`clean`](#mode-clean) proves the tree clean itself rather than trusting the call to refuse.
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
| `duplicate` | two or more active rows share one `cwd` | [`clean`](#mode-clean) |
| `tombstoned` | worktree exists, and its only row is archived | [`sync`](#mode-sync), on confirmation |
| `unknown repo` | worktree under `$WORKTREE_ROOT` whose repo Paseo has never seen | [`sync`](#mode-sync), on confirmation |
| `stray project` | a project whose `rootPath` is a worktree rather than a main checkout | reported; `paseo project delete` removes it, on confirmation |
| `reapable` | pull request merged, issue closed, tree clean | [`clean`](#mode-clean) |

**Put `busy` rows first when any exist.** Those are the rows where an action would interrupt live work.

**An `orphaned` row is a timing artifact on 0.7.** The daemon's own pass archives it, so report it and say when it will go. Queue one for archive only when the user asks to clear it now.

**A stray project has a clear signature**: its `projectKey` matches a real project's while its `rootPath` sits under `$WORKTREE_ROOT`. That is what a registration without `--project` produces, and it is invisible in `workspace ls` because the row beneath it may since have been archived.

### Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Nothing. Say so.

**Where it landed.** Give one table, with the counts per verdict.

**Next.** Crown [`sync`](#mode-sync) when any row is `unregistered` or `tombstoned`. Crown [`clean`](#mode-clean) when any row is `duplicate` or `reapable`. When both apply, crown `clean` first, so `sync` registers into a registry that is already free of dead rows. Say plainly that the sidebar already matches the disk when every row reads `registered`.

## Mode: `sync`

The adding mode, and safe to run repeatedly by construction. It registers, retitles, and restores; **it never archives a row and never touches a directory or a branch**. Removal of any kind, including the archive of a dead row, belongs to [`clean`](#mode-clean).

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

**Report** each `duplicate` set, and route it to [`clean`](#mode-clean). Report each `orphaned` row as self-healing. `sync` names both so the drift is visible, and it archives nothing.

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

**There is still no `paseo workspace unarchive` in 0.7.0.** The subcommand set is `create`, `ls`, `rename`, and `archive`, and nothing else. "Restoring" a tombstone means creating a fresh row for the same path, so the archived row stays in `workspaces.json` and the restored workspace is a new `wks_…` id. Say that when you do it; do not report a resurrection.

### Hand off

**What changed.** Name the scope you ran, the current project or the whole machine. Report registrations, restores, and retitles, each with a count. Name every skip with its reason. Put `busy` skips first, because those are live work.

**Where it landed.** Paseo's registry only, and only new or renamed rows. Say plainly that no row was archived and that no directory, branch, or git registration changed, and that the sidebar reflects the new rows within a few seconds.

**Next.** Crown one:

- **anything `busy`** → name the path and the agent. Tell the user to run `sync` again after that agent finishes.
- **any `stray project`** → name it, and name `paseo project delete "$PROJECT_ID"` as the fix. **Do not run it here.** That command deletes the project *and every workspace under it*, so it belongs behind [`clean`](#mode-clean)'s preview and confirmation, not in `sync`'s straight-through half.
- **any `duplicate` or `reapable`** → route to [`clean`](#mode-clean), which collapses the duplicate rows and tears the merged worktrees down through gitkit in one pass.
- **tracker drift** → route to **issuekit** `close <n>`, otherwise `gh issue close <n>`.
- **nothing left** → say the registry matches the disk and stop. This is not a loop worth repeating.

## Mode: `clean`

The removing mode, and the only one. Every archive and every delete in this skill happens here, in two halves with different blast radii:

- **The registry reap** collapses duplicate rows, and archives an `orphaned` row when the user asks for it before the daemon's own pass gets there. Reversible **only because of what it is scoped to**, not because `archive` is a safe call. See [the reap rule](#1-find-the-registry-reap-candidates).
- **The worktree teardown** removes the whole local footprint of merged work: the agent sessions, the worktree directory, the local branch, and the registry row. Destructive, and git gives none of it back.

**Neither half touches anything before the preview.** The mode first collects both candidate sets, prints them as one list, and waits for one confirmation covering the whole set.

### Scope

`clean` takes the same two scopes as [`sync`](#scope), with the same words. Project scope is the default. "clean all", "clean everything", or "all my projects" widens it to every project `paseo project ls --json` returns.

### 1. Find the registry reap candidates

Run [`list`](#mode-list)'s join first, filtered to the chosen scope. Collect, without archiving anything yet:

- Each `duplicate` set, collapsed on paper to one row: keep the row a live agent is attached to, otherwise the oldest by `createdAt`, and queue the rest for archive.
- Each `orphaned` row, queued for archive **only when the user asked to clear the sidebar now**. Otherwise report it and let the daemon's five-minute pass take it.

**The reap rule: a reap candidate must be a row that cannot reach the disk.** Per [The archive call deletes directories](#the-archive-call-deletes-directories), test each queued row and keep it only when one of these holds:

- Its directory is already gone. That is every `orphaned` row by definition, so the orphan half is safe by construction.
- Its directory's parent is the repo name rather than a hash, so the daemon refuses the delete. Archiving it edits the registry and nothing else. On 0.7 the row's `isPaseoOwnedWorktree` reads `false` here and agrees with the path test; read both and reject the row when they disagree.
- Another active row survives the reap pointing at the same directory. That is what protects a `duplicate` set: the kept row still references the path, so the delete test fails and the directory stays. **The rule holds only while the kept row survives**, so never queue a whole duplicate set, and never queue the kept row.

A row that passes none of the three is a disk delete wearing a reap's clothes. **Move it to the teardown half**, where it must prove a merged pull request first, or reject it and report why.

**Never queue a workspace with a live agent in it.** The archive will not refuse on your behalf; it archives the agent and continues.

**Collect each `stray project` too, as its own candidate class.** `paseo project delete "$PROJECT_ID"` is the fix, and it removes the project *and every workspace under it*, so it never rides along with a row archive. Before you queue one, list the workspaces that would go with it and carry that list into the preview. **Never queue a stray project holding a workspace whose directory a real project still needs**, and never queue one with a live agent under it.

### 2. Find the teardown candidates

From the same join, test every worktree that carries a branch. A candidate must pass **all four** gates:

- **The pull request merged.** Read it per branch, and accept nothing weaker:

  ```sh
  gh pr list --head "$BRANCH" --state merged --json number,title,mergedAt,url --limit 1
  ```

  A closed-unmerged pull request is not a merge, and no open one qualifies. **Without a merged pull request, the worktree is not a candidate**, whatever the branch name says.
- **The tree is clean.** No uncommitted change, no untracked file, no stash entry made in this worktree:

  ```sh
  git -C "$WT" status --porcelain
  ```

- **Nothing is unpushed.** `git -C "$WT" log --oneline "@{upstream}.."` returns nothing, or the branch has no upstream *and* every commit on it is contained in the merged pull request. A commit that exists only here dies with the directory.
- **No live agent.** No non-idle agent's `cwd` sits inside the worktree. A `busy` workspace is never a candidate, and it is reported, never queued.

**`gh` missing or unauthenticated blocks the teardown entirely.** The merge is the whole precondition, and there is no way to prove it without the tracker. Say so, and carry only the registry reap candidates into the preview, rather than falling back to a branch-name guess.

**An open issue does not block the clean.** The pull request merged, so the work is on the base branch and the local copy is redundant. Report the drift and route it to **issuekit** `close <n>` in the hand-off, and do not close the issue here.

### 3. Preview, then confirm once

Print one table before touching anything, split into two labelled sections. The **archive** section lists each registry reap candidate with the workspace id, the title, the reason (`orphaned`, or `duplicate` with the kept row named), and which of the three reap-rule tests it passed. The **delete** section lists each teardown candidate with the branch, the merged pull request number and title, the worktree path, the workspace id, and the agent sessions that will be removed with it. Sum each section in a closing line.

Give a **stray project** section its own block when any is queued, listing the project id, its `rootPath`, and every workspace that goes with it by id and title. That count is what [Reap, then tear down, in this order](#4-reap-then-tear-down-in-this-order) checks the result against.

**Say which section reaches the disk.** State in one line above the table that the archive section removes rows and stops there, and that the delete section removes directories and branches that git cannot restore. The stray project section removes rows only, however many of them.

Then ask **one** question covering the listed set, and wait. This is the mergekit rule applied to a removal: the confirmation is a batch only because every row in it is on the screen. Silence is not consent, and a partial answer means clean only the rows the user named.

An empty list ends the mode here. Say the registry and the disk already match, and skip to the hand-off.

Print the rejected worktrees under the table with their reason, one line each, because "why is this one still here" is the next question every time.

### 4. Reap, then tear down, in this order

**Archive first.** Per confirmed reap candidate:

```sh
paseo workspace archive "$WORKSPACE_ID" --json
```

Then, per confirmed teardown candidate, and never in a different order, since each step removes the thing the next one would otherwise strand:

1. **Stop the agent sessions in that worktree.** Take them from `paseo ls -g --json`, filtered by expanded `cwd`, and stop each one through the `paseo` CLI. Check `paseo --help` for the current verb rather than assuming one. An agent left running holds a directory that is about to disappear.
2. **Remove the worktree through gitkit**, keyed on the branch. Without gitkit installed, `git -C "$REPO" worktree remove "$WT"`. Teardown is **idempotent**: a directory already gone is reported as "already gone", never as an error. **A removal that refuses because the tree is dirty stops that candidate** and is reported; never pass `--force`.
3. **Delete the local branch** with `git -C "$REPO" branch -d "$BRANCH"`, the safe delete. If git refuses because the branch is not merged into the base ref, which happens on a squash merge, confirm that specific branch separately before `-D`, and name the pull request that landed it.
4. **Archive the registry row** with `paseo workspace archive "$WORKSPACE_ID" --json`. The gitkit removal above already deleted the directory, so the call finds nothing left to delete and only the row goes. **Keep this last for that reason.** Archive before the directory is gone and the call deletes it itself, skipping gitkit, the dirty-tree refusal, and the unpushed-commit gate.

**Delete each confirmed stray project last**, after every row above has settled, so the workspace count it reports is the one the preview promised:

```sh
paseo project delete "$PROJECT_ID" --json
```

**Verify the id against `paseo project ls --json` immediately before the call, and read the returned `removedWorkspaceIds` array.** A wrong id is not an error: the daemon accepts any well-formed `prj_…`, removes nothing, and returns an empty array with a success status. So the exit code proves nothing on its own. An empty array where the preview promised workspaces means the id was wrong or the project moved. Say that, and never re-run with a guessed id.

**A failure at any step stops that candidate and continues to the next.** Report the step it stopped on. Never unwind the steps that already succeeded, because each of them is complete on its own.

### Hand off

**What changed.** Name the scope you ran. Report the registry reap first: rows archived and duplicate sets collapsed, with counts. Then report per candidate what was removed: the sessions stopped, the directory deleted, the branch deleted, and the row archived. Give the totals. Name every rejected and every failed candidate with its reason, and put the `busy` ones first.

**Where it landed.** Give the disk and the registry both, since this mode is the one that touches both. Name the worktree root you swept and the paths that are gone.

**Next.** Crown one:

- **any candidate the user held back** → name it and stop. That was a decision, not an oversight.
- **tracker drift**, meaning a merged pull request whose issue is still open → route to **issuekit** `close <n>`.
- **anything `busy`** → name the path and the agent. Tell the user to run `clean` again after that agent finishes.
- **any `unregistered` or `tombstoned` worktree left standing** → route to [`sync`](#mode-sync), which registers into the registry this mode just cleaned.
- **nothing left** → say the disk and the registry match, and stop.

## Mode: `align`

One-time configuration, per machine. It does not touch a single workspace.

**Check the worktree root.** Compare `worktrees.root` in `~/.paseo/config.json` against `$WORKTREE_ROOT`, which is gitkit's convention, defaulting to `~/worktrees` unless the environment says otherwise. Two roots in play means every sweep classifies by path forever.

Aligning it **only affects worktrees Paseo creates itself**. Existing worktrees are untouched, and git stores absolute paths, so nothing moves. Say that out loud, because "aligned" reads like "migrated" and it is not.

**Aligning the roots does not arm the delete.** Paseo's delete test wants `<worktrees.root>/<hash>/<slug>`, and a gitkit worktree carries the repo name where the hash belongs, so it keeps failing the test after alignment exactly as it did before. Say that plainly when the user asks whether alignment is risky. What alignment changes is that Paseo's own new worktrees land beside gitkit's instead of under `~/.paseo/worktrees`, which puts two naming schemes in one directory. That is the real trade to name.

**Surface `daemon.autoArchiveAfterMerge`, and let the user choose.** Setting it `true` lets Paseo archive a workspace by itself when its change request merges. On 0.7 it carries its own gates: it acts only on a merged pull request, only on a clean tree, only when nothing is ahead of origin, and only on a Paseo-created worktree. Those match `clean`'s own gates, so the switch is a fair native shortcut for the Paseo-created half. What it still skips is the preview and the confirmation, and it stops the agents and kills the terminals without asking. It reaches no gitkit worktree at all, so it never replaces `clean` on this machine's own worktrees.

### Hand off

**What changed.** Report which config keys you compared, and which the user chose to change.

**Where it landed.** Report `~/.paseo/config.json`. Repeat that existing worktrees stayed where they were.

**Next.** Run [`list`](#mode-list) to see the whole set in one table. Then stop. This is a one-time setting per machine, not a routine.

## Notes

- **paseokit is machine-local and always optional.** No Paseo on the box means no-op, and nothing else in the workflow may depend on it. gitkit, issuekit, and the rest never call it, because they would break on every machine without the tool. It is a pump you run, not a link in a chain.
- **`orcakit` is the sibling, not the predecessor.** It reconciles the same worktrees into Orca, whose model is the exact inverse: Orca discovers worktrees on its own and knows nothing about them, so orcakit enriches and cleans up, while paseokit registers and reaps. Both are machine-local and optional, and **neither ever calls the other**.
- **Worktree facts belong to gitkit.** The path convention `$WORKTREE_ROOT/<repo>/<branch>` and the `issue-<n>-<slug>` branch grammar appear here only as declared portability fallbacks for machines without gitkit. Branch naming, base-ref resolution, and the teardown rules live there, and any *other* copy of a gitkit fact in this file is a bug.
- **Tracker facts belong to issuekit.** paseokit reads issue and pull request state to build a title and a verdict; it writes none of it.
- **Safe work runs straight through; scope-widening and destructive work asks.** `list` never asks. `sync` runs its additions without a prompt, and stops only for the two operations that register something the user did not name. `clean` lists every planned archive and delete and asks once before doing any of it: the archives because the user should see what leaves the sidebar, and the deletes because a removed worktree is the one thing here that git cannot give back.
- **No `paseo` command is safe because its name sounds safe.** `archive` deletes directories and `project delete` takes every workspace under it with it. Check `paseo <command> --help` for what a verb reaches, and treat a one-line description as a summary rather than a contract.
- **Never write into `~/.paseo/projects/*.json`.** paseokit reads those files for the fields no listing exposes, and writes exclusively through `paseo`. A hand-edited state file needs a daemon restart to take effect, and a restart kills every running agent.
- **No shell available?** Then you cannot reach the `paseo` CLI, `git`, or `gh`. Reason from what the user gives you and **print the exact commands** as a codeblock for them to run, and never report a workspace registered or archived that you could not perform.

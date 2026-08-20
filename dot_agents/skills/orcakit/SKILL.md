---
name: orcakit
description: >-
  Keep the Orca desktop app's workspace list honest about the git worktrees your workflow actually creates: link each one to its issue, keep its status current, and clean out the ones whose work already merged. Use when the user says "orcakit", "clean up my orca workspaces", "my Orca sidebar is full of finished work", "which workspaces are stale", "link my worktrees to their issues", "remove the workspaces for merged issues", or "where should Orca put new worktrees".
license: MIT
allowed-tools: Bash, Read, Skill
metadata:
  internal: false
---

# orcakit

[Orca](https://www.onorca.dev/) shows one **workspace** per git worktree, with a card carrying the linked issue, a status, and any terminals running in it. Worktrees themselves come from plain `git worktree` (gitkit's convention, issuekit's `start`, or your own hands) and Orca discovers them on its own.

What nothing owns is the **drift between the two**. A worktree named `issue-42-add-sso-login` sits in the sidebar with no issue attached, so its card says nothing. An issue closes and its PR merges, but the workspace stays forever, and three weeks later the sidebar is mostly finished work. orcakit owns exactly that reconciliation: **Orca's view of your worktrees, made to match the tracker.**

## The line orcakit does not cross

**Git is the source of truth for a worktree.** orcakit never runs `orca worktree create` to do real work and never invents a path, because creating a worktree is native `git worktree` under gitkit's convention, so a headless Linux box with no Orca on it runs identical commands. orcakit works one layer up, on things Orca alone knows:

- **metadata**, meaning the linked issue, the workspace status, the comment, the display name;
- **Orca-side resources git can't express**, meaning live terminals bound to a workspace, and a repo's archive/setup hooks.

Removing a worktree with git is enough: Orca notices within seconds and drops the entry by itself. The single exception is a workspace Orca created, covered in [Mode: `clean`](#mode-clean), which documents why and confines it there.

**orcakit never touches the tracker.** It reads issues and PRs to judge state; it never closes an issue, moves a label, or edits a PR. When it finds a merged PR whose issue is still open, that's tracker drift and it says so, routing to **issuekit** `close` rather than reaching around it.

## When this fires

- **`list`.** "What's in my Orca workspaces", "which workspaces are stale", "show me my orca sidebar as a table". Read-only.
- **`link`.** "Link my worktrees to their issues", "my workspace cards are blank", "Orca doesn't know what #42's workspace is for".
- **`clean`.** "Clean up my orca workspaces", "remove the workspaces whose issues merged", "my sidebar is full of finished work".
- **`align`.** "Where should Orca put new worktrees", "make Orca use my worktree root", "stop Orca creating worktrees in its own folder".

**If no mode is clear, ask.** `list` is free and `clean` deletes directories; never guess between them.

**Not this skill:** creating a worktree (gitkit), closing an issue or tearing down after a merge (issuekit `close`), driving Orca terminals, browser, or agents (that's the `orca` CLI directly, or an Orca-provided skill if one is installed). orcakit is workspace *hygiene*, not workspace *operation*.

## Preflight (every mode)

```sh
orca status --json      # app running? runtime reachable?
```

- **`orca` not installed** → this machine has no Orca, so there is nothing to reconcile. Say exactly that and stop. Do not fall back to anything: worktrees are already fine without Orca, and nothing else in the workflow depends on this skill.
- **Runtime not reachable** → `orca open` starts the app and waits. Ask before launching a desktop app on someone's machine.
- **`gh` missing or unauthenticated** → `list` still works but every verdict degrades to "unknown tracker state", and `clean` **cannot run at all**, because its whole safety rests on knowing a PR merged. Say which and stop rather than guessing.
- **A rejected `orca` flag or selector** → the CLI moves fast; check `orca <command> --help` before concluding the operation is unsupported. The goal is the contract, meaning the link, the status, and the removal; the exact flag spelling isn't.

Orca must also be configured to surface externally-created worktrees, or it won't see anything gitkit made:

```sh
orca repo list --json    # each repo carries externalWorktreeVisibility
```

If a repo reads `"externalWorktreeVisibility": "hide"`, its gitkit worktrees are invisible to every mode here. There is no CLI flag for this; it's a per-repo setting in the Orca UI. Report the repo by name and let the user flip it, and don't pretend the empty result is an empty worktree root.

## What Orca knows about a workspace

```sh
orca worktree list --json
orca worktree show --worktree "branch:$BRANCH" --json
```

Each record carries `path`, `branch`, `linkedIssue`, `linkedPR`, `workspaceStatus`, `isArchived`, `isMainWorktree`, and `lastActivityAt`. Selectors are `branch:<name>`, `path:<abs-path>`, `issue:<number>`, and `active`/`current`, and you should **prefer `branch:`**, for the same reason gitkit looks worktrees up by branch: a path is a guess, a branch is an identity.

Discovery is eventually consistent. A worktree created seconds ago may resolve via `worktree show` before it appears in `worktree list`; a removed one lingers briefly. Re-read rather than concluding from one stale listing.

### Two kinds of workspace

Everything below turns on this distinction:

| kind | where it lives | who created it | how it goes away |
|---|---|---|---|
| **git-native** | under `$WORKTREE_ROOT` (default `~/worktrees/<repo>/<branch>`) | gitkit / issuekit `start` / a human, with `git worktree add` | **git removes it**; Orca drops the entry on its own |
| **Orca-native** | under Orca's worktree base path (default `~/orca/workspaces/<repo>/<name>`) | `orca worktree create` | **`orca worktree rm`**, so hooks and terminals are handled |

Classify by path prefix. That's a heuristic, not a fact Orca records, so it is a *reason to confirm before deleting*, never a thing to act on silently. [`align`](#mode-align) exists to collapse the two locations into one and retire the guesswork.

## Mode: `list`

Read-only. Changes nothing, asks nothing, and is the right first move whenever the state is unclear.

Take every workspace where `isMainWorktree` is false, and join it against the tracker:

```sh
orca worktree list --json
gh pr list --head "$BRANCH" --state all --json number,state,url,mergedAt
gh issue view "$N" --json number,state,title,labels     # $N parsed from an issue-<n>-<slug> branch
git -C "$WT" status --porcelain                          # dirty?
git -C "$WT" log --oneline "@{upstream}..HEAD"           # unpushed?
```

Render one table (workspace, branch, issue, PR, Orca status, git state) and give each row a verdict:

| verdict | means | fix |
|---|---|---|
| `active` | open issue or open PR, work in flight | nothing |
| `unlinked` | branch names an issue, `linkedIssue` is null | [`link`](#mode-link) |
| `stale status` | Orca says `in-progress`, the PR is merged or in review | [`link`](#mode-link) |
| `reapable` | PR merged, issue closed, tree clean | [`clean`](#mode-clean) |
| `tracker drift` | PR merged, issue still **open** | **issuekit** `close <n>`, not orcakit's to fix |
| `dirty` | uncommitted or unpushed work, whatever the tracker says | a human, before anything else |
| `unknown` | no issue in the branch name and no PR | leave it; say so |

Close by naming which mode clears which rows, and put `dirty` first if any exist, because that's the row where work gets lost.

## Mode: `link`

Attach the metadata Orca cannot infer, so a workspace card actually says what it's for.

For each git-native workspace whose branch matches `issue-<n>-<slug>` and whose `linkedIssue` is null:

```sh
orca worktree set --worktree "branch:$BRANCH" --issue "$N" --json
```

And bring `workspaceStatus` in line with the tracker. Orca's vocabulary is `todo`, `in-progress`, `in-review`, `done`, `archived`; map it from the real state, not from the label alone:

| tracker state | `workspaceStatus` |
|---|---|
| issue open, no PR, no commits on the branch | `todo` |
| issue open, no PR, work committed | `in-progress` |
| PR open | `in-review` |
| PR merged | `done` |
| issue closed and PR merged | `done` (and it's a [`clean`](#mode-clean) candidate) |

```sh
orca worktree set --worktree "branch:$BRANCH" --workspace-status in-review --json
```

Rules:

- **Preview every planned `set` as one table, then take one OK for the batch.** Nothing is destroyed here, but it rewrites the user's sidebar, and that deserves a look, not a surprise.
- **Never overwrite a `linkedIssue` that's already set** to something different. A human or `orca worktree create --issue` put it there deliberately; report the disagreement and leave it.
- **Never overwrite a hand-written `comment`.** Set one only when it's empty.
- **Leave the main worktree alone.** It isn't feature work and a status on it means nothing.
- A branch that names no issue simply gets skipped. Say how many, don't invent links from slugs.

### Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report how many workspaces gained an issue link, how many had their status corrected, and how many were skipped and why.

**Where it landed.** In Orca's sidebar; nothing on disk moved and no git state changed.

**Next.** If `link` marked anything `done`, that set is exactly [`clean`](#mode-clean)'s input, so crown that. Otherwise stop: linked cards are the end state, not a step toward one.

## Mode: `clean`

Reclaim the workspaces whose work already landed. Every removal is irreversible, so the shape is fixed: **gather, qualify, preview everything at once, take one confirm, then remove.**

### 1. Qualify

A workspace is a candidate only when **its work is provably merged and the tracker already agrees**:

```sh
gh pr list --head "$BRANCH" --state merged --json number,url,mergedAt
gh issue view "$N" --json state                       # must be CLOSED
```

- **Primary qualifier.** A merged PR for the branch, and either no issue in the branch name or an issue that is already **closed**.
- **Secondary, shown as its own group.** No PR ever existed, but the branch is fully merged into the base (`git branch --merged "origin/$BASE"`; base resolved gitkit's way, never hard-coded `main`). Real for direct pushes, weaker evidence, so it gets its own section in the preview and is never bundled in with the primary rows.

**A merged PR with an open issue is not a candidate.** That's tracker drift; list it and route to **issuekit** `close <n>`, which closes the issue, unblocks its dependents, *and* tears the worktree down, doing the job properly instead of deleting the evidence behind the tracker's back.

### 2. Disqualify

These are hard skips. Each appears in the preview under **skipped**, with its reason, so nothing vanishes from the report silently:

- **uncommitted changes or untracked files**, where `git status --porcelain` is non-empty;
- **unpushed commits**, or a branch with no upstream at all;
- **the main worktree**, always;
- **the worktree you're currently inside**, because you never delete the floor you're standing on;
- **live Orca terminals**, found with `orca terminal list --worktree "branch:$BRANCH" --json`. Offer `orca terminal stop --worktree "branch:$BRANCH"` as a separate, explicitly confirmed step; never stop someone's running process as a side effect of tidying.

A merged PR does **not** imply an empty worktree. Scratch files, a stashed experiment, and a follow-up commit that never got pushed are none of them in the PR, and all of them live there.

### 3. Preview and confirm

One table, all candidates, each with the evidence that qualified it (PR number, merge date, issue state) and its kind (git-native or Orca-native). Skips listed below it with reasons. Then a single question, naming the count:

> Remove 6 workspaces (4 git-native, 2 Orca-native)? 3 more were skipped, see above.

One OK covers the batch. If the user wants a subset, take the subset; don't re-prompt row by row.

### 4. Remove, by kind

**git-native** → hand it to **gitkit**'s teardown, which looks the worktree up by branch and removes it with native git:

```sh
git -C "$REPO" worktree remove "$WT"
git -C "$REPO" branch -d "$BRANCH"     # -d, never -D
```

Then **stop**. Do not also call `orca worktree rm`, because Orca drops a discovered entry by itself, and a second removal on a path that's already gone just produces a confusing error. If gitkit isn't installed, the two commands above are the whole of it.

**Orca-native** → Orca owns it, so Orca removes it:

```sh
orca worktree rm --worktree "path:$WT" --run-hooks --json
```

This is the one place orcakit runs a vendor command that also performs the git removal, and the reason is specific: Orca created this checkout, has an archive hook and terminal sessions bound to it, and its `rm` sequences all three. Removing it with git first orphans Orca's metadata and skips the hook. The exception is confined to workspaces Orca created, and it never extends to a gitkit worktree.

**Never `--force`.** Every removal here is already gated on a clean tree and a merged PR; if git refuses anyway, that refusal is information. Report it and move to the next row.

### 5. Hand off

**What changed.** Report how many workspaces were removed, by kind, and how many were skipped. Name the skipped ones with reasons; a dirty worktree that survived is the single most important line in the report and goes first.

**Where it landed.** Give the paths that are gone and the branches deleted with them. Note that Orca's sidebar catches up within a few seconds, so an entry still visible right now isn't a failure.

**Next.** Crown one:

- **anything skipped as dirty** → that outranks everything. Name the path and tell the user to go look; unlanded work in a stale worktree is what actually gets lost.
- **tracker drift found** → **issuekit** `close <n>` on those issues, otherwise `gh issue close <n>` plus a manual teardown.
- **nothing left to clean** → say so plainly and stop. The right next move is somewhere else entirely, which is **statuskit** to re-orient if it's installed, otherwise nothing at all. Sidebar hygiene is not a loop worth repeating.

## Mode: `align`

Stop Orca creating worktrees somewhere gitkit will never look. Orca's default is `~/orca/workspaces/<repo>/<name>`; gitkit's convention is `$WORKTREE_ROOT/<repo>/<branch>` (`~/worktrees` unless the environment says otherwise). Two roots means every sweep has to classify by path forever.

```sh
orca project setups --json                                  # find the setup id for the repo
orca project setup-update --setup "$SETUP_ID" \
  --worktree-base-path "$WORKTREE_ROOT/$(basename "$REPO")" --json
```

**Verify rather than assume.** The setups listing does not echo the base path back, and whether Orca appends the repo name to it is not documented anywhere. So confirm it empirically, once per repo, with a throwaway:

```sh
orca worktree create --repo "path:$REPO" --name orcakit-align-check --no-parent --json
# read the path it reports:
#   .../worktrees/<repo>/orcakit-align-check    → correct
#   .../worktrees/<repo>/<repo>/orcakit-…       → doubled; re-set the base to "$WORKTREE_ROOT"
orca worktree rm --worktree "name:orcakit-align-check" --json
```

This is the one `orca worktree create` in the skill, and it exists only to read back a path, so confirm it with the user, and remove the throwaway in the same breath. If the check is declined or can't run, say the base path was set **but not verified**; do not report a convergence you didn't observe.

**Existing worktrees are untouched.** Ones already under `~/orca/workspaces` keep working exactly as they are; git stores absolute paths, and moving them by hand needs `git worktree repair`. `align` only changes where the *next* one goes. Say that out loud, because "aligned" reads like "migrated" and it isn't.

### Hand off

**What changed.** Report which repos had their base path set, and whether the throwaway check confirmed the resulting path.

**Where it landed.** Give the new base path per repo, and a reminder that existing workspaces stayed where they were.

**Next.** With one root in play, [`list`](#mode-list) is worth a run to see the whole set in one table. If nothing else is pending, stop; this is a one-time-per-repo setting, not a routine.

## Notes

- **orcakit is machine-local and always optional.** No Orca on the box means no-op, and nothing else in the workflow may depend on it. gitkit, issuekit, and the rest never call it, because they'd break on every machine without the app. It's a janitor you run, not a link in a chain.
- **`paseokit` is the sibling, not the successor.** It reconciles the same worktrees into [Paseo](https://paseo.sh), whose model is the exact inverse: Paseo discovers nothing and prunes nothing, so paseokit registers and reaps, while orcakit enriches and cleans up. Both are machine-local and optional, and **neither ever calls the other**.
- **Worktree facts belong to gitkit.** The default path convention appears here only as a declared portability fallback for machines without gitkit; everything else, meaning branch naming, base-ref resolution, and teardown rules, lives there, and any *other* copy of a gitkit fact here is the bug.
- **Tracker facts belong to issuekit.** orcakit reads issue and PR state to judge a workspace; it writes none of it.
- **Destructive steps preview and confirm; read-only ones run straight through.** `list` never asks. `link` previews a batch. `clean` previews a batch and takes one OK. `align` confirms before it creates its throwaway.
- **No shell available?** Then you can't reach the `orca` CLI or `gh`. Reason from what the user gives you and **print the exact commands** as a codeblock for them to run, and never report a workspace linked or removed that you could not perform.

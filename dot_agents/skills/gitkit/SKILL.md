---
name: gitkit
description: >-
  The shared git layer every other skill borrows: where a worktree lives and what it's called, how to create/adopt/tear one down, which branch is the base, whether to rebase or merge, how to sync a feature branch with its base and force-push it, how to sweep merged worktrees and branches away, how to recover work that looks lost, and how to stack a branch on one still in review. Use when the user says "spin up a worktree for this", "make me a worktree", "where's the worktree for #42", "tear down this worktree", "clean up my merged worktrees", "what's the base branch here", "should I rebase or merge", "sync this branch with main", "this PR is behind, bring it up to date", "I lost a commit", "recover my work after a bad rebase", "stack this on #43", or runs "/gitkit", and whenever another skill needs any of those answers.
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# gitkit

One place where the git facts live that every other skill in a toolchain keeps re-deriving: **where a worktree goes and what it's named, how it is created, adopted, and removed, which branch is the base, and when to rebase versus merge.**

The **core** here is not clever. All of it is native [git worktree](https://git-scm.com/docs/git-worktree), with no vendor CLI, no GUI dependency, and no recorded state anywhere but git's own. That is the point: a laptop with a desktop dev tool and a headless Linux box run *identical* commands, so there is no second code path to keep in sync and no "degraded mode" to reason about.

**One branch of this skill sits outside that core, and says so.** [Stacked branches](#stacked-branches) drive GitHub's `gh stack` extension, so that branch alone needs `gh` and a GitHub remote. It degrades to plain git rather than failing, and nothing else in this file depends on it, so a box with no `gh` runs everything above untouched.

gitkit is a **primitives skill**. Most of its runs come from another skill calling it, not from a human saying its name.

## When this fires

- **worktree.** "Spin up a worktree for this branch", "make me a worktree for #42", "where is the worktree for `issue-42-…`", "tear down this worktree", "list my worktrees".
- **base ref.** "What's the base branch here", "diff me against the base".
- **sync.** "Should I rebase or merge here", "sync this branch with main", "this branch is behind, bring it up to date", "make this PR review-ready on the latest base".
- **clean.** "Clean up my merged worktrees", "which branches can I delete", "this repo is full of dead branches".
- **rescue.** "I lost a commit", "my rebase ate my work", "I reset the wrong branch", "what's in this stash".
- **stack.** "Stack this on #43", "start #44 on top of #43's branch", "restack this chain", "show me the stack".
- **called by another skill.** Any skill that needs a worktree, a base ref, a branch name, or a sync decision delegates here and uses what comes back.

**Not this skill:** committing, opening a PR, reviewing a diff, judging code. gitkit answers *where and how*, never *what the change should be*.

## Modes

| mode | does | lives |
|---|---|---|
| `worktree` | create, adopt, look up, list, and remove a worktree | [below](#worktree) |
| `sync` | bring a feature branch onto the latest base and force-push it with a lease | [below](#sync) |
| `clean` | sweep the merged worktrees and branches away, one confirmation each | [clean.md](./clean.md) |
| `rescue` | find work that looks lost and restore it onto a new branch | [rescue.md](./rescue.md) |
| `stack` | build and restack a chain of branches through `gh stack` | [stacks.md](./stacks.md), and [Stacked branches](#stacked-branches) |

`worktree` and `sync` sit inline because nearly every run and every calling skill reaches them. The other three load only when their mode fires.

**When the mode is not clear from the ask, pick it from the verb and say which one you picked.** "Tidy this up" after a merge is `clean`; "tidy this up" on a branch behind its base is `sync`. Naming the mode in the first line is what lets the human correct a wrong pick before anything runs.

## The convention

### Path

```
$WORKTREE_ROOT/<repo-basename>/<local-branch-name>
```

`$WORKTREE_ROOT` defaults to `~/worktrees`; honor the environment variable when it is set. `<repo-basename>` is the main checkout's directory name.

**Slashes in a branch name flatten to dashes.** A branch `mimukit/6-marketing-site` gets the directory `mimukit-6-marketing-site`, not a nested `mimukit/` parent. This keeps one flat level per repo, so `ls "$WORKTREE_ROOT/<repo>"` is a complete inventory rather than a tree to walk. The trade is that the directory name no longer round-trips back to the branch name, which costs nothing, because [lookup is always through git](#look-up-a-branchs-worktree), never by reading a path. On the rare collision (branches `a/b` and `a-b` both flatten to `a-b`), `git worktree add` fails on the existing path: report it and let the human pick a name rather than silently appending a suffix.

Worktrees live **outside** the repository, never in a `.worktrees/` directory inside it. An in-repo worktree gets swept into docker build contexts, bind mounts, file watchers, and test globs, and every one of those failures shows up far from its cause.

### The invariant: one branch, one worktree

**A branch has at most one worktree, and the directory is named after it.** A worktree is keyed to a *branch*, not to a workflow stage, so implementing a feature and later reviewing its pull request use the same worktree, because they are the same branch.

This is not a style preference. Git enforces it:

```
$ git worktree add ../wt-b feature-x
fatal: 'feature-x' is already used by worktree at '.../wt-a'
```

Any scheme that names worktrees by stage (`review-…`, `qa-…`) hard-fails the moment two stages touch one branch, which is the normal case, not the edge case.

Consequences:

- **Lookup is by branch, always**, through git, never by reading or guessing at a directory path. This is what makes the flattening above free, and what lets a worktree sitting in some older root keep working untouched.
- **The "kind" of a worktree rides along for free**, because the branch name already carries it. `issue-42-auth-capability-module` is named that because the *branch* was named that when the work started.

### Branch naming

- **`issue-<n>-<slug>`** for work that starts from a tracker issue. Slug from the issue title: if it follows a conventional `type(scope): summary` form, strip the prefix; kebab-case the rest, cap at roughly 50 characters on a word boundary, drop a trailing hyphen. An empty slug degrades to a bare `issue-<n>`. The number guarantees uniqueness, so no tie-break is ever needed.
- **`pr-<n>-<slug>`** only for a **fork** pull request, where no local branch exists yet and one must be invented to hold the fetched head. Slug from the head branch name, kebab-cased, capped at roughly 40 characters.
- Anything else takes a branch name the human or the repo's convention supplies. gitkit does not rename it.

For a same-repo pull request there is already a local branch name: use it. Inventing a `pr-*` name for a branch that exists is how you land on the two-worktrees-one-branch failure above.

## `worktree`

All four are native git, and all four are **idempotent**, so running one twice is a normal thing to do and must never error or destroy work.

### Look up a branch's worktree

The one lookup primitive everything else is built on:

```sh
git -C "$REPO" worktree list --porcelain
```

Each record carries a `worktree <path>` line and, when a branch is checked out, a `branch refs/heads/<name>` line. Match on the branch to get the path. If the porcelain shape ever shifts, check `git worktree list --help` rather than guessing, but treat the `worktree`/`branch` pairing as stable; that is what porcelain output is for.

### Create, or adopt

Always look first. **If a worktree already exists for the branch, adopt it: report the path and stop.** Never create a second one, never error.

When there is none:

```sh
git -C "$REPO" fetch origin --prune
git -C "$REPO" worktree add -b "$BRANCH" "$WORKTREE_ROOT/$(basename "$REPO")/$BRANCH" "$BASE"
```

- Fetch first, always. Branching off a stale base is silent and only surfaces as conflicts later.
- `$BASE` comes from [The base ref](#the-base-ref), never a hard-coded `origin/main`, and never a sibling feature branch. The one exception is a [stack layer](#stacked-branches), whose base *is* the branch below it, named deliberately by the caller.
- Drop `-b` when the branch already exists locally (a same-repo PR you have fetched, a branch you made earlier); `git worktree add <path> <branch>` checks it out.
- For a **fork** pull request, fetch the head into a local branch first with `git fetch origin "pull/<n>/head:pr-<n>-<slug>"`, then add the worktree on that branch, no `-b`.

Report the path and the branch. Creating a worktree does not imply doing anything in it.

### Remove

```sh
git -C "$REPO" worktree remove "$WT"
git -C "$REPO" branch -d "$BRANCH"     # only a branch you created, and only if merged
```

Three rules, each one guarding against a real way to lose work:

- **A dirty worktree stops teardown.** Show exactly what would be lost (uncommitted changes, untracked files, unpushed commits) and let the human decide. Never reach for `--force` on their behalf.
- **Never remove a worktree you adopted rather than created.** If it was already there when you arrived, it is someone else's context; you have no idea what is open in it.
- **Never delete a branch you did not create.** Use `-d` (not `-D`) so git itself refuses an unmerged branch.

Already gone? Report "already gone" and succeed. Teardown is idempotent in the same spirit as adopt.

### List

```sh
git -C "$REPO" worktree list
```

A plain inventory. When the user asks to tidy up rather than to look, that is the [`clean`](#clean) mode, which classifies every row before it offers anything.

If paths look wrong after a move or a restore, `git worktree repair <path>` rewrites the back-pointers. Git stores absolute paths in `.git/worktrees/<name>/gitdir` and in each worktree's `.git` file, so moving a worktree by hand always needs a repair.

## The base ref

Never assume `main`. Repos default to `develop`, `trunk`, and `master` in the wild, and getting this wrong silently produces an empty or enormous diff. The ladder, in order:

1. `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, authoritative when the GitHub CLI is available and authenticated.
2. `git symbolic-ref --short refs/remotes/origin/HEAD`, the local record, if it has been set.
3. `git remote set-head origin --auto` to repair an unset `origin/HEAD`, then retry the previous step. This is the step most implementations skip, and it is the one that turns a failure into an answer.
4. Whichever of `origin/main` / `origin/master` actually exists.
5. Ask the human. Do not guess past this point.

Everything downstream uses the answer: `git diff <base>...HEAD`, ahead/behind counts, and the branch a worktree is cut from.

**A stack layer is the one deliberate exception, and the ladder still runs.** A layer's base is the branch below it rather than the repo default, so the caller names it and this ladder is not consulted for that branch. The ladder is still what resolves the **trunk** the stack's bottom layer sits on. The ban on a sibling-branch base keeps its teeth everywhere else, because what it catches is the *accidental* case: a worktree cut from whatever happened to be checked out. A layer base is legal because somebody said which branch and why. See [Stacked branches](#stacked-branches).

## Rebase or merge

Syncing a feature branch with its base has one default here, and it does not depend on whether a pull request is open:

> **Rebase onto the base to sync a feature branch, published or not. Merging the base in is an exception that needs a stated reason and the user's consent.**

The default is rebase because that is the history worth having: a feature branch that reads as a linear sequence of its own commits, with the base's work underneath rather than braided through it. A repo that merges the base in on every sync accumulates one merge commit per sync, and the branch's own story becomes unreadable long before it lands.

Rebasing does have a real cost, and it is mechanical rather than aesthetic: it rewrites commit SHAs. Once a pull request is open, its review threads are anchored to those commits, so a force-push marks every one of them outdated, human and bot findings alike. That is the cost to **disclose and weigh**, not a bar. It is also the one pre-baked reason to propose the merge exception.

In practice:

```sh
git fetch origin
git rev-list --left-right --count "origin/$BASE"...HEAD   # "<behind>\t<ahead>"; left > 0 means behind
git rebase "origin/$BASE"
```

- **Rebase is the answer unless someone has said otherwise for this branch.** No pull request, an open one, a shared branch: the recommendation is the same.
- **A branch with no remote counterpart rebases straight through.** Nothing points at those SHAs, so nothing can break; this is the cheap-and-reversible class, and it needs no confirmation.
- **A published branch previews once and waits.** One confirmation covers the rebase *and* the `--force-with-lease` push that follows, because they are a single decision, and asking twice asks the same question twice. Name what it costs: the base being synced, the commits being rewritten, and the number of unresolved review threads that will go outdated.
- **Count the threads before you ask.** On a branch with an open PR, query the GraphQL `reviewThreads` connection for unresolved threads and put the number in the preview. "3 review threads will be marked outdated" is a fact the user can decide on; "this may outdate review comments" is not.
- **Unresolved threads are the reason to *offer* the merge exception, not to take it.** Still recommend the rebase; name merge as the available alternative alongside the count. A preference that folds in the case that argues against it was never a preference.
- **`--force-with-lease`, never bare `--force`.** The lease is what stops you overwriting a commit someone else pushed while you were rebasing.
- **On conflict**, stop and surface it (`git diff --name-only --diff-filter=U`). Propose a resolution per file and confirm before writing. A conflict resolution is a code change: run the repo's test gate afterward.

### `sync`

The runnable form of the rule above: bring one feature branch up to date with its base, resolve every conflict, and leave the branch and its pull request on the latest base code. Run it in the branch's worktree. Each step names the condition that ends it.

1. **Fix the ground.** Resolve the base with [the base ref ladder](#the-base-ref). Run `git -C "$WT" fetch origin --prune`. Confirm the worktree is on the feature branch and that `git status --porcelain` is empty. A dirty tree stops the sync: report the files and let the human stash or commit. Ends when the base name, the branch name, and a clean tree are all known.
2. **Measure the gap.** Run `git rev-list --left-right --count "origin/$BASE"...HEAD`. Behind count `0` means the branch is already current: report that, push nothing, and stop. Ends with a behind count and an ahead count.
3. **Preview and confirm, once.** An unpushed branch skips this step and goes straight through. A published branch gets one preview that covers the rebase *and* the force-push: the base, the behind and ahead counts, and the unresolved review thread count from the GraphQL `reviewThreads` connection when a pull request is open. Name merge as the alternative, and still recommend the rebase. Ends on the user's answer.
4. **Rebase.** Run `git rebase "origin/$BASE"`. Ends when the rebase reports success or stops on a conflict.
5. **Resolve every conflict.** For each stop, list the files with `git diff --name-only --diff-filter=U`. Read each conflicted file, propose a resolution that keeps the branch's intent and the base's new code, and confirm before writing. Stage the file, then `git rebase --continue`. Repeat for every remaining stop. `git rebase --abort` restores the pre-rebase state, and it is the answer when a conflict is not yours to settle. Ends when no conflict marker remains and the rebase is complete.
6. **Prove the branch still works.** Run the repository's own test and build gate. Report a failure with its output and stop before the push. Ends with a pass, or a stop.
7. **Push with a lease.** Run `git push --force-with-lease origin "$BRANCH"`. A rejected lease means somebody pushed while you rebased: fetch, show the new commits, and ask before any retry. Ends when the remote branch matches the local one.

**Hand off.** Report the base, the behind and ahead counts, the files whose conflicts you resolved, the gate result, and the pushed branch. Say when the branch was already current and nothing changed. Next, review the pull request diff on the new base, and re-request review when threads went outdated.

### The merge exception

When the user takes the merge, or asks for it outright, it is still a sync, and it says so:

```sh
git merge "origin/$BASE" -m "chore(repo): sync with origin $BASE"
```

- **Never git's default subject.** `Merge branch 'main' into issue-42-tailwind-4-foundation` is what git writes when nobody chose a message, and it reads that way forever in `git log`. The fixed subject is the message.
- **Interpolate the base, don't hardcode `main`.** The [base ref](#the-base-ref) ladder exists because `develop` and `trunk` repos are real; a subject that says `main` in one of them is simply false.
- **No `--no-ff`.** If the sync can fast-forward, the branch had nothing of its own to preserve and git writes no commit at all, so there is no subject to fix, and forcing one manufactures an empty merge commit.
- **State the reason in the same breath as the ask.** "Merging instead of rebasing because this PR has 3 unresolved review threads" is a reason. "Merging to be safe" is not; if you cannot name what rebasing would break, rebase.

### Never bare `git pull`

`git pull` on a branch behind its remote merges by default, and writes `Merge branch 'main' of github.com:owner/repo` without asking anyone. Use `git pull --rebase`, or `git pull --ff-only` when you want the sync to fail loudly rather than resolve itself. The same holds for `git pull` invoked to refresh the base branch itself: configure it or pass the flag, but never let the default run.

## `clean`

Sweep away the worktrees and branches whose work has landed, on your machine and on `origin`. It classifies every worktree, local branch, and remote branch into one bucket — active, adopted, dirty, reapable, orphan — and removes only the reapable ones, one confirmation at a time. A remote delete takes its own confirmation and its own proof that the work landed.

Two things make it more than a `git branch --merged` loop, and both live in **[clean.md](./clean.md)**: a squash-merged branch is invisible to ancestry, so "merged" needs three detections rather than one; and the per-item confirmation is deliberate, because a sweep's rows are not equally safe to delete. Read that file when a run actually sweeps.

The [Remove](#remove) rules govern every removal the sweep makes. It never deletes a branch with `-D`, never touches a worktree it adopted, and stops on a dirty one. On `origin` it never deletes the base branch and never deletes the head of an open pull request.

## `rescue`

Find work that looks lost and put it back. A bad rebase, a hard reset, a deleted branch, a stash nobody can find: the commits usually still exist, and git's own logs say where they went.

The procedure is in **[rescue.md](./rescue.md)**. Two rules shape it. It is **read-only until the restore**, and the restore **adds a branch rather than moving one**, because a reset is the operation that lost the work in the first place. It also states the bound rather than implying safety: an unreachable commit lives until git prunes it.

Never run `git gc`, `git prune`, or `git reflog expire` during a rescue, in any mode.

## Stacked branches

A **stack** is a chain of branches in one repository where each branch is cut from the one below it and the bottom sits on trunk. It is what you reach for when work depends on work that is built but not yet merged: instead of waiting for the prerequisite's pull request to land, you branch from it and keep going.

GitHub supports this natively, and the `gh stack` extension drives it. **This is the one part of gitkit that needs `gh` and a GitHub remote.** The full command surface, the preflight, and the degradation path live in **[stacks.md](./stacks.md)**; read it when a run actually touches a stack. What follows is the part every run needs.

### One worktree per layer

**Each layer keeps its own worktree, cut from the layer below.** The [one branch, one worktree](#the-invariant-one-branch-one-worktree) invariant is unchanged: a layer is a branch, so it gets a directory named after it, and [lookup is still by branch](#look-up-a-branchs-worktree).

The alternative, one worktree for the whole stack with `gh stack up` and `down` moving between layers inside it, is what the extension's own navigation assumes. It is not what this collection does, because every caller here keys a worktree to *the issue being worked*, and a stack is several issues. So `gh stack`'s navigation commands are out of scope, and `up`, `down`, `switch`, `top`, and `bottom` are not gitkit's to run: they would move a checkout that another worktree already holds.

### What gitkit owns here, and what it does not

gitkit takes the **plumbing** and nothing else: create a stack, add a layer, restack, sync, inspect, and adopt existing branches into one. Two commands are deliberately excluded, because they cross boundaries this skill holds elsewhere:

- **`gh stack submit` opens pull requests.** gitkit never opens anything. That belongs to whichever skill authors pull requests.
- **`gh stack merge` merges them.** gitkit never merges, and a stack merge is a *cascade* that lands several pull requests at once, which needs a human confirmation naming every one of them. That belongs to whichever skill owns merging.

Naming the owner rather than the command is the point: gitkit prepares ground, and publishing is somebody else's job whether the branch is stacked or not.

### The cost of depth

Every layer added to a stack is one more pull request to review and one more branch to rebase each time anything below it changes. Restacking is cascading, so a change to the bottom layer rewrites every layer above it.

**No number is stated here on purpose.** How deep a stack should go depends on how big each layer is and how fast they get reviewed, which is the human's call. State the mechanism when they ask, so they can size it themselves.

## Containers and remote boxes

Git worktrees store **absolute** paths. If a repo is bind-mounted into a container at a path different from the host's, every worktree inside it breaks.

- Mount **both** `$WORKTREE_ROOT` and the main checkout. A worktree's real git directory lives under the main repo's `.git/worktrees/`; mounting only the worktree yields a broken checkout.
- Mount both at the **same absolute path** inside and outside the container. This is the robust answer.
- Second belt, on git 2.48+: `git config worktree.useRelativePaths true` and `git worktree repair --relative-paths`. Relative pointers survive remapping *as long as the repo and the worktree root keep their relative positions*, which argues for siding them, e.g. `~/code/<repo>` and `~/worktrees/<repo>`.

A GUI dev tool that manages worktrees is welcome to **observe** these. Orca and its peers read `git worktree list` and typically have a setting to surface externally-created worktrees. That is a one-time UI configuration on whichever machine runs the GUI, and it is the only asymmetry between machines.

**No skill may create or remove a worktree through a vendor CLI**: the moment one does, the two machines diverge. A vendor's own *metadata* about a worktree, such as the issue its card links to, a status, or a comment, is a different layer and is fair game, because it exists only inside that tool and has no git equivalent to diverge from. A companion skill may reconcile that layer (**orcakit** does, for Orca) as long as the worktree itself is still created and destroyed here. gitkit never calls in that direction: it must keep working on a machine where no such tool is installed.

## Notes

- **gitkit is the single source of truth for what it owns.** A calling skill may hold policy about *when* to ask, such as that a PR is worth pulling down or that a branch is ready to publish, but never about *how* the git operation is done.
- **Restating a conclusion is allowed; restating the derivation is the bug.** Every public skill is installed on its own, into repos where gitkit may not exist, so a caller that needs a git fact has to carry enough of one to keep working, and that requirement outranks tidiness. The line runs between the two: a caller may state gitkit's **answer** together with its degradation fallback ("gitkit owns the sync rule, and it resolves to rebase; without gitkit, rebase onto the base"), and may not reproduce the **reasoning that produces** the answer, meaning the full base-ref ladder, the worktree path formula, or the rebase-versus-merge argument. The answer is one line that a rename cannot silently invalidate; the derivation is the thing that drifts. Compliant examples worth reading: prkit and mergekit each name the rebase conclusion and its one-confirmation rule without re-deriving them, and wikikit and designkit each name `gh repo view --json defaultBranchRef` as a base-ref fallback without carrying the five-rung ladder.
- **gitkit never implements, commits, or opens anything.** It prepares the ground and tears it down. Writing code in the worktree, committing, and publishing belong to other skills.
- **Destructive steps preview and confirm.** Removing a worktree, deleting a branch, and rebasing a *published* branch each show what is about to happen and wait for an OK. Creating, adopting, and rebasing an unpushed branch are cheap and reversible, so those run straight through. The line is whether anything outside this machine points at what you are about to rewrite, not which command you typed.
- **No shell available** (e.g. a browser-based agent)? Then you cannot run git. Reason from what the user provides and **print the exact commands** as a codeblock for them to run, and never report a worktree created or removed that you could not perform.

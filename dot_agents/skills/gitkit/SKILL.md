---
name: gitkit
description: >-
  The shared git layer every other skill borrows — where a worktree lives and what it's called, how to create/adopt/tear one down, which branch is the base, and whether to rebase or merge. Use when the user says "spin up a worktree for this", "make me a worktree", "where's the worktree for #42", "tear down this worktree", "clean up my worktrees", "what's the base branch here", "should I rebase or merge", or runs "/gitkit" — and whenever another skill needs any of those answers.
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# gitkit

One place where the git facts live that every other skill in a toolchain keeps re-deriving: **where a worktree goes and what it's named, how it is created, adopted, and removed, which branch is the base, and when to rebase versus merge.**

Nothing here is clever. All of it is native [git worktree](https://git-scm.com/docs/git-worktree) — no vendor CLI, no GUI dependency, no recorded state anywhere but git's own. That is the point: a laptop with a desktop dev tool and a headless Linux box run *identical* commands, so there is no second code path to keep in sync and no "degraded mode" to reason about.

gitkit is a **primitives skill**. Most of its runs come from another skill calling it, not from a human saying its name.

## When this fires

- **worktree** — "spin up a worktree for this branch", "make me a worktree for #42", "where is the worktree for `issue-42-…`", "tear down this worktree", "list my worktrees", "clean up the ones that are merged".
- **base ref** — "what's the base branch here", "diff me against the base".
- **sync** — "should I rebase or merge here", "this branch is behind — bring it up to date".
- **called by another skill** — any skill that needs a worktree, a base ref, a branch name, or a sync decision delegates here and uses what comes back.

**Not this skill:** committing, opening a PR, reviewing a diff, judging code. gitkit answers *where and how*, never *what the change should be*.

## The convention

### Path

```
$WORKTREE_ROOT/<repo-basename>/<local-branch-name>
```

`$WORKTREE_ROOT` defaults to `~/worktrees`; honor the environment variable when it is set. `<repo-basename>` is the main checkout's directory name.

**Slashes in a branch name flatten to dashes.** A branch `mimukit/6-marketing-site` gets the directory `mimukit-6-marketing-site`, not a nested `mimukit/` parent. This keeps one flat level per repo, so `ls "$WORKTREE_ROOT/<repo>"` is a complete inventory rather than a tree to walk. The trade is that the directory name no longer round-trips back to the branch name — which costs nothing, because [lookup is always through git](#look-up-a-branchs-worktree), never by reading a path. On the rare collision (branches `a/b` and `a-b` both flatten to `a-b`), `git worktree add` fails on the existing path: report it and let the human pick a name rather than silently appending a suffix.

Worktrees live **outside** the repository, never in a `.worktrees/` directory inside it. An in-repo worktree gets swept into docker build contexts, bind mounts, file watchers, and test globs — and every one of those failures shows up far from its cause.

### The invariant: one branch, one worktree

**A branch has at most one worktree, and the directory is named after it.** A worktree is keyed to a *branch*, not to a workflow stage — so implementing a feature and later reviewing its pull request use the same worktree, because they are the same branch.

This is not a style preference. Git enforces it:

```
$ git worktree add ../wt-b feature-x
fatal: 'feature-x' is already used by worktree at '.../wt-a'
```

Any scheme that names worktrees by stage (`review-…`, `qa-…`) hard-fails the moment two stages touch one branch — which is the normal case, not the edge case.

Consequences:

- **Lookup is by branch, always** — through git, never by reading or guessing at a directory path. This is what makes the flattening above free, and what lets a worktree sitting in some older root keep working untouched.
- **The "kind" of a worktree rides along for free**, because the branch name already carries it. `issue-42-auth-capability-module` is named that because the *branch* was named that when the work started.

### Branch naming

- **`issue-<n>-<slug>`** — work that starts from a tracker issue. Slug from the issue title: if it follows a conventional `type(scope): summary` form, strip the prefix; kebab-case the rest, cap at roughly 50 characters on a word boundary, drop a trailing hyphen. An empty slug degrades to a bare `issue-<n>`. The number guarantees uniqueness, so no tie-break is ever needed.
- **`pr-<n>-<slug>`** — only for a **fork** pull request, where no local branch exists yet and one must be invented to hold the fetched head. Slug from the head branch name, kebab-cased, capped at roughly 40 characters.
- Anything else — a branch name the human or the repo's convention supplies. gitkit does not rename it.

For a same-repo pull request there is already a local branch name: use it. Inventing a `pr-*` name for a branch that exists is how you land on the two-worktrees-one-branch failure above.

## Worktree operations

All four are native git, and all four are **idempotent** — running one twice is a normal thing to do and must never error or destroy work.

### Look up a branch's worktree

The one lookup primitive everything else is built on:

```sh
git -C "$REPO" worktree list --porcelain
```

Each record carries a `worktree <path>` line and, when a branch is checked out, a `branch refs/heads/<name>` line. Match on the branch to get the path. If the porcelain shape ever shifts, check `git worktree list --help` rather than guessing — but treat the `worktree`/`branch` pairing as stable; that is what porcelain output is for.

### Create — or adopt

Always look first. **If a worktree already exists for the branch, adopt it: report the path and stop.** Never create a second one, never error.

When there is none:

```sh
git -C "$REPO" fetch origin --prune
git -C "$REPO" worktree add -b "$BRANCH" "$WORKTREE_ROOT/$(basename "$REPO")/$BRANCH" "$BASE"
```

- Fetch first, always. Branching off a stale base is silent and only surfaces as conflicts later.
- `$BASE` comes from [The base ref](#the-base-ref) — never a hard-coded `origin/main`, and never a sibling feature branch.
- Drop `-b` when the branch already exists locally (a same-repo PR you have fetched, a branch you made earlier); `git worktree add <path> <branch>` checks it out.
- For a **fork** pull request, fetch the head into a local branch first — `git fetch origin "pull/<n>/head:pr-<n>-<slug>"` — then add the worktree on that branch, no `-b`.

Report the path and the branch. Creating a worktree does not imply doing anything in it.

### Remove

```sh
git -C "$REPO" worktree remove "$WT"
git -C "$REPO" branch -d "$BRANCH"     # only a branch you created, and only if merged
```

Three rules, each one guarding against a real way to lose work:

- **A dirty worktree stops teardown.** Show exactly what would be lost — uncommitted changes, untracked files, unpushed commits — and let the human decide. Never reach for `--force` on their behalf.
- **Never remove a worktree you adopted rather than created.** If it was already there when you arrived, it is someone else's context; you have no idea what is open in it.
- **Never delete a branch you did not create.** `-d` (not `-D`) so git itself refuses an unmerged branch.

Already gone? Report "already gone" and succeed. Teardown is idempotent in the same spirit as adopt.

### List

```sh
git -C "$REPO" worktree list
```

Worth pairing with a staleness signal when the user asks to clean up — a worktree whose branch is fully merged into the base is a teardown candidate. Offer them; do not remove on your own initiative.

If paths look wrong after a move or a restore, `git worktree repair <path>` rewrites the back-pointers. Git stores absolute paths in `.git/worktrees/<name>/gitdir` and in each worktree's `.git` file, so moving a worktree by hand always needs a repair.

## The base ref

Never assume `main`. Repos default to `develop`, `trunk`, and `master` in the wild, and getting this wrong silently produces an empty or enormous diff. The ladder, in order:

1. `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name` — authoritative when the GitHub CLI is available and authenticated.
2. `git symbolic-ref --short refs/remotes/origin/HEAD` — the local record, if it has been set.
3. `git remote set-head origin --auto` to repair an unset `origin/HEAD`, then retry the previous step. This is the step most implementations skip, and it is the one that turns a failure into an answer.
4. Whichever of `origin/main` / `origin/master` actually exists.
5. Ask the human. Do not guess past this point.

Everything downstream — `git diff <base>...HEAD`, ahead/behind counts, the branch a worktree is cut from — uses the answer.

## Rebase or merge

Syncing a feature branch with its base has one default here, and it does not depend on whether a pull request is open:

> **Rebase onto the base to sync a feature branch — published or not. Merging the base in is an exception that needs a stated reason and the user's consent.**

The default is rebase because that is the history worth having: a feature branch that reads as a linear sequence of its own commits, with the base's work underneath rather than braided through it. A repo that merges the base in on every sync accumulates one merge commit per sync, and the branch's own story becomes unreadable long before it lands.

Rebasing does have a real cost, and it is mechanical rather than aesthetic: it rewrites commit SHAs. Once a pull request is open, its review threads are anchored to those commits, so a force-push marks every one of them outdated — human and bot findings alike. That is the cost to **disclose and weigh**, not a bar. It is also the one pre-baked reason to propose the merge exception.

In practice:

```sh
git fetch origin
git rev-list --left-right --count "origin/$BASE"...HEAD   # "<behind>\t<ahead>"; left > 0 means behind
git rebase "origin/$BASE"
```

- **Rebase is the answer unless someone has said otherwise for this branch.** No pull request, an open one, a shared branch — the recommendation is the same.
- **A branch with no remote counterpart rebases straight through.** Nothing points at those SHAs, so nothing can break; this is the cheap-and-reversible class, and it needs no confirmation.
- **A published branch previews once and waits.** One confirmation covers the rebase *and* the `--force-with-lease` push that follows — they are a single decision, and asking twice asks the same question twice. Name what it costs: the base being synced, the commits being rewritten, and the number of unresolved review threads that will go outdated.
- **Count the threads before you ask.** On a branch with an open PR, query the GraphQL `reviewThreads` connection for unresolved threads and put the number in the preview. "3 review threads will be marked outdated" is a fact the user can decide on; "this may outdate review comments" is not.
- **Unresolved threads are the reason to *offer* the merge exception — not to take it.** Still recommend the rebase; name merge as the available alternative alongside the count. A preference that folds in the case that argues against it was never a preference.
- **`--force-with-lease`, never bare `--force`** — the lease is what stops you overwriting a commit someone else pushed while you were rebasing.
- **On conflict**, stop and surface it (`git diff --name-only --diff-filter=U`). Propose a resolution per file and confirm before writing. A conflict resolution is a code change: run the repo's test gate afterward.

### The merge exception

When the user takes the merge — or asks for it outright — it is still a sync, and it says so:

```sh
git merge "origin/$BASE" -m "chore(repo): sync with origin $BASE"
```

- **Never git's default subject.** `Merge branch 'main' into issue-42-tailwind-4-foundation` is what git writes when nobody chose a message, and it reads that way forever in `git log`. The fixed subject is the message.
- **Interpolate the base, don't hardcode `main`.** The [base ref](#the-base-ref) ladder exists because `develop` and `trunk` repos are real; a subject that says `main` in one of them is simply false.
- **No `--no-ff`.** If the sync can fast-forward, the branch had nothing of its own to preserve and git writes no commit at all — there is no subject to fix, and forcing one manufactures an empty merge commit.
- **State the reason in the same breath as the ask.** "Merging instead of rebasing because this PR has 3 unresolved review threads" is a reason. "Merging to be safe" is not; if you cannot name what rebasing would break, rebase.

### Never bare `git pull`

`git pull` on a branch behind its remote merges by default, and writes `Merge branch 'main' of github.com:owner/repo` without asking anyone. Use `git pull --rebase`, or `git pull --ff-only` when you want the sync to fail loudly rather than resolve itself. The same holds for `git pull` invoked to refresh the base branch itself — configure it or pass the flag, but never let the default run.

## Containers and remote boxes

Git worktrees store **absolute** paths. If a repo is bind-mounted into a container at a path different from the host's, every worktree inside it breaks.

- Mount **both** `$WORKTREE_ROOT` and the main checkout. A worktree's real git directory lives under the main repo's `.git/worktrees/`; mounting only the worktree yields a broken checkout.
- Mount both at the **same absolute path** inside and outside the container. This is the robust answer.
- Second belt, on git 2.48+: `git config worktree.useRelativePaths true` and `git worktree repair --relative-paths`. Relative pointers survive remapping *as long as the repo and the worktree root keep their relative positions* — which argues for siding them, e.g. `~/code/<repo>` and `~/worktrees/<repo>`.

A GUI dev tool that manages worktrees is welcome to **observe** these — Orca and its peers read `git worktree list` and typically have a setting to surface externally-created worktrees. That is a one-time UI configuration on whichever machine runs the GUI, and it is the only asymmetry between machines.

**No skill may create or remove a worktree through a vendor CLI**: the moment one does, the two machines diverge. A vendor's own *metadata* about a worktree — the issue its card links to, a status, a comment — is a different layer and is fair game, because it exists only inside that tool and has no git equivalent to diverge from. A companion skill may reconcile that layer (**orcakit** does, for Orca) as long as the worktree itself is still created and destroyed here. gitkit never calls in that direction: it must keep working on a machine where no such tool is installed.

## Notes

- **gitkit is the single source of truth for what it owns.** A calling skill may hold policy about *when* to ask — that a PR is worth pulling down, that a branch is ready to publish — but never about *how* the git operation is done.
- **Restating a conclusion is allowed; restating the derivation is the bug.** Every public skill is installed on its own, into repos where gitkit may not exist, so a caller that needs a git fact has to carry enough of one to keep working — and that requirement outranks tidiness. The line runs between the two: a caller may state gitkit's **answer** together with its degradation fallback ("gitkit owns the sync rule, and it resolves to rebase; without gitkit, rebase onto the base"), and may not reproduce the **reasoning that produces** the answer — the full base-ref ladder, the worktree path formula, the rebase-versus-merge argument. The answer is one line that a rename cannot silently invalidate; the derivation is the thing that drifts. Compliant examples worth reading: prkit and mergekit each name the rebase conclusion and its one-confirmation rule without re-deriving them, and wikikit and designkit each name `gh repo view --json defaultBranchRef` as a base-ref fallback without carrying the five-rung ladder.
- **gitkit never implements, commits, or opens anything.** It prepares the ground and tears it down. Writing code in the worktree, committing, and publishing belong to other skills.
- **Destructive steps preview and confirm.** Removing a worktree, deleting a branch, and rebasing a *published* branch each show what is about to happen and wait for an OK. Creating, adopting, and rebasing an unpushed branch are cheap and reversible — those run straight through. The line is whether anything outside this machine points at what you are about to rewrite, not which command you typed.
- **No shell available** (e.g. a browser-based agent)? Then you cannot run git. Reason from what the user provides and **print the exact commands** as a codeblock for them to run — never report a worktree created or removed that you could not perform.
